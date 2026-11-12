-- Points: what each kind of entry is worth, and totals over the journal.
-- Points are worked out from the entries whenever they are shown, never
-- stored, so a change of values (by officers, later) applies to everyone's
-- history the same way.

local _, ns = ...

local P = {}
ns.Points = P

-- The guild's scale of rewards. `live` marks the kinds this version awards;
-- the others arrive with hidden discoveries and expeditions. `bonus` kinds
-- are never entries of their own: rarefirst is added to the rare entry that
-- is first in the guild's shared ledger.
P.KINDS = {
	{ kind = "zone",       label = "Discover a new zone",            points = 10, live = true },
	{ kind = "zonefull",   label = "Fully explore a zone",           points = 25, live = true },
	{ kind = "continent",  label = "Discover a new continent",       points = 50, live = true },
	{ kind = "rare",       label = "Find a rare creature",           points = 20, live = true },
	{ kind = "rarefirst",  label = "First guild discovery of a rare", points = 50, live = true, bonus = true },
	{ kind = "treasure",   label = "Find hidden treasure",           points = 30, live = true },
	{ kind = "secret",     label = "Discover a secret location",     points = 30 },
	{ kind = "expedition", label = "Complete a guild expedition",    points = 50 },
	{ kind = "area",       label = "Chart an area of a zone",        points = 0,  live = true },
}

local byKind = {}
for _, k in ipairs(P.KINDS) do byKind[k.kind] = k end
P.BY_KIND = byKind

function P.Value(kind)
	local override = ns.db and ns.db.points[kind]
	if type(override) == "number" then return override end
	local k = byKind[kind]
	return k and k.points or 0
end

function P.Of(entry)
	local v = P.Value(entry.kind)
	if entry.kind == "rare" and ns.Ledger.IsFirst(entry) then v = v + P.Value("rarefirst") end
	return v
end

-- Week and month boundaries in UTC, so every member's week starts at the
-- same moment whatever their time zone. Weeks start on Monday.
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

-- Sum of points for one character (or everyone when who is nil), from
-- `since` onward (or all time).
function P.Total(who, since)
	local sum = 0
	for _, e in ipairs(ns.db.entries) do
		if (not who or e.who == who) and (not since or e.t >= since) then
			sum = sum + P.Of(e)
		end
	end
	return sum
end

-- The guild board: one row per character in `members` (a set), with
-- points from `since` onward and their discoveries all time.
function P.Board(members, since)
	local rows = {}
	for _, e in ipairs(ns.db.entries) do
		if members[e.who] then
			local r = rows[e.who]
			if not r then
				r = { who = e.who, points = 0, zones = 0, rares = 0, treasures = 0, firsts = 0, last = 0 }
				rows[e.who] = r
			end
			if not since or e.t >= since then r.points = r.points + P.Of(e) end
			if e.kind == "zone" then r.zones = r.zones + 1 end
			if e.kind == "rare" then
				r.rares = r.rares + 1
				if ns.Ledger.IsFirst(e) then r.firsts = r.firsts + 1 end
			end
			if e.kind == "treasure" then r.treasures = r.treasures + 1 end
			if e.t > r.last then r.last = e.t end
		end
	end
	local list = {}
	for _, r in pairs(rows) do list[#list + 1] = r end
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
	local seen = { zone = {}, area = {}, rare = {}, treasure = {}, continent = {}, zonefull = {} }
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
	local out = {}
	for k, set in pairs(seen) do
		local n = 0
		for _ in pairs(set) do n = n + 1 end
		out[k] = n
	end
	out.zoneSet, out.areaSet = seen.zone, seen.area
	return out
end

-- { [kind] = { count = n, points = p } } for one character.
function P.Breakdown(who, since)
	local out = {}
	for _, e in ipairs(ns.db.entries) do
		if e.who == who and (not since or e.t >= since) then
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
