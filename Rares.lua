-- Rares and treasures: what the client tells an addon about them nearby.
--
--   * Vignettes (VIGNETTE_MINIMAP_UPDATED, VIGNETTES_UPDATED,
--     C_VignetteInfo): Forever's minimap marks rares and treasure chests.
--     A creature behind a vignette is a rare; a game object, a treasure.
--     The vignette also gives an exact map position.
--   * Nameplates, target and mouseover: any creature whose classification
--     is "rare" or "rareelite".
--
-- Each sighting goes into the bestiary (db.finds). The first sighting of a
-- living rare, or of a treasure, by a character also writes a ledger entry,
-- which is what earns points; later sightings are logged but earn nothing.
-- Unit reads can be secret values on this client: those read as unknown
-- and the unit is passed over.

local _, ns = ...

local R = {}
ns.Rares = R

local Readable = ns.Readable
local CLASS_RARE = { rare = true, rareelite = true }

local KEEP_SIGHTINGS = 40     -- recent sightings kept per find
local SAME_SIGHTING = 600     -- seconds: the same find seen again is one sighting
local DEBOUNCE = 3            -- seconds before looking at the same GUID again

-- "Creature-0-4372-0-17-61-0000123456" -> "Creature", 61
local function guidParts(guid)
	if type(guid) ~= "string" then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	return kind, tonumber(id)
end

local recent, recentCount = {}, 0
local function fresh(guid)
	local now = GetTime()
	local t = recent[guid]
	if t and now - t < DEBOUNCE then return false end
	if not t then
		recentCount = recentCount + 1
		if recentCount > 300 then
			for g, at in pairs(recent) do
				if now - at >= DEBOUNCE then
					recent[g] = nil
					recentCount = recentCount - 1
				end
			end
		end
	end
	recent[guid] = now
	return true
end

-- Where the player stands: map, x, y (0-100).
local function playerWhere()
	local map = C_Map.GetBestMapForUnit("player")
	if not map then return nil end
	local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
	if not pos then return { map = map } end
	local x, y = pos:GetXY()
	if not x or (x == 0 and y == 0) then return { map = map } end
	return { map = map, x = x * 100, y = y * 100 }
end

---------------------------------------------------------------------------
-- Recording
---------------------------------------------------------------------------

function R.Record(kind, id, name, where, dead, source)
	if not id then return end
	local me = ns.Me()
	if not me then return end
	local key = kind .. ":" .. id
	local f = ns.db.finds[key]
	if not f then
		f = { kind = kind, id = id, count = 0, sightings = {} }
		ns.db.finds[key] = f
	end
	if name and name ~= "" then f.name = name end
	where = where or playerWhere() or {}
	local zone = where.map and ns.Exploration.ZoneOf(where.map) or where.map
	local now = ns.Now()

	local last = f.sightings[#f.sightings]
	if last and last.who == me and now - last.t < SAME_SIGHTING then
		-- Still the same encounter: keep the better position, note a death.
		if where.x and not last.x then last.map, last.x, last.y = where.map, where.x, where.y end
		if dead then last.dead = true end
		return
	end

	local s = { t = now, who = me, map = where.map, zone = zone, x = where.x, y = where.y, dead = dead or nil, source = source }
	table.insert(f.sightings, s)
	while #f.sightings > KEEP_SIGHTINGS do table.remove(f.sightings, 1) end
	f.count = f.count + 1
	if not f.first then
		f.first = { t = now, who = me, map = where.map, zone = zone, x = where.x, y = where.y }
	end
	ns.Debug("sighting", kind, id, f.name or "?", source)

	-- Only a living rare counts as found: a corpse someone else left does not.
	if not dead then
		ns.Ledger.Award(kind, id, { name = f.name, map = zone, x = where.x, y = where.y })
	end
	ns.Fire("SIGHTING", f, s)
end

---------------------------------------------------------------------------
-- Units: nameplates, target, mouseover
---------------------------------------------------------------------------

function R.Unit(unit, source)
	if not Readable(UnitExists(unit)) then return end
	local guid = Readable(UnitGUID(unit))
	if not guid then return end
	local kind, id = guidParts(guid)
	if kind ~= "Creature" and kind ~= "Vehicle" then return end
	if not fresh(guid) then return end
	if Readable(UnitIsPlayer(unit)) or Readable(UnitPlayerControlled(unit)) then return end
	local class = Readable(UnitClassification(unit))
	if not CLASS_RARE[class or ""] then return end
	local dead = Readable(UnitIsDead(unit)) and true or false
	R.Record("rare", id, Readable(UnitName(unit)), nil, dead, source)
end

---------------------------------------------------------------------------
-- Vignettes
---------------------------------------------------------------------------

local function vignetteWhere(vguid)
	local V = C_VignetteInfo
	if not (V and V.GetVignettePosition) then return nil end
	local map = C_Map.GetBestMapForUnit("player")
	for _ = 1, 4 do
		if not map or map == 0 then return nil end
		local ok, pos = pcall(V.GetVignettePosition, vguid, map)
		if ok and pos then
			local x, y
			if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
			if x and y and not (x == 0 and y == 0) then
				return { map = map, x = x * 100, y = y * 100 }
			end
		end
		local i = C_Map.GetMapInfo(map)
		map = i and i.parentMapID
	end
	return nil
end

function R.Vignette(vguid)
	local V = C_VignetteInfo
	if not (vguid and V and V.GetVignetteInfo) then return end
	if not fresh(vguid) then return end
	local ok, vi = pcall(V.GetVignetteInfo, vguid)
	if not ok or type(vi) ~= "table" then return end
	local kind, id = guidParts(Readable(vi.objectGUID))
	local what
	if kind == "Creature" or kind == "Vehicle" then
		what = "rare"
	elseif kind == "GameObject" then
		what = "treasure"
	else
		return
	end
	R.Record(what, id, Readable(vi.name), vignetteWhere(vguid), Readable(vi.isDead) and true or false, "vignette")
end

-- A full look at every vignette on the minimap; out of combat only.
local scanPending, scanQueued = false, false

function R.Scan()
	scanQueued = false
	if ns.InCombat() then
		scanPending = true
		return
	end
	scanPending = false
	local V = C_VignetteInfo
	if not (V and V.GetVignettes) then return end
	local ok, list = pcall(V.GetVignettes)
	if not ok or type(list) ~= "table" then return end
	for _, g in ipairs(list) do
		local got, vi = pcall(V.GetVignetteInfo, g)
		if got and type(vi) == "table" and Readable(vi.onMinimap) then R.Vignette(g) end
	end
end

local function queueScan()
	if scanQueued then return end
	scanQueued = true
	ns.After(2, R.Scan)
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

local function detect(what) return ns.db.settings.detect[what] end

ns.Listen("READY", function()
	ns.On("VIGNETTE_MINIMAP_UPDATED", function(_, vguid, onMinimap)
		if detect("vignette") and onMinimap then R.Vignette(vguid) end
	end)
	ns.On("VIGNETTES_UPDATED", function()
		if detect("vignette") then queueScan() end
	end)
	ns.On("PLAYER_REGEN_ENABLED", function()
		if scanPending then queueScan() end
	end)
	ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit)
		if detect("nameplate") then R.Unit(unit, "nameplate") end
	end)
	ns.On("PLAYER_TARGET_CHANGED", function()
		if detect("target") then R.Unit("target", "target") end
	end)
	ns.On("UPDATE_MOUSEOVER_UNIT", function()
		if detect("target") then R.Unit("mouseover", "mouseover") end
	end)
	queueScan()
end)

-- Finds of one kind ("rare" or "treasure"), most recently seen first.
function R.List(kind)
	local out = {}
	for _, f in pairs(ns.db.finds) do
		if f.kind == kind then out[#out + 1] = f end
	end
	table.sort(out, function(a, b)
		local ta = a.sightings[#a.sightings]
		local tb = b.sightings[#b.sightings]
		return (ta and ta.t or 0) > (tb and tb.t or 0)
	end)
	return out
end

function R.Status()
	local V = C_VignetteInfo
	ns.Print("vignette API:", (V and V.GetVignettes) and "yes" or "MISSING")
	local n = 0
	if V and V.GetVignettes then
		local ok, list = pcall(V.GetVignettes)
		if ok and type(list) == "table" then n = #list end
	end
	ns.Print(("vignettes around you now: %d"):format(n))
	ns.Print(("bestiary: %d rares, %d treasures"):format(#R.List("rare"), #R.List("treasure")))
end
