-- /loe demo: a guided tour of the journal. It shows every kind of toast,
-- turns through the whole book and back, and fills the pages with a small
-- pretend guild so each one has something to show: guildmates and their
-- finds, an officer, an expedition and a bounty, submissions to review.
--
-- None of it is real: the pretend guildmates live only in memory, every
-- entry is marked as a demo (never sent to the guild, never counted in
-- sync), and all of it is removed when the tour ends, or when the journal
-- next loads if the game was reloaded mid-tour. /loe demo again stops it.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets
local D = {}
ns.Demo = D

local HOUR = 3600

-- The pretend guild, with surnames as Forever writes them.
local CAST = {
	{ who = "Aldric-Stone", class = "WARRIOR", rank = "Officer", rankIndex = 1, online = true, zone = "Stormwind City", level = 38 },
	{ who = "Mira-Vale", class = "HUNTER", rank = "Veteran", rankIndex = 2, online = true, zone = "Darkshore", level = 34 },
	{ who = "Tobin-Ash", class = "MAGE", rank = "Member", rankIndex = 3, online = false, level = 22 },
	{ who = "Sela-Brook", class = "DRUID", rank = "Member", rankIndex = 3, online = true, zone = "Elwynn Forest", level = 19 },
}

-- What each of them has found: zone discoveries, zones fully explored, rares.
local FINDS = {
	["Aldric-Stone"] = { zones = { 1429, 1436, 1433, 1431, 1437, 1426, 1432 }, full = { 1429, 1436 }, rares = { 100 } },
	["Mira-Vale"] = { zones = { 1438, 1439, 1440, 1413, 1411, 1412, 1446, 1447, 1429 }, full = { 1438, 1439 }, rares = { 471, 79 }, continent = { 1414 } },
	["Tobin-Ash"] = { zones = { 1429, 1436, 1433 }, rares = { 471 } },
	["Sela-Brook"] = { zones = { 1438, 1439, 1429 }, full = { 1438 } },
}

local running, token, caption, saved = false, 0, nil, nil
local hideLadder, hideGuildTab, hideMap -- defined with the show-and-tell pieces below

---------------------------------------------------------------------------
-- The pretend guild
---------------------------------------------------------------------------
local function setUp()
	local now = ns.Now()
	local L = ns.Ledger
	saved = { page = ns.db.settings.page, members = ns.Guild.members, name = ns.Guild.name }
	D.holding = true

	-- Guildmates join the roster we hold in memory (the real one comes back
	-- with the next roster refresh).
	local members = {}
	for k, v in pairs(ns.Guild.members) do members[k] = v end
	for _, c in ipairs(CAST) do
		members[c.who] = { rank = c.rank, rankIndex = c.rankIndex, class = c.class, level = c.level, online = c.online, zone = c.zone }
	end
	local me = ns.Me()
	if me and not members[me] then members[me] = { rank = "Member", rankIndex = 3, online = true } end
	ns.Guild.members = members
	ns.Guild.name = ns.Guild.name or "The League of Explorers"
	ns.Work.demo = true -- show the officer tools during the tour
	ns.Guild.CheckMode()

	-- Their discoveries, spread over the last few days.
	for ci, c in ipairs(CAST) do
		local f = FINDS[c.who]
		local seq, t = 0, now - (30 + ci * 7) * HOUR
		local function add(kind, key, extra)
			seq = seq + 1
			t = t + math.random(1, 3) * HOUR
			local e = { who = c.who, seq = seq, t = math.min(t, now - 60), kind = kind, key = key }
			for k, v in pairs(extra or {}) do e[k] = v end
			L.AddDemo(e)
		end
		for _, z in ipairs(f.zones) do add("zone", z, { map = z, name = ns.MapName(z) }) end
		for _, z in ipairs(f.full or {}) do add("zonefull", z, { map = z, name = ns.MapName(z) }) end
		for _, cId in ipairs(f.continent or {}) do add("continent", cId, { map = cId, name = ns.MapName(cId) }) end
		for _, r in ipairs(f.rares or {}) do
			local rare = ns.RareList and ns.RareList[r]
			add("rare", r, { name = rare and rare[1], map = rare and rare[2], x = rare and rare[3], y = rare and rare[4] })
		end
	end

	-- You found one rare yourself: its portrait shows in full colour.
	local mySeq = 900000
	local function mine(kind, key, extra, ago)
		mySeq = mySeq + 1
		local e = { who = me, seq = mySeq, t = now - ago, kind = kind, key = key }
		for k, v in pairs(extra or {}) do e[k] = v end
		return L.AddDemo(e)
	end
	if me then
		local thuros = ns.RareList and ns.RareList[61]
		mine("rare", 61, { name = thuros and thuros[1], map = 1429, x = thuros and thuros[3], y = thuros and thuros[4] }, 5 * HOUR)
	end

	-- An officer's expedition, which Mira has finished and you've started,
	-- and a bounty no one has claimed.
	local postT = now - 26 * HOUR
	local exp = L.AddDemo({ who = "Aldric-Stone", seq = 100, t = postT, kind = "exp", key = postT,
		name = "The Elwynn Hunt", mask = "r471,z1429,r79", note = ("exp:100:%d"):format(postT + 7 * 86400) })
	L.AddDemo({ who = "Aldric-Stone", seq = 101, t = postT + 60, kind = "exp", key = postT + 60,
		name = "Wanted: Gruff Swiftbite", mask = "r100", note = "bounty:50:" })
	for i, g in ipairs({ "r471", "z1429", "r79" }) do
		L.AddDemo({ who = "Mira-Vale", seq = 200 + i, t = postT + i * 2 * HOUR, kind = "hunt", key = exp.id .. "/" .. g })
	end
	if me then mine("hunt", exp.id .. "/z1429", nil, 3 * HOUR) end

	-- Submissions: one waiting for review, one approved.
	local sub1 = L.AddDemo({ who = "Tobin-Ash", seq = 300, t = now - 4 * HOUR, kind = "sub", key = now - 4 * HOUR,
		name = "The Hidden Falls", note = "Behind the waterfall north of Goldshire", map = 1429, x = 47.5, y = 38.2 })
	local sub2 = L.AddDemo({ who = "Sela-Brook", seq = 301, t = now - 20 * HOUR, kind = "sub", key = now - 20 * HOUR,
		name = "Sunset Point", note = "The best view over the sea in Westfall", map = 1436, x = 31.2, y = 81.0 })
	L.AddDemo({ who = "Aldric-Stone", seq = 102, t = now - 18 * HOUR, kind = "rev", key = sub2.id, name = "approved" })
	local sub3 = L.AddDemo({ who = "Mira-Vale", seq = 302, t = now - 30 * HOUR, kind = "sub", key = now - 30 * HOUR,
		name = "The Old Lookout", note = "A tower ruin with a view over the whole forest", map = 1429, x = 63.4, y = 70.2 })
	L.AddDemo({ who = "Aldric-Stone", seq = 103, t = now - 28 * HOUR, kind = "rev", key = sub3.id, name = "approved" })
	local _ = sub1

	ns.Fire("ROSTER")
	ns.Fire("ENTRY_MERGED", {})
end

local function tearDown()
	hideLadder()
	hideGuildTab()
	hideMap()
	if ns.Alerts then ns.Alerts.ClearDemo() end
	D.holding = nil
	ns.Ledger.ClearDemo()
	ns.Work.demo = nil
	ns.Guild.CheckMode()
	if saved then
		ns.Guild.members = saved.members
		ns.Guild.name = saved.name
		ns.db.settings.page = saved.page
	end
	ns.Guild.Refresh()
	ns.Fire("ENTRY_MERGED", {})
end

---------------------------------------------------------------------------
-- The caption at the top of the screen
---------------------------------------------------------------------------
local function makeCaption()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(560, 48)
	f:SetPoint("TOP", 0, -40)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	T.Border(f, "coverEdge")
	f.step = T.Text(f, "", "Label", "label", nil, true)
	f.step:SetPoint("TOPLEFT", 16, -9)
	f.text = T.Text(f, "", "Body", "heading", 430, true)
	f.text:SetPoint("TOPLEFT", f.step, "BOTTOMLEFT", 0, -4)
	f.text:SetWordWrap(false)
	f.stop = W.Button(f, "Stop", 70, 24, function() D.Stop() end)
	f.stop:SetPoint("RIGHT", -12, 0)
	T.OnTheme(function(look)
		local c = look.cover
		f.bg:SetColorTexture(c[1], c[2], c[3], 0.95)
		local t = look.coverText
		f.text:SetTextColor(t[1], t[2], t[3])
	end)
	f:Hide()
	return f
end

local function say(n, total, text)
	caption = caption or makeCaption()
	caption.step:SetText(("LEAGUE OF EXPLORERS DEMO  /  %d OF %d"):format(n, total))
	caption.text:SetText(text)
	caption:Show()
end

---------------------------------------------------------------------------
-- Show-and-tell pieces for the guild features
---------------------------------------------------------------------------

-- Sample guild chat, built by the real chat filter, marked as the demo's.
local CHAT = {
	{ "Aldric-Stone", "New bounty up on Gruff Swiftbite, first to kill him gets it." },
	{ "Mira-Vale", "Finished the Elwynn Hunt! Mother Fang was by the mine." },
	{ "Sela-Brook", "Anyone fancy charting Westfall tonight?" },
}
local function sampleChat()
	local info = ChatTypeInfo and ChatTypeInfo.GUILD
	local r, g, b = info and info.r or 0.25, info and info.g or 1, info and info.b or 0.25
	local lines = {}
	for _, l in ipairs(CHAT) do lines[#lines + 1] = l end
	if ns.Me() then lines[#lines + 1] = { ns.Me(), "On my way!" } end
	for i, l in ipairs(lines) do
		ns.After((i - 1) * 0.8, function()
			if not running then return end
			local GH = ns.GuildHooks
			local line
			if GH.TitleFirst() then
				line = ("[Guild] [%s]: %s"):format(GH.Title(l[1]) or ns.ShortName(l[1]), l[2])
			else
				local _, text = GH.ChatFilter(nil, "CHAT_MSG_GUILD", l[2], l[1])
				line = ("[Guild] [%s]: %s"):format(ns.ShortName(l[1]), text or l[2])
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cff999999(demo)|r " .. line, r, g, b)
		end)
	end
end

-- A card with every rank: its emblem, name and the points it needs, and
-- its chat tag shown on a dark strip, as it really looks in the chat window.
local ladder
local function showLadder()
	if not ladder then
		local W_, ROW = 610, 26
		-- The screen behind is dimmed a little, so the card stands apart.
		local dim = CreateFrame("Frame", nil, UIParent)
		dim:SetAllPoints()
		dim:SetFrameStrata("FULLSCREEN")
		dim.t = dim:CreateTexture(nil, "BACKGROUND")
		dim.t:SetAllPoints()
		dim.t:SetColorTexture(0, 0, 0, 0.35)

		local f = CreateFrame("Frame", nil, dim)
		f:SetSize(W_, 66 + #ns.Points.RANKS * ROW + 20)
		f:SetPoint("CENTER", 0, 30)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f.bg = f:CreateTexture(nil, "BACKGROUND")
		f.bg:SetAllPoints()
		T.Border(f, "coverEdge")
		f.title = T.Text(f, "Explorer ranks", "Title", "heading")
		f.title:SetPoint("TOPLEFT", 20, -16)

		-- Column headings.
		local function head(text, x, right)
			local h = W.Label(f, text)
			if right then h:SetPoint("TOPRIGHT", f, "TOPRIGHT", x, -46) else h:SetPoint("TOPLEFT", x, -46) end
			return h
		end
		head("Rank", 20)
		head("Needs", 196)
		head("In guild chat", -20, true)

		-- The chat strip: the chat window's own dark, for the tags.
		local strip = f:CreateTexture(nil, "BORDER")
		strip:SetPoint("TOPRIGHT", -12, -60)
		strip:SetSize(170, #ns.Points.RANKS * ROW + 8)
		strip:SetColorTexture(0, 0, 0, 0.78)

		for i, r in ipairs(ns.Points.RANKS) do
			local y = -66 - (i - 1) * ROW
			local c = ns.GuildHooks.RankColor(i)
			local ring = T.Circle(f, 13, "ARTWORK", 0)
			ring:SetPoint("TOPLEFT", 20, y - 1)
			ring:SetVertexColor(0, 0, 0, 0.6)
			local dot = T.Circle(f, 10, "ARTWORK", 1)
			dot:SetPoint("CENTER", ring)
			dot:SetVertexColor(c[1], c[2], c[3], 1)
			local name = T.Text(f, r.name, "Body", "text")
			name:SetPoint("LEFT", ring, "RIGHT", 10, 0)
			local need = T.Text(f, ns.Points.RankShort(r), "Small", "subtle")
			need:SetPoint("TOPLEFT", 196, y)
			need:SetWidth(W_ - 196 - 190)
			need:SetWordWrap(false)
			local sample = ns.GuildHooks.TitleFirst() and ("[|cff%s%s|r] [Name]"):format(T.Hex(c), r.name)
				or ("|cff%s[%s]|r"):format(T.Hex(c), r.name)
			local tag = T.Text(f, sample, "Small", "text", nil, true)
			tag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, y)
			tag:SetJustifyH("RIGHT")
		end
		T.OnTheme(function(look) T.Fill(f.bg, { look.page[1], look.page[2], look.page[3], 1 }) end)
		ladder = dim
	end
	ladder:Show()
	T.FadeIn(ladder, 0.2)
end
hideLadder = function() if ladder then ladder:Hide() end end

-- The real Guild tab, with your row's emblem; beside it, the hover details
-- as they look for a guildmate.
local openedGuild = false
local function showGuildTab()
	if ns.Journal.IsShown() then ns.Journal.Toggle() end
	local cf = rawget(_G, "CommunitiesFrame")
	if not (cf and cf.IsShown and cf:IsShown()) and IsInGuild and IsInGuild() and ToggleGuildFrame then
		if pcall(ToggleGuildFrame) then openedGuild = true end
	end
	ns.After(0.6, function()
		if not running then return end
		GameTooltip:SetOwner(caption, "ANCHOR_BOTTOMLEFT", 0, -8)
		GameTooltip:SetText("Mira Vale")
		GameTooltip:AddLine("Level 34 Hunter", 1, 1, 1)
		ns.GuildHooks.AddTooltip(GameTooltip, "Mira-Vale")
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("(what hovering a guildmate's row adds)", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
end
-- The world map, opened on Elwynn Forest with a guildmate's fresh sighting
-- of the bounty's rare on it.
local mapOpened = false
local function showMap()
	if not (WorldMapFrame and ns.Alerts) then return end
	local r = ns.RareList and ns.RareList[100]
	ns.Alerts.AddDemo({ id = 100, who = "Mira-Vale", t = ns.Now() - 120, map = 1429,
		x = r and r[3] or 30, y = r and r[4] or 60, name = r and r[1] or "Gruff Swiftbite" })
	if ns.Journal.IsShown() then ns.Journal.Toggle() end
	if OpenWorldMap then
		pcall(OpenWorldMap, 1429)
	else
		if ShowUIPanel then pcall(ShowUIPanel, WorldMapFrame) else WorldMapFrame:Show() end
		if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, 1429) end
	end
	mapOpened = true
	if ns.MapPins then ns.MapPins.Refresh() end
end

hideMap = function()
	if not mapOpened then return end
	mapOpened = false
	if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown() then
		if HideUIPanel then pcall(HideUIPanel, WorldMapFrame) else WorldMapFrame:Hide() end
	end
end

hideGuildTab = function()
	if caption and GameTooltip:IsOwned(caption) then GameTooltip:Hide() end
	if openedGuild then
		openedGuild = false
		local cf = rawget(_G, "CommunitiesFrame")
		if cf and cf.IsShown and cf:IsShown() and ToggleGuildFrame then pcall(ToggleGuildFrame) end
	end
end

---------------------------------------------------------------------------
-- The tour
---------------------------------------------------------------------------
local function toast(kind, name, points) ns.Toast({ kind = kind, name = name, points = points }) end

local function showRare(id)
	local left = ns.Journal.Pages("bestiary")
	if not (left and left.data) then return end
	for _, z in ipairs(left.data) do
		if z.id == left.zone then
			for _, r in ipairs(z.list) do
				if r.id == id then
					left.selected = r
					left.Render()
					return
				end
			end
		end
	end
end

local STEPS = {
	{ 6, "Discovery pop-ups: one for each thing that earns points.", function()
		local P = ns.Points
		toast("zone", "Darkshore", P.Value("zone"))
		ns.After(0.6, function() toast("zonefull", "Teldrassil", P.Value("zonefull")) end)
		ns.After(1.2, function() toast("continent", "Kalimdor", P.Value("continent")) end)
		ns.After(1.8, function() toast("rare", "Mother Fang", P.Value("rare") + P.Value("rarefirst")) end)
	end },
	{ 6, "Weekly hunt, guild place and treasure pop-ups.", function()
		local P = ns.Points
		toast("weekly", "Mother Fang", P.Value("weekly"))
		ns.After(0.6, function() toast("place", "The Hidden Falls", P.Value("place")) end)
		ns.After(1.2, function() toast("treasure", "Battered Chest", P.Value("treasure")) end)
		ns.After(1.8, function() toast("weeklyall", "All five found", P.Value("weeklyall")) end)
	end },
	{ 6, "Expedition, bounty and collection pop-ups.", function()
		local P = ns.Points
		toast("expedition", "The Elwynn Hunt", 150)
		ns.After(0.6, function() toast("bounty", "Wanted: Gruff Swiftbite", 50) end)
		ns.After(1.2, function() toast("bestiary", "Bestiary of Elwynn Forest", P.Value("bestiary")) end)
	end },
	{ 6, "Guild rare alerts: when a guildmate spots a rare, you get a pop-up. Click it for a waypoint. It also shows on your maps.", function()
		ns.Toast({ kind = "alert", kicker = "Spotted by Mira Vale", name = "Gruff Swiftbite", big = "+50", hold = 6 })
	end },
	{ 9, "World map: rares just spotted by the guild (pulsing), rares you're hunting where the guild last saw them, and guild places.", function()
		showMap()
	end },
	{ 6, "Guild: who uses the addon, guild totals and this week's leaders.", function()
		hideMap()
		ns.Journal.Show("guild")
	end },
	{ 5, "My Journal: your rank, your zones and a map of each one.", function()
		ns.Journal.Show("journal")
	end },
	{ 5, "Bestiary: every rare by zone and type, shown as silhouettes until found.", function()
		local left = ns.Journal.Pages("bestiary")
		if left then
			left.zone, left.selected = 1429, nil
		end
		ns.Journal.Show("bestiary")
	end },
	{ 4, "Rares you've found show in full colour.", function() showRare(61) end },
	{ 4, "Rares the guild has found show as a named silhouette, with who found it first.", function() showRare(471) end },
	{ 6, "Expeditions: the weekly hunt and officer challenges.", function()
		ns.Journal.Show("expeditions")
	end },
	{ 6, "Leaders: leaderboards by week, month and season, plus your rank, collections and season winners.", function()
		ns.Journal.Show("leaders")
	end },
	{ 5, "Guild chat: each message shows the sender's explorer rank.", function()
		sampleChat()
	end },
	{ 7, "Each rank has its own colour, used for its icon and chat tag.", function()
		showLadder()
	end },
	{ 7, "Guild window: an icon next to each addon user's name. Hover to see their rank and points.", function()
		hideLadder()
		showGuildTab()
	end },
	{ 6, "Submissions: suggest a place; officers approve or decline it.", function()
		hideGuildTab()
		ns.Journal.Show("submissions")
	end },
	{ 6, "Choosing an earlier tab turns the pages back.", function()
		local back = { "leaders", "expeditions", "bestiary", "journal", "guild" }
		for i, id in ipairs(back) do
			ns.After((i - 1) * 1.1, function() if running then ns.Journal.Show(id) end end)
		end
	end },
	{ 3, "End of the tour. The example guild has been removed.", function()
		tearDown()
	end },
}

function D.Stop()
	if not running then return end
	running = false
	token = token + 1
	tearDown()
	if caption then caption:Hide() end
	ns.Print("demo over: the example guild and demo entries have been removed.")
end

function D.Start()
	if running then return D.Stop() end
	if ns.InCombat() then
		ns.Print("the demo waits until you're out of combat.")
		return
	end
	running = true
	token = token + 1
	local mine = token
	setUp()
	ns.Print("demo: a tour of the addon with an example guild. Nothing is sent or saved. Type /loe demo again to stop.")
	local i = 0
	local function nextStep()
		if not running or token ~= mine then return end
		i = i + 1
		local step = STEPS[i]
		if not step then
			running = false
			if caption then caption:Hide() end
			ns.Print("demo over: the example guild and demo entries have been removed.")
			return
		end
		say(i, #STEPS, step[2])
		local ok, err = pcall(step[3])
		if not ok then geterrorhandler()(err) end
		ns.After(step[1], nextStep)
	end
	nextStep()
end

function D.Running() return running end

ns.Commands.demo = function() D.Start() end
