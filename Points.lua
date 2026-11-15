-- Points and ranks.
--
-- Points are for the boards: worked out from the entries whenever they are
-- shown, never stored, so a change of values applies to everyone's history
-- alike. They are counted per player (a main and their alts): a zone, rare
-- or treasure counts once for the player, the first time any of their
-- characters finds it.
--
-- Ranks are for what you have done, not how many points you have: each
-- asks for a spread of deeds (zones discovered and fully explored, rares,
-- first guild finds), so no single pursuit gets you there. Exploration
-- done before the journal was begun counts toward your rank, but never for
-- points.

local _, ns = ...

local P = {}
ns.Points = P

-- The scale of rewards. `bonus` kinds are never entries worth points of
-- their own: they are worked out (Work.lua) or added to another entry
-- (rarefirst, to the guild's first find of a rare).
P.KINDS = {
	{ kind = "zone",       label = "Discover a new zone",                  points = 10,  live = true },
	{ kind = "zonefull",   label = "Fully explore a zone",                 points = 40,  live = true },
	{ kind = "continent",  label = "Reach a new continent",          points = 25,  live = true },
	{ kind = "rare",       label = "Find a rare creature",                 points = 10,  live = true },
	{ kind = "rarefirst",  label = "First in the guild to find a rare",    points = 40,  live = true, bonus = true },
	{ kind = "treasure",   label = "Find a new type of treasure",              points = 15,  live = true },
	{ kind = "place",      label = "Visit a guild place",   points = 25,  live = true },
	{ kind = "weekly",     label = "Each target of the weekly hunt",       points = 15,  live = true, bonus = true },
	{ kind = "weeklyall",  label = "Complete the weekly hunt",                points = 25,  live = true, bonus = true },
	{ kind = "secret",     label = "Have a submission approved",    points = 30,  live = true, bonus = true },
	{ kind = "bestiary",   label = "Find every rare in a zone",                 points = 30,  live = true, bonus = true },
	{ kind = "atlas",      label = "Fully explore a continent",   points = 100, live = true, bonus = true },
	{ kind = "expedition", label = "Complete a guild expedition", points = 50,  live = true, bonus = true },
	{ kind = "area",       label = "Explore an area",              points = 0,   live = true },
}

local byKind = {}
for _, k in ipairs(P.KINDS) do byKind[k.kind] = k end
P.BY_KIND = byKind

-- Entries that are worth points by themselves.
local SCORING = { zone = true, zonefull = true, continent = true, rare = true, treasure = true, place = true, area = true }
P.SCORING = SCORING

function P.Value(kind)
	local override = ns.db and ns.db.points[kind]
	if type(override) == "number" then return override end
	local k = byKind[kind]
	return k and k.points or 0
end

function P.Of(entry)
	if not SCORING[entry.kind] then return 0 end
	local v = P.Value(entry.kind)
	if entry.kind == "rare" and not ns.Solo() and ns.Ledger.IsFirst(entry) then v = v + P.Value("rarefirst") end
	return v
end

---------------------------------------------------------------------------
-- Weeks, months and seasons, in UTC, so every member's week starts at the
-- same moment whatever their time zone. Weeks start on Monday; seasons are
-- the quarters of the year.
---------------------------------------------------------------------------
function P.WeekStart(now)
	now = now or ns.Now()
	local d = date("!*t", now)
	local wday = (d.wday + 5) % 7 -- Monday = 0
	return now - wday * 86400 - d.hour * 3600 - d.min * 60 - d.sec
end

function P.MonthStart(now)
	now = now or ns.Now()
	local d = date("!*t", now)
	return now - (d.day - 1) * 86400 - d.hour * 3600 - d.min * 60 - d.sec
end

local SEASONS = { "Winter", "Spring", "Summer", "Autumn" }

local function utc(y, m)
	-- Seconds for 00:00 UTC on the 1st of month m of year y.
	local days = 0
	for yy = 1970, y - 1 do days = days + ((yy % 4 == 0 and (yy % 100 ~= 0 or yy % 400 == 0)) and 366 or 365) end
	local leap = (y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0))
	local month = { 31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	for mm = 1, m - 1 do days = days + month[mm] end
	return days * 86400
end

function P.SeasonStart(now)
	local d = date("!*t", now or ns.Now())
	return utc(d.year, math.floor((d.month - 1) / 3) * 3 + 1)
end

function P.SeasonEnd(start)
	local d = date("!*t", start)
	local m = d.month + 3
	if m > 12 then return utc(d.year + 1, m - 12) end
	return utc(d.year, m)
end

-- Seasons are numbered from the journal's first: Season 1 is autumn 2026
-- (October to December). Anything earlier was the journal being written.
local FIRST_SEASON = utc(2026, 10)
P.FIRST_SEASON = FIRST_SEASON

function P.SeasonNumber(start)
	local a, b = date("!*t", start), date("!*t", FIRST_SEASON)
	return math.floor(((a.year - b.year) * 12 + (a.month - b.month)) / 3) + 1
end

-- "Season 1".
function P.SeasonName(start)
	local n = P.SeasonNumber(start)
	return n >= 1 and ("Season " .. n) or "Before the seasons"
end

-- "Autumn 2026".
function P.SeasonPeriod(start)
	local d = date("!*t", start)
	return ("%s %d"):format(SEASONS[math.floor((d.month - 1) / 3) + 1], d.year)
end

-- "Season 1 (Autumn 2026)".
function P.SeasonFull(start)
	return ("%s (%s)"):format(P.SeasonName(start), P.SeasonPeriod(start))
end

-- Whole days left in the season running now.
function P.SeasonDaysLeft(now)
	now = now or ns.Now()
	return math.max(0, math.ceil((P.SeasonEnd(P.SeasonStart(now)) - now) / 86400))
end

---------------------------------------------------------------------------
-- A player's deeds: their characters' entries, each kind and key counted
-- once (the earliest). Cached until the ledger changes.
---------------------------------------------------------------------------
local deedCache = {}
local function invalidate() deedCache = {} end
ns.Listen("ENTRY_ADDED", invalidate)
ns.Listen("ENTRY_MERGED", invalidate)
ns.Listen("DB_READY", invalidate)
ns.Listen("ROSTER", invalidate)
ns.Listen("MODE", invalidate)

function P.Player(who) return ns.Players and ns.Players.MainOf(who) or who end

-- All of a player's entries, every kind, each kind and key once.
function P.Deeds(player)
	local d = deedCache[player]
	if d then return d end
	local chars = ns.Players and ns.Players.Set(player) or { [player] = true }
	local best = {}
	for _, e in ipairs(ns.db.entries) do
		if chars[e.who] then
			local k = e.kind .. ":" .. tostring(e.key)
			local b = best[k]
			if not b or e.t < b.t then best[k] = e end
		end
	end
	d = {}
	for _, e in pairs(best) do d[#d + 1] = e end
	table.sort(d, function(a, b) return a.t < b.t end)
	deedCache[player] = d
	return d
end

-- A player's points from `since` up to (not including) `upto`.
function P.Total(who, since, upto)
	if not who then return 0 end
	local player = P.Player(who)
	local sum = 0
	for _, e in ipairs(P.Deeds(player)) do
		if (not since or e.t >= since) and (not upto or e.t < upto) then sum = sum + P.Of(e) end
	end
	for _, r in ipairs(ns.Work.Rewards()) do
		if r.who == player and (not since or r.t >= since) and (not upto or r.t < upto) then sum = sum + r.points end
	end
	return sum
end

-- The board: one row per player among `members` (a set of characters),
-- with points from `since` up to `upto`.
function P.Board(members, since, upto)
	local players = {}
	for who in pairs(members) do players[P.Player(who)] = true end
	local list = {}
	for player in pairs(players) do
		local deeds = P.Deeds(player)
		local rewards = false
		for _, r in ipairs(ns.Work.Rewards()) do
			if r.who == player then rewards = true end
		end
		if #deeds > 0 or rewards then
			local last = 0
			for _, e in ipairs(deeds) do
				if SCORING[e.kind] and e.t > last then last = e.t end
			end
			local c = P.Counts(player)
			list[#list + 1] = {
				who = player, points = P.Total(player, since, upto), last = last,
				zones = c.zones, rares = c.rares, firsts = c.firsts,
				alts = #ns.Players.Chars(player) - 1,
			}
		end
	end
	table.sort(list, function(a, b)
		if a.points ~= b.points then return a.points > b.points end
		if a.last ~= b.last then return a.last < b.last end -- first to get there wins a tie
		return a.who < b.who
	end)
	return list
end

-- What the guild has found together: distinct zones, areas, rares and
-- treasures across every member's entries.
function P.Together(members)
	local seen = { zone = {}, area = {}, rare = {}, treasure = {}, continent = {}, zonefull = {}, place = {} }
	for _, e in ipairs(ns.db.entries) do
		if members[e.who] then
			if seen[e.kind] then seen[e.kind][e.key] = true end
			-- Zones and areas known before the journal count for the guild's atlas.
			if e.kind == "base" then
				seen.zone[e.key] = true
				for _, id in ipairs(ns.Exploration.MaskAreas(e.key, e.mask)) do seen.area[id] = true end
			elseif e.kind == "zonefull" then
				seen.zone[e.key] = true
			end
		end
	end
	for zoneID in pairs(seen.zone) do
		local c = ns.Exploration.ContinentOf(zoneID)
		if c then seen.continent[c] = true end
	end
	local out = {}
	for k, set in pairs(seen) do
		local n = 0
		for _ in pairs(set) do n = n + 1 end
		out[k] = n
	end
	out.zoneSet, out.areaSet = seen.zone, seen.area
	return out
end

---------------------------------------------------------------------------
-- Ranks
---------------------------------------------------------------------------

-- Zones with areas to chart (every one of them is "fully explored" at the top).
function P.Explorable()
	local n = 0
	for id in pairs(ns.Areas) do
		if id ~= 1459 then n = n + 1 end -- a battleground
	end
	return n
end

-- Each rank asks for all of its deeds (and every rank below it).
-- full = "all" is every zone that has areas to chart.
P.RANKS = {
	{ name = "Wanderer" },
	{ name = "Pathfinder",      zones = 10 },
	{ name = "Scout",           zones = 20, rares = 10 },
	{ name = "Trailblazer",     zones = 30, full = 5, rares = 25 },
	{ name = "Wayfinder",       zones = 40, full = 10, rares = 50 },
	{ name = "Cartographer",    full = 20, rares = 80 },
	{ name = "Pioneer",         full = 30, rares = 120, firsts = 1 },
	{ name = "Master Explorer", full = 40, rares = 200, firsts = 3 },
	{ name = "Grand Explorer",  full = "all", rares = 300, firsts = 5 },
}

P.DEEDS = {
	{ key = "zones", label = "zones discovered" },
	{ key = "full", label = "zones fully explored" },
	{ key = "rares", label = "rares found" },
	{ key = "firsts", label = "first guild finds" },
}

local function need(r, key)
	-- Solo, there's no guild to be first in.
	if key == "firsts" and ns.Solo() then return nil end
	local v = r[key]
	if v == "all" then return P.Explorable() end
	return v
end
P.Need = need

-- A player's deeds for ranks, counting exploration from before the journal.
function P.Counts(who)
	local player = P.Player(who)
	local zones, full, rares, firsts = {}, {}, {}, 0
	for _, e in ipairs(P.Deeds(player)) do
		if e.kind == "zone" or e.kind == "zonefull" or e.kind == "base" then zones[e.key] = true end
		if e.kind == "zonefull" then full[e.key] = true end
		if e.kind == "base" and ns.Areas[e.key] then
			if #ns.Exploration.MaskAreas(e.key, e.mask) >= #ns.Areas[e.key] then full[e.key] = true end
		end
		if e.kind == "rare" and not rares[e.key] then
			rares[e.key] = true
			if ns.Ledger.IsFirst(e) then firsts = firsts + 1 end
		end
	end
	local function n(t)
		local c = 0
		for _ in pairs(t) do c = c + 1 end
		return c
	end
	return { zones = n(zones), full = n(full), rares = n(rares), firsts = firsts }
end

function P.Firsts(who) return P.Counts(who).firsts end

local function meets(r, c)
	for _, d in ipairs(P.DEEDS) do
		local v = need(r, d.key)
		if v and (c[d.key] or 0) < v then return false end
	end
	return true
end

-- index, rank, next rank (or nil), progress toward it (0-1), and what the
-- next rank asks for: { { label, have, need }, ... }.
function P.RankOf(who)
	local c = P.Counts(who)
	local at = 1
	for i = 2, #P.RANKS do
		if meets(P.RANKS[i], c) then at = i else break end
	end
	local cur, nxt = P.RANKS[at], P.RANKS[at + 1]
	if not nxt then return at, cur, nil, 1, {} end
	local asks, sum, n = {}, 0, 0
	for _, d in ipairs(P.DEEDS) do
		local v = need(nxt, d.key)
		if v then
			local have = c[d.key] or 0
			asks[#asks + 1] = { label = d.label, have = have, need = v }
			sum = sum + math.min(1, have / v)
			n = n + 1
		end
	end
	return at, cur, nxt, n > 0 and sum / n or 1, asks
end

-- What a rank asks for, as text: "30 zones discovered, 5 fully explored, 25 rares".
function P.RankText(r)
	local bits = {}
	for _, d in ipairs(P.DEEDS) do
		local v = need(r, d.key)
		if v then
			local label = d.label
			if d.key == "full" and r.full == "all" then
				bits[#bits + 1] = "every zone fully explored"
			else
				bits[#bits + 1] = v .. " " .. label
			end
		end
	end
	return #bits > 0 and table.concat(bits, ", ") or "from the start"
end

-- The same, short, for tables: "30 zones, 5 explored, 25 rares".
local SHORT = { zones = "zones", full = "explored", rares = "rares", firsts = "firsts" }
function P.RankShort(r)
	local bits = {}
	for _, d in ipairs(P.DEEDS) do
		local v = need(r, d.key)
		if v then bits[#bits + 1] = ((d.key == "full" and r.full == "all") and "all" or tostring(v)) .. " " .. SHORT[d.key] end
	end
	return #bits > 0 and table.concat(bits, ", ") or "from the start"
end

---------------------------------------------------------------------------
-- Seasons: the champions of every season that has ended.
---------------------------------------------------------------------------
function P.Champions(members)
	local first
	for _, e in ipairs(ns.db.entries) do
		if members[e.who] and SCORING[e.kind] and (not first or e.t < first) then first = e.t end
	end
	if not first then return {} end
	local out = {}
	local now = P.SeasonStart(ns.Now())
	local s = math.max(P.SeasonStart(first), FIRST_SEASON)
	while s < now do
		local e = P.SeasonEnd(s)
		local top = {}
		for i, r in ipairs(P.Board(members, s, e)) do
			if i > 3 or r.points <= 0 then break end
			top[#top + 1] = r
		end
		if #top > 0 then
			table.insert(out, 1, { name = P.SeasonName(s), period = P.SeasonPeriod(s), start = s, top = top })
		end
		s = e
	end
	return out
end

-- { [kind] = { count = n, points = p } } for one player.
function P.Breakdown(who, since)
	local out = {}
	for _, e in ipairs(P.Deeds(P.Player(who))) do
		if not since or e.t >= since then
			local b = out[e.kind]
			if not b then
				b = { count = 0, points = 0 }
				out[e.kind] = b
			end
			b.count = b.count + 1
			b.points = b.points + P.Of(e)
		end
	end
	return out
end
