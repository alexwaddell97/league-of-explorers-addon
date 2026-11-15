-- Explorer ranks in the game's own guild features, for guildmates who keep
-- a journal:
--   Guild window  a small emblem in the rank's colour after each member's
--                 name in the Guild tab's member list, and their explorer
--                 rank, points and finds added to the row's tooltip.
--   Guild chat    the sender's rank as a coloured tag at the start of their
--                 guild (and officer) chat lines; a setting, on by default.
-- Only our own additions are drawn: the game's text is never rewritten
-- (Kinship's roleplay names, which change the same rows and lines, keep
-- working), and rows are never moved or resized.

local _, ns = ...

local T = ns.Theme
local GH = {}
ns.GuildHooks = GH

-- Rank colours, rising from the brown of a new explorer through bronze,
-- silver and gold, to sea-green for a Grand Explorer.
local TIER = {
	{ 0.55, 0.45, 0.35 }, { 0.62, 0.50, 0.36 },
	{ 0.72, 0.45, 0.22 }, { 0.78, 0.50, 0.25 },
	{ 0.70, 0.72, 0.76 }, { 0.80, 0.82, 0.86 },
	{ 0.92, 0.74, 0.25 }, { 1.00, 0.82, 0.35 },
	{ 0.35, 0.85, 0.78 },
}
function GH.RankColor(i) return TIER[i] or TIER[1] end

---------------------------------------------------------------------------
-- Who keeps a journal, and their standing (worked out once per change).
---------------------------------------------------------------------------
local cache = {}
local function invalidate() cache = {} end
ns.Listen("ENTRY_ADDED", invalidate)
ns.Listen("ENTRY_MERGED", invalidate)
ns.Listen("ROSTER", invalidate)
ns.Listen("MODE", invalidate)

function GH.Standing(who)
	who = ns.Name(who)
	if not who then return nil end
	local c = cache[who]
	if c ~= nil then return c or nil end
	-- Someone keeps a journal if they have any entry (the demo's pretend
	-- guildmates included, which sync counts leave out).
	if who ~= ns.Me() and #ns.Ledger.Query({ who = who, all = true, limit = 1 }) == 0 then
		cache[who] = false
		return nil
	end
	local P = ns.Points
	local counts = P.Counts(who)
	local firsts = counts.firsts
	local points = P.Total(who)
	local idx, rank = P.RankOf(who)
	local place
	local player = P.Player(who)
	for i, r in ipairs(P.Board(ns.UI.Members(), P.WeekStart())) do
		if r.who == player and r.points > 0 then place = i end
	end
	local zones, rares = counts.zones, counts.rares
	c = { who = who, index = idx, rank = rank.name, points = points, week = P.Total(who, P.WeekStart()),
		place = place, zones = zones, rares = rares, firsts = firsts }
	cache[who] = c
	return c
end

---------------------------------------------------------------------------
-- The Guild tab (the Communities window's member list)
---------------------------------------------------------------------------
local function emblem(row)
	if row.loeEmblem then return row.loeEmblem end
	local e = CreateFrame("Frame", nil, row)
	e:SetSize(11, 11)
	e:SetFrameLevel(row:GetFrameLevel() + 3)
	e.ring = T.Circle(e, 11, "ARTWORK", 0)
	e.ring:SetPoint("CENTER")
	e.ring:SetVertexColor(0, 0, 0, 0.6)
	e.dot = T.Circle(e, 8, "ARTWORK", 1)
	e.dot:SetPoint("CENTER")
	e.shine = T.Circle(e, 3, "ARTWORK", 2)
	e.shine:SetPoint("CENTER", -1, 1)
	e.shine:SetVertexColor(1, 1, 1, 0.55)
	e:EnableMouse(false)
	row.loeEmblem = e
	return e
end

local function rowInfo(row)
	local info = row.memberInfo or (row.GetMemberInfo and row:GetMemberInfo())
	return type(info) == "table" and info or nil
end

-- How far along the name the emblem goes: just after the name as written, or,
-- when the game has drawn its own icons there (the guild leader's crown, and
-- any others), just after the last of them, so the two never overlap.
local function emblemOffset(nf, fs)
	local width = fs:GetWidth() or 0
	local text = math.min(fs:GetStringWidth() or 0, width > 0 and width - 13 or 999)
	local x = text + 5
	local nameLeft = fs.GetLeft and fs:GetLeft()
	local found = false
	if nameLeft and nf.GetRegions then
		for _, r in ipairs({ nf:GetRegions() }) do
			if r ~= fs and r ~= nil and r:GetObjectType() == "Texture" and r:IsShown() then
				local l, rr = r:GetLeft(), r:GetRight()
				if l and rr and rr - l > 2 and l >= nameLeft + text - 4 then
					x = math.max(x, rr - nameLeft + 3)
					found = true
				end
			end
		end
	end
	-- Not laid out yet: allow for the leader's crown if the game is showing it.
	local crown = nf.RankIcon
	if not found and crown and crown.IsShown and crown:IsShown() then
		x = x + (crown:GetWidth() or 12) + 2
	end
	return x
end

local function placeEmblem(row)
	local info = rowInfo(row)
	local nf = row.NameFrame
	local fs = nf and nf.Name
	local s = info and ns.db.settings.guildWindow ~= false and not ns.Solo() and GH.Standing(info.name)
	if not (fs and s) then
		if row.loeEmblem then row.loeEmblem:Hide() end
		return
	end
	local e = emblem(row)
	local c = GH.RankColor(s.index)
	e.dot:SetVertexColor(c[1], c[2], c[3], 1)
	-- Just after the name as written (Kinship's roleplay name included) and
	-- any icons the game puts after it, never past the end of the name column.
	e:ClearAllPoints()
	e:SetPoint("LEFT", fs, "LEFT", emblemOffset(nf, fs), 0)
	e:Show()
end

local function refreshRows()
	local cf = rawget(_G, "CommunitiesFrame")
	local box = cf and cf.MemberList and cf.MemberList.ScrollBox
	if box and box.ForEachFrame then
		box:ForEachFrame(function(row)
			local ok, err = pcall(placeEmblem, row)
			if not ok then ns.Debug("guild row", err) end
			GH.HookRow(row)
		end)
	end
end

-- Their standing, added to the row's tooltip (after the game's own lines).
function GH.AddTooltip(tooltip, who)
	local s = GH.Standing(who)
	if not s then return false end
	local c = GH.RankColor(s.index)
	tooltip:AddLine(" ")
	tooltip:AddLine("League of Explorers", 0.86, 0.68, 0.40)
	tooltip:AddDoubleLine("Explorer rank", s.rank, 1, 1, 1, c[1], c[2], c[3])
	tooltip:AddDoubleLine("Points", T.Number(s.points) .. (s.week > 0 and ("  (+" .. T.Number(s.week) .. " this week)") or ""),
		1, 1, 1, 1, 0.82, 0.35)
	if s.place then tooltip:AddDoubleLine("This week's position", "#" .. s.place, 1, 1, 1, 1, 1, 1) end
	tooltip:AddDoubleLine("Zones discovered / rares", ("%d / %d"):format(s.zones, s.rares), 1, 1, 1, 0.8, 0.8, 0.8)
	if s.firsts > 0 then tooltip:AddDoubleLine("First guild finds", s.firsts, 1, 1, 1, 0.35, 0.85, 0.78) end
	return true
end

function GH.HookRow(row)
	if row.loeHooked then return end
	row.loeHooked = true
	row:HookScript("OnEnter", function(self)
		if ns.db.settings.guildWindow == false or ns.Solo() then return end
		local info = rowInfo(self)
		if not (info and info.name) then return end
		if not GameTooltip:IsOwned(self) then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(ns.ShortName(ns.Name(info.name)))
		end
		if GH.AddTooltip(GameTooltip, info.name) then GameTooltip:Show() end
	end)
end

-- A tab under the guild window's own side tabs (chat, roster, perks,
-- info) that opens the League of Explorers window. It's a plain button,
-- sized and spaced like the tab above it, and placed again whenever the
-- window opens (skins such as EllesmereUI move the side tabs). It shows
-- while the guild's tabs do, so only while a guild is selected.
local ICON = "Interface\\Icons\\INV_Misc_Spyglass_02"
local SIDE_TABS = { "GuildInfoTab", "GuildBenefitsTab", "RosterTab", "ChatTab" }

-- The tabs down the window's right edge: the ones we know by name, and any
-- other the game or a skin puts there (found by where they sit).
local function sideTabs(cf)
	local list, seen = {}, {}
	local function add(t)
		if t and t ~= GH.tab and not seen[t] then
			seen[t] = true
			list[#list + 1] = t
		end
	end
	for _, k in ipairs(SIDE_TABS) do add(cf[k]) end
	local right = cf.GetRight and cf:GetRight()
	if type(right) == "number" and cf.GetChildren then
		for _, c in ipairs({ cf:GetChildren() }) do
			local l = c.GetLeft and c:GetLeft()
			local w = c.GetWidth and c:GetWidth()
			if type(l) == "number" and type(w) == "number" and w > 0 and w < 64 and math.abs(l - right) < 10 then add(c) end
		end
	end
	return list
end

function GH.PlaceTab()
	local tab, cf = GH.tab, rawget(_G, "CommunitiesFrame")
	if not (tab and cf) then return end
	-- Shown while the guild's own tabs are.
	local named, guildShown = false, false
	for _, k in ipairs(SIDE_TABS) do
		local t = cf[k]
		if t then
			named = true
			if t:IsShown() then guildShown = true end
		end
	end
	tab:ClearAllPoints()
	if not guildShown then
		if not named and ns.Guild.InGuild() then
			-- No side tabs on this client: sit at the window's top right corner.
			tab:SetPoint("TOPLEFT", cf, "TOPRIGHT", 2, -36)
			tab:Show()
		else
			tab:Hide()
		end
		return
	end
	-- Under the lowest tab on screen (by name order if positions aren't known).
	local last, lowest, level = nil, nil, 0
	for _, t in ipairs(sideTabs(cf)) do
		if t:IsShown() then
			local b = t.GetBottom and t:GetBottom()
			if type(b) == "number" then
				if not lowest or b < lowest then last, lowest = t, b end
			elseif not last then
				last = t
			end
			local l = t.GetFrameLevel and t:GetFrameLevel()
			if type(l) == "number" and l > level then level = l end
		end
	end
	if not last then
		tab:Hide()
		return
	end
	-- The same gap as between the chat and roster tabs.
	local gap = 12
	local a, b = cf.ChatTab, cf.RosterTab
	local ab, bt = a and a:GetBottom(), b and b:GetTop()
	if type(ab) == "number" and type(bt) == "number" and ab > bt then gap = ab - bt end
	GH.StyleTab(last)
	tab:SetPoint("TOP", last, "BOTTOM", 0, -gap)
	tab:SetFrameLevel(level + 2)
	tab:Show()
end

-- Dressed like the tab above it: with EllesmereUI's skin, its dark plate
-- and black edge round a closely cropped icon; otherwise the game's own
-- side-tab frame. Size and icon placement are copied from that tab.
local function ellesmereStyled(ref)
	local icon = ref and ref.Icon
	if type(icon) ~= "table" or not icon.GetTexCoord then return false end
	local l = icon:GetTexCoord()
	return type(l) == "number" and math.abs(l - 0.12) < 0.01
end

local function edge(frame, size)
	local lines = {}
	for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetColorTexture(0, 0, 0, 1)
		t:SetPoint(pts[1])
		t:SetPoint(pts[2])
		if i <= 2 then t:SetHeight(size) else t:SetWidth(size) end
		lines[i] = t
	end
	return lines
end

function GH.StyleTab(ref)
	local tab = GH.tab
	if not (tab and ref) then return end
	local w, h = ref:GetSize()
	if type(w) == "number" and w > 0 then tab:SetSize(w, h) end
	-- The icon where the other tab has its icon.
	local ri = type(ref.Icon) == "table" and ref.Icon or nil
	tab.Icon:ClearAllPoints()
	local iw, ih
	if ri and ri.GetSize then iw, ih = ri:GetSize() end
	if type(iw) == "number" and iw > 0 then
		tab.Icon:SetSize(iw, ih)
		local p, rel, rp, x, y = ri:GetPoint(1)
		if p and (rel == ref or rel == nil) then
			tab.Icon:SetPoint(p, tab, rp, x or 0, y or 0)
		else
			tab.Icon:SetPoint("CENTER")
		end
	else
		tab.Icon:SetAllPoints()
	end
	local eui = ellesmereStyled(ref)
	if tab.style == (eui and "eui" or "game") then return end
	tab.style = eui and "eui" or "game"
	if eui then
		tab.frameArt:Hide()
		tab.Icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
		tab.plate:Show()
		tab.hover:ClearAllPoints()
		tab.hover:SetAllPoints(tab.plate)
		tab.hover:SetColorTexture(1, 1, 1, 0.1)
	else
		tab.plate:Hide()
		tab.frameArt:Show()
		tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		tab.hover:ClearAllPoints()
		tab.hover:SetAllPoints(tab.Icon)
		tab.hover:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
		tab.hover:SetBlendMode("ADD")
	end
end

function GH.AddTab(cf)
	if GH.tab or not cf then return GH.tab end
	local tab = CreateFrame("Button", "LeagueOfExplorersGuildTab", cf)
	tab:SetSize(32, 32)
	tab:SetFrameLevel(((cf.GetFrameLevel and cf:GetFrameLevel()) or 1) + 10)
	tab.Icon = tab:CreateTexture(nil, "ARTWORK")
	tab.Icon:SetAllPoints()
	tab.Icon:SetTexture(ICON)
	-- EllesmereUI's look: a dark plate with a black edge round the icon.
	tab.plate = CreateFrame("Frame", nil, tab)
	tab.plate:SetPoint("TOPLEFT", tab.Icon, "TOPLEFT", -2, 2)
	tab.plate:SetPoint("BOTTOMRIGHT", tab.Icon, "BOTTOMRIGHT", 2, -2)
	tab.plate:SetFrameLevel(math.max(0, tab:GetFrameLevel() - 1))
	local fill = tab.plate:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetColorTexture(0.067, 0.067, 0.067, 0.97)
	edge(tab.plate, 1)
	tab.plate:Hide()
	-- The game's look: the spellbook-style tab frame behind the icon.
	tab.frameArt = tab:CreateTexture(nil, "BACKGROUND")
	tab.frameArt:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
	tab.frameArt:SetSize(64, 64)
	tab.frameArt:SetPoint("TOPLEFT", -3, 11)
	tab.hover = tab:CreateTexture(nil, "HIGHLIGHT")
	tab.hover:SetAllPoints(tab.Icon)
	tab.hover:SetColorTexture(1, 1, 1, 0.1)
	tab:SetScript("OnClick", function()
		if ns.Journal then ns.Journal.Toggle() end
	end)
	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("League of Explorers")
		GameTooltip:AddLine("Open the League of Explorers window.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
	GH.tab = tab
	-- Placed now, when the window opens (after any skin has moved the tabs),
	-- and whenever the guild's tabs come and go.
	local function soon()
		GH.PlaceTab()
		ns.After(0.2, GH.PlaceTab)
	end
	if cf.HookScript then cf:HookScript("OnShow", soon) end
	for _, k in ipairs(SIDE_TABS) do
		local t = cf[k]
		if t and t.HookScript then
			t:HookScript("OnShow", soon)
			t:HookScript("OnHide", soon)
		end
	end
	GH.PlaceTab()
	return tab
end

-- /loe guildtab: what the guild window looks like to the addon.
ns.Commands.guildtab = function()
	local cf = rawget(_G, "CommunitiesFrame")
	if not cf then
		ns.Print("guild window: not loaded yet (open it once, then try again).")
		return
	end
	local bits = {}
	for _, k in ipairs(SIDE_TABS) do
		local t = cf[k]
		bits[#bits + 1] = k .. "=" .. (t and (t:IsShown() and "shown" or "hidden") or "missing")
	end
	ns.Print("guild window tabs: " .. table.concat(bits, ", "))
	local tab = GH.tab
	if not tab then
		ns.Print("our tab: not made")
		return
	end
	local p, rel, rp, x, y = tab:GetPoint(1)
	local relName = rel and rel.GetName and rel:GetName() or (rel == cf.GuildInfoTab and "GuildInfoTab") or tostring(rel)
	ns.Print(("our tab: %s, visible %s, at %s %s %s %s %s"):format(tab:IsShown() and "shown" or "hidden",
		tostring(tab:IsVisible()), tostring(p), tostring(relName), tostring(rp), tostring(x), tostring(y)))
end

local hooked = false
local function hookGuild()
	if hooked then return end
	local cf = rawget(_G, "CommunitiesFrame")
	local ml = cf and cf.MemberList
	if not ml then return end
	hooked = true
	if ml.RefreshListDisplay then hooksecurefunc(ml, "RefreshListDisplay", refreshRows) end
	if ml.ScrollBox and ml.ScrollBox.RegisterCallback and ScrollBoxListMixin then
		ml.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, refreshRows, GH)
	end
	-- Kinship (or the game) may rewrite the names just after us: place again.
	if ml.HookScript then ml:HookScript("OnShow", function() ns.After(0.1, refreshRows) end) end
	GH.AddTab(cf)
end

ns.On("ADDON_LOADED", function(_, name)
	if name == "Blizzard_Communities" then hookGuild() end
end)
ns.Listen("READY", function()
	hookGuild()
	if ns.db.settings.guildWindow == nil then ns.db.settings.guildWindow = true end
	if ns.db.settings.chatTags == nil then ns.db.settings.chatTags = true end
end)
ns.Listen("ENTRY_MERGED", function() ns.After(0.2, refreshRows) end)

---------------------------------------------------------------------------
-- Guild chat: the explorer rank in its own brackets before the name, in
-- the rank's colour: "[Guild] [Cartographer] [Brennan Black]: ...". The
-- game wraps the name it's given in brackets, so the name given is
-- "Cartographer] [Brennan Black".
--
-- Names go through the game's sender-name hook. Roleplay addons (Kinship,
-- Total RP 3) use it too, for roleplay names, and only one name can show.
-- So the rank rides along with theirs: any name filter added after this
-- file loads (they add theirs at login) is wrapped, and the rank is put in
-- front of the name it gives ("[Cartographer] [Lord Brennan]"). When they
-- give none, the wrapper gives ours.
-- With no roleplay addon, our own filter does it. Only without the hook at
-- all does the rank go at the start of the message instead.
---------------------------------------------------------------------------
function GH.Tag(sender)
	local s = GH.Standing(sender)
	if not s then return nil end
	local c = GH.RankColor(s.index)
	return ("|cff%s[%s]|r "):format(T.Hex(c), s.rank)
end

local CHAT = { CHAT_MSG_GUILD = true, CHAT_MSG_OFFICER = true }

local function member(sender)
	sender = ns.Readable(sender)
	if type(sender) ~= "string" then return nil end
	local who = ns.Name(sender)
	if who and (ns.Guild.IsMember(who) or who == ns.Me()) then return who end
	return nil
end

-- The rank, coloured, for in front of a name: "Cartographer] [", so that
-- inside the game's brackets it reads "[Cartographer] [Name]".
function GH.Prefix(who)
	local s = GH.Standing(who)
	if not s then return nil end
	return ("|cff%s%s|r] ["):format(T.Hex(GH.RankColor(s.index)), s.rank)
end

-- "Cartographer] [Brennan Black": the rank, then the name in its class colour.
function GH.Title(who, guid)
	local prefix = GH.Prefix(who)
	if not prefix then return nil end
	local name = ns.ShortName(who)
	local class
	guid = ns.Readable(guid)
	if type(guid) == "string" and GetPlayerInfoByGUID then
		local ok, _, c = pcall(GetPlayerInfoByGUID, guid)
		if ok then class = ns.Readable(c) end
	end
	local m = ns.Guild.Member(who)
	class = class or (m and m.class)
	local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if cc then name = ("|cff%02x%02x%02x%s|r"):format(cc.r * 255, cc.g * 255, cc.b * 255, name) end
	return prefix .. name
end

local function on() return ns.db and ns.db.settings.chatTags ~= false and not ns.Solo() end

-- Other addons' name filters, wrapped as they're added.
local wrapped = 0
local util = rawget(_G, "ChatFrameUtil")
local nameHook = type(util) == "table" and type(util.AddSenderNameFilter) == "function"
if nameHook then
	local add = util.AddSenderNameFilter
	util.AddSenderNameFilter = function(fn, ...)
		if type(fn) ~= "function" or fn == GH.NameFilter then return add(fn, ...) end
		wrapped = wrapped + 1
		local function withRank(event, ...)
			local name = fn(event, ...)
			if not (CHAT[event] and on()) then return name end
			local ok, who = pcall(member, select(3, ...))
			if not (ok and who) then return name end
			if type(name) == "string" then
				local prefix = GH.Prefix(who)
				return prefix and (prefix .. name) or name
			end
			return GH.Title(who, select(13, ...)) or name
		end
		return add(withRank, ...)
	end
end

GH.TitleFirst = function() return nameHook end
GH.Wrapped = function() return wrapped end

-- Ours, for when no roleplay addon names chat.
local function nameFilter(event, _, _, sender, _, _, _, _, _, _, _, _, _, guid)
	if wrapped > 0 or not CHAT[event] or not on() then return nil end
	local who = member(sender)
	return who and GH.Title(who, guid) or nil
end
GH.NameFilter = nameFilter

local function chatFilter(_, _, msg, sender, ...)
	if nameHook or not on() then return false end
	msg = ns.Readable(msg)
	if type(msg) ~= "string" then return false end
	local who = member(sender)
	if not who then return false end
	local tag = GH.Tag(who)
	if not tag then return false end
	return false, tag .. msg, sender, ...
end
GH.ChatFilter = chatFilter

local function addFilter(event)
	local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if add then pcall(add, event, chatFilter) end
end
ns.Listen("READY", function()
	addFilter("CHAT_MSG_GUILD")
	addFilter("CHAT_MSG_OFFICER")
	if nameHook then pcall(ChatFrameUtil.AddSenderNameFilter, nameFilter) end
end)
