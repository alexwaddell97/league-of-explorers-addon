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

---------------------------------------------------------------------------
-- Names. One form for every character everywhere in the journal: the name
-- as the game gives it, without our own realm on the end (a character from
-- another realm keeps theirs).
--
-- Forever's characters have surnames, which the game writes with a hyphen
-- ("Brennan-Black"), the same mark it uses between a name and its realm.
-- So the journal never splits a name at a hyphen: it only takes off a
-- realm it recognises as ours, in any of the ways the game spells it. The
-- roster, addon messages and the player's own name then all agree.
---------------------------------------------------------------------------
local realmForms
local function ownRealms()
	if realmForms then return realmForms end
	local list = {}
	local function add(r)
		if type(r) == "string" and r ~= "" then
			list[#list + 1] = r
			local squeezed = r:gsub("[%s%-']", "")
			if squeezed ~= r then list[#list + 1] = squeezed end
		end
	end
	add(GetNormalizedRealmName and GetNormalizedRealmName())
	add(GetRealmName and GetRealmName())
	-- Longest first, so "Realm 9 RP PvP" goes before a shorter form of it.
	table.sort(list, function(a, b) return #a > #b end)
	if #list > 0 then realmForms = list end
	return list
end

function ns.Name(n)
	n = ns.Readable(n)
	if type(n) ~= "string" or n == "" then return nil end
	for _, r in ipairs(ownRealms()) do
		local suffix = "-" .. r
		if #n > #suffix and n:sub(-#suffix) == suffix then return n:sub(1, -#suffix - 1) end
	end
	return n
end

local me
-- The logged-in character's name, in the journal's one form. The roster
-- has the last word (see Guild.lua, which checks it by GUID).
function ns.Me()
	if me then return me end
	local name, realm = UnitFullName("player")
	if not name then return nil end
	me = ns.Name((realm and realm ~= "") and (name .. "-" .. realm) or name)
	return me
end

-- Renames this character everywhere in the saved journal (old -> new),
-- for when the roster shows the journal had it under another name.
function ns.SetMe(new)
	local old = ns.Me()
	if not new or new == old then return end
	me = new
	local db = ns.db
	if not (db and old) then return end
	local oldId, newId = old .. "#", new .. "#"
	local function swap(v)
		if type(v) ~= "string" then return v end
		if v == old then return new end
		local i = v:find(oldId, 1, true)
		if i then return v:sub(1, i - 1) .. newId .. v:sub(i + #oldId) end
		return v
	end
	for _, e in ipairs(db.entries) do
		e.who, e.id, e.key = swap(e.who), swap(e.id), swap(e.key)
	end
	if db.chars[old] and not db.chars[new] then db.chars[new], db.chars[old] = db.chars[old], nil end
	if db.seq[old] then db.seq[new], db.seq[old] = math.max(db.seq[new] or 0, db.seq[old]), nil end
	for _, f in pairs(db.finds) do
		for _, s in ipairs(f.sightings or {}) do s.who = swap(s.who) end
		if f.first then f.first.who = swap(f.first.who) end
	end
	if ns.Ledger then ns.Ledger.Rebuild() end
	ns.Debug("you are now", new, "(was", old .. ")")
end

-- For reading: surnames with a space, as the game shows them in chat.
function ns.ShortName(who)
	if not who then return "?" end
	return (who:gsub("%-", " "))
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
	bookAnim = true,    -- the book opens and closes like a tome
	sound = true,
	debug = false,
	minimap = { angle = 215, hide = false },
	detect = { vignette = true, nameplate = true, target = true },
	page = "journal",
	alertMode = "nearby", -- which guild rare sightings pop up (see Alerts.lua)
	mapPins = true,     -- pins on the world map
	minimapPins = true, -- pins on the minimap
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
	db.notes = db.notes or {}
	db.creatures = db.creatures or {}
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
	print("  /loe - open or close the window")
	print("  /loe status - check which game features the addon can use")
	print("  /loe minimap - show or hide the minimap button")
	print("  /loe toasts - turn discovery pop-ups on or off")
	print("  /loe toasts move - move the pop-ups (/loe toasts reset puts them back)")
	print("  /loe whoami - show your character name as the game and addon see it")
	print("  /loe demo - a tour of the addon with an example guild")
	print("  /loe alerts - choose which guild rare sightings pop up")
	print("  /loe solo - switch between solo and guild mode")
	print("  /loe kofi - show the Ko-fi link")
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
		local sub = (rest or ""):lower()
		if sub == "move" and ns.MoveToasts then
			ns.MoveToasts(true)
		elseif sub == "reset" and ns.ResetToasts then
			ns.ResetToasts()
			ns.Print("pop-ups are back at the top of the screen.")
		else
			ns.db.settings.toasts = not ns.db.settings.toasts
			ns.Print("discovery pop-ups", ns.db.settings.toasts and "on" or "off")
		end
	elseif cmd == "debug" then
		ns.db.settings.debug = not ns.db.settings.debug
		ns.Print("debug", ns.db.settings.debug and "on" or "off")
	elseif ns.Commands[cmd] then
		ns.Commands[cmd](rest)
	else
		help()
	end
end
