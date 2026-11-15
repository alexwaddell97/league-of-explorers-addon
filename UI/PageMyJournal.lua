-- My Journal: your rank, your figures, and every zone with a dot for each
-- of its areas. The facing page shows the zone you pick: its real map with
-- what you have explored painted in, its record, the areas you charted and
-- what you found there.

local _, ns = ...

local T, W, U = ns.Theme, ns.Widgets, ns.UI

local function zoneState(ch, zoneID)
	local rec = ch.zones[zoneID]
	local E = ns.Exploration
	local n, total
	if zoneID == E.CurrentZone() then
		n, total = E.Progress(zoneID)
	else
		n, total = rec and rec.explored or 0, ns.Areas[zoneID] and #ns.Areas[zoneID] or 0
	end
	return rec and (rec.seen or rec.base) and true or false, n, total, rec
end

local function pct(n, total)
	if total <= 0 then return 0 end
	return math.floor(n / total * 100 + 0.5)
end

local function build(left, right)
	local PW, PH = ns.Journal.PW, ns.Journal.PH
	local LH = PH - ns.Journal.HEAD

	-- Left page --------------------------------------------------------------
	left.rank = W.RankBar(left, PW)
	left.rank:SetPoint("TOPLEFT")

	left.stats = {}
	local cw = math.floor((PW - 24) / 4)
	for i, label in ipairs({ "Zones", "Areas", "Rares", "Treasures" }) do
		local l = W.Label(left, label)
		l:SetPoint("TOPLEFT", (i - 1) * (cw + 8), -96)
		local v = T.Text(left, "0", "Title", "heading")
		v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -5)
		left.stats[i] = v
	end

	left.segments = W.Segments(left, function(key) left.ShowContinent(key) end)
	left.segments:SetPoint("TOPLEFT", 0, -142)

	left.list = W.List(left, PW, LH - 176, 36, {
		emptyText = "No zones to show.",
		emptyIcon = ns.KIND_ICON.zone,
		build = function(row)
			row.name = T.Text(row, "", "Header", "text")
			row.name:SetPoint("TOPLEFT", 8, -4)
			row.name:SetPoint("RIGHT", -52, 0)
			row.name:SetWordWrap(false)
			row.dots = W.Dots(row, 5, 3, 30)
			row.dots:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
			row.note = T.Text(row, "", "Label", "subtle")
			row.note:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
			row.pct = T.Text(row, "", "Header", "accent")
			row.pct:SetPoint("RIGHT", -8, 0)
			row.pct:SetJustifyH("RIGHT")
		end,
		fill = function(row, z)
			local known, n, total, rec = zoneState(left.ch, z.id)
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
				row.note:SetText(known and "Visited" or "Not visited")
				row.pct:SetText("")
			end
		end,
		onClick = function(z)
			left.zone = z.id
			left.list:Render()
			right.ShowZone(z.id)
		end,
		isSelected = function(z) return z.id == left.zone end,
	})
	left.list:SetPoint("TOPLEFT", 0, -176)

	function left.ShowContinent(index)
		local cont = ns.Exploration.Atlas()[index]
		if not cont then return end
		local changed = left.contIndex ~= index
		left.contIndex = index
		left.segments:Select(index)
		left.list:SetItems(cont.zones, not changed)
		if changed then
			local here = false
			for _, z in ipairs(cont.zones) do
				if z.id == left.zone then here = true end
			end
			if not here and cont.zones[1] then left.zone = cont.zones[1].id end
			left.list:Render()
			right.ShowZone(left.zone)
		end
	end

	-- Right page: the zone ----------------------------------------------------
	right.map = W.MapBanner(right, PW, 196)
	right.map:SetPoint("TOPLEFT")
	T.Border(right.map.text, "panelEdge")

	right.rows = {}
	local prev
	for i, label in ipairs({ "Areas explored", "Discovered", "Fully explored", "Points earned here" }) do
		local s = W.Stat(right, label, PW)
		if i == 1 then s:SetPoint("TOPLEFT", right.map, "BOTTOMLEFT", 0, -12) else s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2) end
		local rule = W.Divider(right)
		rule:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -1)
		rule:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -1)
		right.rows[i] = s
		prev = s
	end
	local al = W.Label(right, "Explored areas")
	al:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -16)
	right.areas = T.Text(right, "", "Small", "text", PW)
	right.areas:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -6)
	right.areas:SetHeight(84)
	right.areas:SetJustifyV("TOP")
	right.areas:SetSpacing(3)
	local fl = W.Label(right, "Found here")
	fl:SetPoint("TOPLEFT", right.areas, "BOTTOMLEFT", 0, -10)
	right.found = T.Text(right, "", "Small", "text", PW)
	right.found:SetPoint("TOPLEFT", fl, "BOTTOMLEFT", 0, -6)
	right.found:SetHeight(46)
	right.found:SetJustifyV("TOP")
	right.found:SetSpacing(3)

	function right.ShowZone(zoneID)
		local ch = left.ch
		if not (zoneID and ch) then return end
		local known, n, total, rec = zoneState(ch, zoneID)
		local done = rec and rec.full and true or false
		local here, focus = W.PlayerFocus()
		local cont = ns.Exploration.ContinentOf(zoneID)
		right.map:SetMap(zoneID, here == zoneID and focus or nil, here == zoneID)
		right.map:SetHeadline({
			kicker = here == zoneID and "You are here" or (cont and ns.MapName(cont) or ""),
			title = ns.MapName(zoneID) or "",
			sub = total > 0 and (done and "Fully explored" or ("%d of %d areas explored"):format(n, total))
				or (known and "Visited" or "Not visited"),
			dots = total > 0 and { n, total, done } or nil,
			big = total > 0 and (pct(n, total) .. "%") or nil,
			bigLabel = total > 0 and "explored" or nil,
			bigRole = done and "done" or "accent",
		})

		local subtle = T.Hex(T.Look().subtle)
		local R = right.rows
		R[1].value:SetText(total > 0 and ("%d / %d"):format(n, total) or "None")
		R[2].value:SetText(rec and rec.seen and T.Date(rec.seen, true) or (rec and rec.base and "Before install") or "Not yet")
		if rec and rec.full and rec.full > 0 then
			R[3].value:SetText(T.Date(rec.full, true))
		else
			R[3].value:SetText(rec and rec.full and "Before install" or (total > 0 and "Not yet" or "-"))
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
		local text = table.concat(names, ",  ")
		if before > 0 then
			text = text .. (text ~= "" and "\n" or "") .. ("|cff%s%d explored before you installed the addon|r"):format(subtle, before)
		end
		right.areas:SetText(text ~= "" and text or ("|cff%sNone yet.|r"):format(subtle))

		local finds = {}
		for _, f in pairs(ns.db.finds) do
			for _, si in ipairs(f.sightings) do
				if si.zone == zoneID then
					finds[#finds + 1] = ("|cff%s%s|r"):format(T.Hex(T.KindColor(f.kind)), f.name or "?")
					break
				end
			end
		end
		table.sort(finds)
		right.found:SetText(#finds > 0 and table.concat(finds, ",  ") or ("|cff%sNo rares or treasures found here yet.|r"):format(subtle))
	end
end

local function refresh(left, right)
	left.ch = ns.Char()
	local me = ns.Me()
	if not (left.ch and me) then return end
	left.rank:SetWho(me)
	local zones = 0
	for _, z in pairs(left.ch.zones) do
		if z.seen or z.base then zones = zones + 1 end
	end
	local areas = 0
	for _ in pairs(left.ch.areas) do areas = areas + 1 end
	left.stats[1]:SetText(zones)
	left.stats[2]:SetText(areas)
	left.stats[3]:SetText(#ns.Ledger.Query({ who = me, kind = "rare" }))
	left.stats[4]:SetText(#ns.Ledger.Query({ who = me, kind = "treasure" }))

	local atlas = ns.Exploration.Atlas()
	if not left.ready then
		left.ready = true
		local items = {}
		for i, cont in ipairs(atlas) do items[i] = { key = i, label = cont.name } end
		left.segments:Rebuild(items)
		local here = ns.Exploration.CurrentZone()
		local hereCont = here and ns.Exploration.ContinentOf(here)
		local start = 1
		for i, cont in ipairs(atlas) do
			if cont.id == hereCont then start = i end
		end
		left.zone = here
		left.ShowContinent(start)
	else
		left.ShowContinent(left.contIndex or 1)
	end
	right.ShowZone(left.zone)
end

ns.Journal.Register({
	id = "journal",
	order = 2,
	title = "My Journal",
	info = "Your exploration: zones, areas, rares and treasures.",
	icon = "Interface\\Icons\\INV_Misc_Book_09",
	build = build,
	refresh = refresh,
})
