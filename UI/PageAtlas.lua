-- Atlas: every zone of a continent with a trail of dots for its areas; the
-- map above shows the zone you pick, painted with what you have explored.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets

local LIST_W = 340

local function zoneState(ch, zoneID)
	local rec = ch.zones[zoneID]
	local E = ns.Exploration
	local n, total
	if zoneID == E.CurrentZone() then
		n, total = E.Progress(zoneID)
	else
		n, total = rec and rec.explored or 0, ns.Areas[zoneID] and #ns.Areas[zoneID] or 0
	end
	local known = rec and (rec.seen or rec.base) and true or false
	return known, n, total, rec
end

local function pct(n, total)
	if total <= 0 then return 0 end
	return math.floor(n / total * 100 + 0.5)
end

local function build(c)
	local CW, CH = ns.Journal.CW, ns.Journal.CH
	c.segments = W.Segments(c, function(key) c.ShowContinent(key) end)
	c.segments:SetPoint("TOPLEFT")
	c.summary = T.Text(c, "", "Small", "subtle")
	c.summary:SetPoint("RIGHT", c, "TOPRIGHT", 0, -12)
	c.summary:SetJustifyH("RIGHT")

	c.list = W.List(c, LIST_W, CH - 36, 40, {
		emptyText = "The atlas is still being drawn.",
		emptyIcon = ns.KIND_ICON.zone,
		build = function(row)
			row.name = T.Text(row, "", "Header", "text")
			row.name:SetPoint("TOPLEFT", 8, -6)
			row.name:SetPoint("RIGHT", -60, 0)
			row.name:SetWordWrap(false)
			row.dots = W.Dots(row, 5, 3, 30)
			row.dots:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -7)
			row.note = T.Text(row, "", "Small", "subtle")
			row.note:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
			row.pct = T.Text(row, "", "Title", "accent")
			row.pct:SetPoint("RIGHT", -8, 0)
			row.pct:SetJustifyH("RIGHT")
		end,
		fill = function(row, z)
			local known, n, total, rec = zoneState(c.ch, z.id)
			row.name:SetText(z.name)
			T.SetRole(row.name, known and "text" or "subtle")
			local done = rec and rec.full and true or false
			if known and total > 0 then
				row.note:SetText("")
				row.dots:Show()
				row.dots:SetProgress(n, total, done)
				row.pct:SetText(pct(n, total) .. "%")
				T.SetRole(row.pct, done and "done" or "accent")
			else
				row.dots:Hide()
				row.note:SetText(known and "Visited" or "Uncharted")
				row.pct:SetText("")
			end
		end,
		onClick = function(z)
			c.zone = z.id
			c.list:Render()
			c.ShowZone()
			ns.Journal.UpdateBanner()
		end,
		isSelected = function(z) return z.id == c.zone end,
	})
	c.list:SetPoint("TOPLEFT", 0, -36)

	-- The zone's record -------------------------------------------------------
	local d = W.Panel(c)
	d:SetPoint("TOPRIGHT", 0, -36)
	local DW = CW - LIST_W - 12
	d:SetSize(DW, CH - 36)
	local colW = math.floor((DW - 28 - 16) / 2)

	local rl = W.Label(d, "Zone record")
	rl:SetPoint("TOPLEFT", 14, -14)
	c.rows = {}
	local prev = rl
	for i, label in ipairs({ "Areas charted", "Discovered", "Fully explored", "Points earned here" }) do
		local s = W.Stat(d, label, colW)
		s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -10 or -4)
		local rule = W.Divider(d)
		rule:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
		rule:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
		c.rows[i] = s
		prev = s
	end

	local sl = W.Label(d, "Seen here")
	sl:SetPoint("TOPLEFT", 14 + colW + 16, -14)
	c.seenText = T.Text(d, "", "Body", "text", colW)
	c.seenText:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 0, -10)
	c.seenText:SetHeight(104)
	c.seenText:SetJustifyV("TOP")
	c.seenText:SetSpacing(4)

	local al = W.Label(d, "Charted areas")
	al:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -24)
	c.areasText = T.Text(d, "", "Body", "text", DW - 28)
	c.areasText:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -10)
	c.areasText:SetHeight(140)
	c.areasText:SetJustifyV("TOP")
	c.areasText:SetSpacing(4)

	function c.ShowZone()
		local zoneID = c.zone
		if not zoneID then return end
		local ch = c.ch
		local _, n, total, rec = zoneState(ch, zoneID)
		local subtle = T.Hex(T.Look().subtle)
		local R = c.rows
		R[1].value:SetText(total > 0 and ("%d / %d"):format(n, total) or "None to chart")
		if rec and rec.seen then
			R[2].value:SetText(T.Date(rec.seen, true))
		elseif rec and rec.base then
			R[2].value:SetText("Before the journal")
		else
			R[2].value:SetText("Not yet")
		end
		if rec and rec.full and rec.full > 0 then
			R[3].value:SetText(T.Date(rec.full, true))
		elseif rec and rec.full then
			R[3].value:SetText("Before the journal")
		else
			R[3].value:SetText(total > 0 and "Not yet" or "-")
		end
		local me, pts = ns.Me(), 0
		for _, e in ipairs(ns.Ledger.Query({ who = me, map = zoneID })) do pts = pts + ns.Points.Of(e) end
		R[4].value:SetText(T.Number(pts))

		local names, before = {}, 0
		for _, id in ipairs(ns.Areas[zoneID] or {}) do
			if ch.areas[id] == 0 then before = before + 1 end
		end
		for _, e in ipairs(ns.Ledger.Query({ who = me, kind = "area", map = zoneID })) do
			names[#names + 1] = e.name or "an unnamed area"
		end
		local text = table.concat(names, "   ")
		if before > 0 then
			text = text .. (text ~= "" and "\n" or "") .. ("|cff%s%d charted before the journal was begun|r"):format(subtle, before)
		end
		c.areasText:SetText(text ~= "" and text or ("|cff%sNone yet.|r"):format(subtle))

		local finds = {}
		for _, f in pairs(ns.db.finds) do
			for _, si in ipairs(f.sightings) do
				if si.zone == zoneID then
					local col = T.Hex(T.KindColor(f.kind))
					finds[#finds + 1] = ("|cff%s%s|r"):format(col, f.name or "?")
					break
				end
			end
		end
		table.sort(finds)
		c.seenText:SetText(#finds > 0 and table.concat(finds, "\n")
			or ("|cff%sNo rares or treasures noted here yet.|r"):format(subtle))
	end

	function c.ShowContinent(index)
		local atlas = ns.Exploration.Atlas()
		local cont = atlas[index]
		if not cont then return end
		local changed = c.contIndex ~= index
		c.contIndex = index
		c.segments:Select(index)
		c.list:SetItems(cont.zones, not changed)
		local known, full = 0, 0
		for _, z in ipairs(cont.zones) do
			local k, _, _, rec = zoneState(c.ch, z.id)
			if k then known = known + 1 end
			if rec and rec.full then full = full + 1 end
		end
		c.summary:SetText(("%d of %d zones discovered  /  %d fully explored"):format(known, #cont.zones, full))
		if changed then
			local stillHere = false
			for _, z in ipairs(cont.zones) do
				if z.id == c.zone then stillHere = true end
			end
			if not stillHere and cont.zones[1] then c.zone = cont.zones[1].id end
			c.list:Render()
			c.ShowZone()
			ns.Journal.UpdateBanner()
		end
	end
end

local function refresh(c)
	c.ch = ns.Char()
	if not c.ch then return end
	local atlas = ns.Exploration.Atlas()
	if not c.ready then
		c.ready = true
		local items = {}
		for i, cont in ipairs(atlas) do items[i] = { key = i, label = cont.name } end
		c.segments:Rebuild(items)
		-- Open on where you stand.
		local here = ns.Exploration.CurrentZone()
		local hereCont = here and ns.Exploration.ContinentOf(here)
		local start = 1
		for i, cont in ipairs(atlas) do
			if cont.id == hereCont then start = i end
		end
		c.zone = here
		c.ShowContinent(start)
	else
		c.ShowContinent(c.contIndex or 1)
	end
	c.ShowZone()
end

-- The map: the chosen zone; a pin on you when it's the zone you're in.
local function banner(c)
	local zoneID = c.zone
	if not (zoneID and c.ch) then return {} end
	local _, n, total, rec = zoneState(c.ch, zoneID)
	local done = rec and rec.full and true or false
	local here, focus = W.PlayerFocus()
	local cont = ns.Exploration.ContinentOf(zoneID)
	local b = {
		map = zoneID,
		kicker = cont and ns.MapName(cont) or "",
		title = ns.MapName(zoneID) or "",
	}
	if here == zoneID then
		b.focus, b.pin, b.live = focus, true, true
	end
	if total > 0 then
		b.sub = done and "Fully explored" or ("%d of %d areas charted"):format(n, total)
		b.dots = { n, total, done }
		b.big = pct(n, total) .. "%"
		b.bigLabel = "explored"
		b.bigRole = done and "done" or "accent"
	else
		b.sub = (rec and (rec.seen or rec.base)) and "Visited" or "Uncharted"
	end
	return b
end

ns.Journal.Register({
	id = "atlas",
	order = 2,
	title = "Atlas",
	icon = "Interface\\Icons\\INV_Misc_Map_01",
	build = build,
	refresh = refresh,
	banner = banner,
})
