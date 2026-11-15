-- Submissions: something the journal doesn't know (a hidden spot, a fine
-- view, an inn) sent to the officers. The left page is the form and your
-- own submissions; the right page is the officers' review list and the
-- guild's approved discoveries, each of which can be marked on the map.

local _, ns = ...

local T, W, U = ns.Theme, ns.Widgets, ns.UI
local Wk = ns.Work

local STATUS = {
	pending = { "Waiting for review", "subtle" },
	approved = { "Approved", "done" },
	declined = { "Declined", "points" },
}

local function whereText(map, x, y)
	if not map then return "Somewhere unknown" end
	local s = ns.MapName(map) or "?"
	if x and y then s = s .. "  " .. T.Coords(x, y) end
	return s
end

local function mark(s)
	if not (s.map and s.x and C_Map.SetUserWaypoint and UiMapPoint) then return end
	local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(s.map, s.x / 100, s.y / 100))
	if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
	end
	ns.Print(ok and ("marked " .. s.title .. " on your map.") or "this map can't take a marker.")
end

local function build(left, right)
	local PW, PH = ns.Journal.PW, ns.Journal.PH
	local LH = PH - ns.Journal.HEAD

	-- Left page: the form --------------------------------------------------------
	local nl = W.Label(left, "Name")
	nl:SetPoint("TOPLEFT")
	left.name = W.Field(left, PW, "A name, like \"The Hidden Falls\"", 40, function() left.Check() end)
	left.name:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", 0, -6)
	local wl = W.Label(left, "Description")
	wl:SetPoint("TOPLEFT", left.name, "BOTTOMLEFT", 0, -12)
	left.why = W.Notes(left, PW, 64, "How to get there and what's there", function() end)
	left.why:SetPoint("TOPLEFT", wl, "BOTTOMLEFT", 0, -6)
	left.why.edit:SetMaxLetters(70)
	local hl = W.Label(left, "Where")
	hl:SetPoint("TOPLEFT", left.why, "BOTTOMLEFT", 0, -12)
	left.here = T.Text(left, "", "Body", "text", PW)
	left.here:SetPoint("TOPLEFT", hl, "BOTTOMLEFT", 0, -6)
	left.send = W.Button(left, "Send to the officers", 160, 24, function()
		local title = left.name:GetValue()
		if title == "" then return end
		if Wk.Submit(title, left.why.edit:GetText()) then
			ns.Print(("sent \"%s\" to the officers."):format(title))
			left.name:SetValue("")
			left.why:SetText("")
			left.Check()
		end
	end)
	-- On its own line under where you stand, at the right.
	left.send:SetPoint("TOPRIGHT", left.here, "BOTTOMRIGHT", 0, -10)
	function left.Check() left.send:SetEnabled(left.name:GetValue() ~= "" and ns.Guild.InGuild()) end

	local yl = U.Heading(left, "Your submissions")
	yl:SetPoint("TOPLEFT", left.here, "BOTTOMLEFT", 0, -50)
	left.mine = W.List(left, PW, LH - 264, 40, {
		emptyText = "Nothing sent yet.",
		emptyIcon = "Interface\\Icons\\INV_Letter_15",
		build = function(row)
			row.title = T.Text(row, "", "Header", "text")
			row.title:SetPoint("TOPLEFT", 8, -5)
			row.title:SetPoint("RIGHT", -10, 0)
			row.title:SetWordWrap(false)
			row.status = T.Text(row, "", "Small", "subtle")
			row.status:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
			row.status:SetPoint("RIGHT", -10, 0)
			row.status:SetWordWrap(false)
		end,
		fill = function(row, s)
			row.title:SetText(s.title)
			local st = STATUS[s.status] or STATUS.pending
			local text = st[1]
			if s.status == "approved" then text = text .. (" by %s  /  +%d points"):format(ns.ShortName(s.reviewer), ns.Points.Value("secret")) end
			if s.status == "declined" then text = text .. " by " .. ns.ShortName(s.reviewer) end
			row.status:SetText(text .. "  /  " .. whereText(s.map, s.x, s.y))
			T.SetRole(row.status, st[2])
		end,
		onClick = mark,
	})
	left.mine:SetPoint("TOPLEFT", yl, "BOTTOMLEFT", 0, -8)

	-- Right page: review, and the guild's approved finds -------------------------
	right.reviewHead = U.Heading(right, "Waiting for review")
	right.reviewHead:SetPoint("TOPLEFT")
	right.review = W.List(right, PW, 200, 64, {
		emptyText = "No submissions to review.",
		emptyIcon = "Interface\\Icons\\INV_Letter_15",
		build = function(row)
			row.title = T.Text(row, "", "Header", "heading")
			row.title:SetPoint("TOPLEFT", 8, -5)
			row.title:SetPoint("RIGHT", -150, 0)
			row.title:SetWordWrap(false)
			row.by = T.Text(row, "", "Label", "subtle")
			row.by:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
			row.by:SetPoint("RIGHT", -150, 0)
			row.by:SetWordWrap(false)
			row.note = T.Text(row, "", "Small", "text")
			row.note:SetPoint("TOPLEFT", row.by, "BOTTOMLEFT", 0, -3)
			row.note:SetPoint("RIGHT", -150, 0)
			row.note:SetWordWrap(false)
			row.yes = W.Button(row, "Approve", 70, 22, function() if row.item then Wk.Review(row.item, true) end end)
			row.yes:SetPoint("RIGHT", -6, 0)
			row.no = W.Button(row, "Decline", 66, 22, function() if row.item then Wk.Review(row.item, false) end end)
			row.no:SetPoint("RIGHT", row.yes, "LEFT", -4, 0)
		end,
		fill = function(row, s)
			row.title:SetText(s.title)
			row.by:SetText(("%s  /  %s  /  %s"):format(ns.ShortName(s.who), whereText(s.map, s.x, s.y), U.Ago(s.t)))
			row.note:SetText(s.note or "")
			local own = s.who == ns.Me() and not Wk.Preview() -- preview lets you try it on your own
			row.yes:SetEnabled(not own)
			row.no:SetEnabled(not own)
		end,
		onClick = mark,
	})
	right.review:SetPoint("TOPLEFT", right.reviewHead, "BOTTOMLEFT", 0, -8)

	right.preview = T.Text(right, "", "Small", "points", PW)
	right.preview:SetPoint("BOTTOMLEFT", 0, 0)
	right.preview:SetText("Officer preview: reviews and submissions aren't sent to the guild, and are deleted when preview is turned off.")

	right.approvedHead = U.Heading(right, "Guild places")
	-- Built at its tallest so it has rows enough; refresh shortens it for officers.
	right.approved = W.List(right, PW, PH - 32, 40, {
		emptyText = "No places approved yet.",
		emptyIcon = "Interface\\Icons\\INV_Misc_Map_01",
		build = function(row)
			row.title = T.Text(row, "", "Header", "text")
			row.title:SetPoint("TOPLEFT", 8, -5)
			row.title:SetPoint("RIGHT", -10, 0)
			row.title:SetWordWrap(false)
			row.by = T.Text(row, "", "Small", "subtle")
			row.by:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
			row.by:SetPoint("RIGHT", -10, 0)
			row.by:SetWordWrap(false)
		end,
		fill = function(row, s)
			row.title:SetText(s.title)
			-- Have you stood there yet? (Any of your characters.)
			local me = ns.Me()
			local been, yours = false, false
			if me then
				local player = ns.Points.Player(me)
				yours = ns.Points.Player(s.who) == player
				for _, e in ipairs(ns.Points.Deeds(player)) do
					if e.kind == "place" and e.key == s.id then been = true end
				end
			end
			local look = T.Look()
			local status = yours and "your find"
				or (been and ("|cff%svisited|r"):format(T.Hex(look.done))
				or ("|cff%s+%d for visiting|r"):format(T.Hex(look.points), ns.Points.Value("place")))
			row.by:SetText(("by %s  /  %s  /  %s"):format(ns.ShortName(s.who), whereText(s.map, s.x, s.y), status))
		end,
		onClick = mark,
	})
end

local function refresh(left, right)
	local PH = ns.Journal.PH
	local map = C_Map.GetBestMapForUnit("player")
	local zone = map and (ns.Exploration.ZoneOf(map) or map)
	local x, y
	local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
	if pos then
		x, y = pos:GetXY()
		if x and y then x, y = x * 100, y * 100 end
	end
	left.here:SetText(whereText(zone, x, y) .. ", where you stand")
	left.Check()

	local me, members = ns.Me(), U.Members()
	local mine, waiting, approved = {}, {}, {}
	for _, s in ipairs(Wk.Submissions()) do
		if s.who == me then mine[#mine + 1] = s end
		if members[s.who] then
			if s.status == "pending" then waiting[#waiting + 1] = s end
			if s.status == "approved" then approved[#approved + 1] = s end
		end
	end
	left.mine:SetItems(mine, true)

	-- Officers see the review list; everyone else gets the whole page for
	-- the guild's discoveries.
	local officer = Wk.AmOfficer()
	right.preview:SetShown(Wk.Preview())
	right.reviewHead:SetShown(officer)
	right.review:SetShown(officer)
	right.approvedHead:ClearAllPoints()
	if officer then
		right.review:SetItems(waiting, true)
		right.approvedHead:SetPoint("TOPLEFT", right.review, "BOTTOMLEFT", 0, -16)
		right.approved:SetHeight(PH - 200 - 64 - (Wk.Preview() and 30 or 0))
	else
		right.approvedHead:SetPoint("TOPLEFT")
		right.approved:SetHeight(PH - 32)
	end
	right.approved:ClearAllPoints()
	right.approved:SetPoint("TOPLEFT", right.approvedHead, "BOTTOMLEFT", 0, -8)
	right.approved:SetItems(approved, true)
end

ns.Journal.Register({
	id = "submissions",
	guild = true,
	order = 6,
	title = "Submissions",
	info = "Suggest a place worth visiting, like a hidden spot or a good view. Approved places earn points.",
	icon = "Interface\\Icons\\INV_Letter_15",
	build = build,
	refresh = refresh,
})
