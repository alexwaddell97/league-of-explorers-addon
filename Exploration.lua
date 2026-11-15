-- Exploration: zones visited, areas charted, zones fully explored and
-- continents reached.
--
-- The client reports explored areas through
-- C_MapExplorationInfo.GetExploredMapTextures(uiMapID): one record per
-- explored overlay, carrying its texture file IDs. Data/Areas.lua lists every
-- overlay of each zone (explored or not) by its first file ID, so explored
-- out of total is a zone's progress. A zone with no overlays (a capital, a
-- small isle) counts as discovered when visited and has no "fully explored".
--
-- Baseline: the first time a character opens its journal, exploration it
-- had already done is recorded without points, so an old character can't
-- cash in years of travel, and an alt can't be brought in to farm them.

local _, ns = ...

local E = {}
ns.Exploration = E

local MapType = Enum and Enum.UIMapType or {}
local T_WORLD = MapType.World or 1
local T_CONTINENT = MapType.Continent or 2
local T_ZONE = MapType.Zone or 3
local AZEROTH = 947

-- Battlegrounds report as zones; they are not part of the world to explore.
local EXCLUDE = { [1459] = true, [1460] = true, [1461] = true }

local function info(mapID)
	return mapID and C_Map.GetMapInfo(mapID) or nil
end

-- Walks up from any map (a cave, a subzone) to the map of the given type.
local function upTo(mapID, mapType)
	for _ = 1, 8 do
		local i = info(mapID)
		if not i then return nil end
		if i.mapType == mapType then return mapID end
		if i.mapType and i.mapType < mapType then return nil end
		mapID = i.parentMapID
		if not mapID or mapID == 0 then return nil end
	end
	return nil
end

function E.ZoneOf(mapID) return upTo(mapID, T_ZONE) end
function E.ContinentOf(mapID) return upTo(mapID, T_CONTINENT) end

function E.CurrentZone()
	local m = C_Map.GetBestMapForUnit("player")
	local zone = m and E.ZoneOf(m)
	if zone and EXCLUDE[zone] then return nil end
	return zone
end

-- Set of every file ID the client reports explored on a map.
function E.ExploredSet(mapID)
	local set = {}
	local api = C_MapExplorationInfo
	if not (api and api.GetExploredMapTextures) then return set end
	local ok, list = pcall(api.GetExploredMapTextures, mapID)
	if not ok or type(list) ~= "table" then return set end
	for _, rec in ipairs(list) do
		for _, id in ipairs(rec.fileDataIDs or {}) do set[id] = true end
	end
	return set
end

-- explored, total for a zone from the client's current state.
function E.Progress(mapID, set)
	local areas = ns.Areas[mapID]
	if not areas then return 0, 0 end
	set = set or E.ExploredSet(mapID)
	local n = 0
	for _, id in ipairs(areas) do
		if set[id] then n = n + 1 end
	end
	return n, #areas
end

---------------------------------------------------------------------------
-- The atlas: every continent and its zones, built once from the client's
-- map tree plus the zones in Data/Areas.lua (Forever's own zones included).
---------------------------------------------------------------------------

local atlas

function E.Atlas()
	if atlas then return atlas end
	local byCont, seen = {}, {}
	local continents = {}

	local function contEntry(id)
		if not byCont[id] then
			local name = ns.MapName(id) or ("Map " .. id)
			byCont[id] = { id = id, name = name, zones = {} }
			table.insert(continents, byCont[id])
		end
		return byCont[id]
	end

	local function addZone(zoneID)
		if seen[zoneID] or EXCLUDE[zoneID] then return end
		local i = info(zoneID)
		if not i or i.mapType ~= T_ZONE or not i.name then return end
		seen[zoneID] = true
		-- A zone with no continent above it (an isle of its own) is filed
		-- under the top map it does have.
		local cont = E.ContinentOf(zoneID) or upTo(zoneID, T_WORLD) or i.parentMapID or 0
		local areas = ns.Areas[zoneID]
		table.insert(contEntry(cont).zones, { id = zoneID, name = i.name, total = areas and #areas or 0 })
	end

	local ok, list = pcall(C_Map.GetMapChildrenInfo, AZEROTH, T_CONTINENT, false)
	if ok and type(list) == "table" then
		for _, c in ipairs(list) do
			local zok, zones = pcall(C_Map.GetMapChildrenInfo, c.mapID, T_ZONE, false)
			if zok and type(zones) == "table" then
				for _, z in ipairs(zones) do addZone(z.mapID) end
			end
		end
	end
	for zoneID in pairs(ns.Areas) do addZone(zoneID) end

	for _, c in ipairs(continents) do
		table.sort(c.zones, function(a, b) return a.name < b.name end)
	end
	table.sort(continents, function(a, b)
		if #a.zones ~= #b.zones then return #a.zones > #b.zones end
		return a.name < b.name
	end)
	atlas = continents
	return atlas
end

function E.ZoneCount()
	local n = 0
	for _, c in ipairs(E.Atlas()) do n = n + #c.zones end
	return n
end

function E.AreaCount()
	local n = 0
	for _, areas in pairs(ns.Areas) do n = n + #areas end
	return n
end

---------------------------------------------------------------------------
-- Area masks: which of a zone's areas (by their order in Data/Areas.lua)
-- are charted, as hex digits, four areas a digit. Small enough to share.
---------------------------------------------------------------------------

function E.Mask(zoneID, charted)
	local areas = ns.Areas[zoneID] or {}
	local digits = {}
	for i = 1, #areas, 4 do
		local v = 0
		for b = 0, 3 do
			local id = areas[i + b]
			if id and charted(id) then v = v + 2 ^ b end
		end
		digits[#digits + 1] = ("%x"):format(v)
	end
	return table.concat(digits)
end

function E.MaskAreas(zoneID, mask)
	local out = {}
	local areas = ns.Areas[zoneID]
	if not areas or type(mask) ~= "string" then return out end
	for d = 1, #mask do
		local v = tonumber(mask:sub(d, d), 16) or 0
		for b = 0, 3 do
			local id = areas[(d - 1) * 4 + b + 1]
			if id and v % 2 == 1 then out[#out + 1] = id end
			v = math.floor(v / 2)
		end
	end
	return out
end

-- The baseline as entries, one per zone known before the journal, worth no
-- points, so guildmates' journals can show the guild's whole atlas.
local function shareBaseline(ch)
	for zoneID, rec in pairs(ch.zones) do
		if rec.base then
			ns.Ledger.Award("base", zoneID, {
				map = zoneID,
				mask = E.Mask(zoneID, function(id) return ch.areas[id] == 0 end),
			})
		end
	end
	ch.baseShared = true
end

---------------------------------------------------------------------------
-- Baseline
---------------------------------------------------------------------------

local function takeBaseline(ch)
	local zones, areas = 0, 0
	for _, cont in ipairs(E.Atlas()) do
		for _, z in ipairs(cont.zones) do
			local set = E.ExploredSet(z.id)
			local n, total = E.Progress(z.id, set)
			if n > 0 then
				zones = zones + 1
				local rec = ch.zones[z.id] or {}
				rec.base = true
				rec.explored, rec.total = n, total
				if total > 0 and n >= total then rec.full = 0 end
				ch.zones[z.id] = rec
				for _, id in ipairs(ns.Areas[z.id] or {}) do
					if set[id] then
						ch.areas[id] = 0
						areas = areas + 1
					end
				end
				local c = E.ContinentOf(z.id)
				if c then ch.continents[c] = ch.continents[c] or 0 end
			end
		end
	end
	ch.baselineAt = ns.Now()
	shareBaseline(ch)
	ns.Print(("Added %d zones and %d areas you had already explored. These count toward your rank but not points. New discoveries earn points."):format(zones, areas))
end

---------------------------------------------------------------------------
-- Checking the player's surroundings
---------------------------------------------------------------------------

-- The area name from the game's "Discovered: X" message, kept a few seconds
-- so the check that follows can name the area it finds.
local lastName, lastNameAt = nil, 0

local function areaName()
	if lastName and GetTime() - lastNameAt < 6 then return lastName end
	local sub = GetSubZoneText and GetSubZoneText()
	if sub and sub ~= "" then return sub end
	return nil
end

function E.Check()
	local ch = ns.Char()
	if not ch or not ch.baselineAt then return end
	local zone = E.CurrentZone()
	if not zone then return end
	local zoneName = ns.MapName(zone)
	local rec = ch.zones[zone]
	if not rec then
		rec = {}
		ch.zones[zone] = rec
	end

	if not rec.seen and not rec.base then
		rec.seen = ns.Now()
		ns.Ledger.Award("zone", zone, { map = zone, name = zoneName })
	end

	local cont = E.ContinentOf(zone)
	if cont and not ch.continents[cont] then
		ch.continents[cont] = ns.Now()
		ns.Ledger.Award("continent", cont, { map = cont, name = ns.MapName(cont) })
	end

	local areas = ns.Areas[zone]
	if not areas then
		if ns.Work then ns.Work.Check("zone", zone, { map = zone }) end
		return
	end
	local set = E.ExploredSet(zone)
	local n = 0
	for _, id in ipairs(areas) do
		if set[id] then
			n = n + 1
			if not ch.areas[id] then
				ch.areas[id] = ns.Now()
				ns.Ledger.Award("area", id, { map = zone, name = areaName() })
			end
		end
	end
	rec.explored, rec.total = n, #areas
	if n >= #areas and not rec.full then
		rec.full = ns.Now()
		ns.Ledger.Award("zonefull", zone, { map = zone, name = zoneName })
	end
	if ns.Work then ns.Work.Check("zone", zone, { map = zone, full = rec.full ~= nil }) end
end

-- Many events can fire together (zone change, discovery, map update); they
-- share one check half a second later.
local queued = false
local function queueCheck()
	if queued then return end
	queued = true
	ns.After(0.5, function()
		queued = false
		E.Check()
	end)
end
E.QueueCheck = queueCheck

-- "Discovered: %s" -> "^Discovered: (.+)$", from the client's own strings so
-- every language works.
local function toPattern(fmt)
	if type(fmt) ~= "string" then return nil end
	local p = fmt:gsub("([%%%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
	p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "%%d+")
	return "^" .. p .. "$"
end

local discoveredPatterns

local function onInfoMessage(_, a, b)
	local msg = type(b) == "string" and b or (type(a) == "string" and a) or nil
	if not msg then return end
	if not discoveredPatterns then
		discoveredPatterns = {}
		for _, fmt in ipairs({ _G.ERR_ZONE_EXPLORED, _G.ERR_ZONE_EXPLORED_XP }) do
			local p = toPattern(fmt)
			if p then table.insert(discoveredPatterns, p) end
		end
	end
	for _, p in ipairs(discoveredPatterns) do
		local name = msg:match(p)
		if name then
			lastName, lastNameAt = name, GetTime()
			queueCheck()
			return
		end
	end
end

ns.Listen("READY", function()
	local ch = ns.Char()
	if not ch.baselineAt then
		takeBaseline(ch)
	elseif not ch.baseShared then
		shareBaseline(ch) -- journals begun before baselines were shared
	end
	ns.On("ZONE_CHANGED_NEW_AREA", queueCheck)
	ns.On("ZONE_CHANGED", queueCheck)
	ns.On("ZONE_CHANGED_INDOORS", queueCheck)
	ns.On("MAP_EXPLORATION_UPDATED", queueCheck)
	ns.On("UI_INFO_MESSAGE", onInfoMessage)
	-- A slow backstop in case the client sends none of the above.
	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(20, function()
			if not ns.InCombat() then queueCheck() end
		end)
	end
	queueCheck()
end)

ns.Commands.status = function()
	local api = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
	ns.Print("exploration API:", api and "yes" or "MISSING")
	ns.Print(("maps: %d zones on %d continents, %d areas (data build %s)"):format(
		E.ZoneCount(), #E.Atlas(), E.AreaCount(), tostring(ns.AREA_BUILD)))
	local zone = E.CurrentZone()
	if zone then
		local n, total = E.Progress(zone)
		ns.Print(("here: %s (%d), %d of %d areas"):format(ns.MapName(zone) or "?", zone, n, total))
	else
		ns.Print("here: not in a tracked zone")
	end
	if ns.Rares and ns.Rares.Status then ns.Rares.Status() end
end
