-- Expeditions: challenges the officers set. An expedition pays everyone
-- who completes it (and half again to the first); a bounty pays only the
-- first. The left page lists them; the right page shows one (its goals,
-- your progress, who has finished) or, for officers, the form to post one.

local _, ns = ...

local T, W, U = ns.Theme, ns.Widgets, ns.UI
local Wk = ns.Work

local REWARDS = { 25, 50, 100, 200 }
local DURATIONS = { { key = 7, label = "1 week" }, { key = 14, label = "2 weeks" }, { key = 30, label = "1 month" }, { key = 0, label = "No end" } }
local GOAL_KINDS = { { key = "z", label = "Visit zones" }, { key = "f", label = "Fully explore" }, { key = "r", label = "Kill rares" } }
local MAX_GOALS = 8

local function endsText(x)
	if x.withdrawn then return "withdrawn" end
	if not x.ends then return "no end date" end
	local left = x.ends - ns.Now()
	if left <= 0 then return "ended " .. T.Date(x.ends, true) end
	local d = math.floor(left / 86400)
	if d >= 1 then return ("ends in %d day%s"):format(d, d == 1 and "" or "s") end
	return ("ends in %d hours"):format(math.max(1, math.floor(left / 3600)))
end

local function build(left, right)
	local PW, PH = ns.Journal.PW, ns.Journal.PH
	local LH = PH - ns.Journal.HEAD

	-- Left page: the list --------------------------------------------------------
	left.filter = "week"
	left.segments = W.Segments(left, function(key)
		left.filter = key
		left.selected = nil
		ns.Journal.RefreshSoon()
	end)
	left.segments:Rebuild({ { key = "week", label = "This week" }, { key = "exp", label = "Expeditions" },
		{ key = "bounty", label = "Bounties" }, { key = "past", label = "Finished" } })
	left.segments:SetPoint("TOPLEFT")
	left.list = W.List(left, PW, LH - 76, 52, {
		emptyText = "Nothing posted yet.",
		emptyIcon = "Interface\\Icons\\INV_Misc_Spyglass_03",
		build = function(row)
			row.title = T.Text(row, "", "Header", "heading")
			row.title:SetPoint("TOPLEFT", 8, -6)
			row.title:SetPoint("RIGHT", -60, 0)
			row.title:SetWordWrap(false)
			row.goal = T.Text(row, "", "Small", "text")
			row.goal:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
			row.goal:SetPoint("RIGHT", -60, 0)
			row.goal:SetWordWrap(false)
			row.when = T.Text(row, "", "Label", "subtle")
			row.when:SetPoint("TOPLEFT", row.goal, "BOTTOMLEFT", 0, -3)
			row.when:SetPoint("RIGHT", -60, 0)
			row.when:SetWordWrap(false)
			row.reward = W.Chip(row, "Small")
			row.reward:SetPoint("TOPRIGHT", -8, -8)
		end,
		fill = function(row, x)
			row.title:SetText(x.title)
			local g = x.goals[1]
			row.goal:SetText(#x.goals == 1 and Wk.GoalName(g) or (#x.goals .. " goals: " .. Wk.GoalName(g) .. ", ..."))
			local done, total, fin = Wk.Progress(x, ns.Me())
			row.when:SetText((x.bounty and "Bounty" or "Expedition") .. "  /  " .. endsText(x)
				.. (fin and "  /  you finished" or ("  /  %d of %d done"):format(done, total)))
			row.reward:Set("+" .. x.reward, T.Look().points)
		end,
		onClick = function(x)
			left.selected = x
			right.composing = false
			left.list:Render()
			right.Draw()
		end,
		isSelected = function(x) return left.selected and x.id == left.selected.id end,
	})
	left.list:SetPoint("TOPLEFT", 0, -34)

	-- This week's hunt, one for each level band: yours is open to start
	-- with, and the others can be looked at.
	left.bands = W.Segments(left, function(key)
		left.band = key
		ns.Journal.RefreshSoon()
	end)
	left.bands:SetPoint("TOPLEFT", 0, -34)
	left.bands:Hide()

	-- The band's five targets, your ticks, how many have found each.
	left.week = W.List(left, PW, LH - 108, 46, {
		build = function(row)
			row.tick = W.Tick(row, 14)
			row.tick:SetPoint("LEFT", 8, 0)
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(24, 24)
			row.icon:SetPoint("LEFT", 30, 0)
			row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			T.Round(row.icon)
			row.title = T.Text(row, "", "Header", "heading")
			row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 2)
			row.title:SetPoint("RIGHT", -60, 0)
			row.title:SetWordWrap(false)
			row.sub = T.Text(row, "", "Small", "subtle")
			row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
			row.sub:SetPoint("RIGHT", -60, 0)
			row.sub:SetWordWrap(false)
			row.reward = W.Chip(row, "Small")
			row.reward:SetPoint("RIGHT", -8, 0)
		end,
		fill = function(row, g)
			local name, where = Wk.WeeklyName(g)
			row.tick:SetChecked(left.hits[g.key] ~= nil, T.Look().done)
			row.tick:SetShown(left.band == left.myBand)
			row.icon:SetTexture(g.k == "r" and ns.KIND_ICON.rare or ns.KIND_ICON.zone)
			row.title:SetText(name)
			local n = left.found[g.key] or 0
			local bits = { g.k == "r" and ("Kill this rare" .. (where and (" in " .. where) or "")) or "Enter this zone" }
			local did = g.k == "r" and "killed" or "visited"
			if not ns.Solo() then
			bits[#bits + 1] = n == 0 and "no one yet" or (n == 1 and (did .. " by 1 player") or (did .. " by " .. n .. " players"))
		end
			row.sub:SetText(table.concat(bits, "  /  "))
			row.reward:Set("+" .. ns.Points.Value("weekly"), T.Look().points)
		end,
	})
	left.week:SetPoint("TOPLEFT", 0, -66)
	left.post = W.Button(left, "Post an expedition", 170, 24, function()
		right.composing = true
		-- The form belongs with the expeditions, not the weekly hunt.
		if left.filter == "week" then
			left.filter = "exp"
			ns.Journal.RefreshSoon()
		end
		right.Draw()
	end)
	left.post:SetPoint("BOTTOMLEFT", 0, 4)
	left.who = T.Text(left, "", "Small", "subtle", PW - 180)
	left.who:SetPoint("BOTTOMRIGHT", 0, 8)
	left.who:SetJustifyH("RIGHT")

	-- Right page: one expedition ---------------------------------------------
	local view = CreateFrame("Frame", nil, right)
	view:SetAllPoints()
	right.view = view
	view.title = T.Text(view, "", "Huge", "heading", PW)
	view.title:SetPoint("TOPLEFT")
	view.title:SetWordWrap(false)
	view.sub = T.Text(view, "", "Small", "subtle", PW)
	view.sub:SetPoint("TOPLEFT", view.title, "BOTTOMLEFT", 0, -5)
	view.pays = T.Text(view, "", "Body", "points", PW)
	view.pays:SetPoint("TOPLEFT", view.sub, "BOTTOMLEFT", 0, -10)
	view.pays:SetSpacing(2)
	local gh = U.Heading(view, "Goals")
	gh:SetPoint("TOPLEFT", view.pays, "BOTTOMLEFT", 0, -16)
	view.goals = W.List(view, PW, 8 * 26, 26, {
		bare = true,
		build = function(row)
			row.tick = W.Tick(row, 14)
			row.tick:SetPoint("LEFT", 4, 0)
			row.text = T.Text(row, "", "Body", "text")
			row.text:SetPoint("LEFT", 26, 0)
			row.text:SetPoint("RIGHT", -90, 0)
			row.text:SetWordWrap(false)
			row.when = T.Text(row, "", "Small", "subtle")
			row.when:SetPoint("RIGHT", -6, 0)
		end,
		fill = function(row, g)
			local t = Wk.GoalDone(left.selected, g, ns.Me())
			row.tick:SetChecked(t ~= nil, T.Look().done)
			row.text:SetText(Wk.GoalName(g))
			row.when:SetText(t and T.Date(t) or "")
		end,
	})
	view.goals:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", 0, -6)
	local fh = U.Heading(view, "Finished by")
	fh:SetPoint("TOPLEFT", view.goals, "BOTTOMLEFT", 0, -10)
	view.done = W.List(view, PW, 4 * 26, 26, {
		bare = true,
		emptyText = "No one yet.",
		build = function(row)
			row.name = T.Text(row, "", "Body", "text")
			row.name:SetPoint("LEFT", 6, 0)
			row.when = T.Text(row, "", "Small", "subtle")
			row.when:SetPoint("RIGHT", -6, 0)
		end,
		fill = function(row, f, i)
			row.name:SetText(U.ClassName(f.who) .. (i == 1 and "  (first)" or ""))
			row.when:SetText(T.Date(f.t, true))
		end,
	})
	view.done:SetPoint("TOPLEFT", fh, "BOTTOMLEFT", 0, -6)
	view.withdraw = W.Button(view, "Withdraw", 110, 22, function()
		if left.selected then Wk.Withdraw(left.selected) end
	end)
	view.withdraw:SetPoint("BOTTOMRIGHT", 0, 0)
	view.blank = U.Note(view, PW, 170, "Interface\\Icons\\INV_Misc_Spyglass_03", "No expedition chosen",
		"Select one to see its goals and who has finished it.")
	view.blank:SetPoint("TOP", 0, -100)

	-- Right page: the officers' form -------------------------------------------
	local form = CreateFrame("Frame", nil, right)
	form:SetAllPoints()
	form:Hide()
	right.form = form
	local draft = { kind = "exp", goal = "z", reward = 50, days = 7, picks = {} }
	local fhd = U.Heading(form, "Post to the guild")
	fhd:SetPoint("TOPLEFT")
	form.name = W.Field(form, PW, "A name, like \"The Long Road South\"", 40)
	form.name:SetPoint("TOPLEFT", fhd, "BOTTOMLEFT", 0, -10)
	form.kind = W.Segments(form, function(k) draft.kind = k end)
	form.kind:Rebuild({ { key = "exp", label = "Expedition" }, { key = "bounty", label = "Bounty (first only)" } })
	form.kind:SetPoint("TOPLEFT", form.name, "BOTTOMLEFT", 0, -10)
	-- Picks are keyed by kind ("z1411", "f1412", "r61"), so one expedition can mix
	-- them: switching category only changes which list is shown.
	form.goal = W.Segments(form, function(k)
		draft.goal = k
		form.Fill()
	end)
	form.goal:Rebuild(GOAL_KINDS)
	form.goal:SetPoint("TOPLEFT", form.kind, "BOTTOMLEFT", 0, -8)
	form.search = W.Field(form, PW, "Search", 30, function() form.Fill() end)
	form.search:SetPoint("TOPLEFT", form.goal, "BOTTOMLEFT", 0, -8)
	form.pick = W.List(form, PW, 168, 24, {
		emptyText = "Nothing matches.",
		build = function(row)
			row.tick = W.Tick(row, 13)
			row.tick:SetPoint("LEFT", 6, 0)
			row.text = T.Text(row, "", "Small", "text")
			row.text:SetPoint("LEFT", 26, 0)
			row.text:SetPoint("RIGHT", -6, 0)
			row.text:SetWordWrap(false)
		end,
		fill = function(row, c)
			row.tick:SetChecked(draft.picks[c.key] ~= nil)
			row.text:SetText(c.label)
		end,
		onClick = function(c)
			local n = 0
			for _ in pairs(draft.picks) do n = n + 1 end
			if draft.picks[c.key] then
				draft.picks[c.key] = nil
			elseif n < MAX_GOALS then
				-- Remember the order goals were picked in; that's the order they're posted in.
				draft.seq = (draft.seq or 0) + 1
				draft.picks[c.key] = draft.seq
			end
			form.pick:Render()
			form.Count()
		end,
	})
	form.pick:SetPoint("TOPLEFT", form.search, "BOTTOMLEFT", 0, -6)
	form.count = T.Text(form, "", "Small", "subtle")
	form.count:SetPoint("TOPLEFT", form.pick, "BOTTOMLEFT", 0, -4)
	form.reward = W.Segments(form, function(k) draft.reward = k end)
	local rewards = {}
	for _, r in ipairs(REWARDS) do rewards[#rewards + 1] = { key = r, label = "+" .. r } end
	form.reward:Rebuild(rewards)
	form.reward:SetPoint("TOPLEFT", form.count, "BOTTOMLEFT", 0, -8)
	form.days = W.Segments(form, function(k) draft.days = k end)
	form.days:Rebuild(DURATIONS)
	form.days:SetPoint("TOPLEFT", form.reward, "BOTTOMLEFT", 0, -8)
	form.send = W.Button(form, "Post it", 110, 24, function()
		local goals = {}
		for k in pairs(draft.picks) do goals[#goals + 1] = k end
		table.sort(goals, function(a, b) return draft.picks[a] < draft.picks[b] end)
		local title = form.name:GetValue()
		if title == "" or #goals == 0 then
			ns.Print("give it a name and at least one goal.")
			return
		end
		local e = Wk.Post(title, draft.kind == "bounty", goals, draft.reward, draft.days > 0 and draft.days or nil)
		if e then
			ns.Print(("posted %s \"%s\" to the guild."):format(draft.kind == "bounty" and "a bounty," or "an expedition,", title))
			form.name:SetValue("")
			draft.picks = {}
			right.composing = false
			left.filter = draft.kind == "bounty" and "bounty" or "exp"
			left.selected = nil
			ns.Journal.RefreshSoon()
		end
	end)
	form.send:SetPoint("BOTTOMRIGHT", 0, 0)
	form.cancel = W.Button(form, "Cancel", 90, 24, function()
		right.composing = false
		right.Draw()
	end)
	form.cancel:SetPoint("RIGHT", form.send, "LEFT", -8, 0)

	-- What can be picked for each kind of goal.
	function form.Fill()
		local q = (form.search:GetValue() or ""):lower()
		local items = {}
		if draft.goal == "r" then
			for _, c in pairs(ns.Bestiary.Catalog()) do
				local zone = ns.MapName(c.zone) or ""
				local label = ("%s  (%s, level %s)"):format(c.name, zone, ns.Bestiary.LevelText(c) or "?")
				if q == "" or label:lower():find(q, 1, true) then items[#items + 1] = { key = "r" .. c.id, label = label } end
			end
		else
			for _, cont in ipairs(ns.Exploration.Atlas()) do
				for _, z in ipairs(cont.zones) do
					if not (draft.goal == "f" and z.total == 0) then
						local label = ("%s  (%s)"):format(z.name, cont.name)
						if q == "" or label:lower():find(q, 1, true) then items[#items + 1] = { key = draft.goal .. z.id, label = label } end
					end
				end
			end
		end
		table.sort(items, function(a, b) return a.label < b.label end)
		form.pick:SetItems(items)
		form.Count()
	end
	function form.Count()
		local n, by = 0, { z = 0, f = 0, r = 0 }
		for key in pairs(draft.picks) do
			n = n + 1
			local k = key:sub(1, 1)
			by[k] = (by[k] or 0) + 1
		end
		local text = ("%d of up to %d goals chosen"):format(n, MAX_GOALS)
		-- Once more than one kind is picked, say which, since only one list shows at a time.
		local parts, kinds = {}, 0
		for _, g in ipairs(GOAL_KINDS) do
			if by[g.key] > 0 then kinds = kinds + 1; parts[#parts + 1] = ("%s %d"):format(g.label:lower(), by[g.key]) end
		end
		if kinds > 1 then text = text .. ": " .. table.concat(parts, ", ") end
		form.count:SetText(text)
	end
	form:SetScript("OnShow", function()
		form.kind:Select(draft.kind)
		form.goal:Select(draft.goal)
		form.reward:Select(draft.reward)
		form.days:Select(draft.days)
		form.Fill()
	end)

	-- Right page: the weekly hunt.
	local weekly = CreateFrame("Frame", nil, right)
	weekly:SetAllPoints()
	weekly:Hide()
	weekly.title = T.Text(weekly, "This week's hunt", "Huge", "heading", PW)
	weekly.title:SetPoint("TOPLEFT")
	weekly.sub = T.Text(weekly, "", "Small", "subtle", PW)
	weekly.sub:SetPoint("TOPLEFT", weekly.title, "BOTTOMLEFT", 0, -5)
	weekly.pays = T.Text(weekly, "", "Body", "points", PW)
	weekly.pays:SetPoint("TOPLEFT", weekly.sub, "BOTTOMLEFT", 0, -10)
	weekly.pays:SetSpacing(2)
	weekly.how = T.Text(weekly, "Each level band gets its own hunt every week: three rares and two zones for those levels, "
		.. "outside the other faction's starting zones. Kill the rares and enter the zones before the week ends. "
		.. "They count even if you've done them before. Your band is set by your level at the start of the week, "
		.. "and you get one hunt a week across all your characters.", "Small", "subtle", PW)
	weekly.how:SetPoint("TOPLEFT", weekly.pays, "BOTTOMLEFT", 0, -10)
	weekly.how:SetSpacing(2)
	weekly.levels = T.Text(weekly, "", "Small", "text", PW)
	weekly.levels:SetPoint("TOPLEFT", weekly.how, "BOTTOMLEFT", 0, -10)
	weekly.levels:SetSpacing(2)
	local wh = U.Heading(weekly, "Progress this week")
	wh:SetPoint("TOPLEFT", weekly.levels, "BOTTOMLEFT", 0, -16)
	weekly.list = W.List(weekly, PW, 5 * 30, 30, {
		bare = true,
		emptyText = "No one has done any of this week's targets yet.",
		build = function(row)
			row.name = T.Text(row, "", "Body", "text")
			row.name:SetPoint("LEFT", 6, 0)
			row.dots = W.Dots(row, 7, 4, 5)
			row.dots:SetPoint("RIGHT", -10, 0)
		end,
		fill = function(row, r)
			local band = Wk.BANDS[r.band]
			row.name:SetText(ns.ShortName(r.who) .. (band and ("  |cff%s%s|r"):format(T.Hex(T.Look().subtle), band.label) or "")
				.. (r.n >= r.total and "  |cff" .. T.Hex(T.Look().done) .. "(all five)|r" or ""))
			row.dots:SetProgress(r.n, r.total, r.n >= r.total)
		end,
	})
	weekly.list:SetPoint("TOPLEFT", wh, "BOTTOMLEFT", 0, -6)

	function right.Draw()
		local officer = Wk.AmOfficer()
		local isWeek = left.filter == "week"
		weekly:SetShown(isWeek)
		if isWeek then
			form:Hide()
			view:Hide()
			local left_ = ns.Points.WeekStart() + 7 * 86400 - ns.Now()
			local d = math.floor(left_ / 86400)
			local ends = d >= 1 and ("ends in %d day%s"):format(d, d == 1 and "" or "s")
				or ("ends in %d hours"):format(math.max(1, math.floor(left_ / 3600)))
			local band, mine = Wk.BANDS[left.band or 1], Wk.BANDS[left.myBand or 1]
			if left.band == left.myBand then
				weekly.sub:SetText(("Your hunt: levels %s  /  %s"):format(band.label, ends))
			else
				weekly.sub:SetText(("Levels %s (yours this week is %s)  /  %s"):format(band.label, mine.label, ends))
			end
			-- How the guild's characters spread over the bands.
			local bits = {}
			for i, b in ipairs(Wk.BANDS) do
				local n = left.bandCounts and left.bandCounts[i] or 0
				bits[#bits + 1] = ("|cff%s%s|r %d"):format(T.Hex(T.Look().subtle), b.label, n)
			end
			weekly.levels:SetText((ns.Solo() and "Your characters by level:   " or "Guild characters by level:   ")
				.. table.concat(bits, "    "))
			weekly.pays:SetText(("+%d points for each target, and +%d more for all five."):format(
				ns.Points.Value("weekly"), ns.Points.Value("weeklyall")))
			weekly.list:SetItems(left.hunters or {})
			return
		end
		local composing = right.composing and officer
		form:SetShown(composing and true or false)
		view:SetShown(not composing)
		if composing then return end
		local x = left.selected
		for _, p in ipairs({ view.title, view.sub, view.pays, gh, view.goals, fh, view.done }) do p:SetShown(x ~= nil) end
		view.blank:SetShown(x == nil)
		view.withdraw:SetShown(x ~= nil and officer and Wk.IsOpen(x))
		if not x then return end
		view.title:SetText(x.title)
		view.sub:SetText(("%s posted by %s, %s  /  %s"):format(x.bounty and "Bounty" or "Expedition",
			ns.ShortName(x.by), T.Date(x.t, true), endsText(x)))
		view.pays:SetText(x.bounty and ("+%d points to the first to claim it."):format(x.reward)
			or ("+%d points to everyone who completes it, and +%d more to the first."):format(x.reward, math.floor(x.reward / 2)))
		view.goals:SetItems(x.goals)
		view.done:SetItems(Wk.Finishers(x))
	end
end

local function refresh(left, right)
	local all = Wk.Expeditions()
	local items = {}
	for _, x in ipairs(all) do
		local open = Wk.IsOpen(x)
		if (left.filter == "past" and not open) or (left.filter == "exp" and open and not x.bounty)
			or (left.filter == "bounty" and open and x.bounty) then
			items[#items + 1] = x
		end
	end
	-- Solo: the weekly hunt is the whole page (expeditions come from officers).
	local solo = ns.Solo()
	if solo then
		left.filter = "week"
		right.composing = false
	end
	left.segments:SetShown(not solo)
	left.bands:ClearAllPoints()
	left.bands:SetPoint("TOPLEFT", 0, solo and 0 or -34)
	left.week:ClearAllPoints()
	left.week:SetPoint("TOPLEFT", 0, solo and -32 or -66)
	left.segments:Select(left.filter)
	left.list:SetItems(items, true)

	-- This week's hunt: your hits, and how many players have found each target.
	local isWeek = left.filter == "week"
	left.week:SetShown(isWeek)
	left.bands:SetShown(isWeek)
	left.list:SetShown(not isWeek)
	if isWeek then
		local P = ns.Points
		local ws = P.WeekStart()
		local members = U.Members()
		local myBand = Wk.MyBand(ws)
		if left.myBand ~= myBand or left.bandsWeek ~= ws then
			-- A new week, or a new band: open yours.
			left.myBand, left.band, left.bandsWeek = myBand, myBand, ws
		end
		local items = {}
		for i, b in ipairs(Wk.BANDS) do items[i] = { key = i, label = i == myBand and (b.label .. " (you)") or b.label } end
		left.bands:Rebuild(items)
		left.bands:Select(left.band)
		left.bandCounts = Wk.BandCounts(members)

		local targets = Wk.Weekly(ws, left.band)
		local me = ns.Me()
		left.hits = me and Wk.WeeklyHits(P.Player(me), ws) or {}
		left.found, left.hunters = {}, {}
		local players = {}
		for who in pairs(members) do players[P.Player(who)] = true end
		for player in pairs(players) do
			local w = Wk.Hunts(player)[ws]
			if w and w.n > 0 then
				if w.band == left.band then
					for _, g in ipairs(targets) do
						if w.hits[g.key] then left.found[g.key] = (left.found[g.key] or 0) + 1 end
					end
				end
				left.hunters[#left.hunters + 1] = { who = player, n = w.n, band = w.band,
					total = #Wk.Weekly(ws, w.band) }
			end
		end
		table.sort(left.hunters, function(a, b)
			if a.n ~= b.n then return a.n > b.n end
			return a.who < b.who
		end)
		left.week:SetItems(targets, true)
	end
	if left.selected then
		local keep
		for _, x in ipairs(items) do
			if x.id == left.selected.id then keep = x end
		end
		left.selected = keep
	end
	left.selected = left.selected or items[1]
	local officer = Wk.AmOfficer() and not solo
	left.post:SetShown(officer)
	left.who:SetShown(not solo)
	if Wk.Preview() then
		left.who:SetText(("|cff%sOfficer preview: posts aren't sent to the guild.|r"):format(T.Hex(T.Look().points)))
	elseif officer then
		left.who:SetText("You can post as an officer.")
	else
		left.who:SetText(ns.Guild.InGuild() and "Your guild's officers post expeditions and bounties." or "Expeditions come from your guild's officers.")
	end
	left.list:Render()
	right.Draw()
end

ns.Journal.Register({
	id = "expeditions",
	order = 4,
	title = "Expeditions",
	info = "Weekly hunts and officer challenges. Only progress made after a challenge is posted counts.",
	soloTitle = "Weekly hunt",
	soloInfo = "A new hunt every week: rares to kill and zones to enter, picked for your level.",
	icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
	build = build,
	refresh = refresh,
})
