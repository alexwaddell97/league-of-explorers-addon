-- The Bestiary's data: every open-world rare (Data/Rares.lua), merged with
-- what the guild has found and what you have seen, grouped by zone and
-- sorted by creature type.
--
-- Creature types aren't in the rare list. They are learned two ways: from
-- the creature itself when you see one (UnitCreatureType), and by asking
-- the game for the creature's tooltip by its id (a "unit:" hyperlink),
-- quietly, a few a second, out of combat. Both are kept in db.creatures, so
-- each creature is only asked about once.

local _, ns = ...

local B = {}
ns.Bestiary = B

-- The game's creature types in English, for reading tooltips on English
-- clients; types learned from creatures you see (in your client's language)
-- are added as they come.
local TYPES = { "Beast", "Humanoid", "Undead", "Elemental", "Demon", "Dragonkin", "Giant", "Mechanical", "Critter" }

function B.Type(id)
	local c = ns.db.creatures[id]
	return c and c.type or nil
end

function B.Learn(id, ctype, level)
	if not id then return end
	local c = ns.db.creatures[id] or {}
	if type(ctype) == "string" and ctype ~= "" then
		c.type = ctype
		ns.db.typeNames = ns.db.typeNames or {}
		ns.db.typeNames[ctype] = true
	end
	if type(level) == "number" and level > 0 then c.level = level end
	ns.db.creatures[id] = c
end

---------------------------------------------------------------------------
-- Asking the game for a creature's type
---------------------------------------------------------------------------
local scan
local function tooltipLines(id)
	local link = ("unit:Creature-0-0-0-0-%d-0000000000"):format(id)
	if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
		local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
		if ok and type(data) == "table" and type(data.lines) == "table" then
			local out = {}
			for i, l in ipairs(data.lines) do out[i] = l.leftText end
			return out
		end
	end
	if not scan then
		scan = CreateFrame("GameTooltip", "LeagueOfExplorersScanTip", UIParent, "GameTooltipTemplate")
	end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	if not pcall(scan.SetHyperlink, scan, link) then return nil end
	local out = {}
	for i = 1, scan:NumLines() do
		local fs = _G["LeagueOfExplorersScanTipTextLeft" .. i]
		out[i] = fs and fs:GetText()
	end
	scan:Hide()
	return out
end

local function typeFromLines(lines)
	if type(lines) ~= "table" then return nil end
	local known = {}
	for _, t in ipairs(TYPES) do known[#known + 1] = t end
	for t in pairs(ns.db.typeNames or {}) do known[#known + 1] = t end
	for i = 2, #lines do
		local text = lines[i]
		if type(text) == "string" then
			for _, t in ipairs(known) do
				if text:find(t, 1, true) then return t end
			end
		end
	end
	return nil
end

-- Lookups run a few at a time: the first ask for a creature starts the
-- server's answer, a later ask reads it. Wanted creatures (the zone open in
-- the Bestiary) jump the queue; the rest are learned in the background after
-- login, so the Bestiary rarely has to wait at all. Each is kept for good.
local MAX_TRIES = 5
local queue, tries, running = {}, {}, false

local function pump()
	if #queue == 0 then
		running = false
		ns.Fire("CREATURES_SETTLED")
		return
	end
	if ns.InCombat() then
		ns.After(2, pump)
		return
	end
	-- Ask about a handful at once: their answers come back together.
	local batch = {}
	for i = 1, math.min(6, #queue) do batch[i] = table.remove(queue, 1) end
	local learned = false
	for _, id in ipairs(batch) do
		if not B.Type(id) then
			local t = typeFromLines(tooltipLines(id))
			if t then
				B.Learn(id, t)
				learned = true
			else
				tries[id] = (tries[id] or 0) + 1
				if tries[id] < MAX_TRIES then queue[#queue + 1] = id end
			end
		end
	end
	if learned then ns.Fire("CREATURE_LEARNED") end
	ns.After(0.25, pump)
end

local function start()
	if not running then
		running = true
		ns.After(0.05, pump)
	end
end

-- urgent: put it at the front (the zone you're looking at).
function B.Want(id, urgent)
	if not id or B.Type(id) or (tries[id] or 0) >= MAX_TRIES then return end
	for i, q in ipairs(queue) do
		if q == id then
			if urgent and i > 1 then
				table.remove(queue, i)
				table.insert(queue, 1, id)
			end
			return
		end
	end
	if urgent then table.insert(queue, 1, id) else queue[#queue + 1] = id end
	start()
end

-- True while any creature in the list still has a lookup to come.
function B.Pending(list)
	for _, r in ipairs(list or {}) do
		if not B.Type(r.id) and (tries[r.id] or 0) < MAX_TRIES then return true end
	end
	return false
end

-- Learn every rare's type in the background, a while after login.
ns.Listen("READY", function()
	ns.After(20, function()
		for id in pairs(ns.RareList or {}) do B.Want(id) end
	end)
end)

---------------------------------------------------------------------------
-- The catalogue
---------------------------------------------------------------------------

-- id -> { id, name, map, zone, x, y, level, levelMax, elite } from Data/Rares.lua.
local catalog
function B.Catalog()
	if catalog then return catalog end
	catalog = {}
	for id, r in pairs(ns.RareList or {}) do
		catalog[id] = {
			id = id, name = r[1], map = r[2], x = r[3], y = r[4],
			level = r[5], levelMax = r[6], elite = r[7],
			zone = ns.Exploration.ZoneOf(r[2]) or r[2],
		}
	end
	return catalog
end

-- Order of creature types in a zone; unknown types go last.
local function typeRank(t) return t and 0 or 1 end

-- Every zone with rares, by name; in each, its rares by type then name:
-- { id, name, list = { rare }, mine = n, guild = n }, where each rare is
-- { id, name, type, level, levelMax, elite, zone, x, y, state, first,
--   mine, find, finders, display }; state "mine" (you found it), "guild"
-- (someone in the guild has), "unknown" (no one yet).
function B.Zones(members)
	local me = ns.Me()
	local zones, list = {}, {}
	local function slot(zoneID, id)
		local z = zones[zoneID]
		if not z then
			z = { id = zoneID, name = ns.MapName(zoneID) or "Unknown lands", list = {}, byId = {} }
			zones[zoneID] = z
			list[#list + 1] = z
		end
		local r = z.byId[id]
		if not r then
			r = { id = id, zone = zoneID, finders = {} }
			z.byId[id] = r
			z.list[#z.list + 1] = r
		end
		return r
	end
	for id, c in pairs(B.Catalog()) do
		local r = slot(c.zone, id)
		r.name, r.level, r.levelMax, r.elite, r.x, r.y, r.map = c.name, c.level, c.levelMax, c.elite, c.x, c.y, c.map
	end
	for _, e in ipairs(ns.Ledger.Query({ kind = "rare", whoIn = members })) do
		local c = B.Catalog()[e.key]
		local zone = (c and c.zone) or e.map
		if zone then
			local r = slot(zone, e.key)
			r.name = r.name or e.name
			r.finders[#r.finders + 1] = e
			r.last = r.last or e
			if ns.Ledger.IsFirst(e) then r.first = e end
			if e.who == me then r.mine = e end
		end
	end
	for _, f in pairs(ns.db.finds) do
		if f.kind == "rare" then
			local c = B.Catalog()[f.id]
			local s = f.sightings[#f.sightings]
			local zone = (c and c.zone) or (f.first and f.first.zone) or (s and s.zone)
			if zone then
				local r = slot(zone, f.id)
				r.name = r.name or f.name
				r.find, r.display = f, f.display
			end
		end
	end
	for _, z in ipairs(list) do
		z.mine, z.guild = 0, 0
		for _, r in ipairs(z.list) do
			r.type = B.Type(r.id)
			-- Yours once you have found it alive; a rare seen only slain stays
			-- in shadow, named, like one only the guild has found.
			r.state = r.mine and "mine" or ((#r.finders > 0 or r.find) and "guild") or "unknown"
			if r.state == "mine" then z.mine = z.mine + 1 end
			if r.state ~= "unknown" then z.guild = z.guild + 1 end
		end
		table.sort(z.list, function(a, b)
			if typeRank(a.type) ~= typeRank(b.type) then return typeRank(a.type) < typeRank(b.type) end
			if (a.type or "") ~= (b.type or "") then return (a.type or "") < (b.type or "") end
			if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
			return (a.name or "") < (b.name or "")
		end)
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

-- A rare's level as text: "24", "24-26", with "elite" when it is.
function B.LevelText(r)
	if not r.level then return nil end
	local s = tostring(r.level)
	if r.levelMax and r.levelMax ~= r.level then s = s .. "-" .. r.levelMax end
	return s .. (r.elite and " elite" or "")
end
