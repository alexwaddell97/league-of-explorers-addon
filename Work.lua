-- The guild's own work: officers, expeditions and bounties, and submitted
-- discoveries. Everything here is written as ledger entries (see
-- Ledger.lua), so it syncs, merges and recovers exactly like discoveries,
-- and the points it awards are worked out from the entries, the same on
-- every member's computer.
--
--   cfg   the guild master's settings: key = time, name = the lowest guild
--         rank (by index; 0 is the guild master) that counts as an officer
--   exp   an officer's expedition or bounty: key = time posted, name =
--         title, mask = goals ("z1411,f1412,r61": discover zone 1411, fully
--         explore 1412, kill rare 61), note = "exp:50:ends" or "bounty:50:ends"
--         (":" because "|" is the game's escape character and never travels)
--   expx  an officer withdrawing one: key = its id
--   hunt  a member meeting a goal: key = "<expedition id>/<goal>", written as
--         it happens (visiting the zone, being in it fully explored,
--         killing the rare), so only what you do after it's posted counts
--   sub   a member's submission: key = time, name = title, note = why, map/x/y
--   rev   an officer's review of one: key = its id, name = "approved"/"declined"

local _, ns = ...

local Wk = {}
ns.Work = Wk

local DEFAULT_OFFICER_RANK = 1 -- the guild master and the rank below

---------------------------------------------------------------------------
-- Preview: lets anyone try the officer and guild master tools. While it's
-- on, you count as the guild master on your own computer only. Everything
-- made meanwhile is marked as a test: it is never sent to the guild (whose
-- members would refuse it anyway, going by the real roster), it is hidden
-- once preview is off, and it is deleted then.
---------------------------------------------------------------------------

function Wk.Preview() return (ns.db and ns.db.settings.preview) or Wk.demo or false end

local function test() return Wk.Preview() or nil end

-- Only test entries made while previewing are seen while previewing.
local function visible(e) return not e.test or Wk.Preview() end

function Wk.SetPreview(on)
	ns.db.settings.preview = on and true or nil
	if not on then
		local kept, removed = {}, 0
		for _, e in ipairs(ns.db.entries) do
			if e.test then removed = removed + 1 else kept[#kept + 1] = e end
		end
		ns.db.entries = kept
		ns.Ledger.Rebuild()
		if removed > 0 then ns.Print(("preview off: %d test entries deleted."):format(removed)) end
	else
		ns.Print("preview on: you can try the officer and guild master tools. Nothing you create is sent to the guild.")
	end
	ns.Fire("ENTRY_MERGED", {})
end

---------------------------------------------------------------------------
-- Officers
---------------------------------------------------------------------------

-- real = the guild's actual roster, ignoring preview.
function Wk.IsLeader(who, real)
	if not real and who == ns.Me() and Wk.Preview() then return true end
	local m = ns.Guild.Member(who)
	return m and m.rankIndex == 0 or false
end

function Wk.OfficerRank()
	for _, e in ipairs(ns.Ledger.Query({ kind = "cfg" })) do
		if visible(e) and Wk.IsLeader(e.who) and tonumber(e.name) then return tonumber(e.name) end
	end
	return DEFAULT_OFFICER_RANK
end

function Wk.IsOfficer(who, real)
	if not real and who == ns.Me() and Wk.Preview() then return true end
	local m = ns.Guild.Member(who)
	return m and m.rankIndex ~= nil and m.rankIndex <= Wk.OfficerRank() or false
end

-- The guild's rank names, from the game: { [index] = name }, 0 the guild master.
function Wk.RankNames()
	local out = {}
	local n = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
	for i = 1, n do
		out[i - 1] = GuildControlGetRankName and GuildControlGetRankName(i) or ("Rank " .. (i - 1))
	end
	return out, n
end

function Wk.AmOfficer() return ns.Me() and Wk.IsOfficer(ns.Me()) or false end

-- The guild master sets which ranks count as officers.
function Wk.SetOfficerRank(n)
	if not Wk.IsLeader(ns.Me()) then return false end
	ns.Ledger.Award("cfg", ns.Now(), { name = tostring(n), test = test() })
	return true
end

---------------------------------------------------------------------------
-- Expeditions and bounties
---------------------------------------------------------------------------

Wk.GOALS = { z = "zone", f = "zonefull", r = "rare" }

local function parseGoals(mask)
	local goals = {}
	for item in (mask or ""):gmatch("[^,]+") do
		local k, id = item:match("^(%a)(%d+)$")
		if k and Wk.GOALS[k] then goals[#goals + 1] = { k = k, id = tonumber(id), key = k .. id } end
	end
	return goals
end

function Wk.GoalName(g)
	if g.k == "r" then
		local r = ns.RareList and ns.RareList[g.id]
		return "Kill " .. ((r and r[1]) or ("rare " .. g.id))
	end
	local zone = ns.MapName(g.id) or ("zone " .. g.id)
	return (g.k == "f" and "Fully explore " or "Visit ") .. zone
end

-- Every expedition and bounty, newest first, withdrawn ones marked.
function Wk.Expeditions()
	if ns.Solo() then return {} end
	local withdrawn = {}
	for _, e in ipairs(ns.Ledger.Query({ kind = "expx" })) do
		if visible(e) and Wk.IsOfficer(e.who) then withdrawn[tostring(e.key)] = e end
	end
	local list = {}
	for _, e in ipairs(ns.Ledger.Query({ kind = "exp" })) do
		if visible(e) and Wk.IsOfficer(e.who) then
			local kind, reward, ends = (e.note or ""):match("^(%a+):(%d+):(%d*)$")
			list[#list + 1] = {
				id = e.id, by = e.who, t = e.t, title = e.name or "Expedition",
				bounty = kind == "bounty", reward = tonumber(reward) or 50,
				ends = tonumber(ends), goals = parseGoals(e.mask),
				withdrawn = withdrawn[e.id] ~= nil,
				test = e.test,
			}
		end
	end
	return list
end

function Wk.IsOpen(x)
	return not x.withdrawn and (not x.ends or ns.Now() < x.ends)
end

-- Posts an expedition (or bounty) as this officer. goals: { "z1411", ... }
function Wk.Post(title, bounty, goals, reward, days)
	if not Wk.AmOfficer() or #goals == 0 then return nil end
	local ends = days and (ns.Now() + days * 86400) or nil
	return ns.Ledger.Award("exp", ns.Now(), {
		name = title, mask = table.concat(goals, ","),
		note = ("%s:%d:%s"):format(bounty and "bounty" or "exp", reward, ends and tostring(ends) or ""),
		test = test(),
	})
end

function Wk.Withdraw(x)
	if not Wk.AmOfficer() then return nil end
	return ns.Ledger.Award("expx", x.id, { test = test() })
end

-- When a member met a goal: their hunt entry's time, or nil.
function Wk.GoalDone(x, g, who)
	local e = ns.Ledger.Has("hunt", x.id .. "/" .. g.key, who)
	return e and e.t or nil
end

-- How far a member is: goals met, total, and when they finished (or nil).
function Wk.Progress(x, who)
	local done, last = 0, 0
	for _, g in ipairs(x.goals) do
		local t = Wk.GoalDone(x, g, who)
		if t then
			done = done + 1
			if t > last then last = t end
		end
	end
	local finished = done == #x.goals and #x.goals > 0 and (not x.ends or last <= x.ends) and last or nil
	return done, #x.goals, finished
end

-- Everyone who finished, earliest first: { { who, t } }.
function Wk.Finishers(x)
	local who = {}
	for _, e in ipairs(ns.Ledger.Query({ kind = "hunt" })) do
		if tostring(e.key):sub(1, #x.id + 1) == x.id .. "/" then who[e.who] = true end
	end
	local out = {}
	for w in pairs(who) do
		local _, _, t = Wk.Progress(x, w)
		if t then out[#out + 1] = { who = w, t = t } end
	end
	table.sort(out, function(a, b)
		if a.t ~= b.t then return a.t < b.t end
		return a.who < b.who
	end)
	return out
end

-- Writes hunt entries for any open goal the player meets right now.
-- what: "zone" with a zone id (visiting it; fully explored when full),
-- or "kill" with a creature id (see Kills in Rares.lua).
function Wk.Check(what, id, data)
	local me = ns.Me()
	if not me then return end
	Wk.CheckWeekly(what, id, data)
	for _, x in ipairs(Wk.Expeditions()) do
		if Wk.IsOpen(x) then
			for _, g in ipairs(x.goals) do
				local hit = false
				if what == "kill" and g.k == "r" and g.id == id then hit = true end
				if what == "zone" and g.id == id then
					if g.k == "z" then hit = true end
					if g.k == "f" and data and data.full then hit = true end
				end
				if hit and not Wk.GoalDone(x, g, me) then
					ns.Ledger.Award("hunt", x.id .. "/" .. g.key, {
						map = data and data.map, x = data and data.x, y = data and data.y, test = x.test,
					})
					local _, _, finished = Wk.Progress(x, me)
					if finished then ns.Fire("EXPEDITION_DONE", x) end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Submissions
---------------------------------------------------------------------------

function Wk.Submit(title, why)
	local map = C_Map.GetBestMapForUnit("player")
	local x, y
	local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
	if pos then
		x, y = pos:GetXY()
		if x and y and not (x == 0 and y == 0) then x, y = x * 100, y * 100 else x, y = nil, nil end
	end
	return ns.Ledger.Award("sub", ns.Now(), {
		name = title, note = why, map = map and (ns.Exploration.ZoneOf(map) or map), x = x, y = y,
		test = test(),
	})
end

-- Every submission, newest first, with its latest officer review.
function Wk.Submissions()
	local reviews = {}
	for _, e in ipairs(ns.Ledger.Query({ kind = "rev" })) do
		local k = tostring(e.key)
		if visible(e) and Wk.IsOfficer(e.who) and not reviews[k] then reviews[k] = e end -- newest first
	end
	local list = {}
	for _, e in ipairs(ns.Ledger.Query({ kind = "sub" })) do
		local r = visible(e) and reviews[e.id]
		if visible(e) then
		list[#list + 1] = {
			id = e.id, who = e.who, t = e.t, title = e.name or "A discovery", note = e.note,
			map = e.map, x = e.x, y = e.y,
			status = r and r.name or "pending", reviewer = r and r.who, reviewedAt = r and r.t,
			test = e.test,
		}
		end
	end
	return list
end

function Wk.Review(sub, approved)
	-- Officers can't review their own, except to try it out in preview.
	if not Wk.AmOfficer() or (sub.who == ns.Me() and not Wk.Preview()) then return nil end
	return ns.Ledger.Award("rev", sub.id, { name = approved and "approved" or "declined", test = test() })
end

---------------------------------------------------------------------------
-- The weekly hunt: every week the journal sets a hunt for each level band,
-- three rares and two zones that suit that band and lie outside the other
-- faction's home zones, worked out from the week's date so it's the same
-- for everyone in the band. Killing a rare or setting foot in a zone
-- that week pays, even if you found them long ago. Rares come back, so the
-- hunt never runs out.
--
-- One hunt per player a week: the band of their first target (whichever
-- character), or before that, the band their character was in when it
-- first looked this week. Levelling mid-week doesn't swap the targets.
---------------------------------------------------------------------------
local WEEK = 7 * 86400
local weeklyCache = {}

Wk.BANDS = {
	{ lo = 1, hi = 19, label = "1-19" },
	{ lo = 20, hi = 29, label = "20-29" },
	{ lo = 30, hi = 39, label = "30-39" },
	{ lo = 40, hi = 49, label = "40-49" },
	{ lo = 50, hi = 60, label = "50-60" },
}

function Wk.BandOf(level)
	level = tonumber(level) or 1
	for i, b in ipairs(Wk.BANDS) do
		if level <= b.hi then return i end
	end
	return #Wk.BANDS
end

-- The levels each zone is meant for. Forever's own zones aren't here: they
-- go by the levels of their rares, and a zone with none sits out the hunt.
local ZONE_LEVELS = {
	[1411] = { 1, 10 }, [1412] = { 1, 10 }, [1413] = { 10, 25 }, [1416] = { 30, 40 },
	[1417] = { 30, 40 }, [1418] = { 35, 45 }, [1419] = { 45, 55 }, [1420] = { 1, 10 },
	[1421] = { 10, 20 }, [1422] = { 51, 58 }, [1423] = { 53, 60 }, [1424] = { 20, 30 },
	[1425] = { 40, 50 }, [1426] = { 1, 10 }, [1427] = { 43, 50 }, [1428] = { 50, 58 },
	[1429] = { 1, 10 }, [1430] = { 55, 60 }, [1431] = { 18, 30 }, [1432] = { 10, 20 },
	[1433] = { 15, 25 }, [1434] = { 30, 45 }, [1435] = { 35, 45 }, [1436] = { 10, 20 },
	[1437] = { 20, 30 }, [1438] = { 1, 10 }, [1439] = { 10, 20 }, [1440] = { 18, 30 },
	[1441] = { 25, 35 }, [1442] = { 15, 27 }, [1443] = { 30, 40 }, [1444] = { 40, 50 },
	[1445] = { 35, 45 }, [1446] = { 40, 50 }, [1447] = { 45, 55 }, [1448] = { 48, 55 },
	[1449] = { 48, 55 }, [1450] = { 55, 60 }, [1451] = { 55, 60 }, [1452] = { 55, 60 },
}

-- The other faction's home zones: no hunting there.
local HOSTILE = {
	Alliance = { [1411] = true, [1412] = true, [1420] = true, [1421] = true },
	Horde = { [1426] = true, [1429] = true, [1432] = true, [1436] = true, [1438] = true, [1439] = true },
}

function Wk.Faction()
	local ch = ns.Char and ns.Char()
	return (ch and ch.faction) or (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
end

local zoneRange
function Wk.ZoneLevels(zone)
	local z = ZONE_LEVELS[zone]
	if z then return z[1], z[2] end
	if not zoneRange then
		zoneRange = {}
		for _, r in pairs(ns.RareList or {}) do
			local id = ns.Exploration.ZoneOf(r[2]) or r[2]
			if not ZONE_LEVELS[id] and r[5] then
				local zr = zoneRange[id] or { r[5], r[6] or r[5] }
				zr[1] = math.min(zr[1], r[5])
				zr[2] = math.max(zr[2], r[6] or r[5])
				zoneRange[id] = zr
			end
		end
	end
	local zr = zoneRange[zone]
	if zr then return zr[1], zr[2] end
end

local function sortedKeys(t, keep)
	local out = {}
	for k, v in pairs(t or {}) do
		if keep(k, v) then out[#out + 1] = k end
	end
	table.sort(out)
	return out
end

-- A band's targets for a week: { { k = "r"|"z", id, key } }, five of them.
function Wk.Weekly(weekStart, band)
	weekStart = weekStart or ns.Points.WeekStart()
	if Wk.weeklyOverride then return Wk.weeklyOverride end
	band = band or Wk.MyBand(weekStart)
	local faction = Wk.Faction()
	local ck = weekStart .. ":" .. band .. ":" .. faction
	if weeklyCache[ck] then return weeklyCache[ck] end
	local b = Wk.BANDS[band] or Wk.BANDS[1]
	local hostile = HOSTILE[faction] or {}
	-- Rares at the band's levels (a couple over is fair game for a group).
	local rares = sortedKeys(ns.RareList, function(_, r)
		local lo, hi = r[5], r[6] or r[5]
		if not lo or lo > b.hi + 2 or hi < b.lo then return false end
		return not hostile[ns.Exploration.ZoneOf(r[2]) or r[2]]
	end)
	-- Zones whose levels overlap the band.
	local zones = sortedKeys(ns.Areas, function(id)
		if id == 1459 or hostile[id] then return false end
		local lo, hi = Wk.ZoneLevels(id)
		return lo and lo <= b.hi and hi >= b.lo
	end)
	-- A small, fixed random sequence seeded by the week and band: same everywhere.
	local seed = (math.floor(weekStart / WEEK) * 7919 + band * 104723 + 104729) % 2147483647
	local function nextInt(n)
		seed = (seed * 48271) % 2147483647
		return seed % n + 1
	end
	local out, used = {}, {}
	local function pick(list, k, count)
		local tries = 0
		while count > 0 and #list > 0 and tries < 200 do
			tries = tries + 1
			local id = list[nextInt(#list)]
			if not used[k .. id] then
				used[k .. id] = true
				out[#out + 1] = { k = k, id = id, key = k .. id }
				count = count - 1
			end
		end
	end
	pick(rares, "r", 3)
	pick(zones, "z", 2)
	weeklyCache[ck] = out
	return out
end

function Wk.WeeklyName(g)
	if g.k == "r" then
		local r = ns.RareList and ns.RareList[g.id]
		return (r and r[1]) or ("Rare " .. g.id), r and ns.MapName(ns.Exploration.ZoneOf(r[2]) or r[2])
	end
	return ns.MapName(g.id) or ("Zone " .. g.id), nil
end

-- A player's hunts, week by week: { [ws] = { band, hits = { [key] = t }, n, last } }.
-- Only the band of their first target that week counts.
local function hunts(player)
	local out = {}
	for _, e in ipairs(ns.Points.Deeds(player)) do -- oldest first
		if e.kind == "weekly" then
			local ws, band, key = tostring(e.key):match("^(%d+)/(%d+)/(.+)$")
			ws, band = tonumber(ws), tonumber(band)
			if ws then
				local w = out[ws]
				if not w then
					w = { band = band, hits = {}, n = 0, last = 0 }
					out[ws] = w
				end
				if band == w.band and not w.hits[key] then
					w.hits[key] = e.t
					w.n = w.n + 1
					if e.t > w.last then w.last = e.t end
				end
			end
		end
	end
	return out
end
Wk.Hunts = hunts

-- When a player hit each of a week's targets: { [key] = t }, and the band
-- they are hunting that week (nil before their first target).
function Wk.WeeklyHits(player, weekStart)
	weekStart = weekStart or ns.Points.WeekStart()
	local w = hunts(player)[weekStart]
	if not w then return {}, nil end
	return w.hits, w.band
end

-- The band this player hunts this week.
function Wk.MyBand(weekStart)
	weekStart = weekStart or ns.Points.WeekStart()
	local me = ns.Me()
	if me then
		local _, band = Wk.WeeklyHits(ns.Points.Player(me), weekStart)
		if band and Wk.BANDS[band] then return band end
	end
	local level = UnitLevel and UnitLevel("player") or 0
	local ch = ns.Char and ns.Char()
	if ch then
		if ch.hunt and ch.hunt.ws == weekStart then return ch.hunt.band end
		if level and level > 0 then
			ch.hunt = { ws = weekStart, band = Wk.BandOf(level) }
			return ch.hunt.band
		end
	end
	return Wk.BandOf(level > 0 and level or 1)
end

function Wk.CheckWeekly(what, id, data)
	local ws = ns.Points.WeekStart()
	local band = Wk.MyBand(ws)
	for _, g in ipairs(Wk.Weekly(ws, band)) do
		if (what == "kill" and g.k == "r" and g.id == id) or (what == "zone" and g.k == "z" and g.id == id) then
			local e = ns.Ledger.Award("weekly", ws .. "/" .. band .. "/" .. g.key, {
				map = data and data.map, x = data and data.x, y = data and data.y,
			})
			if e then ns.Fire("WEEKLY_HIT", g, band) end
		end
	end
end

-- How many of the guild's characters are in each band, by their level now.
function Wk.BandCounts(members)
	local counts = {}
	for i in ipairs(Wk.BANDS) do counts[i] = 0 end
	for who in pairs(members) do
		local m = ns.Guild.Member(who)
		local level = (m and m.level) or (ns.db.chars[who] and ns.db.chars[who].level)
		if level and level > 0 then
			local b = Wk.BandOf(level)
			counts[b] = counts[b] + 1
		end
	end
	return counts
end

---------------------------------------------------------------------------
-- Places the guild has charted: every approved submission is a place in
-- everyone's journal. Standing there (within a few dozen yards) finds it,
-- once, for points; the one who submitted it was already rewarded.
---------------------------------------------------------------------------
local PLACE_YARDS = 30

function Wk.Places()
	local out = {}
	if ns.Solo() then return out end
	for _, s in ipairs(Wk.Submissions()) do
		if s.status == "approved" and s.map and s.x and s.y then out[#out + 1] = s end
	end
	return out
end

local function yardsBetween(map, x1, y1, x2, y2)
	if C_Map.GetWorldPosFromMapPos and CreateVector2D then
		local ok1, _, a = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x1 / 100, y1 / 100))
		local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x2 / 100, y2 / 100))
		if ok1 and ok2 and a and b then
			local ax, ay = a:GetXY()
			local bx, by = b:GetXY()
			return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
		end
	end
	-- No world positions: a zone map is roughly a thousand yards across.
	return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) * 10
end

function Wk.CheckPlaces()
	local me = ns.Me()
	if not me or ns.InCombat() then return end
	local zone = ns.Exploration.CurrentZone()
	if not zone then return end
	local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(zone, "player")
	if not pos then return end
	local px, py = pos:GetXY()
	if not px or (px == 0 and py == 0) then return end
	px, py = px * 100, py * 100
	local mine = ns.Players.Set(ns.Players.MainOf(me))
	for _, p in ipairs(Wk.Places()) do
		if p.map == zone and not mine[p.who] and not ns.Ledger.Has("place", p.id) then
			if yardsBetween(zone, px, py, p.x, p.y) <= PLACE_YARDS then
				ns.Ledger.Award("place", p.id, { name = p.title, map = zone, x = p.x, y = p.y, test = p.test })
			end
		end
	end
end

ns.Listen("READY", function()
	if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(3, function() Wk.CheckPlaces() end) end
end)

---------------------------------------------------------------------------
-- Collections: one-off badges for a whole set, each with its points.
--   bestiary  every rare in a zone found
--   atlas     every zone of a continent fully explored
-- A set finished before the journal was begun is a badge without points.
---------------------------------------------------------------------------
local function zoneRares()
	local byZone = {}
	for id, c in pairs(ns.Bestiary.Catalog()) do
		byZone[c.zone] = byZone[c.zone] or {}
		table.insert(byZone[c.zone], id)
	end
	return byZone
end

function Wk.Collections(player)
	local found, full = {}, {}
	for _, e in ipairs(ns.Points.Deeds(player)) do
		if e.kind == "rare" then found[e.key] = e.t end
		if e.kind == "zonefull" then full[e.key] = full[e.key] or e.t end
		if e.kind == "base" and ns.Areas[e.key] and #ns.Exploration.MaskAreas(e.key, e.mask) >= #ns.Areas[e.key] then
			full[e.key] = full[e.key] or 0
		end
	end
	local out = {}
	for zone, ids in pairs(zoneRares()) do
		local last = 0
		for _, id in ipairs(ids) do
			local t = found[id]
			if not t then last = nil break end
			if t > last then last = t end
		end
		if last then
			out[#out + 1] = { kind = "bestiary", key = zone, t = last, points = ns.Points.Value("bestiary"),
				label = "Bestiary of " .. (ns.MapName(zone) or "?") }
		end
	end
	for _, cont in ipairs(ns.Exploration.Atlas()) do
		local last, count = 0, 0
		for _, z in ipairs(cont.zones) do
			if z.total > 0 then
				count = count + 1
				local t = full[z.id]
				if not t then last = nil break end
				if t > last then last = t end
			end
		end
		if last and count > 0 then
			out[#out + 1] = { kind = "atlas", key = cont.id, t = last, points = last > 0 and ns.Points.Value("atlas") or 0,
				label = "Atlas of " .. cont.name }
		end
	end
	table.sort(out, function(a, b) return a.t > b.t end)
	return out
end

---------------------------------------------------------------------------
-- Rewards: points worked out from the entries rather than written as
-- entries, per player: expeditions, bounties, approved submissions, the
-- weekly hunt and collections. { who = player, t, points, kind, ref, label }
---------------------------------------------------------------------------
local rewards

local function compute()
	local out = {}
	local P, Pl = ns.Points, ns.Players
	-- Expeditions and bounties: once per player, by their first character to finish.
	for _, x in ipairs(Wk.Expeditions()) do
		local seen, order = {}, {}
		for _, f in ipairs(Wk.Finishers(x)) do
			local player = Pl.MainOf(f.who)
			if not seen[player] then
				seen[player] = true
				order[#order + 1] = { who = player, t = f.t }
			end
		end
		if x.bounty then
			if order[1] then out[#out + 1] = { who = order[1].who, t = order[1].t, points = x.reward, kind = "bounty", ref = x, first = true } end
		else
			for i, f in ipairs(order) do
				local bonus = i == 1 and math.floor(x.reward / 2) or 0
				out[#out + 1] = { who = f.who, t = f.t, points = x.reward + bonus, kind = "expedition", ref = x, first = i == 1 }
			end
		end
	end
	-- Approved submissions.
	for _, s in ipairs(Wk.Submissions()) do
		if s.status == "approved" then
			out[#out + 1] = { who = Pl.MainOf(s.who), t = s.reviewedAt, points = P.Value("secret"), kind = "secret", ref = s }
		end
	end
	-- The weekly hunt and collections, for every player with entries.
	local players = {}
	for _, e in ipairs(ns.db.entries) do players[Pl.MainOf(e.who)] = true end
	for player in pairs(players) do
		for ws, w in pairs(hunts(player)) do
			for key, t in pairs(w.hits) do
				out[#out + 1] = { who = player, t = t, points = P.Value("weekly"), kind = "weekly", ref = key }
			end
			if w.n >= #Wk.Weekly(ws, w.band) then
				out[#out + 1] = { who = player, t = w.last, points = P.Value("weeklyall"), kind = "weeklyall", ref = ws }
			end
		end
		for _, c in ipairs(Wk.Collections(player)) do
			if c.points > 0 then
				out[#out + 1] = { who = player, t = c.t, points = c.points, kind = c.kind, ref = c.key, label = c.label }
			end
		end
	end
	return out
end

function Wk.Rewards()
	if not rewards then rewards = compute() end
	return rewards
end

local function invalidate()
	rewards = nil
end
ns.Listen("ENTRY_ADDED", invalidate)
ns.Listen("ENTRY_MERGED", invalidate)
ns.Listen("ROSTER", invalidate)
ns.Listen("MODE", invalidate)
ns.Listen("DB_READY", invalidate)

---------------------------------------------------------------------------
-- Guild milestones: shared goals, reached together. Each is noted with the
-- moment the guild got there, and the next one to aim for.
---------------------------------------------------------------------------
local MILESTONES = {
	{ key = "rare", label = "rares found by the guild", steps = { 25, 50, 100, 200, 300 } },
	{ key = "zonefull", label = "zones fully explored by the guild", steps = { 10, 25, 40 } },
	{ key = "place", label = "approved guild places", steps = { 5, 15, 30 } },
}

-- Reached: { { t, text } }, oldest first; next: { text, have, need }.
function Wk.Milestones(members)
	local entries = {}
	for _, e in ipairs(ns.db.entries) do
		if members[e.who] then entries[#entries + 1] = e end
	end
	table.sort(entries, function(a, b) return a.t < b.t end)
	local reached, nexts = {}, {}
	for _, m in ipairs(MILESTONES) do
		local seen, count, step = {}, 0, 1
		for _, e in ipairs(entries) do
			-- Places count by submission approved; discoveries by their kind.
			if e.kind == m.key and not seen[e.key] then
				seen[e.key] = true
				count = count + 1
				while m.steps[step] and count >= m.steps[step] do
					reached[#reached + 1] = { t = e.t, text = ("The guild reached %d %s"):format(m.steps[step], m.label) }
					step = step + 1
				end
			end
		end
		if m.steps[step] then nexts[#nexts + 1] = { text = m.label, have = count, need = m.steps[step] } end
	end
	table.sort(reached, function(a, b) return a.t < b.t end)
	-- The nearest next milestone, by how close it is.
	table.sort(nexts, function(a, b) return a.have / a.need > b.have / b.need end)
	return reached, nexts[1]
end

ns.Commands.officers = function(rest)
	local n = tonumber(rest)
	if not n then
		ns.Print(("officers are guild ranks 0 to %d (0 is the guild master). The guild master can change it: /loe officers <rank>"):format(Wk.OfficerRank()))
		return
	end
	if Wk.SetOfficerRank(n) then
		ns.Print(("officers are now guild ranks 0 to %d."):format(n))
	else
		ns.Print("only the guild master can change which ranks are officers.")
	end
end
