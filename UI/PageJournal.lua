-- Journal: the map shows where you stand; below it your figures at a
-- glance, your points, the zone nearest to fully explored, and the
-- timeline of what you have found.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets

-- Icons for each kind of entry, shared with other pages and the toasts.
ns.KIND_ICON = {
	zone = "Interface\\Icons\\INV_Misc_Map_01",
	zonefull = "Interface\\Icons\\INV_Misc_Map02",
	continent = "Interface\\Icons\\INV_Misc_Spyglass_02",
	area = "Interface\\Icons\\INV_Misc_Note_02",
	rare = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	treasure = "Interface\\Icons\\INV_Misc_TreasureChest01b",
}

local function countKeys(t)
	local n = 0
	for _ in pairs(t or {}) do n = n + 1 end
	return n
end

local function build(c)
	local CW, CH = ns.Journal.CW, ns.Journal.CH
	local tw = math.floor((CW - 36) / 4)
	local ROW2, SIDE_W = 96, 300  -- second row: 84-tall tiles plus the 12 gap
	local half = math.floor((CH - ROW2 - 12) / 2)
	local function tile(i, label, icon, withBar)
		local t = W.Tile(c, label, tw, 84, icon)
		t:SetPoint("TOPLEFT", (i - 1) * (tw + 12), 0)
		if withBar then
			t.bar = W.Bar(t, tw - 28, 2)
			t.bar:SetPoint("BOTTOMLEFT", 14, 10)
		end
		return t
	end
	c.zones = tile(1, "Zones discovered", ns.KIND_ICON.zone, true)
	c.areas = tile(2, "Areas charted", ns.KIND_ICON.area, true)
	c.rares = tile(3, "Rares found", ns.KIND_ICON.rare)
	c.treasures = tile(4, "Treasures found", ns.KIND_ICON.treasure)

	-- Timeline, in a panel level with the two on the right.
	local listW = CW - SIDE_W - 12
	local tl = W.Panel(c)
	tl:SetPoint("TOPLEFT", 0, -ROW2)
	tl:SetSize(listW, CH - ROW2)
	local tlLabel = W.Label(tl, "Recent discoveries")
	tlLabel:SetPoint("TOPLEFT", 14, -14)
	c.list = W.List(tl, listW, CH - ROW2 - 38, 30, {
		bare = true,
		stripes = false,
		emptyText = "Nothing written yet. Every zone, area, rare and treasure you find from now on appears here.",
		build = W.TimelineBuild,
		fill = function(row, e, i, last)
			local p = ns.Points.Of(e)
			W.TimelineFill(row, e.kind, T.Date(e.t), ns.Ledger.Describe(e), p > 0 and ("+" .. p) or "", i == 1, last)
			T.SetRole(row.text, e.kind == "area" and "subtle" or "text")
		end,
	})
	c.list:SetPoint("TOPLEFT", 0, -32)

	-- Points
	local pts = W.Panel(c)
	pts:SetSize(SIDE_W, half)
	pts:SetPoint("TOPRIGHT", 0, -ROW2)
	local pl = W.Label(pts, "Points")
	pl:SetPoint("TOPLEFT", 14, -14)
	c.total = T.Text(pts, "0", "Display", "points")
	c.total:SetPoint("TOPLEFT", pl, "BOTTOMLEFT", 0, -6)
	c.week = W.Stat(pts, "This week", 272)
	c.week:SetPoint("TOPLEFT", c.total, "BOTTOMLEFT", 0, -8)
	c.month = W.Stat(pts, "This month", 272)
	c.month:SetPoint("TOPLEFT", c.week, "BOTTOMLEFT", 0, 0)

	-- Nearest to fully explored
	local near = W.Panel(c)
	near:SetSize(SIDE_W, CH - ROW2 - 12 - half)
	near:SetPoint("TOPRIGHT", pts, "BOTTOMRIGHT", 0, -12)
	local nl = W.Label(near, "Nearest to fully explored")
	nl:SetPoint("TOPLEFT", 14, -14)
	c.nearName = T.Text(near, "", "Title", "heading", 272)
	c.nearName:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", 0, -8)
	c.nearName:SetWordWrap(false)
	c.nearDots = W.Dots(near, 7, 4, 24)
	c.nearDots:SetPoint("TOPLEFT", c.nearName, "BOTTOMLEFT", 0, -10)
	c.nearNote = T.Text(near, "", "Small", "subtle", 272)
	c.nearNote:SetPoint("TOPLEFT", c.nearDots, "BOTTOMLEFT", 0, -10)
	c.nearNote:SetSpacing(2)
end

local function refresh(c)
	local me, ch = ns.Me(), ns.Char()
	if not (me and ch) then return end
	local P, E = ns.Points, ns.Exploration

	local discovered, best, bestP = 0, nil, nil
	for id, z in pairs(ch.zones) do
		if z.seen or z.base then discovered = discovered + 1 end
		if not z.full and (z.total or 0) > 0 and (z.explored or 0) > 0 then
			local p = z.explored / z.total
			if not bestP or p > bestP then best, bestP = id, p end
		end
	end
	local zoneCount, areaCount, areas = E.ZoneCount(), E.AreaCount(), countKeys(ch.areas)
	c.zones.value:SetText(discovered)
	c.zones.note:SetText("of " .. zoneCount)
	c.zones.bar:SetProgress(discovered, zoneCount, discovered >= zoneCount)
	c.areas.value:SetText(areas)
	c.areas.note:SetText("of " .. areaCount)
	c.areas.bar:SetProgress(areas, areaCount, areas >= areaCount)
	c.rares.value:SetText(#ns.Ledger.Query({ who = me, kind = "rare" }))
	c.treasures.value:SetText(#ns.Ledger.Query({ who = me, kind = "treasure" }))

	c.total:SetText(T.Number(P.Total(me)))
	c.week.value:SetText(T.Number(P.Total(me, P.WeekStart())))
	c.month.value:SetText(T.Number(P.Total(me, P.MonthStart())))

	if best then
		local z = ch.zones[best]
		c.nearName:SetText(ns.MapName(best) or "?")
		c.nearDots:Show()
		c.nearDots:SetProgress(z.explored, z.total)
		c.nearNote:SetText(("%d of %d areas charted. %d more for +%d."):format(
			z.explored, z.total, z.total - z.explored, P.Value("zonefull")))
	else
		c.nearName:SetText("-")
		c.nearDots:Hide()
		c.nearNote:SetText("Chart an area of any zone to see how close you are.")
	end

	c.list:SetItems(ns.Ledger.Query({ who = me, limit = 300 }), true)
end

-- The map: where you are, with a pin on you.
local function banner()
	local zone, focus = W.PlayerFocus()
	local b = { map = zone, focus = focus, pin = true, live = true, kicker = "You are in" }
	if not zone then
		b.title = GetZoneText and GetZoneText() or ""
		return b
	end
	b.title = ns.MapName(zone) or ""
	local n, total = ns.Exploration.Progress(zone)
	local cont = ns.Exploration.ContinentOf(zone)
	local rec = ns.Char() and ns.Char().zones[zone]
	local done = rec and rec.full and true or false
	if total > 0 then
		b.sub = ("%s%d of %d areas charted"):format(cont and (ns.MapName(cont) .. "  /  ") or "", n, total)
		b.dots = { n, total, done }
		b.big = math.floor(n / total * 100 + 0.5) .. "%"
		b.bigLabel = done and "fully explored" or "explored"
		b.bigRole = done and "done" or "accent"
	else
		b.sub = cont and ns.MapName(cont) or ""
	end
	return b
end

ns.Journal.Register({
	id = "journal",
	order = 1,
	title = "Journal",
	icon = "Interface\\Icons\\INV_Misc_Book_09",
	build = build,
	refresh = refresh,
	banner = banner,
})
