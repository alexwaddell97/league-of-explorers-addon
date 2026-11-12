-- League of Explorers: core. Events, internal signals, the saved database,
-- small helpers every module shares, and the slash command.

local ADDON, ns = ...
_G.LeagueOfExplorers = ns

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = GetMeta and GetMeta(ADDON, "Version") or "?"
ns.ADDON = ADDON

---------------------------------------------------------------------------
-- Game events: any number of handlers per event. An event this client does
-- not know is skipped quietly, so one missing event never breaks the rest.
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
	if not handlers[event] then
		local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
		if not ok then return false end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
	return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		xpcall(list[i], geterrorhandler(), event, ...)
	end
end)

---------------------------------------------------------------------------
-- Internal signals between modules ("ENTRY_ADDED", "SIGHTING", ...).
---------------------------------------------------------------------------

local listeners = {}

function ns.Listen(signal, fn)
	listeners[signal] = listeners[signal] or {}
	table.insert(listeners[signal], fn)
end

function ns.Fire(signal, ...)
	local list = listeners[signal]
	if not list then return end
	for i = 1, #list do
		xpcall(list[i], geterrorhandler(), ...)
	end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Forever can hand addons "secret" values for some unit reads (in combat or
-- restricted areas). Comparing or indexing one throws, so every unit read
-- passes through here: a secret value reads as unknown (nil).
function ns.Readable(v)
	if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
	return v
end

-- Seconds since the epoch on the server's clock: the same on every
-- character and every member's computer, so entries sort the same for all.
function ns.Now()
	return (GetServerTime and GetServerTime()) or time()
end

function ns.After(seconds, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(seconds, fn)
	else
		fn()
	end
end

function ns.InCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

local me
-- "Name-Realm" for the logged-in character, once the realm is known.
function ns.Me()
	if me then return me end
	local name, realm = UnitFullName("player")
	realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName())
	if not name or not realm or realm == "" then return nil end
	me = name .. "-" .. realm
	return me
end

-- "Name" alone when the realm is ours, else "Name-Realm".
function ns.ShortName(who)
	if not who then return "?" end
	local name, realm = who:match("^(.-)%-(.+)$")
	if not name then return who end
	local mine = GetNormalizedRealmName and GetNormalizedRealmName()
	if realm == mine then return name end
	return who
end

function ns.MapName(mapID)
	local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
	return info and info.name or nil
end

function ns.Print(...)
	local parts = { ... }
	for i = 1, select("#", ...) do parts[i] = tostring(parts[i]) end
	DEFAULT_CHAT_FRAME:AddMessage("|cffd9b36cLeague of Explorers|r: " .. table.concat(parts, " "))
end

function ns.Debug(...)
	if ns.db and ns.db.settings.debug then ns.Print("|cff999999[debug]|r", ...) end
end

---------------------------------------------------------------------------
-- Saved data (account-wide, so alts share one journal file).
--
-- entries   append-only list of journal entries; the single source of truth
--           for points. Each: { id, who, t, kind, key, name?, map?, x?, y? }.
--           id is "who#seq", unique across the guild once entries are shared.
-- seq       last sequence number used per character.
-- chars     per character: zones, continents and areas seen, and the
--           baseline taken when the journal was first opened.
-- finds     rares and treasures by "kind:id": first sighting, recent sightings.
-- points    officer overrides of point values (empty until guild settings).
-- settings  this player's preferences.
---------------------------------------------------------------------------

local DEFAULT_SETTINGS = {
	toasts = true,
	sound = true,
	debug = false,
	minimap = { angle = 215, hide = false },
	detect = { vignette = true, nameplate = true, target = true },
	page = "journal",
	look = "explorer",
}

local function fill(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			fill(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local function initDB()
	local db = _G.LeagueOfExplorersDB
	if type(db) ~= "table" then db = {} end
	db.version = db.version or 1
	db.entries = db.entries or {}
	db.seq = db.seq or {}
	db.chars = db.chars or {}
	db.finds = db.finds or {}
	db.points = db.points or {}
	db.settings = db.settings or {}
	fill(db.settings, DEFAULT_SETTINGS)
	_G.LeagueOfExplorersDB = db
	ns.db = db
end

-- This character's record, created on first use.
function ns.Char(who)
	who = who or ns.Me()
	if not who then return nil end
	local c = ns.db.chars[who]
	if not c then
		c = { zones = {}, continents = {}, areas = {} }
		ns.db.chars[who] = c
	end
	if who == ns.Me() then
		local _, class = UnitClass("player")
		c.class = class
		c.level = UnitLevel("player")
		c.faction = UnitFactionGroup("player")
	end
	return c
end

---------------------------------------------------------------------------
-- Lifecycle: DB_READY once saved data is loaded, READY once the character
-- is known and in the world (modules start their detection there).
---------------------------------------------------------------------------

ns.On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	initDB()
	ns.Fire("DB_READY")
end)

local started = false
ns.On("PLAYER_ENTERING_WORLD", function()
	if started then return end
	if not ns.Me() then return end
	started = true
	ns.Char()
	ns.Fire("READY")
end)

---------------------------------------------------------------------------
-- /loe and /explorers. Modules add subcommands to ns.Commands.
---------------------------------------------------------------------------

ns.Commands = {}

local function help()
	ns.Print("commands:")
	print("  /loe - open or close the journal")
	print("  /loe status - what the journal can detect on this client")
	print("  /loe minimap - show or hide the minimap button")
	print("  /loe toasts - turn discovery pop-ups on or off")
	print("  /loe look - switch between the Explorer and Blizzard looks")
	print("  /loe debug - turn debug messages on or off")
end

SLASH_LEAGUEOFEXPLORERS1 = "/loe"
SLASH_LEAGUEOFEXPLORERS2 = "/explorers"
SlashCmdList.LEAGUEOFEXPLORERS = function(msg)
	if not ns.db then return end
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "" then
		if ns.Journal then ns.Journal.Toggle() end
	elseif cmd == "help" then
		help()
	elseif cmd == "toasts" then
		ns.db.settings.toasts = not ns.db.settings.toasts
		ns.Print("discovery pop-ups", ns.db.settings.toasts and "on" or "off")
	elseif cmd == "debug" then
		ns.db.settings.debug = not ns.db.settings.debug
		ns.Print("debug", ns.db.settings.debug and "on" or "off")
	elseif ns.Commands[cmd] then
		ns.Commands[cmd](rest)
	else
		help()
	end
end
