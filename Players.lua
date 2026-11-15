-- Players: one person, one rank. A player's characters share one place on
-- the boards, and a zone or rare counts once for the player, however many
-- of their characters find it.
--
-- Each character says which is its main with a "main" entry (key
-- "Name@time"; the latest wins), written by that character when it logs
-- in, so it travels with sync like everything else. On this account the
-- main is a setting (the journal's cog); every character on the account
-- follows it.

local _, ns = ...

local Pl = {}
ns.Players = Pl

local mains -- character -> its main, from the entries (built on demand)

local function build()
	mains = {}
	for _, e in ipairs(ns.Ledger.Query({ kind = "main", all = true })) do -- newest first
		if not mains[e.who] then
			local m = tostring(e.key):match("^(.-)@%d+$")
			if m and m ~= "" then mains[e.who] = m end
		end
	end
end

local function invalidate() mains = nil end
ns.Listen("ENTRY_ADDED", invalidate)
ns.Listen("ENTRY_MERGED", invalidate)
ns.Listen("DB_READY", invalidate)

-- The player a character belongs to (named by their main).
function Pl.MainOf(who)
	if not who then return nil end
	if not mains then build() end
	return mains[who] or who
end

-- Every character of a player, the main first.
function Pl.Chars(player)
	if not mains then build() end
	local out = { player }
	for who, m in pairs(mains) do
		if m == player and who ~= player then out[#out + 1] = who end
	end
	return out
end

function Pl.Set(player)
	local set = {}
	for _, who in ipairs(Pl.Chars(player)) do set[who] = true end
	return set
end

-- This account's main: the setting, else the character that began a
-- journal first.
function Pl.MyMain()
	local s = ns.db.settings
	if s.main and ns.db.chars[s.main] then return s.main end
	local best, at
	for who, c in pairs(ns.db.chars) do
		local t = c.baselineAt or math.huge
		if not at or t < at or (t == at and who < best) then best, at = who, t end
	end
	s.main = best or ns.Me()
	return s.main
end

-- Writes this character's main, when it has changed.
function Pl.Declare()
	local me = ns.Me()
	if not me then return end
	local main = Pl.MyMain()
	if Pl.MainOf(me) ~= main then
		ns.Ledger.Award("main", main .. "@" .. ns.Now(), {})
		invalidate()
	end
end

function Pl.SetMain(name)
	if not ns.db.chars[name] then return end
	ns.db.settings.main = name
	Pl.Declare()
	ns.Fire("ENTRY_MERGED", {})
end

-- This account's characters, the main first.
function Pl.Mine()
	local out = {}
	for who in pairs(ns.db.chars) do out[#out + 1] = who end
	table.sort(out)
	local main = Pl.MyMain()
	table.sort(out, function(a, b)
		if (a == main) ~= (b == main) then return a == main end
		return a < b
	end)
	return out
end

ns.Listen("READY", function() Pl.Declare() end)
