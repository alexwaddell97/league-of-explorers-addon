-- The guild: who is in it, their rank, class and level, whether they are
-- online and where. Read from the game's guild roster, which is server
-- data, so it is also what sync trusts to decide who counts as a member.

local _, ns = ...

local G = {}
ns.Guild = G

G.members = {} -- "Name-Realm" -> { rank, rankIndex, class, level, online, zone }
G.name = nil

-- Roster and addon-message names in the journal's one form (Core.lua).
function G.Full(name) return ns.Name(name) end

function G.InGuild()
	return IsInGuild and IsInGuild() and G.name ~= nil or false
end

function G.IsMember(who) return G.members[who] ~= nil end

-- Solo mode: the addon is just yours, with no guild pages, leaderboards or
-- sharing. Chosen per character in the settings; until it's chosen, it is
-- on for a character outside a guild. The demo's example guild is never solo.
function G.Solo()
	if ns.Work and ns.Work.demo then return false end
	local me = ns.Me()
	local c = ns.db and me and ns.db.chars[me]
	if c and c.solo ~= nil then return c.solo end
	return not (IsInGuild and IsInGuild())
end
ns.Solo = G.Solo

local lastSolo
-- Tells everything when the mode has changed (MODE).
function G.CheckMode()
	local s = G.Solo()
	if s ~= lastSolo then
		lastSolo = s
		ns.Fire("MODE", s)
	end
end

function G.SetSolo(on)
	local c = ns.Char()
	if not c then return end
	c.solo = on and true or false
	G.CheckMode()
end

function G.Member(who) return G.members[who] end

-- The characters on this account (they share one saved journal).
function G.IsMine(who) return ns.db and ns.db.chars[who] ~= nil end

function G.Refresh()
	-- The demo's pretend guild holds the roster until the tour ends.
	if ns.Demo and ns.Demo.holding then return end
	local members = {}
	if IsInGuild and IsInGuild() then
		G.name = GetGuildInfo and GetGuildInfo("player") or G.name
		local n = GetNumGuildMembers and GetNumGuildMembers() or 0
		local myGuid = UnitGUID and ns.Readable(UnitGUID("player"))
		for i = 1, n do
			local name, rankName, rankIndex, level, _, zone, _, _, online, _, class,
				_, _, _, _, _, guid = GetGuildRosterInfo(i)
			local who = G.Full(ns.Readable(name))
			-- The roster knows exactly how the guild names you: go by that.
			if who and myGuid and ns.Readable(guid) == myGuid and who ~= ns.Me() then
				ns.SetMe(who)
			end
			if who then
				members[who] = {
					rank = rankName, rankIndex = rankIndex, level = level,
					class = class, online = online and true or false, zone = zone,
				}
			end
		end
	else
		G.name = nil
	end
	G.members = members
	ns.Fire("ROSTER")
	G.CheckMode()
end

function G.Counts()
	local total, online = 0, 0
	for _, m in pairs(G.members) do
		total = total + 1
		if m.online then online = online + 1 end
	end
	return total, online
end

local function request()
	if not (IsInGuild and IsInGuild()) then return end
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	elseif GuildRoster then
		GuildRoster()
	end
end
G.Request = request

local pending = false
local function refreshSoon()
	if pending then return end
	pending = true
	ns.After(1, function()
		pending = false
		G.Refresh()
	end)
end

ns.Listen("READY", function()
	ns.On("GUILD_ROSTER_UPDATE", refreshSoon)
	ns.On("PLAYER_GUILD_UPDATE", function()
		request()
		refreshSoon()
	end)
	request()
	G.Refresh()
	-- The roster's online flags and zones go stale; ask again now and then.
	if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(60, request) end
end)

-- /loe solo: switch between solo and guild mode.
ns.Commands.solo = function()
	G.SetSolo(not G.Solo())
	ns.Print(G.Solo() and "solo mode: on. Guild pages, leaderboards and sharing are off."
		or "solo mode: off. Guild pages, leaderboards and sharing are on.")
end

-- What the game calls you, every way it does, and what the journal makes
-- of it: for checking names on a realm that does them its own way.
ns.Commands.whoami = function()
	local name, realm = UnitFullName("player")
	ns.Print(("UnitFullName: %q, %q"):format(tostring(name), tostring(realm)))
	ns.Print(("UnitName: %q"):format(tostring(UnitName("player"))))
	ns.Print(("realm: %q (normalized %q)"):format(tostring(GetRealmName and GetRealmName()),
		tostring(GetNormalizedRealmName and GetNormalizedRealmName())))
	local myGuid = UnitGUID("player")
	local rosterName
	for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
		local n, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
		if guid and guid == myGuid then rosterName = n end
	end
	ns.Print(("on the guild roster: %q"):format(tostring(rosterName)))
	ns.Print(("the addon calls you: %q"):format(tostring(ns.Me())))
	local total, online = G.Counts()
	ns.Print(("guild: %d members, %d online"):format(total, online))
end
