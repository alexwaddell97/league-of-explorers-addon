-- Rare alerts and map targets.
--
-- When you spot a rare alive, the guild hears about it straight away (an
-- "A" message over guild sync, see Sync.lua): who saw it, where and when.
-- When you kill it, a second message tells them it's gone. Alerts aren't
-- kept: a sighting stays on the map for FRESH seconds.
--
-- Whether a guildmate's sighting pops up is up to you (alertMode):
--   nearby   rares in the zone you're in, and rares you're hunting (default)
--   targets  only rares you're hunting (weekly hunt, bounties, expeditions)
--   all      every rare
--   off      none
-- Rares far below your level never pop up unless you're hunting them, and
-- at most CAP others pop up in any ten minutes. Every sighting still goes
-- on the map.
--
-- This file also works out what goes on the world map and minimap (see
-- UI/MapPins.lua): guild places, rares spotted in the last few minutes,
-- and where the rares you're hunting were last seen by the guild.

local _, ns = ...

local A = {}
ns.Alerts = A

local FRESH = 600   -- seconds a sighting stays on the map
local RESEND = 300  -- seconds before the same rare is announced again
local FAR_BELOW = 10 -- rares this many levels under you don't pop up (unless wanted)
local CAP, CAP_WINDOW = 4, 600

A.MODES = {
	{ key = "nearby", label = "your zone and hunted rares" },
	{ key = "targets", label = "hunted rares only" },
	{ key = "all", label = "every rare" },
	{ key = "off", label = "off" },
}

function A.Mode()
	local s = ns.db and ns.db.settings
	if not s then return "nearby" end
	if s.alertMode == nil and s.alerts == false then s.alertMode = "off" end
	s.alerts = nil
	for _, m in ipairs(A.MODES) do
		if m.key == s.alertMode then return m.key end
	end
	return "nearby"
end

function A.ModeLabel(mode)
	mode = mode or A.Mode()
	for _, m in ipairs(A.MODES) do
		if m.key == mode then return m.label end
	end
	return mode
end

-- The next mode along, for the settings button and /loe alerts.
function A.CycleMode()
	local cur, nextKey = A.Mode(), A.MODES[1].key
	for i, m in ipairs(A.MODES) do
		if m.key == cur then nextKey = (A.MODES[i + 1] or A.MODES[1]).key end
	end
	ns.db.settings.alertMode = nextKey
	return nextKey
end

local popped = {} -- times of recent pop-ups that weren't for something you hunt

local recent = {} -- id -> { id, who, t, map, x, y, name, dead }
local sentAt, shownAt = {}, {}
A.recent = recent

local function rareName(id)
	local f = ns.db and ns.db.finds["rare:" .. id]
	local r = ns.RareList and ns.RareList[id]
	return (f and f.name) or (r and r[1]) or ("Rare " .. id)
end
A.RareName = rareName

-- A fresh sighting of this rare (alive), or nil.
function A.Recent(id)
	local a = recent[id]
	if a and not a.dead and ns.Now() - a.t <= FRESH then return a end
	return nil
end

function A.Spotted()
	local out = {}
	for id in pairs(recent) do
		local a = A.Recent(id)
		if a then out[#out + 1] = a end
	end
	table.sort(out, function(a, b) return a.t > b.t end)
	return out
end

---------------------------------------------------------------------------
-- Targets: the rares you are asked to kill right now.
--   { [id] = { why = "weekly"|"bounty"|"expedition", title, reward } }
-- Ones you have already done are left out.
---------------------------------------------------------------------------
function A.Targets()
	local out = {}
	local Wk, P = ns.Work, ns.Points
	local me = ns.Me()
	if not (Wk and me) then return out end
	local ws = P.WeekStart()
	local hits = Wk.WeeklyHits(P.Player(me), ws)
	for _, g in ipairs(Wk.Weekly(ws)) do
		if g.k == "r" and not hits[g.key] then
			out[g.id] = { why = "weekly", title = "Weekly hunt", reward = P.Value("weekly") }
		end
	end
	for _, x in ipairs(Wk.Expeditions()) do
		if Wk.IsOpen(x) then
			local claimed = x.bounty and Wk.Finishers(x)[1]
			for _, g in ipairs(x.goals) do
				if g.k == "r" and not claimed and not Wk.GoalDone(x, g, me) then
					out[g.id] = { why = x.bounty and "bounty" or "expedition", title = x.title, reward = x.reward }
				end
			end
		end
	end
	return out
end

-- Where each of these rares ({ [id] = true }) was last seen alive, by you
-- or the guild: { [id] = { map, x, y, t, who } }. Only real sightings:
-- the spawn points in the rare list are never shown.
function A.LastSeen(ids)
	local out = {}
	local function take(id, map, x, y, t, who)
		local b = out[id]
		if map and x and y and t and (not b or t > b.t) then out[id] = { map = map, x = x, y = y, t = t, who = who } end
	end
	for id in pairs(ids) do
		local f = ns.db.finds["rare:" .. id]
		for _, s in ipairs(f and f.sightings or {}) do
			if not s.dead then take(id, s.map, s.x, s.y, s.t, s.who or ns.Me()) end
		end
	end
	for _, e in ipairs(ns.db.entries) do
		-- Solo: only your own characters' sightings.
		local ours = not ns.Solo() or ns.db.chars[e.who] ~= nil
		if e.kind == "rare" and ids[e.key] and ours and (not e.test or e.demo or ns.Work.Preview()) then take(e.key, e.map, e.x, e.y, e.t, e.who) end
	end
	return out
end

-- Should a guildmate's sighting of this rare (on map) pop up for you?
function A.Wanted(id, map, targets)
	local mode = A.Mode()
	if mode == "off" then return false end
	local t = (targets or A.Targets())[id]
	if t then return true, t end
	if mode == "targets" then return false end
	local r = ns.RareList and ns.RareList[id]
	local level = UnitLevel and UnitLevel("player") or 0
	if r and r[5] and level and level > 0 and (r[6] or r[5]) + FAR_BELOW < level then return false end
	if mode == "nearby" then
		local here = ns.Exploration.CurrentZone()
		local zone = map and (ns.Exploration.ZoneOf(map) or map)
		if not (here and zone == here) then return false end
	end
	-- Not too many, however busy the guild is.
	local now, n = ns.Now(), 0
	for i = #popped, 1, -1 do
		if now - popped[i] > CAP_WINDOW then table.remove(popped, i) else n = n + 1 end
	end
	if n >= CAP then return false end
	return true
end

---------------------------------------------------------------------------
-- Waypoints
---------------------------------------------------------------------------
function A.CanMark(map, x, y)
	return map and x and y and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates
		and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(map)) and true or false
end

function A.Waypoint(map, x, y, label)
	if not A.CanMark(map, x, y) then
		ns.Print("this map can't take a marker.")
		return false
	end
	local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
	if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
	end
	if ok then
		ns.Print(("waypoint set%s: %s %s"):format(label and (" for " .. label) or "", ns.MapName(map) or "?",
			ns.Theme and ns.Theme.Coords(x, y) or ""))
	end
	return ok
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function remember(a)
	recent[a.id] = a
	ns.Fire("ALERTS_CHANGED")
end

ns.Listen("SIGHTING", function(f, s)
	if f.kind ~= "rare" or s.dead or not (s.map and s.x) then return end
	local now = ns.Now()
	remember({ id = f.id, who = ns.Me(), t = now, map = s.map, x = s.x, y = s.y, name = f.name })
	if sentAt[f.id] and now - sentAt[f.id] < RESEND then return end
	sentAt[f.id] = now
	if ns.Sync and ns.Sync.SendAlert then ns.Sync.SendAlert(f.id, s.map, s.x, s.y, false) end
end)

ns.Listen("RARE_KILLED", function(id)
	local a = recent[id]
	if a then
		a.dead = true
		ns.Fire("ALERTS_CHANGED")
	end
	sentAt[id] = nil
	if ns.Sync and ns.Sync.SendAlert then ns.Sync.SendAlert(id, a and a.map, a and a.x, a and a.y, true) end
end)

-- The demo's pretend sighting, and clearing it away.
function A.AddDemo(a)
	a.demo = true
	remember(a)
end

function A.ClearDemo()
	for id, a in pairs(recent) do
		if a.demo then recent[id] = nil end
	end
	ns.Fire("ALERTS_CHANGED")
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
function A.Heard(sender, id, map, x, y, dead)
	if not id then return end
	local now = ns.Now()
	if dead then
		local a = recent[id]
		if a and not a.dead then
			a.dead = true
			ns.Fire("ALERTS_CHANGED")
		end
		return
	end
	if not (map and x and y) then return end
	local a = { id = id, who = sender, t = now, map = map, x = x, y = y, name = rareName(id) }
	remember(a)
	-- One pop-up per rare every few minutes, however many see it.
	if shownAt[id] and now - shownAt[id] < RESEND then return end
	local wanted, target = A.Wanted(id, map)
	if not wanted then return end
	shownAt[id] = now
	if not target then popped[#popped + 1] = now end
	ns.Fire("RARE_ALERT", a, target)
end

-- /loe alerts: step through which guild sightings pop up.
ns.Commands.alerts = function()
	A.CycleMode()
	ns.Print("guild rare alerts: " .. A.ModeLabel())
end
