-- The ledger: the journal's append-only list of entries, yours and (once
-- shared) your guildmates'.
--
-- Every award goes through Ledger.Award, which writes an entry at most once
-- per character for each (kind, key): a zone, a rare's creature ID, a
-- treasure's object ID. That one rule is the guard against repeat farming.
-- Entries are never edited by their author, so members' journals merge by
-- passing each other the entries they lack (see Sync.lua).
--
-- An entry is { id = "who#seq", who, seq, t, kind, key, name?, map?, x?, y? }.
-- via = the member who relayed it, when it didn't come from its author.

local _, ns = ...

local L = {}
ns.Ledger = L

-- base: a zone known before the journal was begun, worth nothing; its mask
-- holds the areas already charted then (see Exploration.lua).
-- The guild's own records travel as entries too (see Work.lua):
--   exp   an officer's expedition or bounty     expx  an officer withdrawing one
--   hunt  a member meeting one of its goals     sub   a member's submission
--   rev   an officer's review of a submission   cfg   the guild master's settings
--   main  a character naming its player's main     weekly a weekly hunt target met
--   place a place the guild has charted, found (a discovery, worth points)
--   kill  a rare killed (worth nothing itself; bounties and hunts ask for it)
L.KINDS = {
	zone = true, zonefull = true, continent = true, area = true, rare = true, treasure = true, base = true,
	exp = true, expx = true, hunt = true, sub = true, rev = true, cfg = true,
	main = true, weekly = true, place = true, kill = true,
}

-- Kinds that are records rather than discoveries: never listed with the
-- discoveries, only when asked for by kind.
L.HIDDEN = { base = true, exp = true, expx = true, hunt = true, sub = true, rev = true, cfg = true, main = true, weekly = true, kill = true }

-- Kinds only an officer may write; cfg only the guild master.
L.OFFICER = { exp = true, expx = true, rev = true }

-- who -> { ["kind:key"] = entry }; id -> entry; "kind:key" -> the guild's
-- first entry for it; who -> highest seq held. Rebuilt from entries on load.
local index, byId, firsts, maxSeq = {}, {}, {}, {}

local function akey(kind, key)
	return kind .. ":" .. tostring(key)
end

local function earlier(a, b)
	if a.t ~= b.t then return a.t < b.t end
	return a.id < b.id
end

local function indexEntry(e)
	local t = index[e.who]
	if not t then
		t = {}
		index[e.who] = t
	end
	local k = akey(e.kind, e.key)
	t[k] = e
	byId[e.id] = e
	local f = firsts[k]
	if not f or earlier(e, f) then firsts[k] = e end
	-- Preview entries never travel, so digests don't count them.
	if not e.test and (e.seq or 0) > (maxSeq[e.who] or 0) then maxSeq[e.who] = e.seq end
end

local function rebuild()
	index, byId, firsts, maxSeq = {}, {}, {}, {}
	for _, e in ipairs(ns.db.entries) do
		-- Entries saved before seq was stored carry it in their id.
		if not e.seq then e.seq = tonumber(e.id:match("#(%d+)$")) end
		indexEntry(e)
	end
end
L.Rebuild = rebuild
-- Demo entries (see UI/Demo.lua) never outlive the demo: any left by a
-- reload mid-tour are cleared when the journal loads.
local function dropDemo()
	local kept = {}
	for _, e in ipairs(ns.db.entries) do
		if not e.demo then kept[#kept + 1] = e end
	end
	ns.db.entries = kept
end

ns.Listen("DB_READY", function()
	dropDemo()
	rebuild()
end)

-- Adds a demo entry as it is (any author), kept on this computer only.
function L.AddDemo(e)
	e.test, e.demo = true, true
	e.id = e.who .. "#" .. e.seq
	table.insert(ns.db.entries, e)
	indexEntry(e)
	return e
end

-- Removes every demo entry.
function L.ClearDemo()
	dropDemo()
	rebuild()
end

function L.Has(kind, key, who)
	who = who or ns.Me()
	local t = who and index[who]
	return t and t[akey(kind, key)] or nil
end

function L.Get(id) return byId[id] end

function L.MaxSeq(who) return maxSeq[who] or 0 end

-- Everyone with entries, for sync digests and boards.
function L.Authors()
	local out = {}
	for who in pairs(maxSeq) do out[#out + 1] = who end
	table.sort(out)
	return out
end

-- True when this entry is the first in the guild's ledger for its kind
-- and key (the first guild discovery of a rare, say).
function L.IsFirst(e)
	return firsts[akey(e.kind, e.key)] == e
end

-- Fields an entry may carry besides its identity.
-- test marks an entry made in officer preview: kept on this computer only.
local FIELDS = { "name", "map", "x", "y", "note", "mask", "test" }

-- Writes an entry for the logged-in character unless it already has one for
-- this kind and key. Returns the new entry, or nil when nothing was written.
function L.Award(kind, key, data)
	local who = ns.Me()
	if not who or key == nil then return nil end
	if L.Has(kind, key, who) then return nil end
	local seq = math.max(ns.db.seq[who] or 0, maxSeq[who] or 0) + 1
	ns.db.seq[who] = seq
	local e = { id = who .. "#" .. seq, who = who, seq = seq, t = ns.Now(), kind = kind, key = key }
	if data then
		for _, f in ipairs(FIELDS) do
			if data[f] ~= nil then e[f] = data[f] end
		end
	end
	table.insert(ns.db.entries, e)
	indexEntry(e)
	ns.Debug("entry", e.id, kind, tostring(key), e.name or "")
	ns.Fire("ENTRY_ADDED", e)
	return e
end

-- Takes in an entry from another member. `authored` = it came from the
-- character it belongs to, whose own copy always wins over a relayed one.
-- Returns the stored entry when something changed, else nil.
function L.Merge(e, authored, via)
	if type(e) ~= "table" or not L.KINDS[e.kind] then return nil end
	if type(e.who) ~= "string" or not e.who:find("-", 1, true) then return nil end
	if type(e.seq) ~= "number" or e.seq < 1 or e.seq % 1 ~= 0 then return nil end
	if type(e.t) ~= "number" or e.t < 1700000000 or e.t > ns.Now() + 600 then return nil end
	if e.key == nil then return nil end
	if L.OFFICER[e.kind] and not (ns.Work and ns.Work.IsOfficer(e.who)) then return nil end
	if e.kind == "cfg" and not (ns.Work and ns.Work.IsLeader(e.who)) then return nil end
	local id = e.who .. "#" .. e.seq
	local have = byId[id]
	if have then
		if not (authored and have.via) then return nil end
		-- The author's copy replaces a relayed one.
		for _, f in ipairs({ "t", "kind", "key", "name", "map", "x", "y", "mask", "note" }) do have[f] = e[f] end
		have.via = nil
		rebuild()
		ns.Fire("ENTRY_MERGED", have)
		return have
	end
	if L.Has(e.kind, e.key, e.who) then return nil end
	local stored = { id = id, who = e.who, seq = e.seq, t = e.t, kind = e.kind, key = e.key }
	for _, f in ipairs(FIELDS) do
		if e[f] ~= nil then stored[f] = e[f] end
	end
	if not authored then stored.via = via end
	table.insert(ns.db.entries, stored)
	indexEntry(stored)
	-- One of this account's characters getting its lost entries back.
	if ns.db.chars[e.who] and (ns.db.seq[e.who] or 0) < e.seq then ns.db.seq[e.who] = e.seq end
	ns.Fire("ENTRY_MERGED", stored)
	return stored
end

-- Entries newest first that pass the filter: { who, whoIn = set, kind,
-- kinds = set, since, map, limit, after = seq (with who) }. Baseline
-- entries only come back when asked for by kind.
function L.Query(filter)
	filter = filter or {}
	local out = {}
	for _, e in ipairs(ns.db.entries) do
		if (not filter.who or e.who == filter.who)
			and (not filter.whoIn or filter.whoIn[e.who])
			and (not filter.kind or e.kind == filter.kind)
			and (not L.HIDDEN[e.kind] or filter.kind == e.kind or filter.all)
			and (not filter.kinds or filter.kinds[e.kind])
			and (not filter.since or e.t >= filter.since)
			and (not filter.map or e.map == filter.map)
			and (not filter.after or (e.seq or 0) > filter.after) then
			out[#out + 1] = e
		end
	end
	table.sort(out, function(a, b) return earlier(b, a) end)
	if filter.limit and #out > filter.limit then
		for i = #out, filter.limit + 1, -1 do out[i] = nil end
	end
	return out
end

-- How each kind of entry reads in the journal.
local PHRASE = {
	zone = "Discovered %s",
	zonefull = "Fully explored %s",
	continent = "Reached %s",
	area = "Explored %s",
	rare = "Found %s",
	treasure = "Found %s",
	place = "Visited %s",
}

function L.Describe(e)
	local name = e.name
	if not name and e.map then name = ns.MapName(e.map) end
	name = name or "an unknown area"
	return (PHRASE[e.kind] or "%s"):format(name)
end
