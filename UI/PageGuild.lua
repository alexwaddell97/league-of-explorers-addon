-- The Guild: the main page. Who has signed up, what the guild has found
-- together, your rank, this week's leaders and the guild's chronicle.

local _, ns = ...

local T, W, U = ns.Theme, ns.Widgets, ns.UI

local CHRONICLE = { zone = true, zonefull = true, continent = true, rare = true, treasure = true, place = true }

local function build(left, right)
	local PW = ns.Journal.PW

	-- Left page --------------------------------------------------------------
	local su = W.Label(left, "Signed up")
	su:SetPoint("TOPLEFT")
	left.signed = T.Text(left, "0", "Display", "heading")
	left.signed:SetPoint("TOPLEFT", su, "BOTTOMLEFT", 0, -6)
	left.signedNote = T.Text(left, "", "Small", "subtle")
	left.signedNote:SetPoint("BOTTOMLEFT", left.signed, "BOTTOMRIGHT", 8, 4)
	left.signedBar = W.Bar(left, PW, 4)
	left.signedBar:SetPoint("TOPLEFT", left.signed, "BOTTOMLEFT", 0, -8)

	local tog = W.Label(left, "Guild totals")
	tog:SetPoint("TOPLEFT", left.signedBar, "BOTTOMLEFT", 0, -22)
	left.rows = {}
	local prev = tog
	for i, label in ipairs({ "Zones discovered", "Areas explored", "Continents reached", "Rare creatures", "Treasures" }) do
		local s = W.Stat(left, label, PW)
		s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -8 or -2)
		if i <= 2 then
			s.bar = W.Bar(left, PW, 3)
			s.bar:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -1)
			s.spacer = CreateFrame("Frame", nil, left)
			s.spacer:SetSize(1, 6)
			s.spacer:SetPoint("TOPLEFT", s.bar, "BOTTOMLEFT")
			prev = s.spacer
		else
			prev = s
		end
		left.rows[i] = s
	end

	local rk = W.Label(left, "Your rank")
	rk:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -20)
	left.rank = W.RankBar(left, PW)
	left.rank:SetPoint("TOPLEFT", rk, "BOTTOMLEFT", 0, -8)

	-- The next goal the guild is working toward together.
	left.mileLabel = W.Label(left, "Next guild milestone")
	left.mileLabel:SetPoint("TOPLEFT", left.rank, "BOTTOMLEFT", 0, -40)
	left.mileText = T.Text(left, "", "Body", "text", PW - 70)
	left.mileText:SetPoint("TOPLEFT", left.mileLabel, "BOTTOMLEFT", 0, -6)
	left.mileBar = W.Bar(left, PW, 4)
	left.mileBar:SetPoint("TOPLEFT", left.mileText, "BOTTOMLEFT", 0, -6)
	left.mileCount = T.Text(left, "", "Header", "points")
	left.mileCount:SetPoint("BOTTOMRIGHT", left.mileBar, "TOPRIGHT", 0, 6)
	left.mileCount:SetJustifyH("RIGHT")

	left.alone = U.Note(left, PW, 120, "Interface\\Icons\\INV_Misc_GroupNeedMore", "Not in a guild",
		"In a guild, discoveries are shared with other members and you appear on the leaderboards. Until then, it tracks your own progress.")
	left.alone:SetPoint("BOTTOMLEFT")

	-- Right page -------------------------------------------------------------
	local wk = U.Heading(right, "This week's leaders")
	wk:SetPoint("TOPLEFT")
	right.top = W.List(right, PW, 5 * 34, 34, {
		bare = true,
		emptyText = "No points earned this week yet.",
		build = U.BoardBuild,
		fill = U.BoardFill,
		onClick = function() ns.Journal.Show("leaders") end,
	})
	right.top:SetPoint("TOPLEFT", wk, "BOTTOMLEFT", 0, -8)

	local ch = U.Heading(right, "Recent activity")
	ch:SetPoint("TOPLEFT", right.top, "BOTTOMLEFT", 0, -16)
	right.chronicle = W.List(right, PW, ns.Journal.PH - 5 * 34 - 70, 30, {
		bare = true,
		stripes = false,
		emptyText = "Guild discoveries will show here.",
		build = function(row)
			W.TimelineBuild(row)
			row.date:SetWidth(64)
			row.text:ClearAllPoints()
			row.text:SetPoint("LEFT", 96, 0)
			row.text:SetPoint("RIGHT", -52, 0)
		end,
		fill = function(row, e, i, last)
			if e.kind == "milestone" then
				W.TimelineFill(row, "milestone", U.Ago(e.t), e.text, "", i == 1, last)
				T.SetRole(row.text, "heading")
				return
			end
			local first = e.kind == "rare" and ns.Ledger.IsFirst(e)
			local text = ns.ShortName(e.who) .. ": " .. ns.Ledger.Describe(e) .. (first and "  (first in the guild)" or "")
			W.TimelineFill(row, e.kind, U.Ago(e.t), text, "+" .. ns.Points.Of(e), i == 1, last)
			T.SetRole(row.text, first and "points" or "text")
		end,
	})
	right.chronicle:SetPoint("TOPLEFT", ch, "BOTTOMLEFT", 0, -8)
end

local function refresh(left, right)
	local members = U.Members()
	local inGuild = ns.Guild.InGuild()
	local P, E = ns.Points, ns.Exploration

	local total = 0
	for _ in pairs(members) do total = total + 1 end
	local signed = U.SignedUp(members)
	left.signed:SetText(signed)
	left.signedNote:SetText(inGuild and ("of %d members use the addon"):format(total) or "character uses the addon")
	left.signedBar:SetProgress(signed, math.max(total, 1))

	local tog = P.Together(members)
	local R = left.rows
	R[1].value:SetText(("%d / %d"):format(tog.zone, E.ZoneCount()))
	R[1].bar:SetProgress(tog.zone, E.ZoneCount(), tog.zone >= E.ZoneCount())
	R[2].value:SetText(("%d / %d"):format(tog.area, E.AreaCount()))
	R[2].bar:SetProgress(tog.area, E.AreaCount(), tog.area >= E.AreaCount())
	R[3].value:SetText(tog.continent)
	R[4].value:SetText(tog.rare)
	R[5].value:SetText(tog.treasure)

	local me = ns.Me()
	if me then left.rank:SetWho(me) end
	left.alone:SetShown(not inGuild)

	local reached, nextGoal = ns.Work.Milestones(members)
	local showMile = inGuild or (ns.Work and ns.Work.demo)
	for _, x in ipairs({ left.mileLabel, left.mileText, left.mileCount, left.mileBar }) do x:SetShown(showMile and nextGoal ~= nil) end
	if nextGoal then
		left.mileText:SetText(("%d %s"):format(nextGoal.need, nextGoal.text))
		left.mileCount:SetText(("%d / %d"):format(nextGoal.have, nextGoal.need))
		left.mileBar:SetProgress(nextGoal.have, nextGoal.need)
	end

	local board = P.Board(members, P.WeekStart())
	local top = {}
	for i = 1, math.min(5, #board) do
		if board[i].points > 0 then top[#top + 1] = board[i] end
	end
	right.top:SetItems(top)
	-- Discoveries and the guild's milestones, newest first.
	local items = ns.Ledger.Query({ whoIn = members, kinds = CHRONICLE, limit = 200 })
	for _, m in ipairs(reached) do items[#items + 1] = { kind = "milestone", t = m.t, text = m.text } end
	table.sort(items, function(a, b) return a.t > b.t end)
	right.chronicle:SetItems(items, true)
end

ns.Journal.Register({
	id = "guild",
	guild = true, -- hidden in solo mode
	order = 1,
	title = "Guild",
	heading = function() return ns.Guild.name or "The Guild" end,
	info = "Guild progress: who uses the addon, what the guild has found and recent discoveries.",
	icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
	build = build,
	refresh = refresh,
})
