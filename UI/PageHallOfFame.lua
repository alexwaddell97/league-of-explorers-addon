-- Hall of Fame: your points this week, this month and for all time, your
-- points by deed, your characters ranked, and the scale of rewards.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets

local function build(c)
	local CW, CH = ns.Journal.CW, ns.Journal.CH
	local tw = math.floor((CW - 24) / 3)
	c.week = W.Tile(c, "This week", tw, 84)
	c.week:SetPoint("TOPLEFT")
	c.month = W.Tile(c, "This month", tw, 84)
	c.month:SetPoint("TOPLEFT", tw + 12, 0)
	c.life = W.Tile(c, "All time", tw, 84)
	c.life:SetPoint("TOPRIGHT")
	for _, t in ipairs({ c.week, c.month, c.life }) do T.SetRole(t.value, "points") end

	local half = math.floor((CW - 12) / 2)
	local left = W.Panel(c)
	left:SetPoint("TOPLEFT", 0, -96)
	left:SetSize(half, CH - 96)
	local lw = half - 28
	local deeds = W.Label(left, "By deed")
	deeds:SetPoint("TOPLEFT", 14, -14)
	c.deeds = {}
	local prev = deeds
	for _, k in ipairs(ns.Points.KINDS) do
		if k.live then
			local s = W.Stat(left, k.label, lw)
			s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, prev == deeds and -10 or -1)
			c.deeds[k.kind] = s
			prev = s
		end
	end
	local chars = W.Label(left, "Your characters")
	chars:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -16)
	c.chars = W.List(left, lw + 8, 84, 26, {
		bare = true,
		build = function(row)
			row.rank = T.Text(row, "", "Header", "subtle")
			row.rank:SetPoint("LEFT", 4, 0)
			row.rank:SetWidth(24)
			row.name = T.Text(row, "", "Body", "text")
			row.name:SetPoint("LEFT", 30, 0)
			row.name:SetPoint("RIGHT", -80, 0)
			row.name:SetWordWrap(false)
			row.pts = T.Text(row, "", "Header", "points")
			row.pts:SetPoint("RIGHT", -6, 0)
			row.pts:SetJustifyH("RIGHT")
		end,
		fill = function(row, ch, i)
			row.rank:SetText(i .. ".")
			local name = ns.ShortName(ch.who)
			local col = ch.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[ch.class]
			if col then name = ("|cff%s%s|r"):format(T.Hex({ col.r, col.g, col.b }), name) end
			row.name:SetText(name)
			row.pts:SetText(T.Number(ch.points))
		end,
	})
	c.chars:SetPoint("TOPLEFT", chars, "BOTTOMLEFT", -4, -6)

	local right = W.Panel(c)
	right:SetPoint("TOPRIGHT", 0, -96)
	right:SetSize(CW - half - 12, CH - 96)
	local rw = CW - half - 12 - 28
	local scale = W.Label(right, "Scale of rewards")
	scale:SetPoint("TOPLEFT", 14, -14)
	c.scale = {}
	prev = scale
	for _, k in ipairs(ns.Points.KINDS) do
		if k.points > 0 then
			local s = W.Stat(right, k.label, rw)
			s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, prev == scale and -10 or -3)
			T.SetRole(s.label, k.live and "text" or "subtle")
			s.value:Hide()
			s.chip = W.Chip(s)
			s.chip:SetPoint("RIGHT")
			s.live = k.live
			c.scale[k.kind] = s
			prev = s
		end
	end
	local note = T.Text(right, "Each deed pays once per character. Exploration from before the journal was begun is written in without points. Greyed deeds arrive with guild sync and expeditions.", "Small", "subtle", rw)
	note:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
	note:SetSpacing(3)
end

local function refresh(c)
	local me = ns.Me()
	if not me then return end
	local P = ns.Points
	c.week.value:SetText(T.Number(P.Total(me, P.WeekStart())))
	c.week.note:SetText("since Monday")
	c.month.value:SetText(T.Number(P.Total(me, P.MonthStart())))
	c.month.note:SetText(date("!%B", ns.Now()))
	c.life.value:SetText(T.Number(P.Total(me)))
	c.life.note:SetText(("%d entries"):format(#ns.Ledger.Query({ who = me })))

	local look = T.Look()
	local b = P.Breakdown(me)
	for kind, s in pairs(c.deeds) do
		local d = b[kind]
		if not d then
			s.value:SetText("-")
			T.SetRole(s.value, "subtle")
		elseif P.Value(kind) > 0 then
			s.value:SetText(("%d   |cff%s+%s|r"):format(d.count, T.Hex(look.points), T.Number(d.points)))
			T.SetRole(s.value, "text")
		else
			s.value:SetText(d.count)
			T.SetRole(s.value, "text")
		end
	end
	for kind, s in pairs(c.scale) do
		s.chip:Set("+" .. P.Value(kind), s.live and look.points or look.subtle)
	end

	local list = {}
	for who, ch in pairs(ns.db.chars) do
		list[#list + 1] = { who = who, class = ch.class, points = P.Total(who) }
	end
	table.sort(list, function(x, y)
		if x.points ~= y.points then return x.points > y.points end
		return x.who < y.who
	end)
	c.chars:SetItems(list)
end

-- The map: where you stand, with your name and points over it.
local function banner()
	local me, ch = ns.Me(), ns.Char()
	local zone, focus = W.PlayerFocus()
	return {
		map = zone, focus = focus, pin = true, live = true,
		kicker = "Hall of Fame",
		title = me and ns.ShortName(me) or "",
		sub = ("Level %d %s %s%s"):format(UnitLevel("player") or 0, UnitRace("player") or "", UnitClass("player") or "",
			ch and ch.baselineAt and ("  /  journal begun " .. T.Date(ch.baselineAt, true)) or ""),
		big = me and T.Number(ns.Points.Total(me)) or "0",
		bigLabel = "points",
		bigRole = "points",
	}
end

ns.Journal.Register({
	id = "halloffame",
	order = 5,
	title = "Hall of Fame",
	icon = "Interface\\Icons\\INV_Crown_01",
	build = build,
	refresh = refresh,
	banner = banner,
})
