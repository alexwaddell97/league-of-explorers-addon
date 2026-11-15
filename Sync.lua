-- Guild sync: members' journals merge over the guild addon channel, so
-- every member's journal holds the whole guild's discoveries.
--
-- Messages (prefix "LoE", channel GUILD, fields split by "~"):
--   E~1~who~seq~t~kind~key~map~x~y~name~mask~note   one entry
--   H~1~part~parts~who:seq,who:seq,...         a digest: the highest seq
--                                              held for each author
--   A~1~id~map~x~y~dead                        a rare spotted alive (or, with
--                                              dead = 1, killed): see Alerts.lua
--
-- New entries go out the moment they are written. On login (and every so
-- often) each member sends a digest; whoever holds entries the sender lacks
-- answers with them:
--   * the author answers for their own entries (and for a member asking
--     after their own lost entries, that member's copies are answered by
--     anyone), so a member with lost saved data gets it all back;
--   * for an author who is offline, anyone holding them answers after a
--     short random wait, and stands down if someone else sends first.
-- The game confirms who sent each message, so an entry is "authored" only
-- when it came from its own character; an author's copy always wins over a
-- relayed one. Only guild members (from the server's roster) are heard.

local _, ns = ...

local S = {}
ns.Sync = S

local PREFIX, VERSION = "LoE", "1"
local SEP = "~"
local SEND_EVERY = 0.2       -- seconds between queued messages (5 a second)
local DIGEST_EVERY = 900     -- a fresh digest every 15 minutes
local DIGEST_GAP = 45        -- at most one answering digest this often
local MAX_LEN = 250

local queue, pendingIds = {}, {}
local stats = { sent = 0, heard = 0, merged = 0 }
S.stats = stats

---------------------------------------------------------------------------
-- Wire format
---------------------------------------------------------------------------
local function clean(s)
	if s == nil then return "" end
	return (tostring(s):gsub("[~|\n\r,:]", " "))
end

local function num(s) return s ~= "" and tonumber(s) or nil end

-- Keys and masks may hold commas and colons (goal lists, entry ids), so
-- only the separators that would break a message are taken out of them.
local function cleanKey(s)
	if s == nil then return "" end
	return (tostring(s):gsub("[~|\n\r]", " "))
end

function S.Encode(e)
	local head = table.concat({
		"E", VERSION, e.who, e.seq, e.t, e.kind, cleanKey(e.key), e.map or "",
		e.x and ("%.1f"):format(e.x) or "", e.y and ("%.1f"):format(e.y) or "",
		clean(e.name):sub(1, 48), cleanKey(e.mask),
	}, SEP)
	-- The note takes whatever room is left in the message.
	local room = MAX_LEN - #head - 1
	return head .. SEP .. cleanKey(e.note):sub(1, math.max(0, room))
end

function S.Decode(msg)
	local f = {}
	for part in (msg .. SEP):gmatch("(.-)" .. SEP) do f[#f + 1] = part end
	if f[1] ~= "E" then return nil end
	local e = {
		who = f[3], seq = num(f[4] or ""), t = num(f[5] or ""), kind = f[6],
		key = num(f[7] or "") or f[7], map = num(f[8] or ""),
		x = num(f[9] or ""), y = num(f[10] or ""),
		name = (f[11] ~= "" and f[11]) or nil, mask = (f[12] ~= "" and f[12]) or nil,
		note = (f[13] and f[13] ~= "" and f[13]) or nil,
	}
	return e
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function canSend()
	return ns.Guild.InGuild() and not ns.Solo() and C_ChatInfo and C_ChatInfo.SendAddonMessage
end

local THROTTLED = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.AddonMessageThrottle

local function push(msg, id)
	queue[#queue + 1] = { msg = msg, id = id }
end

local pump = CreateFrame("Frame")
local wait = 0
pump:SetScript("OnUpdate", function(_, elapsed)
	wait = wait - elapsed
	if wait > 0 or #queue == 0 then return end
	wait = SEND_EVERY
	if not canSend() then
		queue = {}
		return
	end
	local item = table.remove(queue, 1)
	-- An answer someone else already gave is dropped.
	if item.id and pendingIds[item.id] == false then return end
	if item.id then pendingIds[item.id] = nil end
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, item.msg, "GUILD")
	if ok and THROTTLED and result == THROTTLED then
		table.insert(queue, 1, item)
		wait = 1.5
		return
	end
	stats.sent = stats.sent + 1
end)

local function sendEntry(e, id)
	if e.test then return end -- officer preview: never leaves this computer
	push(S.Encode(e), id)
end

-- A rare spotted (or killed): goes ahead of everything else in the queue.
function S.SendAlert(id, map, x, y, dead)
	if not canSend() or not id then return end
	table.insert(queue, 1, { msg = table.concat({ "A", VERSION, id, map or "",
		x and ("%.1f"):format(x) or "", y and ("%.1f"):format(y) or "", dead and "1" or "" }, SEP) })
end

-- Members and this account's characters still in the guild: whose entries we share.
local function shared(who)
	return ns.Guild.IsMember(who)
end

local lastDigest = 0
function S.SendDigest(force)
	if not canSend() then return end
	local now = GetTime()
	if not force and now - lastDigest < DIGEST_GAP then return end
	lastDigest = now
	local pairsList = {}
	for _, who in ipairs(ns.Ledger.Authors()) do
		if shared(who) then pairsList[#pairsList + 1] = who .. ":" .. ns.Ledger.MaxSeq(who) end
	end
	-- Split across messages; every part stands alone.
	local chunks, cur = {}, {}
	local len = 12
	for _, p in ipairs(pairsList) do
		if len + #p + 1 > MAX_LEN and #cur > 0 then
			chunks[#chunks + 1] = cur
			cur, len = {}, 12
		end
		cur[#cur + 1] = p
		len = len + #p + 1
	end
	chunks[#chunks + 1] = cur
	for i, c in ipairs(chunks) do
		push(table.concat({ "H", VERSION, i, #chunks, table.concat(c, ",") }, SEP))
	end
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local digests = {} -- sender -> { pairs = {}, got = n, parts = n }

local function answer(sender, theirs)
	local me = ns.Me()
	local needOurs = false
	for _, who in ipairs(ns.Ledger.Authors()) do
		if shared(who) then
			local have, has = ns.Ledger.MaxSeq(who), theirs[who] or 0
			if have > has then
				local mine = ns.Guild.IsMine(who)
				local authorAway = not (ns.Guild.Member(who) and ns.Guild.Member(who).online)
				if mine or who == sender or authorAway then
					local delay = (mine or who == me) and (0.3 + math.random() * 1.2) or (2 + math.random() * 5)
					local list = ns.Ledger.Query({ who = who, after = has, all = true })
					for i = #list, 1, -1 do
						local e = list[i]
						pendingIds[e.id] = true
					end
					ns.After(delay, function()
						for i = #list, 1, -1 do
							local e = list[i]
							if pendingIds[e.id] then sendEntry(e, e.id) end
						end
					end)
				end
			end
		end
	end
	for who, seq in pairs(theirs) do
		if seq > ns.Ledger.MaxSeq(who) then needOurs = true end
	end
	-- They hold entries we lack: our digest asks for them.
	if needOurs then ns.After(1 + math.random() * 2, function() S.SendDigest() end) end
end

local function onDigest(sender, part, parts, body)
	local d = digests[sender]
	if not d or d.parts ~= parts then
		d = { pairs = {}, got = 0, parts = parts }
		digests[sender] = d
		-- Parts that never arrive don't hold the answer up for long.
		ns.After(4, function()
			if digests[sender] == d then
				digests[sender] = nil
				answer(sender, d.pairs)
			end
		end)
	end
	for item in body:gmatch("[^,]+") do
		local who, seq = item:match("^(.+):(%d+)$")
		if who then d.pairs[who] = tonumber(seq) end
	end
	d.got = d.got + 1
	if d.got >= parts then
		digests[sender] = nil
		answer(sender, d.pairs)
	end
end

function S.OnMessage(prefix, msg, channel, sender)
	if prefix ~= PREFIX or channel ~= "GUILD" or ns.Solo() then return end
	msg, sender = ns.Readable(msg), ns.Readable(sender)
	if type(msg) ~= "string" or type(sender) ~= "string" then return end
	sender = ns.Guild.Full(sender)
	if sender == ns.Me() or not ns.Guild.IsMember(sender) then return end
	stats.heard = stats.heard + 1
	local kind = msg:sub(1, 2)
	if kind == "E" .. SEP then
		local e = S.Decode(msg)
		if not e or not e.who then return end
		e.who = ns.Name(e.who)
		if not (ns.Guild.IsMember(e.who) or ns.Guild.IsMine(e.who)) then return end
		if e.seq then
			-- Someone answered with this entry: our own answer can stand down.
			local id = e.who .. "#" .. e.seq
			if pendingIds[id] then pendingIds[id] = false end
		end
		if ns.Ledger.Merge(e, e.who == sender, sender) then stats.merged = stats.merged + 1 end
	elseif kind == "A" .. SEP then
		local id, map, x, y, dead = msg:match("^A~[^~]*~(%d+)~(%d*)~([%d%.]*)~([%d%.]*)~?(%d?)")
		if id and ns.Alerts then
			ns.Alerts.Heard(sender, tonumber(id), num(map), num(x), num(y), dead == "1")
		end
	elseif kind == "H" .. SEP then
		local _, part, parts, body = msg:match("^H~([^~]*)~(%d+)~(%d+)~(.*)$")
		part, parts = tonumber(part), tonumber(parts)
		if part and parts and body then onDigest(sender, part, parts, body) end
	end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
ns.Listen("READY", function()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	end
	ns.On("CHAT_MSG_ADDON", function(_, ...) S.OnMessage(...) end)
	-- Give the roster a moment to arrive before the first digest.
	ns.After(8, function() S.SendDigest(true) end)
	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(DIGEST_EVERY, function() S.SendDigest(true) end)
	end
end)

ns.Listen("ENTRY_ADDED", function(e)
	if canSend() then sendEntry(e) end
end)

-- Joining a guild (or the roster first arriving) starts a fresh exchange.
local wasIn = false
ns.Listen("ROSTER", function()
	local inGuild = ns.Guild.InGuild()
	if inGuild and not wasIn then ns.After(3, function() S.SendDigest(true) end) end
	wasIn = inGuild
end)

ns.Commands.sync = function()
	local total, online = ns.Guild.Counts()
	ns.Print(("guild: %s, %d members (%d online)"):format(ns.Guild.name or "none", total, online))
	ns.Print(("sync: %d sent, %d heard, %d entries merged, %d waiting to send"):format(
		stats.sent, stats.heard, stats.merged, #queue))
	ns.Print(("stored: %d entries from %d characters"):format(#ns.db.entries, #ns.Ledger.Authors()))
	S.SendDigest(true)
end
