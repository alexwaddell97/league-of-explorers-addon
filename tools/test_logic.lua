-- Offline test: loads the addon against a fake game API and walks a
-- player through a session. Run from the addon folder with any Lua 5.1+:
--   luatex --luaonly tools/test_logic.lua      (or: lua tools/test_logic.lua)
-- It checks detection and points, and builds every journal page against
-- permissive fake frames so a nil slip in UI code shows up here.

local failures, checks = 0, 0
local function ok(cond, msg)
	checks = checks + 1
	if not cond then
		failures = failures + 1
		print("FAIL: " .. msg)
	end
end
local function eq(a, b, msg) ok(a == b, ("%s (got %s, want %s)"):format(msg, tostring(a), tostring(b))) end

---------------------------------------------------------------------------
-- Fake clock and timers
---------------------------------------------------------------------------
local now, gtime = 1794000000, 1000 -- a Thursday in November 2026
function GetServerTime() return now end
date, time = os.date, os.time
function GetTime() return gtime end
local function advance(s) now = now + s; gtime = gtime + s end
local timers = {}
C_Timer = {
	After = function(_, fn) table.insert(timers, fn) end,
	NewTicker = function() return {} end,
}
local function flush()
	for _ = 1, 5 do
		local list = timers
		timers = {}
		for _, fn in ipairs(list) do fn() end
		if #timers == 0 then return end
	end
end

---------------------------------------------------------------------------
-- Permissive fake frames: any method works; a few return real values.
---------------------------------------------------------------------------
local Mock = {}
local NUMERIC = { GetWidth = 100, GetHeight = 100, GetStringWidth = 60, GetFrameLevel = 1,
	GetEffectiveScale = 1, GetLeft = 0, GetTop = 0, GetVerticalScroll = 0, GetStringHeight = 14 }
local function newMock(name)
	local m = { _scripts = {}, _shown = true, _name = name }
	return setmetatable(m, Mock)
end
Mock.__index = function(self, k)
	-- Fields (lower case) are unset until code sets them; methods always exist.
	if type(k) ~= "string" or not k:match("^%u") then return nil end
	if NUMERIC[k] then return function() return NUMERIC[k] end end
	if k == "SetScript" then return function(s, ev, fn) s._scripts[ev] = fn end end
	if k == "GetScript" then return function(s, ev) return s._scripts[ev] end end
	if k == "Show" then return function(s) s._shown = true; if s._scripts.OnShow then s._scripts.OnShow(s) end end end
	if k == "Hide" then return function(s) s._shown = false; if s._scripts.OnHide then s._scripts.OnHide(s) end end end
	if k == "SetShown" then return function(s, v) if v then s:Show() else s:Hide() end end end
	if k == "IsShown" then return function(s) return s._shown end end
	if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
	if k == "GetCenter" then return function() return 0, 0 end end
	if k == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 12, "" end end
	if k == "RegisterEvent" then return function(s, ev) local e = rawget(s, "_events") or {}; rawset(s, "_events", e); e[ev] = true end end
	if k:match("^Create") then return function() return newMock() end end
	return function(s) return s end
end

local eventFrames = {}
function CreateFrame(_, name)
	local f = newMock(name)
	table.insert(eventFrames, f)
	if name then _G[name] = f end
	return f
end
UIParent, Minimap, GameTooltip = newMock(), newMock(), newMock()
STANDARD_TEXT_FONT = "Fonts/FRIZQT__.TTF"
function CreateFont() return newMock() end
function CreateColor(...) return { ... } end
function GetPhysicalScreenSize() return 2560, 1440 end
function SetPortraitTexture() end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) print("  chat: " .. msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end }
GameFontHighlight = newMock()
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = {}
function PlaySound() return true end
function geterrorhandler() return function(e) print("ERROR: " .. tostring(e)); failures = failures + 1 end end
function InCombatLockdown() return false end
function GetLocale() return "enUS" end
function GetCursorPosition() return 0, 0 end
function GetMinimapShape() return "ROUND" end
RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 } }

local function fire(event, ...)
	for _, f in ipairs(eventFrames) do
		local evs = rawget(f, "_events")
		if evs and evs[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
	end
end

---------------------------------------------------------------------------
-- Fake player and world
---------------------------------------------------------------------------
function UnitFullName() return "Tester", "Realm" end
function GetNormalizedRealmName() return "Realm" end
function UnitClass() return "Hunter", "HUNTER" end
function UnitRace() return "Orc" end
function UnitLevel() return 30 end
function UnitFactionGroup() return "Horde" end
function GetSubZoneText() return "" end
function GetZoneText() return "Durotar" end
function strsplit(sep, s)
	local out = {}
	for part in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
	return table.unpack(out)
end
ERR_ZONE_EXPLORED = "Discovered: %s"
ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }

local MAPS = {
	[947] = { name = "Azeroth", mapType = 1, parentMapID = 946 },
	[1414] = { name = "Kalimdor", mapType = 2, parentMapID = 947 },
	[1415] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
	[1411] = { name = "Durotar", mapType = 3, parentMapID = 1414 },
	[1412] = { name = "Mulgore", mapType = 3, parentMapID = 1414 },
	[1429] = { name = "Elwynn Forest", mapType = 3, parentMapID = 1415 },
	[1453] = { name = "Stormwind City", mapType = 3, parentMapID = 1415 },
	[1459] = { name = "Alterac Valley", mapType = 3, parentMapID = 1415 },
	[9001] = { name = "Skull Rock", mapType = 4, parentMapID = 1411 },
}
local here = 1411
local explored = {} -- map -> list of first file IDs explored
C_Map = {
	GetMapInfo = function(id) local m = MAPS[id]; if not m then return nil end; return { mapID = id, name = m.name, mapType = m.mapType, parentMapID = m.parentMapID } end,
	GetMapChildrenInfo = function(parent, mapType)
		local out = {}
		for id, m in pairs(MAPS) do
			if m.parentMapID == parent and m.mapType == mapType then out[#out + 1] = { mapID = id } end
		end
		return out
	end,
	GetBestMapForUnit = function() return here end,
	GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.25 end } end,
	GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end,
	GetMapArtLayerTextures = function() local t = {}; for i = 1, 12 do t[i] = 1000 + i end; return t end,
}
C_MapExplorationInfo = {
	GetExploredMapTextures = function(map)
		local out = {}
		for _, id in ipairs(explored[map] or {}) do
			out[#out + 1] = { fileDataIDs = { id, id + 500000000 }, textureWidth = 300, textureHeight = 200, offsetX = 10, offsetY = 20 }
		end
		return out
	end,
}
local unit = {}
function UnitExists(u) return unit[u] ~= nil end
function UnitGUID(u) return unit[u] and unit[u].guid end
function UnitIsPlayer() return false end
function UnitPlayerControlled() return false end
function UnitClassification(u) return unit[u] and unit[u].class end
function UnitIsDead(u) return unit[u] and unit[u].dead end
function UnitName(u) return unit[u] and unit[u].name end
local vignettes = {}
C_VignetteInfo = {
	GetVignettes = function() local out = {}; for g in pairs(vignettes) do out[#out + 1] = g end; return out end,
	GetVignetteInfo = function(g) return vignettes[g] end,
	GetVignettePosition = function() return { GetXY = function() return 0.4, 0.6 end } end,
}

---------------------------------------------------------------------------
-- Load the addon in .toc order
---------------------------------------------------------------------------
-- A guild of three: you, an officer online, a member offline.
local roster = {
	{ "Tester-Realm", "Guild Master", 0, 30, "Hunter", "Elwynn Forest", "", "", true, 0, "HUNTER" },
	{ "Other-Realm", "Officer", 1, 40, "Mage", "Darkshore", "", "", true, 0, "MAGE" },
	{ "Away-Realm", "Member", 3, 20, "Rogue", "", "", "", false, 0, "ROGUE" },
}
function IsInGuild() return true end
function GetGuildInfo() return "League of Explorers" end
function GetNumGuildMembers() return #roster end
function GetGuildRosterInfo(i) return table.unpack(roster[i]) end
C_GuildInfo = { GuildRoster = function() end }
local sent = {}
C_ChatInfo = {
	RegisterAddonMessagePrefix = function() end,
	SendAddonMessage = function(_, msg) sent[#sent + 1] = msg; return 0 end,
}
-- Runs every OnUpdate script a number of times (the send queue, tweens).
local function tick(n)
	for _ = 1, n or 1 do
		for _, f in ipairs(eventFrames) do
			local fn = rawget(f, "_scripts") and f._scripts.OnUpdate
			if fn then fn(f, 0.25) end
		end
	end
end

local ns = {}
local files = {}
for line in io.lines("LeagueOfExplorers.toc") do
	if not line:match("^##") and line:match("%.lua%s*$") then files[#files + 1] = line:gsub("\\", "/"):gsub("%s+$", "") end
end
for _, f in ipairs(files) do
	local chunk = assert(loadfile(f))
	chunk("LeagueOfExplorers", ns)
end

-- Durotar has 11 areas in the real data: take the first three as explored
-- before the journal is installed.
local DUROTAR = ns.Areas[1411]
local ELWYNN = ns.Areas[1429]
explored[1411] = { DUROTAR[1], DUROTAR[2], DUROTAR[3] }

fire("ADDON_LOADED", "LeagueOfExplorers")
fire("PLAYER_ENTERING_WORLD")
flush()

local db = ns.db
local me = ns.Me()
eq(me, "Tester-Realm", "character key")
local ch = db.chars[me]
ok(ch.baselineAt ~= nil, "baseline taken")
ok(ch.zones[1411] and ch.zones[1411].base, "Durotar known from baseline")
eq(ch.areas[DUROTAR[1]], 0, "baseline area stored as 0")
ok(ch.continents[1414] ~= nil, "Kalimdor known from baseline")
eq(#db.entries, 1, "baseline writes one base entry")
eq(ns.Points.Total(me), 0, "and it is worth nothing")

-- A new area, announced by the game.
advance(60)
explored[1411][4] = DUROTAR[4]
fire("UI_INFO_MESSAGE", 0, "Discovered: Razor Hill")
flush()
eq(#db.entries, 2, "one area entry")
eq(db.entries[2].kind, "area", "entry kind area")
eq(db.entries[2].name, "Razor Hill", "area named from the message")
eq(ns.Points.Total(me), 0, "areas are worth 0 by default")

-- The XP form of the message.
advance(5)
explored[1411][5] = DUROTAR[5]
fire("UI_INFO_MESSAGE", 0, "Discovered Sen'jin Village: 120 experience gained")
flush()
eq(db.entries[3].name, "Sen'jin Village", "area named from the XP message")

-- Every area: fully explored, once. From inside a cave map.
advance(60)
here = 9001
explored[1411] = {}
for i, id in ipairs(DUROTAR) do explored[1411][i] = id end
fire("ZONE_CHANGED")
flush()
ok(ns.Ledger.Has("zonefull", 1411), "Durotar fully explored")
eq(ns.Points.Total(me), 25, "fully explored is worth 25")
fire("ZONE_CHANGED")
flush()
eq(ns.Points.Total(me), 25, "no second fully-explored award")

-- New continent and zone.
advance(600)
here = 1429
explored[1429] = { ELWYNN[1] }
fire("ZONE_CHANGED_NEW_AREA")
flush()
ok(ns.Ledger.Has("zone", 1429), "Elwynn discovered")
ok(ns.Ledger.Has("continent", 1415), "Eastern Kingdoms reached")
eq(ns.Points.Total(me), 25 + 10 + 50, "zone + continent points")

-- A city with no areas: discovered on a visit, never "fully explored".
advance(60)
here = 1453
fire("ZONE_CHANGED_NEW_AREA")
flush()
ok(ns.Ledger.Has("zone", 1453), "Stormwind discovered")
ok(not ns.Ledger.Has("zonefull", 1453), "no fully-explored for a zone without areas")

-- Battlegrounds don't count.
here = 1459
fire("ZONE_CHANGED_NEW_AREA")
flush()
ok(not ns.Ledger.Has("zone", 1459), "battleground ignored")

-- Back to Elwynn: nothing new.
here = 1429
local before = #db.entries
fire("ZONE_CHANGED_NEW_AREA")
flush()
eq(#db.entries, before, "revisiting earns nothing")

-- Rares by target.
advance(30)
unit.target = { guid = "Creature-0-1-0-1-3270-000000001", class = "rare", name = "Elder Mottled Boar" }
fire("PLAYER_TARGET_CHANGED")
ok(ns.Ledger.Has("rare", 3270), "rare found by target")
local f = db.finds["rare:3270"]
eq(f.count, 1, "one sighting")
eq(f.sightings[1].zone, 1429, "sighting zone recorded")
advance(700)
fire("PLAYER_TARGET_CHANGED")
eq(f.count, 2, "second sighting after ten minutes")
local rareEntries = #ns.Ledger.Query({ who = me, kind = "rare" })
eq(rareEntries, 1, "second sighting earns nothing")
-- A normal mob is ignored; a dead rare is logged without points.
unit.target = { guid = "Creature-0-1-0-1-299-000000002", class = "normal", name = "Young Wolf" }
advance(5)
fire("PLAYER_TARGET_CHANGED")
ok(db.finds["rare:299"] == nil, "normal creature ignored")
unit.target = { guid = "Creature-0-1-0-1-61-000000003", class = "rareelite", name = "Thuros Lightfingers", dead = true }
advance(5)
fire("PLAYER_TARGET_CHANGED")
ok(db.finds["rare:61"] ~= nil, "dead rare logged")
ok(not ns.Ledger.Has("rare", 61), "dead rare earns nothing")

-- A secret GUID is passed over.
issecretvalue = function(v) return v == "SECRET" end
unit.target = { guid = "SECRET", class = "rare", name = "Hidden" }
advance(5)
fire("PLAYER_TARGET_CHANGED")
issecretvalue = nil

-- Treasure by vignette.
vignettes["V1"] = { objectGUID = "GameObject-0-1-0-1-2843-0000001", name = "Battered Chest", onMinimap = true }
fire("VIGNETTE_MINIMAP_UPDATED", "V1", true)
ok(ns.Ledger.Has("treasure", 2843), "treasure found by vignette")
local tf = db.finds["treasure:2843"]
eq(tf.first.x, 40, "vignette x position")

eq(ns.Points.Total(me), 25 + 10 + 50 + 10 + 20 + 50 + 30, "total points (your rare is the guild's first)")
ok(ns.Points.WeekStart() <= now and now - ns.Points.WeekStart() < 7 * 86400, "week start within a week")
eq(os.date("!*t", ns.Points.WeekStart()).wday, 2, "week starts on Monday")
eq(os.date("!*t", ns.Points.MonthStart()).day, 1, "month starts on the 1st")

-- Entry ids are unique and sequential.
local ids = {}
for _, e in ipairs(db.entries) do
	ok(not ids[e.id], "unique id " .. e.id)
	ids[e.id] = true
end

-- Index rebuilt from saved entries after a reload.
fire("ADDON_LOADED", "LeagueOfExplorers")
ok(ns.Ledger.Has("treasure", 2843), "index survives reload")

---------------------------------------------------------------------------
-- Guild sync
---------------------------------------------------------------------------
local S = ns.Sync
eq(ns.Guild.name, "League of Explorers", "guild read from the roster")
ok(ns.Guild.Member("Other-Realm").online, "officer online")
ok(ns.Ledger.Has("base", 1411), "baseline shared as a base entry")
eq(#ns.Exploration.MaskAreas(1411, ns.Ledger.Has("base", 1411).mask), 3, "base mask holds the 3 baseline areas")
eq(ns.Points.Total(me, nil), 195, "base entries are worth nothing")

-- Our entries went out as they were written; the first digest follows.
flush()
tick(400)
local function sentStarting(prefix)
	for _, m in ipairs(sent) do if m:sub(1, #prefix) == prefix then return true end end
	return false
end
ok(sentStarting("E~1~Tester-Realm~"), "own entries broadcast")
ok(sentStarting("H~1~1~1~"), "digest sent")

-- Round trip.
local rt = S.Decode(S.Encode({ who = "A-Realm", seq = 3, t = 1794000000, kind = "rare", key = 61, map = 1429, x = 40.25, y = 60, name = "Thur~os|x" }))
eq(rt.key, 61, "encode/decode key")
eq(rt.x, 40.3, "encode/decode x")
eq(rt.name, "Thur os x", "separators stripped from names")

-- An officer's earlier sighting of the same rare takes the guild first.
local before = ns.Points.Total(me)
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Other-Realm", seq = 1, t = 1794000000 - 3600, kind = "rare", key = 3270, name = "Elder Mottled Boar", map = 1429 }), "GUILD", "Other-Realm")
ok(ns.Ledger.Has("rare", 3270, "Other-Realm"), "officer's entry merged")
eq(ns.Points.Total(me), before - 50, "guild first moves to the earlier find")
eq(ns.Points.Total("Other-Realm"), 70, "officer gets find plus guild first")

-- Strangers are not heard; entries for non-members are dropped.
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Stranger-Realm", seq = 1, t = 1794000000, kind = "zone", key = 1411 }), "GUILD", "Stranger-Realm")
ok(not ns.Ledger.Has("zone", 1411, "Stranger-Realm"), "non-member ignored")

-- A relay for an offline member, then that member's own copy wins.
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Away-Realm", seq = 1, t = 1794000000, kind = "zone", key = 1411 }), "GUILD", "Other-Realm")
ok(ns.Ledger.Has("zone", 1411, "Away-Realm"), "relayed entry kept")
eq(ns.Ledger.Get("Away-Realm#1").via, "Other-Realm", "relay remembered")
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Away-Realm", seq = 1, t = 1794000000, kind = "zone", key = 1412 }), "GUILD", "Away-Realm")
ok(ns.Ledger.Has("zone", 1412, "Away-Realm") and not ns.Ledger.Has("zone", 1411, "Away-Realm"), "author's copy replaces the relay")
eq(ns.Ledger.Get("Away-Realm#1").via, nil, "replaced entry is authored")
local count = #db.entries
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Away-Realm", seq = 1, t = 1794000000, kind = "zone", key = 1411 }), "GUILD", "Other-Realm")
eq(#db.entries, count, "a later relay can't overwrite the author")

-- A future-dated or malformed entry is refused.
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Other-Realm", seq = 2, t = now + 99999, kind = "zone", key = 1413 }), "GUILD", "Other-Realm")
ok(not ns.Ledger.Has("zone", 1413, "Other-Realm"), "future entry refused")
fire("CHAT_MSG_ADDON", "LoE", "E~1~Other-Realm~x~~zone~1413", "GUILD", "Other-Realm")
ok(not ns.Ledger.Has("zone", 1413, "Other-Realm"), "malformed entry refused")

-- The officer logs in having lost their journal: their digest says they
-- hold nothing, so we send their entry back even though they're online,
-- and send ours too.
sent = {}
fire("CHAT_MSG_ADDON", "LoE", "H~1~1~1~Tester-Realm:0,Other-Realm:0", "GUILD", "Other-Realm")
flush()
tick(800)
ok(sentStarting("E~1~Other-Realm~1~"), "lost entries returned to their author")
ok(sentStarting("E~1~Tester-Realm~1~"), "our entries answered")
ok(sentStarting("E~1~Away-Realm~"), "an offline member's entries are relayed to whoever lacks them")

-- The board and the guild's atlas.
local members = { ["Tester-Realm"] = true, ["Other-Realm"] = true, ["Away-Realm"] = true }
local board = ns.Points.Board(members)
eq(board[1].who, "Tester-Realm", "you lead the board")
eq(board[2].who, "Other-Realm", "officer second")
eq(board[2].firsts, 1, "officer's guild first counted")
local together = ns.Points.Together(members)
eq(together.zone, 4, "guild zones: Durotar, Elwynn, Stormwind, Mulgore")
eq(together.area, 3 + 8 + 1, "guild areas: baseline 3, charted 8 in Durotar, 1 in Elwynn")
eq(together.rare, 1, "guild rares (the slain one earned no entry)")
local week = ns.Points.Board(members, ns.Points.WeekStart())
ok(#week == 3, "weekly board lists everyone with entries")

-- Commands and every journal page, against the fake frames.
SlashCmdList.LEAGUEOFEXPLORERS("status")
SlashCmdList.LEAGUEOFEXPLORERS("")
for _, id in ipairs({ "journal", "atlas", "bestiary", "treasures", "halloffame" }) do
	ns.Journal.Show(id)
end
flush()
-- Both looks: switch, and every page again.
SlashCmdList.LEAGUEOFEXPLORERS("look blizzard")
eq(db.settings.look, "blizzard", "look switched to blizzard")
for _, id in ipairs({ "journal", "atlas", "bestiary", "treasures", "halloffame" }) do
	ns.Journal.Show(id)
end
flush()
SlashCmdList.LEAGUEOFEXPLORERS("look")
eq(db.settings.look, "explorer", "look toggled back to explorer")
SlashCmdList.LEAGUEOFEXPLORERS("minimap")
SlashCmdList.LEAGUEOFEXPLORERS("minimap")
ns.Toast(db.entries[#db.entries])
flush()

print(("%d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
