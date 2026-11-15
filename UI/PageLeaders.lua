-- Leaders: the guild's board for this week, this month, this season or all
-- time, one row per player (a main and their alts). The facing page shows
-- your standing and what your next rank asks for, the collections you have
-- completed, and the Hall of Champions: the top three of every season. How
-- points and ranks work opens from a button.

local _, ns = ...

local T, W, U = ns.Theme, ns.Widgets, ns.UI

local PERIODS = {
	{ key = "week", label = "This week" },
	{ key = "month", label = "This month" },
	{ key = "season", label = "Season" },
	{ key = "all", label = "All time" },
}

local function since(key)
	local P = ns.Points
	if key == "week" then return P.WeekStart() end
	if key == "month" then return P.MonthStart() end
	if key == "season" then return P.SeasonStart() end
	return nil
end

-- The season tab carries the season's number: "Season 1".
local function periods()
	PERIODS[3].label = ns.Points.SeasonName(ns.Points.SeasonStart())
	return PERIODS
end

local function periodName(key)
	if key == "season" then return "in " .. ns.Points.SeasonName(ns.Points.SeasonStart()) end
	return ({ week = "this week", month = "this month", all = "all time" })[key]
end

-- How points and ranks work: a card over the book.
local function buildHelp(parent)
	local m = CreateFrame("Frame", nil, parent)
	m:SetAllPoints(parent)
	m:SetFrameLevel(parent:GetFrameLevel() + 80)
	m:EnableMouse(true)
	m.dim = m:CreateTexture(nil, "BACKGROUND")
	m.dim:SetAllPoints()
	m.dim:SetColorTexture(0, 0, 0, 0.35)
	m:SetScript("OnMouseDown", function() m:Hide() end)
	local card = CreateFrame("Frame", nil, m)
	card:SetSize(660, 470)
	card:SetPoint("CENTER")
	card:EnableMouse(true)
	card.bg = card:CreateTexture(nil, "BACKGROUND")
	card.bg:SetAllPoints()
	T.Border(card, "coverEdge")
	T.OnTheme(function(look) T.Fill(card.bg, { look.page[1], look.page[2], look.page[3], 1 }) end)
	local close = W.RoundButton(card, 20, "close", function() m:Hide() end)
	close:SetPoint("TOPRIGHT", -8, -8)

	local rh = U.Heading(card, "Ranks")
	rh:SetPoint("TOPLEFT", 20, -18)
	rh.rule:SetPoint("RIGHT", card, "CENTER", -14, 0)
	local note = T.Text(card, "Ranks are based on what you've done, not points. Each rank needs everything listed, plus the ranks "
		.. "below it. Exploration from before you installed the addon counts.", "Small", "subtle", 300)
	note:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 0, -6)
	note:SetSpacing(2)
	local prev = note
	for i, r in ipairs(ns.Points.RANKS) do
		local c = ns.GuildHooks and ns.GuildHooks.RankColor(i) or T.Look().accent
		local dot = T.Circle(card, 9, "ARTWORK")
		dot:SetVertexColor(c[1], c[2], c[3], 1)
		dot:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -12 or -7)
		local name = T.Text(card, r.name, "Body", "text")
		name:SetPoint("LEFT", dot, "RIGHT", 8, 0)
		local need = T.Text(card, ns.Points.RankShort(r), "Small", "subtle", 170)
		need:SetPoint("LEFT", dot, "RIGHT", 128, 0)
		need:SetWordWrap(false)
		prev = dot
	end

	local sh = U.Heading(card, "Points")
	sh:SetPoint("TOPLEFT", card, "TOP", 10, -18)
	local pnote = T.Text(card, "Points are for the leaderboards. Each find counts once per player, across all your characters.",
		"Small", "subtle", 300)
	pnote:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, -6)
	pnote:SetSpacing(2)
	prev = pnote
	for _, k in ipairs(ns.Points.KINDS) do
		if k.points > 0 then
			local s = W.Stat(card, k.label, 300)
			s:SetHeight(18)
			s.label:SetFontObject(T.FONTS.Small)
			s.value:SetFontObject(T.FONTS.Small)
			s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, prev == pnote and -10 or 0)
			s.value:SetText((k.kind == "expedition" and "about +" or "+") .. ns.Points.Value(k.kind))
			T.SetRole(s.value, "points")
			prev = s
		end
	end
	m:Hide()
	return m
end

local function build(left, right)
	local PW, PH = ns.Journal.PW, ns.Journal.PH
	local LH = PH - ns.Journal.HEAD

	left.period = ns.db.settings.board or "week"
	left.segments = W.Segments(left, function(key)
		left.period = key
		ns.db.settings.board = key
		ns.Journal.RefreshSoon()
	end)
	left.segments:Rebuild(periods())
	left.seasonShown = PERIODS[3].label
	left.segments:SetPoint("TOPLEFT")
	left.count = T.Text(left, "", "Small", "subtle", PW)
	left.count:SetPoint("TOPLEFT", 0, -32)
	left.board = W.List(left, PW, LH - 52, 40, {
		emptyText = "No points in this period yet.",
		emptyIcon = "Interface\\Icons\\INV_Crown_01",
		build = U.BoardBuild,
		fill = U.BoardFill,
	})
	left.board:SetPoint("TOPLEFT", 0, -52)

	-- Right page --------------------------------------------------------------
	local st = U.Heading(right, "Your standing")
	st:SetPoint("TOPLEFT")
	right.place = T.Text(right, "", "Display", "points")
	right.place:SetPoint("TOPLEFT", st, "BOTTOMLEFT", 0, -10)
	right.placeNote = T.Text(right, "", "Small", "subtle", PW - 70)
	right.placeNote:SetPoint("BOTTOMLEFT", right.place, "BOTTOMRIGHT", 10, 4)
	right.rank = W.RankBar(right, PW)
	right.rank:SetPoint("TOPLEFT", right.place, "BOTTOMLEFT", 0, -14)

	local ch = U.Heading(right, "Collections")
	ch:SetPoint("TOPLEFT", right.rank, "BOTTOMLEFT", 0, -34)
	right.collections = T.Text(right, "", "Small", "text", PW)
	right.collections:SetPoint("TOPLEFT", ch, "BOTTOMLEFT", 0, -8)
	right.collections:SetHeight(64)
	right.collections:SetJustifyV("TOP")
	right.collections:SetSpacing(3)

	local hh = U.Heading(right, "Season winners")
	hh:SetPoint("TOPLEFT", right.collections, "BOTTOMLEFT", 0, -12)
	right.champions = T.Text(right, "", "Small", "text", PW)
	right.champions:SetPoint("TOPLEFT", hh, "BOTTOMLEFT", 0, -8)
	right.champions:SetHeight(120)
	right.champions:SetJustifyV("TOP")
	right.champions:SetSpacing(3)

	right.help = W.Button(right, "How points and ranks work", 210, 24, function()
		-- Over the window in use (the book or the map look's).
		local host = ns.Journal.Book()
		if not right.helpCard or right.helpCard:GetParent() ~= host then right.helpCard = buildHelp(host) end
		right.helpCard:Show()
	end)
	right.help:SetPoint("BOTTOMLEFT", 0, 0)
end

local function refresh(left, right)
	local P = ns.Points
	local members = U.Members()
	local me = ns.Me()
	local player = me and P.Player(me)
	if left.seasonShown ~= P.SeasonName(P.SeasonStart()) then
		left.segments:Rebuild(periods())
		left.seasonShown = PERIODS[3].label
	end
	left.segments:Select(left.period)
	local board = P.Board(members, since(left.period))
	local shown = {}
	for _, r in ipairs(board) do
		if left.period == "all" or r.points > 0 then shown[#shown + 1] = r end
	end
	left.board:SetItems(shown, true)
	local total = 0
	for _ in pairs(members) do total = total + 1 end
	local line = ("%d players  /  %d guild members"):format(#board, total)
	if left.period == "season" then
		local days = P.SeasonDaysLeft()
		line = ("%s  /  %s  /  ends in %d day%s"):format(P.SeasonName(P.SeasonStart()), P.SeasonPeriod(P.SeasonStart()),
			days, days == 1 and "" or "s")
	end
	left.count:SetText(line)

	local place, mine
	for i, r in ipairs(shown) do
		if r.who == player then place, mine = i, r end
	end
	if place then
		right.place:SetText("#" .. place)
		right.placeNote:SetText(("of %d  /  %s points %s"):format(#shown, T.Number(mine.points), periodName(left.period)))
	else
		right.place:SetText("-")
		right.placeNote:SetText("No points " .. periodName(left.period) .. " yet")
	end
	if me then right.rank:SetWho(me) end

	local subtle = T.Hex(T.Look().subtle)
	local cols = player and ns.Work.Collections(player) or {}
	if #cols > 0 then
		local bits = {}
		for _, c in ipairs(cols) do
			bits[#bits + 1] = c.label .. (c.points > 0 and (" |cff%s(+%d)|r"):format(T.Hex(T.Look().points), c.points) or "")
		end
		right.collections:SetText(table.concat(bits, "\n"))
	else
		right.collections:SetText(("|cff%sFind every rare in a zone, or fully explore a continent, to complete a collection.|r"):format(subtle))
	end

	local champs = P.Champions(members)
	if #champs > 0 then
		local lines = {}
		for i, s in ipairs(champs) do
			if i > 3 then break end
			local names = {}
			for j, r in ipairs(s.top) do names[j] = ("%d. %s %s"):format(j, ns.ShortName(r.who), ("|cff%s%s|r"):format(T.Hex(T.Look().points), T.Number(r.points))) end
			lines[#lines + 1] = ("|cff%s%s|r  |cff%s%s|r\n   %s"):format(T.Hex(T.Look().heading), s.name, subtle, s.period,
				table.concat(names, "   "))
		end
		right.champions:SetText(table.concat(lines, "\n"))
	else
		local ss = P.SeasonStart()
		right.champions:SetText(("|cff%s%s (%s) ends in %d days. The top three players will be listed here.|r"):format(
			subtle, P.SeasonName(ss), P.SeasonPeriod(ss), P.SeasonDaysLeft()))
	end
end

ns.Journal.Register({
	id = "leaders",
	guild = true,
	order = 5,
	title = "Leaders",
	info = "Guild leaderboards by week, month and season (three months). Alts count with their main.",
	icon = "Interface\\Icons\\INV_Crown_01",
	build = build,
	refresh = refresh,
})
