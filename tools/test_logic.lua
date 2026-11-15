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
	GetEffectiveScale = 1, GetLeft = 0, GetTop = 0, GetVerticalScroll = 0, GetStringHeight = 14, NumLines = 0 }
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
	if k == "SetText" then return function(s, t) rawset(s, "_text", t) end end
	if k == "GetText" then return function(s) return rawget(s, "_text") or "" end end
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
-- Chat filters and the game's guild window, enough to hook into.
local chatFilters, nameFilters = {}, {}
ChatFrameUtil = { AddMessageEventFilter = function(ev, fn)
	chatFilters[ev] = chatFilters[ev] or {}
	table.insert(chatFilters[ev], fn)
end, AddSenderNameFilter = function(fn) nameFilters[#nameFilters + 1] = fn end }
function hooksecurefunc(t, name, fn)
	if type(t) ~= "table" then return end
	local orig = t[name]
	t[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return table.unpack(r)
	end
end
local guildRow = newMock()
guildRow.NameFrame = { Name = newMock() }
guildRow.memberInfo = { name = "Other-Realm-ForeverRealm" }
local strangerRow = newMock()
strangerRow.NameFrame = { Name = newMock() }
strangerRow.memberInfo = { name = "Away-Realm-ForeverRealm" }
CommunitiesFrame = { MemberList = {
	ScrollBox = { ForEachFrame = function(_, fn) fn(guildRow); fn(strangerRow) end },
	RefreshListDisplay = function() end,
} }
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
-- Forever writes surnames with a hyphen: "Tester-Realm" is a name and a
-- surname here; the realm itself is "Forever Realm".
function GetNormalizedRealmName() return "ForeverRealm" end
function GetRealmName() return "Forever Realm" end
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
function UnitGUID(u) if u == "player" then return "Player-1-00000001" end return unit[u] and unit[u].guid end
function UnitIsPlayer() return false end
function UnitPlayerControlled() return false end
function UnitClassification(u) return unit[u] and unit[u].class end
function UnitIsDead(u) return unit[u] and unit[u].dead end
function UnitName(u) return unit[u] and unit[u].name end
function UnitCreatureType(u) return unit[u] and unit[u].ctype end
function UnitIsTapDenied(u) return unit[u] and unit[u].denied or false end
function UnitThreatSituation(_, u) return unit[u] and unit[u].threat end
local loot = {}
function GetNumLootItems() return #loot end
function GetLootSourceInfo(slot) return loot[slot], 1 end
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
	-- The roster writes our own realm on the end of everyone, and has our GUID.
	{ "Tester-Realm-ForeverRealm", "Guild Master", 0, 30, "Hunter", "Elwynn Forest", "", "", true, 0, "HUNTER", 0, 0, false, false, 0, "Player-1-00000001" },
	{ "Other-Realm-ForeverRealm", "Officer", 1, 40, "Mage", "Darkshore", "", "", true, 0, "MAGE" },
	{ "Away-Realm", "Member", 3, 20, "Rogue", "", "", "", false, 0, "ROGUE" },
}
function IsInGuild() return true end
function GetGuildInfo() return "League of Explorers" end
function GetNumGuildMembers() return #roster end
function GetGuildRosterInfo(i) return table.unpack(roster[i]) end
C_GuildInfo = { GuildRoster = function() end }
local RANKS = { "Guild Master", "Officer", "Veteran", "Member", "Initiate" }
function GuildControlGetNumRanks() return #RANKS end
function GuildControlGetRankName(i) return RANKS[i] end
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
-- The weekly hunt picks its targets from the date; keep it out of the
-- point totals below (it has its own test near the end).
ns.Work.weeklyOverride = {}

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
eq(ns.Points.Total(me), 40, "fully explored is worth 40")
fire("ZONE_CHANGED")
flush()
eq(ns.Points.Total(me), 40, "no second fully-explored award")

-- New continent and zone.
advance(600)
here = 1429
explored[1429] = { ELWYNN[1] }
fire("ZONE_CHANGED_NEW_AREA")
flush()
ok(ns.Ledger.Has("zone", 1429), "Elwynn discovered")
ok(ns.Ledger.Has("continent", 1415), "Eastern Kingdoms reached")
eq(ns.Points.Total(me), 40 + 10 + 25, "zone + continent points")

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

eq(ns.Points.Total(me), 40 + 10 + 25 + 10 + 10 + 40 + 15, "total points (your rare is the guild's first)")
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
eq(ns.Points.Total(me, nil), 150, "base entries are worth nothing")

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
eq(ns.Points.Total(me), before - 40, "guild first moves to the earlier find")
eq(ns.Points.Total("Other-Realm"), 50, "officer gets find plus guild first")

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

-- Officers, expeditions, bounties and submissions.
local Wk = ns.Work
ok(Wk.IsLeader(me) and Wk.AmOfficer(), "the guild master is an officer")
ok(Wk.IsOfficer("Other-Realm"), "rank 1 is an officer by default")
ok(not Wk.IsOfficer("Away-Realm"), "rank 3 is not")
local beforeExp = ns.Points.Total(me)
advance(60)
local x = Wk.Post("Into Mulgore", false, { "z1412" }, 50, 7)
ok(x ~= nil, "expedition posted")
here = 1412
fire("ZONE_CHANGED_NEW_AREA")
flush()
local xp = Wk.Expeditions()[1]
local d, _, fin = Wk.Progress(xp, me)
eq(d, 1, "goal met by visiting after posting")
ok(fin ~= nil, "expedition finished")
eq(ns.Points.Total(me) - beforeExp, 10 + 75, "zone + expedition reward with first-finisher bonus")
-- A bounty from the officer, claimed by killing the rare.
advance(30)
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Other-Realm", seq = 5, t = now, kind = "exp", key = now,
	name = "Hunt the boar", mask = "r3270", note = "bounty:100:" }), "GUILD", "Other-Realm")
eq(#Wk.Expeditions(), 2, "officer's bounty merged")
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Away-Realm", seq = 7, t = now, kind = "exp", key = now,
	name = "Fake", mask = "z1411", note = "exp:200:" }), "GUILD", "Away-Realm")
eq(#Wk.Expeditions(), 2, "non-officer expedition refused")
local beforeBounty = ns.Points.Total(me)
advance(700)
unit.target = { guid = "Creature-0-1-0-1-3270-000000009", class = "rare", name = "Elder Mottled Boar", ctype = "Beast" }
fire("PLAYER_TARGET_CHANGED")
eq(ns.Points.Total(me) - beforeBounty, 0, "seeing the bounty's rare alive doesn't claim it")
eq(ns.Bestiary.Type(3270), "Beast", "creature type learned from the unit")
-- Another group's kill: its corpse, and skinning it, claim nothing.
unit.target = { guid = "Creature-0-1-0-1-3270-000000010", class = "rare", name = "Elder Mottled Boar", dead = true, denied = true }
fire("PLAYER_TARGET_CHANGED")
loot = { "Creature-0-1-0-1-3270-000000010" }
fire("LOOT_OPENED")
loot = {}
eq(ns.Points.Total(me) - beforeBounty, 0, "another group's kill doesn't claim it")
-- A corpse you never fought claims nothing either.
unit.target = { guid = "Creature-0-1-0-1-3270-000000011", class = "rare", name = "Elder Mottled Boar", dead = true }
fire("UNIT_HEALTH", "target")
eq(ns.Points.Total(me) - beforeBounty, 0, "a corpse you didn't fight doesn't count")
-- Fighting it, and seeing it die: the bounty is yours.
unit.target = { guid = "Creature-0-1-0-1-3270-000000009", class = "rare", name = "Elder Mottled Boar", threat = 3 }
fire("UNIT_HEALTH", "target")
unit.target.dead, unit.target.threat = true, nil
fire("UNIT_HEALTH", "target")
eq(ns.Points.Total(me) - beforeBounty, 100, "bounty paid to the first to kill it")
ok(ns.Ledger.Has("kill", 3270), "the kill is written down")
eq(Wk.GoalName({ k = "r", id = 3270, key = "r3270" }), "Kill Elder Mystic Razorsnout", "rare goals ask for a kill")
-- Submissions: the officer submits, the guild master approves.
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Other-Realm", seq = 6, t = now, kind = "sub", key = now,
	name = "The Hidden Falls", note = "Behind the waterfall", map = 1429, x = 40, y = 50 }), "GUILD", "Other-Realm")
local subs = Wk.Submissions()
eq(#subs, 1, "submission merged")
eq(subs[1].note, "Behind the waterfall", "note carried over the wire")
eq(subs[1].status, "pending", "waiting for review")
local otherBefore = ns.Points.Total("Other-Realm")
Wk.Review(subs[1], true)
eq(Wk.Submissions()[1].status, "approved", "approved")
eq(ns.Points.Total("Other-Realm") - otherBefore, 30, "approved submission pays its finder")
for _, e in ipairs(ns.Ledger.Query({ who = me })) do
	ok(not ns.Ledger.HIDDEN[e.kind], "no record kinds in the journal list: " .. e.kind)
end
-- The Bestiary knows every rare, and its state.
local zones = ns.Bestiary.Zones({ [me] = true, ["Other-Realm"] = true })
ok(#zones > 0, "bestiary has zones")
local elwynn
for _, z in ipairs(zones) do if z.id == 1429 then elwynn = z end end
ok(elwynn and #elwynn.list >= 8, "Elwynn has its rares from the list")
local states = {}
for _, r in ipairs(elwynn.list) do states[r.id] = r.state end
eq(states[61], "guild", "Thuros Lightfingers, seen only slain, stays in shadow")
eq(states[79], "unknown", "Narg the Taskmaster is undiscovered")

-- Officer preview, for a member who isn't one.
roster[1][3] = 3 -- you become a plain Member
ns.Guild.Refresh()
ok(not Wk.AmOfficer() and not Wk.IsLeader(me), "a member is not an officer")
local expBefore = #Wk.Expeditions()
local entriesBefore = #db.entries
local seqBefore = ns.Ledger.MaxSeq(me)
Wk.SetPreview(true)
ok(Wk.AmOfficer() and Wk.IsLeader(me), "preview makes you officer and guild master here")
ok(not Wk.IsOfficer(me, true), "but not by the real roster")
sent = {}
local px = Wk.Post("Preview trip", false, { "z1411" }, 25, 7)
ok(px and px.test, "preview post marked as a test")
local shown = false
for _, e2 in ipairs(Wk.Expeditions()) do if e2.id == px.id then shown = true end end
ok(shown, "preview expedition shows while previewing")
local mySub = Wk.Submit("My own find", "testing")
ok(mySub and mySub.test, "preview submission marked as a test")
local own
for _, sb in ipairs(Wk.Submissions()) do if sb.id == mySub.id then own = sb end end
ok(Wk.Review(own, true) ~= nil, "preview lets you review your own")
ok(Wk.SetOfficerRank(2), "preview lets you set officer ranks")
eq(Wk.OfficerRank(), 2, "officer rank set while previewing")
tick(200)
local leaked = false
for _, m in ipairs(sent) do
	if m:find("Preview trip", 1, true) or m:find("My own find", 1, true) or m:find("~cfg~", 1, true) or m:find("~rev~Tester", 1, true) then leaked = true end
end
ok(not leaked, "nothing made in preview is sent")
eq(ns.Ledger.MaxSeq(me), seqBefore, "digests don't count preview entries")
-- A guildmate's client would refuse it anyway, by the real roster.
Wk.SetPreview(false)
eq(#db.entries, entriesBefore, "preview entries deleted when it's switched off")
eq(#Wk.Expeditions(), expBefore, "preview expedition gone")
eq(Wk.OfficerRank(), 1, "officer rank back to the guild's own")
roster[1][3] = 0
ns.Guild.Refresh()

-- Names: surnames survive, our realm comes off, other realms stay.
eq(ns.Name("Brennan-Black-ForeverRealm"), "Brennan-Black", "our realm taken off a surnamed name")
eq(ns.Name("Brennan-Black-Forever Realm"), "Brennan-Black", "our realm, spelled with its space")
eq(ns.Name("Brennan-Black"), "Brennan-Black", "a surname is never taken for a realm")
eq(ns.Name("Zeck-ForeverRealm"), "Zeck", "a plain name loses our realm")
eq(ns.Name("Visitor-Elsewhere"), "Visitor-Elsewhere", "another realm stays")
eq(ns.ShortName("Brennan-Black"), "Brennan Black", "shown with a space, as the game shows it")
local total = 0
for _ in pairs(ns.UI.Members()) do total = total + 1 end
eq(total, 3, "you are counted once (the roster's copy matches)")
-- A message sent with the realm on the end is still one of us.
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Other-Realm", seq = 40, t = now, kind = "zone", key = 1429 }), "GUILD", "Other-Realm-ForeverRealm")
ok(ns.Ledger.Has("zone", 1429, "Other-Realm"), "sender with realm suffix accepted as the author")
-- The roster says we're called something else: the journal follows it.
local mineBefore = #ns.Ledger.Query({ who = "Tester-Realm", all = true })
roster[1][1] = "Tester-Renamed-ForeverRealm"
ns.Guild.Refresh()
eq(ns.Me(), "Tester-Renamed", "the roster's name for you wins")
eq(#ns.Ledger.Query({ who = "Tester-Renamed", all = true }), mineBefore, "your entries moved to it")
roster[1][1] = "Tester-Realm-ForeverRealm"
ns.Guild.Refresh()
eq(ns.Me(), "Tester-Realm", "and back")
eq(#ns.Ledger.Query({ who = "Tester-Realm", all = true }), mineBefore, "entries back too")

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
eq(together.continent, 2, "continents follow from the zones, baseline included")
local week = ns.Points.Board(members, ns.Points.WeekStart())
ok(#week == 3, "weekly board lists everyone with entries")

-- Commands and every journal page, against the fake frames.
SlashCmdList.LEAGUEOFEXPLORERS("status")
SlashCmdList.LEAGUEOFEXPLORERS("")
for _, id in ipairs({ "guild", "journal", "bestiary", "expeditions", "leaders", "submissions" }) do
	ns.Journal.Show(id)
	tick(4)
	eq(ns.Journal.Current().id, id, "turned to " .. id)
end
flush()
-- Back through the book the other way.
for _, id in ipairs({ "submissions", "leaders", "expeditions", "bestiary", "journal", "guild" }) do
	ns.Journal.Show(id)
	tick(4)
	eq(ns.Journal.Current().id, id, "turned back to " .. id)
end
flush()
SlashCmdList.LEAGUEOFEXPLORERS("minimap")
SlashCmdList.LEAGUEOFEXPLORERS("minimap")
ns.Toast(db.entries[#db.entries])
flush()

-- Ranks in the guild window and guild chat.
CommunitiesFrame.MemberList.RefreshListDisplay()
ok(guildRow.loeEmblem and guildRow.loeEmblem._shown, "rank emblem on a journal-keeper's row")
local awayShown = strangerRow.loeEmblem and strangerRow.loeEmblem._shown
ok(ns.Ledger.MaxSeq("Away-Realm") > 0 and awayShown or not awayShown, "an emblem only for those who keep a journal")
local st = ns.GuildHooks.Standing("Other-Realm-ForeverRealm")
ok(st and st.rank and st.points > 0, "a guildmate's standing")
-- A tab on the guild window opens the League of Explorers window, and
-- shows only while the guild's own side tabs do.
local gtab = ns.GuildHooks.tab
ok(gtab ~= nil, "a tab on the guild window")
local wasOpen = ns.Journal.IsShown()
gtab._scripts.OnClick(gtab)
tick(8)
ok(ns.Journal.IsShown() ~= wasOpen, "clicking it opens or closes the window")
gtab._scripts.OnClick(gtab)
tick(8)
local infoTab = newMock()
CommunitiesFrame.GuildInfoTab = infoTab
ns.GuildHooks.PlaceTab()
ok(gtab:IsShown(), "shown under the guild's tabs")
infoTab:Hide()
ns.GuildHooks.PlaceTab()
ok(not gtab:IsShown(), "hidden when the guild's tabs are (another community selected)")
infoTab:Show()
ns.GuildHooks.PlaceTab()
ok(ns.GuildHooks.AddTab(CommunitiesFrame) == gtab, "only one tab, however often the window loads")
ns.Commands.guildtab()
-- Dressed like the tab above it: EllesmereUI's plate when that skin is on.
local refTab = newMock()
refTab.Icon = { GetTexCoord = function() return 0.12, 0.88, 0.12, 0.88 end, GetSize = function() return 26, 26 end,
	GetPoint = function() return "CENTER", refTab, "CENTER", 0, 0 end }
ns.GuildHooks.StyleTab(refTab)
eq(gtab.style, "eui", "styled like EllesmereUI's tabs")
refTab.Icon.GetTexCoord = function() return 0, 1, 0, 1 end
ns.GuildHooks.StyleTab(refTab)
eq(gtab.style, "game", "and like the game's own without it")

-- The book opens and closes like a tome: closing waits for the cover to
-- swing shut; Escape (the game hiding it) closes it the same way.
local JF = _G.LeagueOfExplorersJournal
ns.Journal.Show("guild")
tick(8)
ok(JF:IsShown(), "the book is open")
ns.Journal.Toggle()
ok(JF:IsShown(), "closing: still showing while the cover swings shut")
tick(8)
ok(not JF:IsShown(), "and gone once it has")
ns.Journal.Show("guild")
tick(8)
ok(_G.LeagueOfExplorersJournalEscape:IsShown(), "Escape has something to close while it's open")
_G.LeagueOfExplorersJournalEscape:Hide() -- what Escape does
ok(JF:IsShown(), "Escape: the book stays to close properly")
ok(not _G.LeagueOfExplorersJournalEscape:IsShown(), "and Escape is free again while it closes")
tick(8)
ok(not JF:IsShown(), "and then it's gone")
-- The cover says whose book it is, and the sheets are only out while it moves.
local tm = ns.Journal.Tome()
ns.Journal.Show("guild")
tick(1)
eq(tm.cover.front.name:GetText(), ns.ShortName(ns.Points.Player(ns.Me())), "the cover has the owner's name")
ok(tm.cover.frame:IsShown() and tm.leaves[1].frame:IsShown(), "cover and flyleaves out while it opens")
tick(8)
ok(not tm.cover.frame:IsShown() and not tm.leaves[2].frame:IsShown(), "and put away once it's open")
ns.Journal.Toggle()
tick(8)
db.settings.bookAnim = false
ns.Journal.Show("guild")
ns.Journal.Toggle()
ok(not JF:IsShown(), "with the setting off it closes at once")
db.settings.bookAnim = true

-- Guild chat: the rank as a title before the name. Our own name filter
-- does it while no roleplay addon names chat.
eq(#nameFilters, 1, "the sender-name hook is in place")
local ours = nameFilters[1]
local title = ours("CHAT_MSG_GUILD", nil, "hello", "Other-Realm-ForeverRealm")
ok(type(title) == "string" and title:find("^|cff%x+" .. st.rank .. "|r%] %[Other Realm$") ~= nil, "rank before the name: " .. tostring(title))
eq(ours("CHAT_MSG_SAY", nil, "x", "Other-Realm-ForeverRealm"), nil, "only guild and officer chat")
eq(ours("CHAT_MSG_GUILD", nil, "x", "Stranger-Elsewhere"), nil, "nobody outside the guild")
-- Kinship's message filter runs first (it changes the text, not the sender).
local function kinshipLike(_, _, msg, sender, ...) return false, msg .. " (rp)", sender, ... end
local function runChat(event, msg, sender)
	local args = { msg, sender, "", "" }
	local chain = { kinshipLike }
	for _, f in ipairs(chatFilters[event] or {}) do chain[#chain + 1] = f end
	for _, f in ipairs(chain) do
		local r = { f(nil, event, table.unpack(args)) }
		if r[1] then return nil end
		if r[2] ~= nil then args = { table.unpack(r, 2) } end
	end
	return args[1], args[2]
end
local line, from = runChat("CHAT_MSG_GUILD", "hello all", "Other-Realm-ForeverRealm")
eq(line, "hello all (rp)", "the message itself is left alone (Kinship's change kept)")
eq(from, "Other-Realm-ForeverRealm", "the sender is left as it was")
ok(chatFilters["CHAT_MSG_OFFICER"] ~= nil, "officer chat watched too")
-- Kinship adds its roleplay-name filter at login: the rank goes in front of
-- its name, and in front of ours for someone without a roleplay name.
local function kinshipName(event, _, _, sender)
	if sender == "Other-Realm-ForeverRealm" then return "|cffffd100Lord Otherwyn|r" end
	return nil
end
ChatFrameUtil.AddSenderNameFilter(kinshipName)
eq(#nameFilters, 2, "Kinship's name filter is added")
local kin = nameFilters[2]
ok(kin ~= kinshipName, "and wrapped")
eq(kin("CHAT_MSG_GUILD", nil, "hi", "Other-Realm-ForeverRealm"), ns.GuildHooks.Prefix("Other-Realm") .. "|cffffd100Lord Otherwyn|r",
	"the rank in front of Kinship's roleplay name")
local plainTitle = kin("CHAT_MSG_GUILD", nil, "hi", me)
ok(type(plainTitle) == "string" and plainTitle:find("Tester Realm", 1, true) ~= nil, "someone without a roleplay name still gets the title")
eq(kin("CHAT_MSG_SAY", nil, "hi", "Other-Realm-ForeverRealm"), "|cffffd100Lord Otherwyn|r", "say: Kinship's name, untouched")
eq(ours("CHAT_MSG_GUILD", nil, "hi", "Other-Realm-ForeverRealm"), nil, "ours stands back, so only one name is given")
db.settings.chatTags = false
eq(kin("CHAT_MSG_GUILD", nil, "hi", "Other-Realm-ForeverRealm"), "|cffffd100Lord Otherwyn|r", "setting off: Kinship's name alone")
db.settings.chatTags = true

-- The guided demo: a pretend guild for the tour, gone afterwards.
local entriesBeforeDemo = #db.entries
local membersBefore = 0
for _ in pairs(ns.Guild.members) do membersBefore = membersBefore + 1 end
local pointsBefore = ns.Points.Total(me)
sent = {}
SlashCmdList.LEAGUEOFEXPLORERS("demo")
ok(ns.Demo.Running(), "demo running")
ok(ns.Guild.Member("Mira-Vale") ~= nil, "pretend guildmates on the roster")
ns.Guild.Refresh()
ok(ns.Guild.Member("Mira-Vale") ~= nil, "a roster refresh doesn't end the pretend guild")
local board = ns.Points.Board(ns.UI.Members(), nil)
local onBoard = false
for _, r in ipairs(board) do if r.who == "Mira-Vale" then onBoard = r.points > 0 end end
ok(onBoard, "pretend guildmate on the leaderboard with points")
ok(ns.Work.AmOfficer(), "officer tools shown during the demo")
local demoExp
for _, x in ipairs(ns.Work.Expeditions()) do if x.title == "The Elwynn Hunt" then demoExp = x end end
ok(demoExp ~= nil, "demo expedition posted by the pretend officer")
eq(#ns.Work.Finishers(demoExp), 1, "Mira has finished it")
local pend = 0
for _, sb in ipairs(ns.Work.Submissions()) do if sb.status == "pending" then pend = pend + 1 end end
ok(pend >= 1, "a demo submission waits for review")
local ms = ns.GuildHooks.Standing("Mira-Vale")
ok(ms and ms.points > 0, "pretend guildmates have a standing (tags, emblems, hover)")
local demoTitle = ns.GuildHooks.Title("Mira-Vale")
ok(type(demoTitle) == "string" and demoTitle:find(ms.rank, 1, true) ~= nil, "demo chat shows Mira's rank")
ok(ns.UI.SignedUp(ns.UI.Members()) >= 5, "pretend guildmates count as signed up")
-- Run the whole tour.
for _ = 1, 40 do
	flush()
	tick(8)
end
ok(not ns.Demo.Running(), "the tour ends by itself")
eq(ns.Alerts.Recent(100), nil, "the demo's pretend sighting is gone")
eq(#db.entries, entriesBeforeDemo, "no demo entries left")
local membersAfter = 0
for _ in pairs(ns.Guild.members) do membersAfter = membersAfter + 1 end
eq(membersAfter, membersBefore, "the real roster is back")
eq(ns.Points.Total(me), pointsBefore, "your points are as they were")
ok(not ns.Work.AmOfficer() or ns.Work.IsOfficer(me, true), "officer tools only if you really are one")
local leaked = false
for _, m in ipairs(sent) do
	if m:find("Mira-Vale", 1, true) or m:find("Elwynn Hunt", 1, true) or m:find("Hidden Falls", 1, true) then leaked = true end
end
ok(not leaked, "nothing from the demo was sent")
-- Stopping early cleans up too.
SlashCmdList.LEAGUEOFEXPLORERS("demo")
SlashCmdList.LEAGUEOFEXPLORERS("demo")
ok(not ns.Demo.Running(), "stopped early")
eq(#db.entries, entriesBeforeDemo, "nothing left after stopping early")
-- And a reload mid-tour clears anything left behind.
SlashCmdList.LEAGUEOFEXPLORERS("demo")
fire("ADDON_LOADED", "LeagueOfExplorers")
eq(#db.entries, entriesBeforeDemo, "demo entries cleared on the next load")
SlashCmdList.LEAGUEOFEXPLORERS("demo")

---------------------------------------------------------------------------
-- One player, one rank: alts count with their main, each find once.
---------------------------------------------------------------------------
local P, Pl = ns.Points, ns.Players
local otherBefore = P.Total("Other-Realm")
-- Away says Other is its main; Away found Mulgore (zone 1412) and Other hasn't.
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Away-Realm", seq = 50, t = now, kind = "main", key = "Other-Realm@" .. now }), "GUILD", "Away-Realm")
eq(Pl.MainOf("Away-Realm"), "Other-Realm", "Away is Other's alt")
eq(P.Total("Away-Realm"), P.Total("Other-Realm"), "an alt shows its player's points")
ok(P.Total("Other-Realm") > otherBefore, "the alt's finds count for the player")
-- The same zone found by both counts once.
local before2 = P.Total("Other-Realm")
fire("CHAT_MSG_ADDON", "LoE", S.Encode({ who = "Other-Realm", seq = 60, t = now, kind = "zone", key = 1412 }), "GUILD", "Other-Realm")
eq(P.Total("Other-Realm"), before2, "a zone found by two of a player's characters counts once")
local rows = P.Board({ ["Other-Realm"] = true, ["Away-Realm"] = true }, nil)
eq(#rows, 1, "one row for the player and their alt")
eq(rows[1].alts, 1, "the row knows its alt")

---------------------------------------------------------------------------
-- Ranks by deeds, with exploration from before the journal counting.
---------------------------------------------------------------------------
local c = P.Counts(me)
ok(c.zones >= 4 and c.full >= 1, "counts include zones and fully explored (baseline too)")
local idx, rank, nxt, prog, asks = P.RankOf(me)
eq(rank.name, "Wanderer", "a handful of zones is still a Wanderer")
eq(nxt.name, "Pathfinder", "next is Pathfinder")
eq(asks[1].need, 10, "Pathfinder asks for 10 zones")
ok(prog > 0 and prog < 1, "progress toward it")
eq(P.RankShort(P.RANKS[9]), "all explored, 300 rares, 5 firsts", "the top rank in short")
-- Points alone don't make a rank: lots of rares, no zones, stays put.
local fake = {}
for i = 1, 40 do fake[i] = { who = "Rich-Hunter", seq = i, t = now - i, kind = "rare", key = 900000 + i } end
for _, e in ipairs(fake) do ns.Ledger.AddDemo(e) end
ns.Fire("ENTRY_MERGED", {})
local ridx = P.RankOf("Rich-Hunter")
eq(ridx, 1, "forty rares without zones is still a Wanderer")
ns.Ledger.ClearDemo()
ns.Fire("ENTRY_MERGED", {})

---------------------------------------------------------------------------
-- The weekly hunt: same targets for everyone, repeatable each week.
---------------------------------------------------------------------------
ns.Work.weeklyOverride = nil
local wk1 = ns.Work.Weekly(P.WeekStart())
eq(#wk1, 5, "five targets a week")
local wk1b = ns.Work.Weekly(P.WeekStart())
eq(wk1b[1].key, wk1[1].key, "the same week gives the same targets")
local wk2 = ns.Work.Weekly(P.WeekStart() + 7 * 86400)
local same = 0
for i = 1, 5 do if wk1[i].key == wk2[i].key then same = same + 1 end end
ok(same < 5, "next week is different")
-- Level bands: a level 30 character hunts 30-39, fitting targets only.
eq(ns.Work.MyBand(), 3, "a level 30 character hunts the 30-39 band")
eq(ns.Work.BandOf(1), 1, "level 1 is the first band")
eq(ns.Work.BandOf(60), 5, "level 60 is the last band")
for band, b in ipairs(ns.Work.BANDS) do
	for w = 0, 5 do
		local list = ns.Work.Weekly(P.WeekStart() + w * 7 * 86400, band)
		local rares, zones, fits, home = 0, 0, true, false
		for _, g in ipairs(list) do
			if g.k == "r" then
				rares = rares + 1
				local r = ns.RareList[g.id]
				if r[5] > b.hi + 2 or (r[6] or r[5]) < b.lo then fits = false end
				if (ns.Exploration.ZoneOf(r[2]) or r[2]) == 1429 then home = true end
			else
				zones = zones + 1
				local lo, hi = ns.Work.ZoneLevels(g.id)
				if not lo or lo > b.hi or hi < b.lo then fits = false end
				if g.id == 1429 or g.id == 1426 or g.id == 1438 then home = true end
			end
		end
		ok(rares == 3 and zones == 2, ("band %s week %d has three rares and two zones"):format(b.label, w))
		ok(fits, ("band %s week %d: every target suits the band"):format(b.label, w))
		ok(not home, ("band %s week %d: nothing in the Alliance's home zones for a Horde guild"):format(b.label, w))
	end
end
ok(ns.Work.Weekly(P.WeekStart(), 1)[1].key ~= ns.Work.Weekly(P.WeekStart(), 5)[1].key, "each band has its own hunt")
local silithus = false
for band = 1, 4 do
	for _, g in ipairs(ns.Work.Weekly(P.WeekStart(), band)) do
		if g.id == 1451 or (g.k == "r" and ns.RareList[g.id][2] == 1451) then silithus = true end
	end
end
ok(not silithus, "no Silithus below level 50")
-- This week: Elwynn and a rare already found long ago both count.
ns.Work.weeklyOverride = { { k = "z", id = 1429, key = "z1429" }, { k = "r", id = 3270, key = "r3270" } }
local wkBefore = P.Total(me)
here = 1429
fire("ZONE_CHANGED_NEW_AREA")
flush()
advance(700)
unit.target = { guid = "Creature-0-1-0-1-3270-000000077", class = "rare", name = "Elder Mottled Boar" }
fire("PLAYER_TARGET_CHANGED")
eq(P.Total(me) - wkBefore, 15, "seeing the hunt's rare isn't enough")
-- Looting it: only the group that tagged it can, so it's a kill.
loot = { "Creature-0-1-0-1-3270-000000077" }
fire("LOOT_OPENED")
loot = {}
eq(P.Total(me) - wkBefore, 15 + 15 + 25, "two targets and the whole (two-target) hunt")
local hits = ns.Work.WeeklyHits(P.Player(me))
ok(hits.z1429 and hits.r3270, "both hits recorded")
local _, huntBand = ns.Work.WeeklyHits(P.Player(me))
eq(huntBand, 3, "the hunt was in this character's band")
-- An alt in another band can't run a second hunt the same week.
local altBefore = P.Total(me)
ns.Ledger.AddDemo({ who = me, seq = 900, t = now + 5, kind = "weekly", key = P.WeekStart() .. "/1/r61" })
ns.Fire("ENTRY_MERGED", {})
eq(P.Total(me), altBefore, "one hunt a player a week: another band's target pays nothing")
ns.Ledger.ClearDemo()
ns.Fire("ENTRY_MERGED", {})
ns.Work.weeklyOverride = {}

---------------------------------------------------------------------------
-- Places the guild has charted: approved submissions you can stand at.
---------------------------------------------------------------------------
local placeBefore = P.Total(me)
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.40, 0.50 end } end
here = 1429
ns.Work.CheckPlaces()
local found = ns.Ledger.Has("place", "Other-Realm#6")
ok(found ~= nil, "standing at an approved place finds it")
eq(P.Total(me) - placeBefore, 25, "a guild place is worth 25")
ns.Work.CheckPlaces()
eq(P.Total(me) - placeBefore, 25, "and only once")
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.25 end } end

---------------------------------------------------------------------------
-- Collections and milestones.
---------------------------------------------------------------------------
-- Every Elwynn rare found: a bestiary collection.
local elwynnIds = {}
for id, r in pairs(ns.Bestiary.Catalog()) do if r.zone == 1429 then elwynnIds[#elwynnIds + 1] = id end end
for i, id in ipairs(elwynnIds) do ns.Ledger.AddDemo({ who = "Other-Realm", seq = 700 + i, t = now + i, kind = "rare", key = id }) end
-- And enough rares besides for the guild's first milestone (25).
for i = 1, 25 do ns.Ledger.AddDemo({ who = "Other-Realm", seq = 750 + i, t = now + 50 + i, kind = "rare", key = 950000 + i }) end
ns.Fire("ENTRY_MERGED", {})
local cols = ns.Work.Collections("Other-Realm")
local hasElwynn = false
for _, cl in ipairs(cols) do if cl.kind == "bestiary" and cl.key == 1429 then hasElwynn = cl.points == 30 end end
ok(hasElwynn, "every Elwynn rare: the Bestiary of Elwynn Forest, worth 30")
local reached, nextGoal = ns.Work.Milestones({ [me] = true, ["Other-Realm"] = true, ["Away-Realm"] = true })
ok(#reached >= 1, "the guild reached a milestone (rares)")
ok(nextGoal ~= nil and nextGoal.need > nextGoal.have, "and has a next one to aim for")
ns.Ledger.ClearDemo()
ns.Fire("ENTRY_MERGED", {})

---------------------------------------------------------------------------
-- Seasons: quarters, named, with champions once they end.
---------------------------------------------------------------------------
local ss = P.SeasonStart(now)
local sd = os.date("!*t", ss)
ok(sd.day == 1 and sd.hour == 0 and (sd.month - 1) % 3 == 0, "a season starts on the 1st of a quarter")
eq(P.SeasonName(P.SeasonStart(1794000000)), "Season 1", "autumn 2026 is Season 1")
eq(P.SeasonPeriod(P.SeasonStart(1794000000)), "Autumn 2026", "November is in the autumn season")
eq(P.SeasonFull(P.SeasonEnd(P.SeasonStart(1794000000))), "Season 2 (Winter 2027)", "then Season 2, winter 2027")
ok(P.SeasonDaysLeft() > 40 and P.SeasonDaysLeft() < 60, "about seven weeks of Season 1 left")
eq(os.date("!*t", P.SeasonEnd(ss)).month, (sd.month + 2) % 12 + 1, "and ends three months on")
eq(#P.Champions({ [me] = true }), 0, "no champions before a season has ended")
-- Nothing from before Season 1 makes a champion.
ns.Ledger.AddDemo({ who = "Other-Realm", seq = 800, t = P.SeasonStart(now) - 30 * 86400, kind = "zone", key = 1446 })
ns.Fire("ENTRY_MERGED", {})
eq(#P.Champions({ [me] = true, ["Other-Realm"] = true }), 0, "no champions from before Season 1")
ns.Ledger.ClearDemo()
-- Into Season 2: Season 1's top three are written up.
local saved = now
ns.Ledger.AddDemo({ who = "Other-Realm", seq = 801, t = now, kind = "zonefull", key = 1446 })
now = P.SeasonEnd(P.SeasonStart(now)) + 86400
ns.Fire("ENTRY_MERGED", {})
local champs = P.Champions({ [me] = true, ["Other-Realm"] = true })
eq(#champs, 1, "Season 1 has its champions in Season 2")
eq(champs[1] and champs[1].name, "Season 1", "named by number")
eq(champs[1] and champs[1].period, "Autumn 2026", "with its time of year")
eq(champs[1] and #champs[1].top, 2, "both of the season's explorers, in order")
ok(champs[1].top[1].points >= champs[1].top[2].points, "highest first")
now = saved
ns.Ledger.ClearDemo()
ns.Fire("ENTRY_MERGED", {})

---------------------------------------------------------------------------
-- Rare alerts: your sighting goes out at once; a guildmate's pops up.
---------------------------------------------------------------------------
local A = ns.Alerts
sent = {}
here = 1429
advance(30)
unit.target = { guid = "Creature-0-1-0-1-99-000000301", class = "rare", name = "Morgaine the Sly" }
fire("PLAYER_TARGET_CHANGED")
tick(5)
ok(sentStarting("A~1~99~1429~"), "spotting a rare tells the guild where")
ok(A.Recent(99) ~= nil, "and it's on your own map")
sent = {}
advance(30)
unit.target = { guid = "Creature-0-1-0-1-99-000000302", class = "rare", name = "Morgaine the Sly" }
fire("PLAYER_TARGET_CHANGED")
tick(5)
ok(not sentStarting("A~1~99~"), "not again a minute later")

local popups = {}
ns.Listen("RARE_ALERT", function(a, target) popups[#popups + 1] = { a = a, target = target } end)
-- Level 10 rare, level 30 you: not worth a pop-up...
fire("CHAT_MSG_ADDON", "LoE", "A~1~79~1429~40.9~77.5~", "GUILD", "Other-Realm")
eq(#popups, 0, "a rare far below your level doesn't pop up")
ok(A.Recent(79) and A.Recent(79).who == "Other-Realm", "but it's on the map, with who saw it")
-- ...unless you're hunting it.
ns.Work.weeklyOverride = { { k = "r", id = 79, key = "r79" }, { k = "r", id = 61, key = "r61" } }
fire("CHAT_MSG_ADDON", "LoE", "A~1~79~1429~41.0~77.0~", "GUILD", "Other-Realm")
eq(#popups, 1, "a weekly hunt target pops up whatever its level")
eq(popups[1] and popups[1].target and popups[1].target.why, "weekly", "and says why")
eq(A.Recent(79).x, 41.0, "the newest sighting wins")
fire("CHAT_MSG_ADDON", "LoE", "A~1~79~1429~41.0~77.0~", "GUILD", "Away-Realm")
eq(#popups, 1, "one pop-up per rare every few minutes, however many see it")
-- Pins: the spotted rares and the guild place. A target no one has seen
-- gets no pin: its spawn point in the rare list is never given away.
local function kinds()
	local items = ns.MapPins.Items()
	local byKind = {}
	for _, it in ipairs(items) do byKind[it.kind] = (byKind[it.kind] or 0) + 1 end
	return items, byKind
end
local items, byKind = kinds()
eq(byKind.alert, 2, "pins for the two fresh sightings")
eq(byKind.weekly, nil, "no pin for a hunt target no one has seen")
-- Once a guildmate has seen it, it's pinned where they saw it.
ns.Ledger.AddDemo({ who = "Other-Realm", seq = 990, t = now - 86400, kind = "rare", key = 61, map = 1429, x = 29.5, y = 58.3 })
ns.Fire("ENTRY_MERGED", {})
items, byKind = kinds()
eq(byKind.weekly, 1, "a hunt target the guild has seen is pinned where it was seen")
local seenPin
for _, it in ipairs(items) do if it.kind == "weekly" then seenPin = it end end
ok(seenPin and seenPin.lines[2]:find("Last seen by Other Realm"), "and says who saw it")
eq(byKind.place, 1, "a pin for the guild place")
local placePin
for _, it in ipairs(items) do if it.kind == "place" then placePin = it end end
ok(placePin and placePin.faded, "a place you've been to is faded")
eq(select(1, ns.MapPins.Translate(1429, 0.4, 0.6, 1429)), 0.4, "a pin on its own map stays put")
-- The world map: pins drawn through a data provider, as the game's own are.
MapCanvasDataProviderMixin = { GetMap = function(self) return self.owner end }
function CreateFromMixins(...) local t = {}; for _, m in ipairs({ ... }) do for k, v in pairs(m) do t[k] = v end end; return t end
local canvas = newMock()
WorldMapFrame = {
	AddDataProvider = function(self, prov) prov.owner = self end,
	IsShown = function() return true end,
	GetMapID = function() return 1429 end,
	GetCanvas = function() return canvas end,
	GetCanvasScale = function() return 2 end,
}
local framesBefore = #eventFrames
local prov = ns.MapPins.BuildWorldMap()
ok(prov ~= nil, "the world map takes our pins")
prov:RefreshAllData()
eq(#eventFrames - framesBefore, #items, "one pin for each item on Elwynn's map")
ns.db.settings.mapPins = false
prov:RefreshAllData()
local framesAfter = #eventFrames
prov:RefreshAllData()
eq(#eventFrames, framesAfter, "no new pins with world map pins off")
ns.db.settings.mapPins = true
-- The minimap: 466 yards across at zoom 0 outdoors, 100 pixels wide.
local L = ns.MapPins.Layout
local function one(kind, x, y, facing, square)
	return L({ { item = { kind = kind }, x = x, y = y } }, 0.5, 0.5, 1000, 1000, 466 + 2 / 3, 50, facing, square)[1]
end
local east = one("weekly", 0.8, 0.5)
ok(east.far and math.abs(east.dx - 44) < 0.01 and math.abs(east.dy) < 0.01, "300 yards east: out of range, so on the edge to the east")
local near = one("weekly", 0.52, 0.5)
ok(not near.far and math.abs(near.dx - 20 * 100 / 466.67) < 0.05, "20 yards east: in range, to the right")
eq(one("place", 0.8, 0.5), nil, "a place out of range is hidden")
local turned = one("weekly", 0.5, 0.48, math.pi / 2)
ok(turned.dx > 0 and math.abs(turned.dy) < 0.01, "facing west, something north shows to the right")
local corner = one("bounty", 0.9, 0.9, 0, true)
ok(math.abs(corner.dx - 44) < 0.01 and math.abs(corner.dy - 44) < 0.01, "a square minimap puts it in the corner")
-- Killed: off the map.
fire("CHAT_MSG_ADDON", "LoE", "A~1~79~~~~1", "GUILD", "Other-Realm")
eq(A.Recent(79), nil, "a kill takes it off the map")
ns.Ledger.ClearDemo()
ns.Fire("ENTRY_MERGED", {})
-- Sightings fade after ten minutes.
advance(700)
eq(#A.Spotted(), 0, "old sightings are gone")
-- Alerts can be turned off.
ns.db.settings.alertMode = "off"
fire("CHAT_MSG_ADDON", "LoE", "A~1~79~1429~41.0~77.0~", "GUILD", "Other-Realm")
eq(#popups, 1, "no pop-ups with alerts off")
-- Nearby (the default): a rare in another zone stays on the map only.
ns.db.settings.alertMode = "nearby"
here = 1429
fire("CHAT_MSG_ADDON", "LoE", "A~1~3270~1411~50.0~50.0~", "GUILD", "Other-Realm")
eq(#popups, 1, "a rare in another zone doesn't pop up")
ok(A.Recent(3270) ~= nil, "but it's on the map")
-- Hunted rares only: a rare in your zone you aren't hunting stays quiet.
ns.db.settings.alertMode = "targets"
fire("CHAT_MSG_ADDON", "LoE", "A~1~99~1429~30.0~60.0~", "GUILD", "Other-Realm")
eq(#popups, 1, "hunted-only mode skips other rares")
-- Every rare: but no more than four in ten minutes.
ns.db.settings.alertMode = "all"
ns.Work.weeklyOverride = {}
UnitLevel = function() return 1 end
for i, id in ipairs({ 61, 99, 471, 3270, 79 }) do
	fire("CHAT_MSG_ADDON", "LoE", ("A~1~%d~1429~30.0~60.0~"):format(id), "GUILD", "Away-Realm")
end
eq(#popups, 5, "at most four pop-ups in ten minutes for rares you aren't hunting")
UnitLevel = function() return 30 end
eq(ns.Commands.alerts and (function() ns.db.settings.alertMode = "off"; ns.Commands.alerts(); return ns.db.settings.alertMode end)(), "nearby", "/loe alerts steps on from off to nearby")
ns.Work.weeklyOverride = {}

-- Ko-fi: the link box opens with the link ready to copy.
SlashCmdList.LEAGUEOFEXPLORERS("kofi")
ok(ns.Support.box and ns.Support.box._shown, "Ko-fi box shown")
eq(ns.Support.box.field.edit:GetText(), "https://ko-fi.com/vaxorus", "the Ko-fi link is in the box")

-- Solo mode: off in a guild until chosen; on, the guild pages, guild
-- firsts, expeditions and sharing step aside.
ns.Char().solo = nil
ok(not ns.Solo(), "in a guild, guild mode by default")
IsInGuild = function() return false end
ok(ns.Solo(), "outside a guild, solo by default")
IsInGuild = function() return true end
ns.Guild.SetSolo(true)
ok(ns.Solo(), "solo mode chosen")
ok(not ns.Journal.Available({ guild = true }) and ns.Journal.Available({}), "guild pages step aside")
ns.Journal.Show("leaders")
tick(8)
eq(ns.Journal.Current().id, "journal", "a guild page opens your own instead")
eq(#ns.Work.Expeditions(), 0, "no officer expeditions while solo")
local soloAsks = false
for _, d in ipairs(select(5, ns.Points.RankOf(ns.Me())) or {}) do
	if d.label == "first guild finds" then soloAsks = true end
end
ok(not soloAsks, "ranks don't ask for guild firsts")
local firstRare
for _, e in ipairs(ns.db.entries) do
	if e.kind == "rare" and ns.Ledger.IsFirst(e) then firstRare = e end
end
if firstRare then eq(ns.Points.Of(firstRare), ns.Points.Value("rare"), "no guild-first bonus") end
local sentSolo = 0
local realSend = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function() sentSolo = sentSolo + 1 end
ns.Sync.SendAlert(61, 1429, 30, 60, false)
flush()
C_ChatInfo.SendAddonMessage = realSend
eq(sentSolo, 0, "nothing is sent while solo")
SlashCmdList.LEAGUEOFEXPLORERS("solo")
ok(not ns.Solo(), "/loe solo switches back to guild mode")
ns.Journal.Toggle()
tick(8)

print(("%d checks, %d failures"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
