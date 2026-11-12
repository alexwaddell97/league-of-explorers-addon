-- The guild: who is in it, their rank, class and level, whether they are
-- online and where. Read from the game's guild roster, which is server
-- data, so it is also what sync trusts to decide who counts as a member.

local _, ns = ...

local G = {}
ns.Guild = G

G.members = {} -- "Name-Realm" -> { rank, rankIndex, class, level, online, zone }
G.name = nil

local realm

-- Roster and addon-message names can come without a realm for your own
-- realm; everything in the journal uses "Name-Realm".
function G.Full(name)
	if type(name) ~= "string" or name == "" then return nil end
	if name:find("-", 1, true) then return name end
	realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName())
	return realm and (name .. "-" .. realm) or name
end

function G.InGuild()
	return IsInGuild and IsInGuild() and G.name ~= nil or false
end

function G.IsMember(who) return G.members[who] ~= nil end

function G.Member(who) return G.members[who] end

-- The characters on this account (they share one saved journal).
function G.IsMine(who) return ns.db and ns.db.chars[who] ~= nil end

function G.Refresh()
	local members = {}
	if IsInGuild and IsInGuild() then
		G.name = GetGuildInfo and GetGuildInfo("player") or G.name
		local n = GetNumGuildMembers and GetNumGuildMembers() or 0
		for i = 1, n do
			local name, rankName, rankIndex, level, _, zone, _, _, online, _, class = GetGuildRosterInfo(i)
			local who = G.Full(ns.Readable(name))
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
