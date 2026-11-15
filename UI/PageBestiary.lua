-- The Bestiary, laid out as the guild's sketch draws it:
--   A  a column of zones down the left page, each with how many of its
--      rares you have found
--   B  the zone's rares, grouped by creature type: black silhouettes until
--      found. A rare the guild has found shows its name; one you have found
--      yourself shows in full colour.
--   C  the chosen creature on the right page: its portrait, its record,
--      your notes, and any bounty or expedition on it.

local _, ns = ...

local T, W, U = ns.Theme, ns.Widgets, ns.UI
local B = ns.Bestiary

local COL_A, TILE, GAP, PER_ROW, HEAD_H = 132, 81, 9, 3, 22
local WAIT = 6 -- seconds a zone's grid waits for its creature types at most
local waitingZone -- the zone whose grid is waiting, if any

-- Where it was last seen: your last sighting or the guild's, never the
-- spawn points in the rare list. Finding it is the point.
local function place(r)
	local s = r.find and r.find.sightings[#r.find.sightings]
	-- A guildmate's sighting in the last few minutes beats an older one of yours.
	local a = ns.Alerts and ns.Alerts.Recent(r.id)
	if a and (not s or a.t > s.t) then return a.map, a.x, a.y, a.t, "Spotted" end
	if s and s.x then return s.map, s.x, s.y, s.t, "Last seen" end
	local e = r.last
	if e and e.x then return e.map, e.x, e.y, e.t, "Last seen" end
	return r.zone, nil, nil, nil, "Roams in"
end

local function plural(t)
	if not t then return "Unknown" end
	if t:sub(-1) == "s" then return t end
	return t .. "s"
end

local function build(left, right)
	local PW, PH = ns.Journal.PW, ns.Journal.PH
	local LH = PH - ns.Journal.HEAD
	local gridX = COL_A + 12
	local gridW = PW - gridX
	local GRID_H = 290

	-- A: zones ----------------------------------------------------------------
	left.zones = W.List(left, COL_A, LH, 34, {
		emptyText = "",
		build = function(row)
			row.name = T.Text(row, "", "Small", "text")
			row.name:SetPoint("TOPLEFT", 8, -5)
			row.name:SetPoint("RIGHT", -4, 0)
			row.name:SetWordWrap(false)
			row.count = T.Text(row, "", "Label", "subtle")
			row.count:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
		end,
		fill = function(row, z)
			row.name:SetText(z.name)
			row.count:SetText(("%d of %d found"):format(z.mine, #z.list))
			T.SetRole(row.count, z.mine == #z.list and "done" or "subtle")
		end,
		onClick = function(z)
			left.zone = z.id
			left.selected = nil
			left.scroll:SetVerticalScroll(0)
			left.Render()
		end,
		isSelected = function(z) return z.id == left.zone end,
	})
	left.zones:SetPoint("TOPLEFT")

	-- B: the grid, scrolling, grouped by creature type -------------------------
	left.scroll = CreateFrame("ScrollFrame", nil, left)
	left.scroll:SetPoint("TOPLEFT", gridX, 0)
	left.scroll:SetSize(gridW - 10, GRID_H)
	left.grid = CreateFrame("Frame", nil, left.scroll)
	left.grid:SetSize(gridW - 10, 1)
	left.scroll:SetScrollChild(left.grid)
	left.bar = W.ScrollBar(left.scroll, TILE + GAP)
	-- Only tiles wholly inside the scrolling area show their creature (see
	-- Portrait:SetModelsOff).
	function left.ClipModels()
		local from = tonumber(left.scroll:GetVerticalScroll()) or 0
		local to = from + GRID_H
		for i = 1, left.used or 0 do
			local t = left.tiles[i]
			t:SetModelsOff(not (t.top and t.top >= from - 0.5 and t.top + TILE <= to + 0.5))
		end
	end
	left.scroll:HookScript("OnVerticalScroll", function() left.ClipModels() end)
	left.tiles, left.heads = {}, {}
	local tileW = math.floor((gridW - 10 - (PER_ROW - 1) * GAP) / PER_ROW)

	local function tile(i)
		local t = left.tiles[i]
		if t then return t end
		t = W.Portrait(left.grid, tileW, 0.7)
		t:SetHeight(TILE)
		t:SetScript("OnClick", function(self)
			if not self.rare then return end
			W.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
			left.selected = self.rare
			left.Render()
		end)
		t:EnableMouseWheel(true)
		t:SetScript("OnMouseWheel", function(_, d)
			local fn = left.scroll:GetScript("OnMouseWheel")
			if fn then fn(left.scroll, d) end
		end)
		left.tiles[i] = t
		return t
	end
	local function head(i)
		local h = left.heads[i]
		if h then return h end
		h = W.Label(left.grid, "")
		left.heads[i] = h
		return h
	end

	-- While a zone's creature types are still being read, the grid waits
	-- rather than laying out once and then shuffling.
	left.reading = T.Text(left, "Loading creatures...", "Body", "subtle", gridW - 10)
	left.reading:SetPoint("TOP", left, "TOPLEFT", gridX + (gridW - 10) / 2, -GRID_H / 2 + 10)
	left.reading:SetJustifyH("CENTER")
	left.reading:Hide()
	left.waitFrom = {}

	local bw = gridW
	local yl = W.Label(left, "You have found here")
	yl:SetPoint("TOPLEFT", gridX, -GRID_H - 16)
	left.youText = T.Text(left, "", "Header", "heading")
	left.youText:SetPoint("TOPRIGHT", 0, -GRID_H - 14)
	left.youText:SetJustifyH("RIGHT")
	left.youBar = W.Bar(left, bw, 4)
	left.youBar:SetPoint("TOPLEFT", yl, "BOTTOMLEFT", 0, -8)
	local gl = W.Label(left, "Found by the guild")
	left.guildLabel = gl
	gl:SetPoint("TOPLEFT", left.youBar, "BOTTOMLEFT", 0, -14)
	left.guildText = T.Text(left, "", "Header", "heading")
	left.guildText:SetPoint("TOP", gl, "TOP", 0, 2)
	left.guildText:SetPoint("RIGHT", 0, 0)
	left.guildText:SetJustifyH("RIGHT")
	left.guildBar = W.Bar(left, bw, 4)
	left.guildBar:SetPoint("TOPLEFT", gl, "BOTTOMLEFT", 0, -8)
	local al = W.Label(left, "In total")
	left.allLabel = al
	al:SetPoint("TOPLEFT", left.guildBar, "BOTTOMLEFT", 0, -14)
	left.allText = T.Text(left, "", "Header", "heading")
	left.allText:SetPoint("TOP", al, "TOP", 0, 2)
	left.allText:SetPoint("RIGHT", 0, 0)
	left.allText:SetJustifyH("RIGHT")
	left.allBar = W.Bar(left, bw, 4)
	left.allBar:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -8)

	-- C: the creature ---------------------------------------------------------
	-- The whole creature, stepped back a little so tall ones keep their heads.
	right.portrait = W.Portrait(right, PW, 0, 1.1)
	right.portrait:SetSize(PW, 168)
	right.portrait:SetModelBox(150, 164)
	right.portrait:SetPoint("TOPLEFT")
	right.portrait.name:Hide()
	right.title = T.Text(right, "", "Huge", "heading", PW)
	right.title:SetPoint("TOPLEFT", right.portrait, "BOTTOMLEFT", 0, -10)
	right.title:SetWordWrap(false)
	right.kind = T.Text(right, "", "Small", "subtle", PW)
	right.kind:SetPoint("TOPLEFT", right.title, "BOTTOMLEFT", 0, -4)
	right.rows = {}
	local prev = right.kind
	for i, label in ipairs({ "First found by", "Found by", "Your first time", "Your sightings", "Last seen" }) do
		local s = W.Stat(right, label, PW)
		s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -8 or -1)
		local rule = W.Divider(right)
		rule:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -1)
		rule:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -1)
		s.rule = rule
		right.rows[i] = s
		prev = s
	end
	local nl = W.Label(right, "Personal notes")
	nl:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
	right.notes = W.Notes(right, PW, 52, "Write anything you want to remember about it.", function(text)
		local r = left.selected
		if r then ns.db.notes["rare:" .. r.id] = text ~= "" and text or nil end
	end)
	right.notes:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", 0, -6)

	local bl = W.Label(right, "Bounty board")
	right.bountyLabel = bl
	bl:SetPoint("TOPLEFT", right.notes, "BOTTOMLEFT", 0, -12)
	right.bounty = T.Text(right, "", "Small", "text", PW)
	right.bounty:SetPoint("TOPLEFT", bl, "BOTTOMLEFT", 0, -6)
	right.bounty:SetSpacing(2)

	right.blank = U.Note(right, PW, 160, ns.KIND_ICON.rare, "Choose a creature", "Select a zone, then a creature.")
	right.blank:SetPoint("TOP", 0, -120)
	right.parts = { right.portrait, right.title, right.kind, nl, right.notes, bl, right.bounty }
	for _, s in ipairs(right.rows) do
		right.parts[#right.parts + 1] = s
		right.parts[#right.parts + 1] = s.rule
	end

	-- Drawing -----------------------------------------------------------------
	function left.Render()
		local data = left.data or {}
		local z
		for _, zz in ipairs(data) do
			if zz.id == left.zone then z = zz end
		end
		z = z or data[1]
		left.zone = z and z.id
		left.zones:Render()

		-- Wait (briefly) for this zone's creature types, asking for them first.
		local waiting = false
		if z and B.Pending(z.list) then
			for _, r in ipairs(z.list) do
				if not r.type then B.Want(r.id, true) end
			end
			left.waitFrom[z.id] = left.waitFrom[z.id] or GetTime()
			waiting = GetTime() - left.waitFrom[z.id] < WAIT
			if waiting then
				ns.After(WAIT + 0.2, function()
					if waitingZone == z.id and ns.Journal.IsShown() then ns.Journal.RefreshSoon() end
				end)
			end
		end
		waitingZone = waiting and z.id or nil
		left.reading:SetShown(waiting)

		-- Lay the grid out: a heading for each creature type, then its tiles.
		local y, ti, hi, col = 0, 0, 0, 0
		local lastType = false
		for _, r in ipairs((not waiting and z) and z.list or {}) do
			if r.type ~= lastType then
				if col > 0 then y = y - TILE - GAP end
				col = 0
				hi = hi + 1
				local h = head(hi)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", 0, y - 4)
				h:SetText(plural(r.type):upper())
				h:Show()
				y = y - HEAD_H
				lastType = r.type
			end
			ti = ti + 1
			local t = tile(ti)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", col * (tileW + GAP), y)
			t.top = -y
			t.rare = r
			t:Set({ id = r.id, display = r.display, icon = ns.KIND_ICON.rare, name = r.name,
				state = r.state, selected = r == left.selected })
			t:Show()
			col = col + 1
			if col == PER_ROW then
				col = 0
				y = y - TILE - GAP
			end
		end
		if col > 0 then y = y - TILE - GAP end
		left.used = ti
		for i = ti + 1, #left.tiles do left.tiles[i]:Hide() end
		for i = hi + 1, #left.heads do left.heads[i]:Hide() end
		left.grid:SetHeight(math.max(1, -y))
		left.bar.Update()
		left.ClipModels()

		local mine, all = 0, 0
		for _, zz in ipairs(data) do mine, all = mine + zz.mine, all + #zz.list end
		local n = z and #z.list or 0
		local zm, zg = z and z.mine or 0, z and z.guild or 0
		left.youText:SetText(("%d of %d"):format(zm, n))
		left.youBar:SetProgress(zm, math.max(1, n), n > 0 and zm >= n)
		left.guildText:SetText(("%d of %d"):format(zg, n))
		left.guildBar:SetProgress(zg, math.max(1, n), n > 0 and zg >= n)
		-- Solo: no guild line.
		local solo = ns.Solo()
		for _, x in ipairs({ left.guildLabel, left.guildText, left.guildBar }) do x:SetShown(not solo) end
		left.allLabel:ClearAllPoints()
		left.allLabel:SetPoint("TOPLEFT", solo and left.youBar or left.guildBar, "BOTTOMLEFT", 0, -14)
		left.allText:SetText(("%d of %d"):format(mine, all))
		left.allBar:SetProgress(mine, math.max(1, all), all > 0 and mine >= all)

		-- Keep the chosen creature if it's still in this zone, else the first.
		local sel, found = left.selected, nil
		for _, r in ipairs(z and z.list or {}) do
			if sel and r.id == sel.id then found = r end
		end
		left.selected = found or (z and z.list[1])
		for i = 1, ti do
			local t = left.tiles[i]
			t.sel:SetShown(t.rare == left.selected)
		end
		right.ShowRare(left.selected)
	end

	function right.ShowRare(r)
		for _, x in ipairs(right.parts) do x:SetShown(r ~= nil) end
		right.blank:SetShown(r == nil)
		if not r then return end
		right.portrait:Set({ id = r.id, display = r.display, icon = ns.KIND_ICON.rare, state = r.state })
		-- Solo: who in the guild found it, and bounties, don't apply.
		local solo = ns.Solo()
		local R = right.rows
		for i = 1, 2 do
			R[i]:SetShown(not solo)
			R[i].rule:SetShown(not solo)
		end
		R[3]:ClearAllPoints()
		R[3]:SetPoint("TOPLEFT", solo and right.kind or R[2], "BOTTOMLEFT", 0, solo and -8 or -1)
		right.bountyLabel:SetShown(not solo)
		right.bounty:SetShown(not solo)
		local lvl = B.LevelText(r)
		local what = ("%s%s"):format(r.type and r.type:lower() or "creature", lvl and (", level " .. lvl) or "")
		if r.state == "unknown" then
			right.title:SetText("Undiscovered")
			right.kind:SetText(("A rare %s. %s"):format(what,
				solo and "You haven't found it yet." or "No one in the guild has found it yet."))
		else
			right.title:SetText(r.name or "Unknown creature")
			right.kind:SetText(r.state == "mine" and ("Rare " .. what)
				or ("Rare %s. Found by the guild. Find it yourself to see its portrait."):format(what))
		end
		R[1].value:SetText(r.first and ("%s, %s"):format(ns.ShortName(r.first.who), T.Date(r.first.t, true)) or "No one yet")
		local killers, kseen = 0, {}
		for _, e in ipairs(ns.Ledger.Query({ kind = "kill" })) do
			local p = ns.Points.Player(e.who)
			if e.key == r.id and not kseen[p] then
				kseen[p] = true
				killers = killers + 1
			end
		end
		local found = #r.finders == 0 and "-" or (#r.finders == 1 and "1 player" or (#r.finders .. " players"))
		R[2].value:SetText(killers > 0 and ("%s, %d killed it"):format(found, killers) or found)
		R[3].value:SetText(r.mine and T.Date(r.mine.t, true) or (r.find and "Only seen dead" or "Not yet"))
		R[4].value:SetText(r.find and r.find.count or 0)
		local map, x, y, t, label = place(r)
		R[5].label:SetText(label)
		local where = map and (ns.MapName(map) or "?") or "-"
		if x then where = where .. "  " .. T.Coords(x, y) end
		R[5].value:SetText(where .. (t and ("  /  " .. U.Ago(t)) or ""))
		right.notes:SetText(ns.db.notes["rare:" .. r.id])

		-- Bounties and expeditions that want this creature.
		local lines = {}
		for _, xp in ipairs(ns.Work.Expeditions()) do
			if ns.Work.IsOpen(xp) then
				for _, g in ipairs(xp.goals) do
					if g.k == "r" and g.id == r.id then
						lines[#lines + 1] = ("%s  |cff%s+%d|r  (%s)"):format(xp.title, T.Hex(T.Look().points), xp.reward,
							xp.bounty and "bounty: first to kill it" or "expedition")
					end
				end
			end
		end
		right.bounty:SetText(#lines > 0 and table.concat(lines, "\n")
			or ("|cff%sNo bounty posted for this creature.|r"):format(T.Hex(T.Look().subtle)))
	end
end

local function refresh(left)
	left.data = B.Zones(U.Members())
	left.zones:SetItems(left.data, true)
	if not left.zone then
		local here = ns.Exploration.CurrentZone()
		for _, z in ipairs(left.data) do
			if z.id == here then left.zone = here end
		end
	end
	left.Render()
end

ns.Journal.Register({
	id = "bestiary",
	order = 3,
	title = "Bestiary",
	info = "Every rare creature, by zone and type. Rares you haven't found show as silhouettes.",
	icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	build = build,
	refresh = refresh,
})

-- Creature types arrive as the game answers. Only a grid that is waiting
-- for them redraws; a grid already on show is never shuffled under you.
ns.Listen("CREATURE_LEARNED", function()
	if not waitingZone then return end
	local cur = ns.Journal.Current()
	if cur and cur.id == "bestiary" and ns.Journal.IsShown() then ns.Journal.RefreshSoon() end
end)
