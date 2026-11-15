-- The journal: an open book. A flat dark cover, two paper pages either
-- side of the spine, and a ribbon bookmark standing up from the top edge
-- for each section. Choosing a bookmark turns the page: the sound of a page
-- turning, and a leaf sweeping across from the right page to the left.
--
-- Sections register with Journal.Register({ id, order, title, info, icon,
-- build(left, right), refresh(left, right) }). left and right are the
-- writing areas of the two pages; left sits under the section's title and
-- page info, as the guild's sketch has it.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets
local J = {}
ns.Journal = J

local BOOK_W, BOOK_H = 960, 600
local COVER = 18                        -- cover showing round the pages
local BLOCK = 4                         -- leaves showing beneath each page (the book's thickness)
local PAGE_W = (BOOK_W - 2 * COVER) / 2 -- the pages meet at the fold
local PAGE_H = BOOK_H - 2 * COVER - BLOCK * 2
local INSET = 24                        -- writing area inside each page
local HEAD = 64                         -- title and page info at the top of the left page
local RIBBON_H, RIBBON_UP = 30, 8       -- bookmark height; how far the open one rises
local TOP = RIBBON_H + RIBBON_UP + 4    -- room above the book for the bookmarks
J.PW, J.PH = PAGE_W - 2 * INSET, PAGE_H - 2 * INSET
J.HEAD = HEAD

local sections, byId = {}, {}
local frame, book, current
local mframe -- the map look's window (see "The map look" below)
local function mapOn() return ns.db and ns.db.settings.shell == "map" or false end
J.MapOn = mapOn

function J.Register(def)
	table.insert(sections, def)
	byId[def.id] = def
	table.sort(sections, function(a, b) return a.order < b.order end)
end

-- Guild pages step aside in solo mode; some pages go by another name there.
local function available(s) return not (s.guild and ns.Solo()) end
local function titleOf(s) return (ns.Solo() and s.soloTitle) or s.title end
local function infoOf(s) return (ns.Solo() and s.soloInfo) or s.info end
local function shown()
	local out = {}
	for _, s in ipairs(sections) do
		if available(s) then out[#out + 1] = s end
	end
	return out
end
-- Page numbers run through the pages there are.
local function pageOf(s)
	for i, x in ipairs(shown()) do
		if x == s then return i * 2 - 1 end
	end
	return s.order * 2 - 1
end
J.Available = available

local function sound(kit)
	if ns.db.settings.sound == false then return end
	if SOUNDKIT and SOUNDKIT[kit] then pcall(PlaySound, SOUNDKIT[kit]) end
end

---------------------------------------------------------------------------
-- Settings popover (the cog above the cover)
---------------------------------------------------------------------------
local function buildSettings(f)
	local s = CreateFrame("Frame", nil, f)
	s:SetSize(260, 488)
	s:SetFrameLevel(f:GetFrameLevel() + 60)
	s:EnableMouse(true)
	s:Hide()
	s.bg = s:CreateTexture(nil, "BACKGROUND")
	s.bg:SetAllPoints()
	s.edge = T.Border(s, "windowEdge")
	T.OnTheme(function(look) T.Fill(s.bg, { look.window[1], look.window[2], look.window[3], 1 }) end)

	local settings = ns.db.settings
	local Wk = ns.Work
	-- Everything in the popover, top to bottom: { widget, gap above it,
	-- guild = only in guild mode }. Laid out again each time it opens.
	local items, toggles = {}, {}
	local function add(w, gap, guildOnly)
		items[#items + 1] = { w = w, gap = gap or -4, guild = guildOnly }
		return w
	end
	local function toggle(label, get, set, guildOnly, gap)
		local t = W.Toggle(s, label, 232, get, set)
		toggles[#toggles + 1] = t
		return add(t, gap, guildOnly)
	end
	local function refresh() s:GetScript("OnShow")() end

	-- The look: the book, or the map window.
	add(W.Label(s, "Look"))
	local lookSeg = add(W.Segments(s, function(key) J.SetShell(key) end), -8)
	lookSeg:Rebuild({ { key = "book", label = "Book" }, { key = "map", label = "Map" } })
	add(W.Label(s, "Preferences"), -14)
	toggle("Solo mode", function() return ns.Solo() end, function(v)
		ns.Guild.SetSolo(v)
		refresh()
	end, false, -8)
	add(T.Text(s, "No guild pages, leaderboards or sharing.", "Label", "subtle", 232), -2)
	toggle("Discovery pop-ups", function() return settings.toasts end, function(v) settings.toasts = v end, false, -8)
	toggle("Sounds", function() return settings.sound end, function(v) settings.sound = v end)
	toggle("Open and close like a book", function() return settings.bookAnim ~= false end, function(v)
		settings.bookAnim = v
	end)
	items[#items].book = true -- only the book opens like one
	toggle("Minimap button", function() return not settings.minimap.hide end, function(v)
		settings.minimap.hide = not v
		ns.Fire("MINIMAP_SETTING")
	end)
	toggle("Ranks in the guild window", function() return settings.guildWindow ~= false end, function(v)
		settings.guildWindow = v
		ns.Fire("ENTRY_MERGED", {})
	end, true)
	toggle("Ranks in guild chat", function() return settings.chatTags ~= false end, function(v)
		settings.chatTags = v
	end, true)
	toggle("Pins on the world map", function() return settings.mapPins ~= false end, function(v)
		settings.mapPins = v
		ns.Fire("MAP_PINS_SETTING")
	end)
	toggle("Pins on the minimap", function() return settings.minimapPins ~= false end, function(v)
		settings.minimapPins = v
		ns.Fire("MAP_PINS_SETTING")
	end)
	-- Which guildmates' rare sightings pop up: click to step through.
	local alertBtn = add(W.Button(s, "", 232, 22, function()
		ns.Alerts.CycleMode()
		refresh()
	end), -6, true)
	add(W.Button(s, "Move pop-ups", 232, 22, function()
		s:Hide()
		ns.MoveToasts(true)
	end), -4)

	-- Your characters (they share one rank), and in guild mode the officer
	-- tools: try them, and (as guild master) say which ranks are officers.
	local guild = add(W.Label(s, "Guild"), -14)
	local mainBtn = add(W.Button(s, "", 232, 22, function()
		-- Step through this account's characters in name order.
		local cur = ns.Players.MyMain()
		local sorted = {}
		for who in pairs(ns.db.chars) do sorted[#sorted + 1] = who end
		table.sort(sorted)
		local idx = 1
		for i, who in ipairs(sorted) do
			if who == cur then idx = i end
		end
		ns.Players.SetMain(sorted[idx % #sorted + 1])
		refresh()
	end), -8)
	toggle("Preview officer tools", function() return Wk.Preview() end, function(v)
		Wk.SetPreview(v)
		refresh()
	end, true, -6)
	local ranks = add(W.Button(s, "", 232, 22, function()
		local _, n = Wk.RankNames()
		if n < 2 then return end
		-- Cycle through: officers are ranks 0 to r, r from 1 to the second-lowest rank.
		local r = Wk.OfficerRank() + 1
		if r > n - 2 then r = 1 end
		Wk.SetOfficerRank(r)
		refresh()
	end), -8, true)
	local rankNote = add(T.Text(s, "", "Label", "subtle", 232), -5, true)

	-- A quiet link to support the addon, at the foot.
	if ns.Support then
		local kofi = ns.Support.Link(s)
		kofi:SetPoint("BOTTOMLEFT", 14, 12)
	end

	-- Stacks what this mode shows, and fits the popover round it.
	local function layout()
		local solo = ns.Solo()
		local prev, h = nil, 14
		for _, it in ipairs(items) do
			local show = not (it.guild and solo) and not (it.book and mapOn())
			it.w:SetShown(show)
			if show then
				it.w:ClearAllPoints()
				if prev then
					it.w:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, it.gap)
					h = h - it.gap
				else
					it.w:SetPoint("TOPLEFT", 14, -14)
				end
				h = h + (it.w:GetHeight() or 0)
				prev = it.w
			end
		end
		s:SetHeight(h + 44) -- and room for the Ko-fi link
	end

	s:SetScript("OnShow", function()
		layout()
		lookSeg:Select(mapOn() and "map" or "book")
		for _, t in ipairs(toggles) do t:Refresh() end
		alertBtn:SetText("Rare alerts: " .. ns.Alerts.ModeLabel())
		guild:SetText(ns.Solo() and "CHARACTERS" or "GUILD")
		local mine = ns.Players.Mine()
		mainBtn:SetText(("Your main: %s%s"):format(ns.ShortName(ns.Players.MyMain()),
			#mine > 1 and ("  (" .. (#mine - 1) .. (#mine == 2 and " alt)" or " alts)")) or ""))
		mainBtn:SetEnabled(#mine > 1)
		local leader = Wk.IsLeader(ns.Me())
		local names = Wk.RankNames()
		local r = Wk.OfficerRank()
		ranks:SetText(("Officers: up to %s"):format(names[r] or ("rank " .. r)))
		ranks:SetEnabled(leader)
		rankNote:SetText(leader and "Click to change which ranks are officers."
			or "The guild master chooses which ranks are officers.")
	end)
	return s
end

---------------------------------------------------------------------------
-- Bookmarks: a cloth ribbon with the section's name, standing up from the
-- top of the book. The open one rises and deepens.
---------------------------------------------------------------------------
local function makeRibbon(parent, s, width)
	local r = CreateFrame("Button", nil, parent)
	r:SetSize(width, RIBBON_H + RIBBON_UP)
	r.id = s.id
	r.body = r:CreateTexture(nil, "ARTWORK")
	r.body:SetTexture(T.WHITE)
	r.body:SetPoint("BOTTOMLEFT")
	r.body:SetPoint("BOTTOMRIGHT")
	r.body:SetHeight(RIBBON_H)
	r.shine = r:CreateTexture(nil, "ARTWORK", nil, 1)
	r.shine:SetPoint("TOPLEFT", r.body, "TOPLEFT")
	r.shine:SetPoint("BOTTOMRIGHT", r.body, "BOTTOMRIGHT")
	-- Stitched edges, as on a cloth ribbon.
	r.stitchL = T.Line(r, true, nil, "ARTWORK")
	r.stitchL:SetPoint("TOPLEFT", r.body, "TOPLEFT", 3, -3)
	r.stitchL:SetPoint("BOTTOMLEFT", r.body, "BOTTOMLEFT", 3, 3)
	r.stitchR = T.Line(r, true, nil, "ARTWORK")
	r.stitchR:SetPoint("TOPRIGHT", r.body, "TOPRIGHT", -3, -3)
	r.stitchR:SetPoint("BOTTOMRIGHT", r.body, "BOTTOMRIGHT", -3, 3)
	r.icon = r:CreateTexture(nil, "OVERLAY")
	r.icon:SetSize(16, 16)
	r.icon:SetTexture(s.icon)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	T.Round(r.icon)
	r.text = r:CreateFontString(nil, "OVERLAY")
	r.text:SetFontObject(T.FONTS.SmallShadow)
	r.text:SetWordWrap(false)
	r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
	function r:SetLabel(text)
		self.text:SetText(text)
		local tw = self.text:GetStringWidth() + 20
		self.icon:ClearAllPoints()
		self.icon:SetPoint("TOP", self.body, "TOP", -tw / 2 + 8, -7)
	end
	r:SetLabel(s.title)

	function r:Paint()
		local look = T.Look()
		local c = look.ribbons[self.id] or { 0.4, 0.3, 0.2 }
		local sel = self.id == (current and current.id)
		local k = sel and 1 or (self.hover and 0.85 or 0.62)
		self.body:SetVertexColor(c[1] * k, c[2] * k, c[3] * k, 1)
		T.Gradient(self.shine, "VERTICAL", 0, 0, 0, sel and 0.28 or 0.4, 0)
		self.stitchL:SetVertexColor(1, 1, 1, sel and 0.35 or 0.2)
		self.stitchR:SetVertexColor(1, 1, 1, sel and 0.35 or 0.2)
		local tc = look.ribbonText or { 1, 0.97, 0.9 }
		self.text:SetTextColor(tc[1], tc[2], tc[3], sel and 1 or 0.75)
		self.icon:SetAlpha(sel and 1 or 0.7)
		self.icon:SetDesaturated(not sel and not self.hover)
	end
	local function rise(p) r.body:SetHeight(RIBBON_H + RIBBON_UP * p) end
	r:SetScript("OnEnter", function(self)
		self.hover = true
		self:Paint()
		if self.id ~= (current and current.id) then T.Tween(self, 0.5, 0.15, rise, T.Ease.outQuart) end
	end)
	r:SetScript("OnLeave", function(self)
		self.hover = false
		self:Paint()
		if self.id ~= (current and current.id) then T.Tween(self, 0, 0.15, rise, T.Ease.outQuart) end
	end)
	r:SetScript("OnClick", function(self) J.Show(self.id) end)
	function r:Rise(on) T.Tween(self, on and 1 or 0, 0.2, rise, T.Ease.outQuart) end
	T.OnTheme(function() r:Paint() end)
	return r
end

---------------------------------------------------------------------------
-- The page turn. A leaf turns about the spine: turning forward it lifts
-- off the right page and lands on the left; turning back, the other way.
-- Its width follows the cosine of its angle (it foreshortens as it stands
-- up), its free edge reaches a little taller than the spine in perspective
-- (the game's texture-corner offsets), faint lines of writing on it narrow
-- with it, shade moves across it as
-- it turns away from the light, its free edge catches a highlight, and it
-- casts a shadow on the page beneath. The new page is uncovered beneath
-- the lifting leaf at once; the facing page changes only as the leaf
-- lands on it, as in a real book.
---------------------------------------------------------------------------
local TURN_TIME = 0.55

local function ease(p) return p * p * (3 - 2 * p) end -- slow off, slow down

local function makeLeaf(b)
	local leaf = CreateFrame("Frame", nil, b)
	leaf:SetFrameLevel(b:GetFrameLevel() + 30)
	leaf.paper = leaf:CreateTexture(nil, "ARTWORK")
	leaf.paper:SetAllPoints()
	leaf.shade = leaf:CreateTexture(nil, "ARTWORK", nil, 1)
	leaf.shade:SetAllPoints()
	leaf.edge = leaf:CreateTexture(nil, "ARTWORK", nil, 2)
	leaf.edge:SetTexture(T.WHITE)
	leaf.edge:SetWidth(1.5)
	-- Faint lines of writing, so it reads as a page and not a blank card:
	-- a heading, then lines of text of varying length.
	leaf.lines = {}
	local LINES = {
		{ 0.08, 0.50, 3 }, { 0.13, 0.80, 1 },
		{ 0.20, 0.84, 1 }, { 0.24, 0.78, 1 }, { 0.28, 0.82, 1 }, { 0.32, 0.60, 1 },
		{ 0.39, 0.84, 1 }, { 0.43, 0.80, 1 }, { 0.47, 0.83, 1 }, { 0.51, 0.70, 1 },
		{ 0.58, 0.82, 1 }, { 0.62, 0.84, 1 }, { 0.66, 0.76, 1 }, { 0.70, 0.45, 1 },
		{ 0.77, 0.83, 1 }, { 0.81, 0.80, 1 }, { 0.85, 0.66, 1 },
	}
	for i, l in ipairs(LINES) do
		local t = leaf:CreateTexture(nil, "ARTWORK", nil, 0)
		t:SetTexture(T.WHITE)
		t.y, t.frac, t.h = l[1], l[2], l[3]
		leaf.lines[i] = t
	end
	-- The shadow it casts lies over the page beneath, under the leaf.
	leaf.castFrame = CreateFrame("Frame", nil, b)
	leaf.castFrame:SetFrameLevel(b:GetFrameLevel() + 29)
	leaf.castFrame:SetAllPoints()
	leaf.cast = leaf.castFrame:CreateTexture(nil, "ARTWORK")
	leaf:Hide()
	leaf.cast:Hide()

	local paperSide

	-- forward: from the right page to the left. onStart runs as the leaf
	-- lifts; onLand as it lands.
	function leaf:Play(forward, onStart, onLand)
		local look = T.Look()
		local from = forward and b.right or b.left
		local to = forward and b.left or b.right
		local sp = look.spine
		local landed = false
		paperSide = nil

		local function settle()
			if landed then return end
			landed = true
			onLand()
			-- The landed leaf is the new page's paper: let it fade into it.
			self.cast:Hide()
			T.SetProgress(self.paper, 0)
			T.Tween(self.paper, 1, 0.12, function(q)
				self:SetAlpha(1 - q)
				if q >= 1 then
					self:Hide()
					self:SetAlpha(1)
				end
			end)
		end
		self.finish = settle

		-- A fade-out still running from the last turn is cancelled.
		T.Tween(self.paper, 1, 0.001, function() end)
		onStart()
		self:SetAlpha(1)
		self:Show()
		self.cast:Show()
		T.SetProgress(self, 0)
		T.Tween(self, 1, TURN_TIME, function(p)
			local th = math.pi * ease(p)
			local c, sn = math.cos(th), math.sin(th)
			local page = c >= 0 and from or to
			local onRight = page == b.right
			local spineSide = onRight and "LEFT" or "RIGHT"
			local freeSide = onRight and "RIGHT" or "LEFT"

			local w = math.max(1, PAGE_W * math.abs(c))
			self:ClearAllPoints()
			self:SetPoint(spineSide, page, spineSide, 0, 0)
			self:SetSize(w, PAGE_H)

			-- Perspective: the free edge, nearer to you, stands a little taller.
			local d = PAGE_H * 0.03 * sn
			for _, tex in ipairs({ self.paper, self.shade }) do
				if tex.SetVertexOffset then
					local up, down = onRight and 3 or 1, onRight and 4 or 2
					local sUp, sDown = onRight and 1 or 3, onRight and 2 or 4
					tex:SetVertexOffset(sUp, 0, 0)
					tex:SetVertexOffset(sDown, 0, 0)
					tex:SetVertexOffset(up, 0, d)
					tex:SetVertexOffset(down, 0, -d)
				end
			end

			-- The writing narrows with the page; it starts at the page's left margin.
			local ink = look.text
			for _, t in ipairs(self.lines) do
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", self, "TOPLEFT", w * 0.09, -PAGE_H * t.y)
				t:SetSize(math.max(1, w * t.frac * 0.82), t.h)
				t:SetVertexColor(ink[1], ink[2], ink[3], (t.h > 1 and 0.22 or 0.12) * (1 - 0.6 * sn))
			end

			-- Front of the leaf, then its back: the paper of the side it's on.
			local side = onRight and "right" or "left"
			if paperSide ~= side then
				paperSide = side
				T.Fill(self.paper, look.page)
			end

			-- Turned away from the light, it darkens toward its free edge.
			local spineA, freeA = 0.08 * sn, 0.04 + 0.42 * sn
			if onRight then
				T.Gradient(self.shade, "HORIZONTAL", sp[1], sp[2], sp[3], spineA, freeA)
			else
				T.Gradient(self.shade, "HORIZONTAL", sp[1], sp[2], sp[3], freeA, spineA)
			end
			self.edge:ClearAllPoints()
			self.edge:SetPoint("TOP" .. freeSide)
			self.edge:SetPoint("BOTTOM" .. freeSide)
			self.edge:SetVertexColor(1, 1, 1, 0.5 * sn)
			-- The highlight runs the whole length of the taller free edge.
			if self.edge.SetVertexOffset then
				self.edge:SetVertexOffset(1, 0, d)
				self.edge:SetVertexOffset(3, 0, d)
				self.edge:SetVertexOffset(2, 0, -d)
				self.edge:SetVertexOffset(4, 0, -d)
			end

			-- Its shadow falls past its free edge, on the page beneath.
			local cw = 10 + 46 * sn
			self.cast:ClearAllPoints()
			if onRight then
				self.cast:SetPoint("TOPLEFT", self, "TOPRIGHT")
				self.cast:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT")
				T.Gradient(self.cast, "HORIZONTAL", 0, 0, 0, 0.30 * sn, 0)
			else
				self.cast:SetPoint("TOPRIGHT", self, "TOPLEFT")
				self.cast:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT")
				T.Gradient(self.cast, "HORIZONTAL", 0, 0, 0, 0, 0.30 * sn)
			end
			-- Never past the outer edge of the page it falls on.
			local room = PAGE_W * math.abs(c) < PAGE_W and (PAGE_W - PAGE_W * math.abs(c)) or 0
			self.cast:SetWidth(math.max(1, math.min(cw, room)))
			self.cast:SetShown(room > 1 and sn > 0.02)

			if p >= 1 then settle() end
		end)
	end
	return leaf
end

---------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------
local function makePage(b, side)
	local L = side == "left"
	local outer = L and "LEFT" or "RIGHT"
	local inner = L and "RIGHT" or "LEFT"
	local p = CreateFrame("Frame", nil, b)
	p:SetSize(PAGE_W, PAGE_H)
	p:SetPoint("TOP" .. outer, (L and 1 or -1) * COVER, -COVER)
	p.paper = p:CreateTexture(nil, "BACKGROUND", nil, 1)
	p.paper:SetAllPoints()
	-- The page curving down into the fold, and away at its outer edge.
	p.fold = p:CreateTexture(nil, "BACKGROUND", nil, 3)
	p.fold:SetWidth(84)
	p.fold:SetPoint("TOP" .. inner)
	p.fold:SetPoint("BOTTOM" .. inner)
	p.crease = p:CreateTexture(nil, "BACKGROUND", nil, 4)
	p.crease:SetWidth(10)
	p.crease:SetPoint("TOP" .. inner)
	p.crease:SetPoint("BOTTOM" .. inner)
	p.curl = p:CreateTexture(nil, "BACKGROUND", nil, 3)
	p.curl:SetWidth(30)
	p.curl:SetPoint("TOP" .. outer)
	p.curl:SetPoint("BOTTOM" .. outer)
	-- The leaves beneath: thin edges stepping out below and to the outer side.
	p.underFill = b:CreateTexture(nil, "BACKGROUND", nil, -5)
	p.underFill:SetPoint("TOP" .. outer, p, "BOTTOM" .. outer, (L and -1 or 1) * BLOCK, 0)
	p.underFill:SetPoint("BOTTOM" .. inner, p, "BOTTOM" .. inner, 0, -BLOCK * 2)
	p.sideFill = b:CreateTexture(nil, "BACKGROUND", nil, -5)
	p.sideFill:SetPoint("TOP" .. inner, p, "TOP" .. outer, 0, -1)
	p.sideFill:SetPoint("BOTTOM" .. outer, p, "BOTTOM" .. outer, (L and -1 or 1) * BLOCK, 0)
	p.leaves = {}
	for i = 1, BLOCK do
		local edge = T.Line(b, true, nil, "BACKGROUND")
		edge:SetPoint("TOP" .. outer, p, "TOP" .. outer, (L and -1 or 1) * i, -i)
		edge:SetPoint("BOTTOM" .. outer, p, "BOTTOM" .. outer, (L and -1 or 1) * i, -i * 2)
		local under = T.Line(b, false, nil, "BACKGROUND")
		under:SetPoint("BOTTOM" .. outer, p, "BOTTOM" .. outer, (L and -1 or 1) * i, -i * 2)
		under:SetPoint("BOTTOM" .. inner, p, "BOTTOM" .. inner, 0, -i * 2)
		p.leaves[#p.leaves + 1] = { edge, under, i }
	end
	p.inset = CreateFrame("Frame", nil, b)
	p.inset:SetFrameLevel(b:GetFrameLevel() + 2)
	p.inset:SetAllPoints(p)
	p.area = CreateFrame("Frame", nil, p.inset)
	p.area:SetPoint("TOPLEFT", INSET + (L and 0 or 6), -INSET)
	p.area:SetPoint("BOTTOMRIGHT", -INSET - (L and 6 or 0), INSET)
	p.number = T.Text(p.inset, "", "Label", "subtle")
	p.number:SetPoint("BOTTOM" .. outer, (L and 1 or -1) * 26, 10)
	T.OnTheme(function(look)
		T.Fill(p.paper, look.page)
		local sp = look.spine
		local foldA, creaseA, curlA = 0.30, 0.22, 0.10
		if L then
			T.Gradient(p.fold, "HORIZONTAL", sp[1], sp[2], sp[3], 0, foldA)
			T.Gradient(p.crease, "HORIZONTAL", sp[1], sp[2], sp[3], 0, creaseA)
			T.Gradient(p.curl, "HORIZONTAL", sp[1], sp[2], sp[3], curlA, 0)
		else
			T.Gradient(p.fold, "HORIZONTAL", sp[1], sp[2], sp[3], foldA, 0)
			T.Gradient(p.crease, "HORIZONTAL", sp[1], sp[2], sp[3], creaseA, 0)
			T.Gradient(p.curl, "HORIZONTAL", sp[1], sp[2], sp[3], 0, curlA)
		end
		local pg, e = look.page, look.pageEdge
		p.underFill:SetColorTexture(pg[1] * 0.86, pg[2] * 0.84, pg[3] * 0.80, 1)
		p.sideFill:SetColorTexture(pg[1] * 0.86, pg[2] * 0.84, pg[3] * 0.80, 1)
		for _, l in ipairs(p.leaves) do
			local a = (e[4] or 1) * (1 - (l[3] - 1) * 0.18)
			l[1]:SetVertexColor(e[1], e[2], e[3], a)
			l[2]:SetVertexColor(e[1], e[2], e[3], a)
		end
	end)
	return p
end

-- A brass corner guard: a turned square, clipped by a small frame at the
-- corner of the cover so only its triangle shows.
local function makeCorner(b, point)
	local c = CreateFrame("Frame", nil, b)
	c:SetSize(26, 26)
	c:SetPoint(point)
	c:SetFrameLevel(b:GetFrameLevel() + 4)
	if c.SetClipsChildren then c:SetClipsChildren(true) end
	local t = c:CreateTexture(nil, "ARTWORK")
	t:SetTexture(T.WHITE)
	t:SetSize(37, 37)
	t:SetRotation(math.rad(45))
	t:SetPoint("CENTER", c, point, 0, 0)
	local shine = c:CreateTexture(nil, "ARTWORK", nil, 1)
	shine:SetTexture(T.WHITE)
	shine:SetSize(22, 22)
	shine:SetRotation(math.rad(45))
	shine:SetPoint("CENTER", c, point, 0, 0)
	c.parts = { t, shine }
	return c
end

---------------------------------------------------------------------------
-- Opening and closing like a tome.
--
-- Shut, the book is its front cover lying over the right half; the left
-- half is clipped away (frame.clip). Opening, the cover swings over the
-- spine and two blank flyleaves follow it, each landing on the one before;
-- then the left page shows through as they fade. Closing, the left half
-- (the cover with its leaves) swings back over and lands shut, and the
-- book fades.
--
-- Each sheet turns about the spine and is drawn in perspective: a point u
-- pixels from the spine, turned to th, lies u*cos(th) across and u*sin(th)
-- toward you, and is scaled by FOCAL / (FOCAL - depth). Every texture on a
-- sheet is a quad whose four corners are placed that way (the game's
-- texture-corner offsets), so the tooling, corner guards and emblem tilt
-- with the cover. Faces are lit from above-left; the cover's board edge
-- shows as it stands up; each sheet casts a shadow past its free edge.
-- Off with settings.bookAnim = false.
---------------------------------------------------------------------------
local R = BOOK_W / 2        -- a sheet's reach from the spine
local FOCAL = 4000          -- how far away you are: smaller, more perspective
local BOARD = 5             -- the cover board's thickness
local TOP_V, BOT_V = BOOK_H / 2, -BOOK_H / 2
local PG_TOP, PG_BOT = BOOK_H / 2 - COVER, -(BOOK_H / 2 - COVER - BLOCK * 2)
local OPEN_TIME, CLOSE_TIME = 1.0, 0.95
local GOLD = { 0.86, 0.69, 0.40 }
local BRASS = { 0.70, 0.53, 0.28 }

local function animOn() return ns.db and ns.db.settings.bookAnim ~= false end
local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end

local anchor -- the book: every sheet is placed from its centre, the spine

-- Where a point u from the spine lands with the sheet turned to th: how
-- far across, and its scale.
local function proj(th, u)
	local s = FOCAL / (FOCAL - u * math.sin(th))
	return u * math.cos(th) * s, s
end

-- Places a texture as the quad with these corners, from the book's centre:
-- upper-left, lower-left, upper-right, lower-right.
local function quad(tex, ax, ay, bx, by, cx, cy, dx, dy)
	local minx, maxx = math.min(ax, bx, cx, dx), math.max(ax, bx, cx, dx)
	local miny, maxy = math.min(ay, by, cy, dy), math.max(ay, by, cy, dy)
	if maxx - minx < 0.5 then maxx = minx + 0.5 end
	if maxy - miny < 0.5 then maxy = miny + 0.5 end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", anchor, "CENTER", minx, maxy)
	tex:SetPoint("BOTTOMRIGHT", anchor, "CENTER", maxx, miny)
	if tex.SetVertexOffset then
		tex:SetVertexOffset(1, ax - minx, ay - maxy)
		tex:SetVertexOffset(2, bx - minx, by - miny)
		tex:SetVertexOffset(3, cx - maxx, cy - maxy)
		tex:SetVertexOffset(4, dx - maxx, dy - miny)
	end
end

-- Shapes on a sheet, as { u, v } corners (u from the spine, v up from the
-- middle): upper-left, lower-left, upper-right, lower-right.
local function rect(u0, u1, v0, v1) return { u0, v0, u0, v1, u1, v0, u1, v1 } end
local function diamond(u, v, rw, rh)
	rh = rh or rw
	return { u, v + rh, u - rw, v, u + rw, v, u, v - rh }
end
-- A star point from (cu, cv) toward (dx, dy): base at r0, tip at r1.
local function spike(cu, cv, dx, dy, r0, r1, w)
	local m = r0 + (r1 - r0) * 0.3
	return { cu + dx * r1, cv + dy * r1, cu + dx * m - dy * w, cv + dy * m + dx * w,
		cu + dx * m + dy * w, cv + dy * m - dx * w, cu + dx * r0, cv + dy * r0 }
end
-- A corner guard: a triangle in the corner (u, v), legs running in and
-- up or down (sv).
local function guard(u, v, leg, sv)
	return { u - leg, v, u, v + sv * leg, u, v, u, v + sv * leg }
end

local function face(parent, level)
	local fr = parent
	if level then
		fr = CreateFrame("Frame", nil, parent)
		fr:SetFrameLevel(level)
		fr:SetAllPoints(anchor)
	end
	return { frame = fr, parts = {}, ovals = {} }
end

-- A texture on a face: shape is one of the shapes above. Non-rectangles
-- need the corner offsets, and are left out on a client without them.
local function part(fc, layer, sub, pts, shape)
	local tex = fc.frame:CreateTexture(nil, layer, nil, sub)
	tex:SetTexture(T.WHITE)
	if tex.SetSnapToPixelGrid then
		tex:SetSnapToPixelGrid(false)
		tex:SetTexelSnappingBias(0)
	end
	local p = { tex = tex, pts = pts, shape = shape }
	fc.parts[#fc.parts + 1] = p
	return tex, p
end

-- Round things (the emblem): kept round, narrowed as the sheet turns.
local function oval(fc, size, sub, u, v)
	local tex = T.Circle(fc.frame, size, "ARTWORK", sub)
	fc.ovals[#fc.ovals + 1] = { tex = tex, u = u, v = v, r = size / 2 }
	return tex
end

local function solid(tex, c, a) tex:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end

local function poseFace(fc, th)
	for _, p in ipairs(fc.parts) do
		if p.shape and not p.tex.SetVertexOffset then
			p.tex:Hide()
		else
			local q = p.pts
			local x1, s1 = proj(th, q[1])
			local x2, s2 = proj(th, q[3])
			local x3, s3 = proj(th, q[5])
			local x4, s4 = proj(th, q[7])
			quad(p.tex, x1, q[2] * s1, x2, q[4] * s2, x3, q[6] * s3, x4, q[8] * s4)
		end
	end
	for _, o in ipairs(fc.ovals) do
		local x0 = proj(th, o.u - o.r)
		local x1 = proj(th, o.u + o.r)
		local _, s = proj(th, o.u)
		o.tex:ClearAllPoints()
		o.tex:SetPoint("CENTER", anchor, "CENTER", (x0 + x1) / 2, o.v * s)
		o.tex:SetSize(math.max(0.5, math.abs(x1 - x0)), o.r * 2 * s)
	end
end

-- How lit a face is (1 = lying flat): the light comes from above and to
-- the left of you. front: the face that is up when the sheet lies on the
-- right.
local LIGHT_FLAT = 0.42 + 0.58 * 0.91
local function lightOf(th, front)
	local c, sn = math.cos(th), math.sin(th)
	local d = front and (0.41 * sn + 0.91 * c) or (-0.41 * sn - 0.91 * c)
	return (0.42 + 0.58 * math.max(0, d)) / LIGHT_FLAT
end

-- A page as it lies in the book: paper, shading into the fold, curling
-- away at the outer edge.
local function pageParts(fc)
	local paper = part(fc, "BACKGROUND", 0, rect(0, PAGE_W, PG_TOP, PG_BOT))
	local fold = part(fc, "BACKGROUND", 1, rect(0, 84, PG_TOP, PG_BOT))
	local crease = part(fc, "BACKGROUND", 2, rect(0, 10, PG_TOP, PG_BOT))
	local curl = part(fc, "BACKGROUND", 1, rect(PAGE_W - 30, PAGE_W, PG_TOP, PG_BOT))
	T.OnTheme(function(look)
		solid(paper, look.page)
		local sp = look.spine
		T.Gradient(fold, "HORIZONTAL", sp[1], sp[2], sp[3], 0.30, 0)
		T.Gradient(crease, "HORIZONTAL", sp[1], sp[2], sp[3], 0.22, 0)
		T.Gradient(curl, "HORIZONTAL", sp[1], sp[2], sp[3], 0, 0.10)
	end)
end

local function brassGuards(fc, leg)
	local list = {}
	for _, sv in ipairs({ -1, 1 }) do
		local v = sv < 0 and TOP_V or BOT_V
		list[#list + 1] = { part(fc, "OVERLAY", 0, guard(R, v, leg, sv), true), 1 }
		list[#list + 1] = { part(fc, "OVERLAY", 1, guard(R - 3, v + sv * 3, leg - 12, sv), true), 2 }
		list[#list + 1] = { part(fc, "OVERLAY", 2, diamond(R - leg * 0.3, v + sv * leg * 0.3, 2.2), true), 3 }
	end
	T.OnTheme(function()
		for _, g in ipairs(list) do
			if g[2] == 1 then solid(g[1], BRASS)
			elseif g[2] == 2 then g[1]:SetVertexColor(0.88, 0.74, 0.48, 0.55)
			else g[1]:SetVertexColor(0.24, 0.16, 0.08, 0.9) end
		end
	end)
end

-- The cover: tooled leather, brass corners, the emblem, and whose book it is.
local coverFonts = {}
local function coverFont(name, size)
	if coverFonts[name] then return coverFonts[name] end
	local f = CreateFont("LeagueOfExplorersCover" .. name)
	f:SetFont("Fonts\\MORPHEUS.TTF", size, "")
	f:SetShadowColor(0, 0, 0, 0.9)
	f:SetShadowOffset(1, -1)
	coverFonts[name] = f
	return f
end

local function makeFront(fc, level)
	local JOINT = 38
	local UC = (JOINT + R) / 2 -- the middle of the panel
	local VC = 30              -- the emblem's height
	local look = T.Look()

	-- The leather: lighter toward the top, darker toward its edges, and
	-- the joint where it bends round the spine.
	local leather = part(fc, "BACKGROUND", -8, rect(0, R, TOP_V, BOT_V))
	local tone = part(fc, "BACKGROUND", -7, rect(0, R, TOP_V, BOT_V))
	local spine = part(fc, "BACKGROUND", -6, rect(0, JOINT, TOP_V, BOT_V))
	local vEdge = part(fc, "BACKGROUND", -5, rect(R - 70, R, TOP_V, BOT_V))
	local vTop = part(fc, "BACKGROUND", -5, rect(0, R, TOP_V, TOP_V - 60))
	local vBot = part(fc, "BACKGROUND", -5, rect(0, R, BOT_V + 60, BOT_V))
	local groove = part(fc, "BORDER", 0, rect(JOINT, JOINT + 2, TOP_V, BOT_V))
	local ridge = part(fc, "BORDER", 0, rect(JOINT + 2, JOINT + 3, TOP_V, BOT_V))
	local bands = {}
	for _, v in ipairs({ 205, 72, -72, -205 }) do
		bands[#bands + 1] = { part(fc, "BORDER", 1, rect(3, JOINT - 4, v + 6, v + 4)), true }
		bands[#bands + 1] = { part(fc, "BORDER", 1, rect(3, JOINT - 4, v - 3, v - 6)), false }
	end

	-- Tooling: a gold rule, a blind rule inside it, and a fine gold rule
	-- inside that, with a diamond at each corner.
	local tooled = {}
	local function frameRule(inset, thick, kind)
		local l, r, t, b = JOINT + inset, R - inset, TOP_V - inset, BOT_V + inset
		for _, q in ipairs({ rect(l, r, t, t - thick), rect(l, r, b + thick, b), rect(l, l + thick, t, b), rect(r - thick, r, t, b) }) do
			tooled[#tooled + 1] = { part(fc, "ARTWORK", -2, q), kind }
		end
		return l, r, t, b
	end
	local l, r, t, b = frameRule(18, 2, "gold")
	frameRule(25, 1, "blind")
	local l2, r2, t2, b2 = frameRule(31, 1, "fine")
	for _, c in ipairs({ { l, t }, { r, t }, { l, b }, { r, b } }) do
		tooled[#tooled + 1] = { part(fc, "ARTWORK", -1, diamond(c[1], c[2], 6), true), "gold" }
	end
	for _, c in ipairs({ { l2, t2 }, { r2, t2 }, { l2, b2 }, { r2, b2 } }) do
		tooled[#tooled + 1] = { part(fc, "ARTWORK", -1, diamond(c[1], c[2], 3), true), "gold" }
	end
	-- Rules under the title and over the owner's name, a diamond in each.
	for _, v in ipairs({ 158, -92 }) do
		tooled[#tooled + 1] = { part(fc, "ARTWORK", -1, rect(UC - 104, UC - 10, v + 0.6, v - 0.6)), "fine" }
		tooled[#tooled + 1] = { part(fc, "ARTWORK", -1, rect(UC + 10, UC + 104, v + 0.6, v - 0.6)), "fine" }
		tooled[#tooled + 1] = { part(fc, "ARTWORK", -1, diamond(UC, v, 5), true), "gold" }
	end
	for i, du in ipairs({ -16, 0, 16 }) do
		tooled[#tooled + 1] = { part(fc, "ARTWORK", -1, diamond(UC + du, -232, i == 2 and 4 or 3), true), "gold" }
	end

	-- The emblem: a compass star behind a gold ring round the spyglass.
	for k = 0, 7 do
		local a = k * math.pi / 4
		local long = k % 2 == 0
		tooled[#tooled + 1] = { part(fc, "ARTWORK", long and 0 or -1,
			spike(UC, VC, math.sin(a), math.cos(a), 40, long and 88 or 66, long and 7 or 5), true), long and "gold" or "dim" }
	end
	local ring = oval(fc, 98, 1, UC, VC)
	local well = oval(fc, 90, 2, UC, VC)
	local seal = oval(fc, 84, 3, UC, VC)
	seal:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
	seal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if seal.SetDesaturated then seal:SetDesaturated(true) end

	brassGuards(fc, 30)

	-- A sheen across the leather, moving as the cover turns to the light.
	local sheenA, pa = part(fc, "OVERLAY", 4, rect(0, 1, TOP_V, BOT_V))
	local sheenB, pb = part(fc, "OVERLAY", 4, rect(0, 1, TOP_V, BOT_V))
	fc.shade = part(fc, "OVERLAY", 7, rect(0, R, TOP_V, BOT_V))
	function fc.update(th)
		local uc = math.max(100, R * 0.80 - R * th)
		pa.pts = rect(uc - 90, uc, TOP_V, BOT_V)
		pb.pts = rect(uc, uc + 90, TOP_V, BOT_V)
		local a = 0.03 + 0.09 * math.max(0, 1 - math.abs(th - 0.32) / 0.4)
		T.Gradient(sheenA, "HORIZONTAL", 1, 0.92, 0.78, 0, a)
		T.Gradient(sheenB, "HORIZONTAL", 1, 0.92, 0.78, a, 0)
	end

	-- The words: stamped in gold. FontStrings can't be narrowed, so they
	-- are scaled with the cover's depth and fade as it turns edge-on.
	local w = CreateFrame("Frame", nil, fc.frame)
	w:SetFrameLevel(level + 2)
	w:SetSize(R - JOINT - 70, BOOK_H)
	fc.words, fc.wordsU = w, UC
	local function line(text, font, size, v, dim)
		local fs = w:CreateFontString(nil, "OVERLAY")
		fs:SetFontObject(coverFont(font, size))
		fs:SetWidth(R - JOINT - 80)
		fs:SetWordWrap(false)
		fs:SetJustifyH("CENTER")
		fs:SetPoint("CENTER", w, "CENTER", 0, v)
		fs:SetText(text)
		fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3], dim and 0.78 or 1)
		return fs
	end
	line("League of", "Small", 20, 222)
	line("Explorers", "Big", 38, 190)
	fc.owned = line("Owned by", "Label", 15, -118, true)
	fc.name = line("", "Name", 28, -148)
	fc.rank = line("", "Rank", 16, -180, true)

	T.OnTheme(function(lk)
		look = lk
		solid(leather, lk.cover, 1)
		T.Gradient(tone, "VERTICAL", 1, 0.86, 0.70, 0, 0.07)
		T.Gradient(spine, "HORIZONTAL", 0, 0, 0, 0.40, 0.18)
		T.Gradient(vEdge, "HORIZONTAL", 0, 0, 0, 0, 0.32)
		T.Gradient(vTop, "VERTICAL", 0, 0, 0, 0, 0.28)
		T.Gradient(vBot, "VERTICAL", 0, 0, 0, 0.32, 0)
		groove:SetVertexColor(0, 0, 0, 0.55)
		ridge:SetVertexColor(1, 0.9, 0.75, 0.08)
		for _, bd in ipairs(bands) do
			if bd[2] then bd[1]:SetVertexColor(1, 0.9, 0.75, 0.10) else bd[1]:SetVertexColor(0, 0, 0, 0.40) end
		end
		for _, x in ipairs(tooled) do
			if x[2] == "gold" then solid(x[1], GOLD, 0.92)
			elseif x[2] == "dim" then solid(x[1], GOLD, 0.60)
			elseif x[2] == "fine" then solid(x[1], GOLD, 0.55)
			else x[1]:SetVertexColor(0, 0, 0, 0.35) end
		end
		solid(ring, GOLD, 1)
		solid(well, lk.cover, 1)
		seal:SetVertexColor(0.98, 0.80, 0.48, 1)
		fc.shade:SetVertexColor(0, 0, 0, 0)
	end)
end

-- The inside of the cover: its leather turned in round a pasted-down
-- endpaper, which is the left page's place in the open book.
local function makeInside(fc)
	local leather = part(fc, "BACKGROUND", -8, rect(0, R, TOP_V, BOT_V))
	pageParts(fc)
	brassGuards(fc, 26)
	fc.shade = part(fc, "OVERLAY", 7, rect(0, R, TOP_V, BOT_V))
	T.OnTheme(function(look)
		solid(leather, look.cover, 1)
		fc.shade:SetVertexColor(0, 0, 0, 0)
	end)
end

-- A flyleaf: a blank page, with a highlight on its free edge.
local function makeFlyleaf(f, i)
	local sh = { i = i, reach = PAGE_W, v0 = PG_TOP, v1 = PG_BOT, castLeft = true }
	sh.frame = CreateFrame("Frame", nil, f)
	sh.frame:SetAllPoints(anchor)
	sh.front = face(sh.frame)
	pageParts(sh.front)
	sh.front.rim = part(sh.front, "ARTWORK", 0, rect(PAGE_W - 1.5, PAGE_W, PG_TOP, PG_BOT))
	sh.front.shade = part(sh.front, "OVERLAY", 7, rect(0, PAGE_W, PG_TOP, PG_BOT))
	sh.cast = sh.frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	sh.frame:Hide()
	return sh
end

local function makeCoverSheet(f, b)
	local sh = { reach = R, v0 = TOP_V, v1 = BOT_V }
	local base = b:GetFrameLevel() + 40
	sh.frame = CreateFrame("Frame", nil, f)
	sh.frame:SetFrameLevel(base)
	sh.frame:SetAllPoints(b)
	sh.front = face(sh.frame, base + 1)
	makeFront(sh.front, base + 1)
	sh.back = face(sh.frame, base + 1)
	makeInside(sh.back)
	sh.cast = sh.frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	sh.cast:SetTexture(T.WHITE)
	sh.edge = sh.frame:CreateTexture(nil, "ARTWORK", nil, 0)
	sh.edge:SetTexture(T.WHITE)
	sh.rim = sh.frame:CreateTexture(nil, "ARTWORK", nil, 1)
	sh.rim:SetTexture(T.WHITE)
	sh.frame:Hide()
	return sh
end

-- Draws a sheet turned to th (0 lying on the right, pi on the left).
local function poseSheet(sh, th)
	local c, sn = math.cos(th), math.sin(th)
	local up = c >= 0
	local fc = (up or not sh.back) and sh.front or sh.back
	if sh.back then
		sh.front.frame:SetShown(fc == sh.front)
		sh.back.frame:SetShown(fc == sh.back)
	end
	-- Flyleaves lie under the cover on the right and over it on the left.
	if sh.i then
		local lv = anchor:GetFrameLevel() + (up and (39 - sh.i) or (50 + sh.i))
		if sh.frame:GetFrameLevel() ~= lv then sh.frame:SetFrameLevel(lv) end
	end
	if fc.update then fc.update(th) end
	poseFace(fc, th)

	local lit = lightOf(th, up)
	fc.shade:SetVertexColor(0, 0, 0, clamp01(1 - lit) * 0.95)
	if fc.rim then fc.rim:SetVertexColor(1, 1, 1, 0.5 * sn) end
	if fc.words then
		local x, s = proj(th, fc.wordsU)
		fc.words:SetScale(s)
		fc.words:ClearAllPoints()
		fc.words:SetPoint("CENTER", anchor, "CENTER", x / s, 0)
		local fade = clamp01((c - 0.5) / 0.5)
		fc.words:SetAlpha(fade * fade * math.min(1, lit))
	end

	local xf, sf = proj(th, sh.reach)
	-- The board's edge, standing out past the face as the cover stands up.
	if sh.edge then
		local dir = up and 1 or -1
		local xo = xf + dir * BOARD * sn * sf
		local show = math.abs(xo - xf) > 0.3
		sh.edge:SetShown(show)
		sh.rim:SetShown(show)
		if show then
			quad(sh.edge, xf, TOP_V * sf, xf, BOT_V * sf, xo, TOP_V * sf, xo, BOT_V * sf)
			quad(sh.rim, xo - dir, TOP_V * sf, xo - dir, BOT_V * sf, xo, TOP_V * sf, xo, BOT_V * sf)
			local cv = T.Look().cover
			-- Lit as it faces up and toward the light.
			local k = 0.55 + 0.75 * math.max(0, -0.41 * c + 0.91 * sn)
			sh.edge:SetVertexColor(cv[1] * k, cv[2] * k, cv[3] * k, 1)
			sh.rim:SetVertexColor(1, 0.88, 0.66, 0.35 * sn)
		end
	end

	-- Its shadow, past its free edge on what lies beneath: wider and softer
	-- the higher it is. The light is from the left, so it falls mostly to
	-- the right; the cover throws none on the empty left.
	local a = 0.34 * math.min(1, sn * 5) * (1 - 0.45 * sn)
	local cast = sh.cast
	if up and a > 0.01 then
		local x1 = math.min(R, xf + 8 + 52 * sn)
		if x1 - xf > 1 then
			quad(cast, xf, sh.v0, xf, sh.v1, x1, sh.v0, x1, sh.v1)
			T.Gradient(cast, "HORIZONTAL", 0, 0, 0, a, 0)
		end
		cast:SetShown(x1 - xf > 1)
	elseif not up and sh.castLeft and a > 0.01 then
		local x0 = math.max(-R, xf - 6 - 28 * sn)
		if xf - x0 > 1 then
			quad(cast, x0, sh.v0, x0, sh.v1, xf, sh.v0, xf, sh.v1)
			T.Gradient(cast, "HORIZONTAL", 0, 0, 0, 0, a * 0.6)
		end
		cast:SetShown(xf - x0 > 1)
	else
		cast:Hide()
	end
end

local function makeTome(f, b)
	anchor = b
	local tm = { cover = makeCoverSheet(f, b) }
	tm.leaves = { makeFlyleaf(f, 1), makeFlyleaf(f, 2) }
	tm.all = { tm.cover, tm.leaves[1], tm.leaves[2] }
	return tm
end

-- Whose book: your main's name and rank.
local function owner()
	local me = ns.Me()
	if not me then return nil end
	local P = ns.Points
	local who = (P and P.Player) and P.Player(me) or me
	local rank
	if P and P.RankOf then
		local ok, _, r = pcall(P.RankOf, who)
		rank = ok and r and r.name or nil
	end
	return ns.ShortName(who), rank
end

local tome
local closing = false

-- Escape: the game hides this stand-in (it's in UISpecialFrames, the book
-- isn't), and the book closes itself the slow way. quiet: hidden by us.
local escProxy
local function escape(on)
	if not escProxy then return end
	escProxy.quiet = true
	escProxy:SetShown(on)
	escProxy.quiet = false
end

-- The cover and flyleaves (for the tests).
function J.Tome() return tome end

local function writeCover()
	local fc = tome.cover.front
	local name, rank = owner()
	fc.name:SetText(name or "")
	fc.rank:SetText(rank or "")
	fc.owned:SetShown(name ~= nil)
end

local function leftRibbons(a)
	for _, r in pairs(frame.ribbons or {}) do
		if r.x and r.x < R then r:SetAlpha(a) end
	end
end

local function settle()
	if tome then
		for _, sh in ipairs(tome.all) do
			sh.frame:Hide()
			sh.frame:SetAlpha(1)
		end
	end
	if frame then
		frame.clip:SetWidth(BOOK_W)
		frame:SetAlpha(1)
		leftRibbons(1)
	end
end

local function swing(q) return 0.5 * q * q + 0.5 * q * q * (3 - 2 * q) end -- lifted gently, falls under its weight
local function float(q) return q * q * (3 - 2 * q) end                      -- a page: lighter, settles softly

-- A sheet's angle at a moment: still until start, over in dur, then a
-- small bounce off what it lands on.
local function angle(now, start, dur, curve, amp, bounce)
	if now <= start then return 0 end
	local q = (now - start) / dur
	if q < 1 then return math.pi * curve(q) end
	local k = (now - start - dur) / bounce
	if k >= 1 then return math.pi end
	return math.pi - amp * math.sin(math.pi * k) * (1 - k)
end

-- The cover swings open and the flyleaves follow; then the left page shows.
function J.PlayOpen()
	closing = false
	escape(true)
	local cv, l1, l2 = tome.cover, tome.leaves[1], tome.leaves[2]
	writeCover()
	frame.clip:SetWidth(R)
	leftRibbons(0)
	for _, sh in ipairs(tome.all) do
		sh.frame:SetAlpha(1)
		sh.frame:Show()
		poseSheet(sh, 0)
	end
	frame:SetAlpha(0)
	local turned, shown = false, false
	T.SetProgress(cv, 0)
	T.Tween(cv, 1, OPEN_TIME, function(p)
		local now = p * OPEN_TIME
		frame:SetAlpha(clamp01(now / 0.10))
		poseSheet(cv, angle(now, 0.06, 0.56, swing, 0.10, 0.16))
		poseSheet(l1, angle(now, 0.20, 0.50, float, 0.06, 0.12))
		poseSheet(l2, angle(now, 0.30, 0.50, float, 0.05, 0.10))
		if not turned and now >= 0.20 then
			turned = true
			sound("IG_ABILITY_PAGE_TURN")
		end
		if now >= 0.86 then
			if not shown then
				shown = true
				frame.clip:SetWidth(BOOK_W)
			end
			local q = clamp01((now - 0.86) / 0.14)
			for _, sh in ipairs(tome.all) do sh.frame:SetAlpha(1 - q) end
			leftRibbons(q)
		end
		if p >= 1 then settle() end
	end)
end

-- Closes the book: the left half swings back over and lands shut, then
-- the book fades.
function J.Close()
	if mapOn() then return J.CloseMap() end
	if not (frame and frame:IsShown()) or closing then return end
	if book.leaf:IsShown() and book.leaf.finish then book.leaf.finish() end
	if frame.settings then frame.settings:Hide() end
	escape(false)
	if not animOn() then
		frame:Hide()
		return
	end
	closing = true
	local cv, l1, l2 = tome.cover, tome.leaves[1], tome.leaves[2]
	writeCover()
	for _, sh in ipairs(tome.all) do
		sh.frame:SetAlpha(0)
		sh.frame:Show()
		poseSheet(sh, math.pi)
	end
	local thumped, lifted = false, false
	T.SetProgress(cv, 0)
	T.Tween(cv, 1, CLOSE_TIME, function(p)
		local now = p * CLOSE_TIME
		if now < 0.12 then
			-- The page's writing gives way to the sheets about to lift.
			local q = now / 0.12
			for _, sh in ipairs(tome.all) do sh.frame:SetAlpha(q) end
			leftRibbons(1 - q)
		else
			if not lifted then
				lifted = true
				for _, sh in ipairs(tome.all) do sh.frame:SetAlpha(1) end
				leftRibbons(0)
				frame.clip:SetWidth(R)
			end
			local th = math.pi - angle(now, 0.12, 0.56, swing, 0.10, 0.14)
			poseSheet(cv, th)
			-- The leaves go over with the cover, and under it once past upright.
			local withIt = th > math.pi / 2
			l1.frame:SetShown(withIt)
			l2.frame:SetShown(withIt)
			if withIt then
				poseSheet(l1, th)
				poseSheet(l2, th)
			end
		end
		if not thumped and now >= 0.68 then
			thumped = true
			sound("IG_SPELLBOOK_CLOSE")
		end
		if now > 0.80 then frame:SetAlpha(1 - clamp01((now - 0.80) / 0.15)) end
		if p >= 1 then
			closing = false
			frame:Hide()
			settle()
		end
	end)
end

-- The bookmarks of the pages there are, in order, side by side: three
-- over the left page, then the rest over the right.
local RIBBON_SLOT = (PAGE_W - 24) / 3
function J.PlaceRibbons()
	if not frame then return end
	local list = shown()
	local per = 3
	for _, r in pairs(frame.ribbons) do r:Hide() end
	for i, s in ipairs(list) do
		local r = frame.ribbons[s.id]
		local onLeft = i <= per
		local n = onLeft and (i - 1) or (i - 1 - per)
		local x = (onLeft and COVER or (BOOK_W - COVER - PAGE_W)) + 12 + n * RIBBON_SLOT + 4
		r.x = x
		r:ClearAllPoints()
		r:SetPoint("BOTTOMLEFT", book, "TOPLEFT", x, -6)
		r:SetLabel(titleOf(s))
		r:Show()
	end
end

local function build()
	local f = CreateFrame("Frame", "LeagueOfExplorersJournal", UIParent)
	frame = f
	f:SetSize(BOOK_W, BOOK_H + TOP)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint()
		ns.db.settings.pos = { point = point, x = x, y = y }
	end)
	local pos = ns.db.settings.pos
	if pos and pos.point then
		f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
	else
		f:SetPoint("CENTER", 0, 20)
	end
	f:Hide()
	escProxy = CreateFrame("Frame", "LeagueOfExplorersJournalEscape", UIParent)
	escProxy:SetSize(1, 1)
	escProxy:Hide()
	escProxy:SetScript("OnHide", function(self)
		-- Hidden with the whole interface, or by us: not Escape.
		if self:IsShown() or self.quiet then return end
		J.Close()
	end)
	table.insert(UISpecialFrames, "LeagueOfExplorersJournalEscape")
	f:SetScript("OnShow", function(self)
		sound("IG_SPELLBOOK_OPEN")
		if animOn() then
			J.PlayOpen()
		else
			escape(true)
			T.FadeIn(self, 0.18)
		end
	end)
	f:SetScript("OnHide", function(self)
		-- The whole interface hidden (not the book): nothing to do.
		if self:IsShown() then return end
		if f.settings then f.settings:Hide() end
		escape(false)
		if not animOn() then sound("IG_SPELLBOOK_CLOSE") end
		closing = false
		settle()
	end)

	-- Everything of the book is drawn inside this, so the left half can be
	-- clipped away while the book is shut (see the tome above).
	f.clip = CreateFrame("Frame", nil, f)
	f.clip:SetPoint("TOPRIGHT")
	f.clip:SetPoint("BOTTOMRIGHT")
	f.clip:SetWidth(BOOK_W)
	if f.clip.SetClipsChildren then f.clip:SetClipsChildren(true) end

	-- The book sits above its bookmarks, so they look tucked into it.
	book = CreateFrame("Frame", nil, f.clip)
	book:SetSize(BOOK_W, BOOK_H)
	book:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
	book:SetFrameLevel(f:GetFrameLevel() + 6)
	book.cover = book:CreateTexture(nil, "BACKGROUND", nil, -8)
	book.cover:SetAllPoints()
	book.edge = T.Border(book)
	book.inner = CreateFrame("Frame", nil, book)
	book.inner:SetPoint("TOPLEFT", 5, -5)
	book.inner:SetPoint("BOTTOMRIGHT", -5, 5)
	book.innerEdge = T.Border(book.inner)
	-- The fold where the pages meet.
	book.spineFrame = CreateFrame("Frame", nil, book)
	book.spineFrame:SetAllPoints()
	book.spineFrame:SetFrameLevel(book:GetFrameLevel() + 3)
	book.spine = book.spineFrame:CreateTexture(nil, "ARTWORK")
	book.spine:SetWidth(2)
	book.spine:SetPoint("TOP", 0, -COVER)
	book.spine:SetPoint("BOTTOM", 0, COVER + BLOCK * 2)
	book.corners = {
		makeCorner(book, "TOPLEFT"), makeCorner(book, "TOPRIGHT"),
		makeCorner(book, "BOTTOMLEFT"), makeCorner(book, "BOTTOMRIGHT"),
	}

	book.left = makePage(book, "left")
	book.right = makePage(book, "right")
	book.leaf = makeLeaf(book)
	tome = makeTome(f, book)

	f.title = T.Text(book.left.area, "", "Huge", "heading", J.PW)
	f.title:SetPoint("TOPLEFT")
	f.title:SetWordWrap(false)
	f.info = T.Text(book.left.area, "", "Small", "subtle", J.PW)
	f.info:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
	f.info:SetSpacing(2)
	-- Two lines fit above the rule; anything longer is cut, not overlapped.
	if f.info.SetMaxLines then f.info:SetMaxLines(2) end
	f.rule = W.Divider(book.left.area)
	f.rule:SetPoint("TOPLEFT", 0, -HEAD + 8)
	f.rule:SetPoint("TOPRIGHT", 0, -HEAD + 8)

	-- Bookmarks: three over each page, as in the sketch.
	f.ribbons = {}
	for _, s in ipairs(sections) do
		f.ribbons[s.id] = makeRibbon(f.clip, s, RIBBON_SLOT - 8)
	end
	J.PlaceRibbons()

	-- Close and settings sit in the right page's top corner, inside its margin.
	f.close = W.RoundButton(book, 18, "close", function() J.Close() end)
	f.close:SetPoint("TOPRIGHT", book.right, "TOPRIGHT", -3, -3)
	f.close:SetFrameLevel(book:GetFrameLevel() + 20)
	f.gear = W.RoundButton(book, 18, "Interface\\Icons\\INV_Misc_Gear_01", function()
		f.settings:SetShown(not f.settings:IsShown())
	end)
	f.gear:SetFrameLevel(book:GetFrameLevel() + 20)
	-- The Ko-fi cup, beside the cog.
	if ns.Support then
		f.kofi = ns.Support.Button(book)
		f.kofi:SetPoint("RIGHT", f.gear, "LEFT", -4, 0)
		f.kofi:SetFrameLevel(book:GetFrameLevel() + 20)
	end
	f.gear:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Settings")
		GameTooltip:Show()
	end)
	f.gear:HookScript("OnLeave", function() GameTooltip:Hide() end)
	f.settings = buildSettings(f)
	f.settings:SetPoint("TOPRIGHT", book.right, "TOPRIGHT", -6, -30)

	for _, s in ipairs(sections) do
		s.left = CreateFrame("Frame", nil, book.left.area)
		s.left:SetPoint("TOPLEFT", 0, -HEAD)
		s.left:SetSize(J.PW, J.PH - HEAD)
		s.right = CreateFrame("Frame", nil, book.right.area)
		s.right:SetAllPoints()
		s.left:Hide()
		s.right:Hide()
	end

	f.gear:ClearAllPoints()
	f.gear:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
	T.OnTheme(function(look)
		T.Fill(book.cover, look.cover)
		local e = look.coverEdge
		book.edge:SetColor(e[1], e[2], e[3], e[4])
		book.innerEdge:SetColor(e[1], e[2], e[3], (e[4] or 1) * 0.5)
		local sp = look.spine
		book.spine:SetColorTexture(sp[1], sp[2], sp[3], 0.35)
		for _, c in ipairs(book.corners) do
			c.parts[1]:SetVertexColor(0.70, 0.53, 0.28, 1)
			c.parts[2]:SetVertexColor(0.86, 0.70, 0.42, 0.55)
		end
	end)
end

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------
local function ensure(s)
	if s.built then return s.ok end
	s.built = true
	local ok, err = pcall(s.build, s.left, s.right)
	s.ok = ok
	if not ok then
		geterrorhandler()(err)
		local msg = T.Text(s.left, "This page failed to load. The other pages still work.", "Body", "subtle", J.PW)
		msg:SetPoint("TOPLEFT", 0, -20)
	end
	return ok
end

local function refresh(s)
	if s and s.refresh and s.ok then
		local ok, err = pcall(s.refresh, s.left, s.right)
		if not ok then geterrorhandler()(err) end
	end
end

-- The title, page info and page number belong to the left page.
local function writeLeft(s)
	frame.title:SetText(s.heading and s.heading() or titleOf(s))
	frame.info:SetText(infoOf(s) or "")
	book.left.number:SetText(pageOf(s))
end

local function showOnly(s)
	for _, other in ipairs(sections) do
		other.left:SetShown(other == s)
		other.right:SetShown(other == s)
	end
	writeLeft(s)
	book.right.number:SetText(pageOf(s) + 1)
end

local function showNow(s)
	showOnly(s)
	refresh(s)
end

-- Turning from one section to another, forward or back by bookmark order.
local function turn(old, new)
	local forward = new.order > old.order
	sound("IG_ABILITY_PAGE_TURN")
	book.leaf:Play(forward, function()
		-- Beneath the lifting leaf, the new page is already there.
		refresh(new)
		if forward then
			old.right:Hide()
			new.right:Show()
			book.right.number:SetText(pageOf(new) + 1)
		else
			old.left:Hide()
			new.left:Show()
			writeLeft(new)
		end
	end, function()
		-- The leaf lands: the facing page is the new one too.
		showOnly(new)
	end)
end

---------------------------------------------------------------------------
-- The map look: the same pages in a window with the live map of where you
-- are across the top, tabs under it, and the two pages as dark panels side
-- by side (settings.shell = "map"; the book is the default). The pages'
-- writing areas, with the title and page info, move between the two
-- windows, so every page works in both.
---------------------------------------------------------------------------
local AREA_W, AREA_H = PAGE_W - 2 * INSET - 6, PAGE_H - 2 * INSET
local M_EDGE, M_GAP, M_PAD = 8, 10, 14
local M_BANNER, M_TAB = 100, 34
local M_PANEL_W, M_PANEL_H = AREA_W + 2 * M_PAD, AREA_H + 2 * M_PAD
local M_W = 2 * M_EDGE + 2 * M_PANEL_W + M_GAP
local M_H = M_EDGE + M_BANNER + M_TAB + M_GAP + M_PANEL_H + M_EDGE
local attached = "book"

-- The map over the window: where you are, and how much of it you've explored.
function J.UpdateBanner()
	if not (mframe and mframe:IsShown()) then return end
	local zone, focus = W.PlayerFocus()
	local b = { kicker = "You are in" }
	if zone then
		mframe.banner:SetMap(zone, focus, true)
		b.title = ns.MapName(zone) or ""
		local n, total = ns.Exploration.Progress(zone)
		local cont = ns.Exploration.ContinentOf(zone)
		local rec = ns.Char() and ns.Char().zones[zone]
		local done = rec and rec.full and true or false
		if total and total > 0 then
			b.sub = ("%s%d of %d areas explored"):format(cont and ((ns.MapName(cont) or "") .. "  /  ") or "", n, total)
			b.dots = { n, total, done }
			b.big = math.floor(n / total * 100 + 0.5) .. "%"
			b.bigLabel = done and "fully explored" or "explored"
			b.bigRole = done and "done" or "accent"
		else
			b.sub = cont and ns.MapName(cont) or ""
		end
	else
		mframe.banner:SetMap(nil)
		b.title = GetZoneText and GetZoneText() or ""
	end
	mframe.banner:SetHeadline(b)
end

-- The tabs: the pages there are in this mode.
local function mapTabs()
	local f = mframe
	if f.tabs then f.tabs:Hide() end
	local items = {}
	for _, s in ipairs(shown()) do items[#items + 1] = { id = s.id, label = titleOf(s), icon = s.icon } end
	f.tabs = W.Tabs(f.tabStrip, items, function(id) J.Show(id) end)
	f.tabs:SetPoint("LEFT", 2, 0)
	if current then f.tabs:Select(current.id) end
end

local function buildMap()
	local f = CreateFrame("Frame", "LeagueOfExplorersMapWindow", UIParent)
	mframe = f
	f:SetSize(M_W, M_H)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint()
		ns.db.settings.mapPos = { point = point, x = x, y = y }
	end)
	local pos = ns.db.settings.mapPos
	if pos and pos.point then
		f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
	else
		f:SetPoint("CENTER", 0, 20)
	end
	f:Hide()
	f:SetScript("OnShow", function(self)
		sound("IG_CHARACTER_INFO_OPEN")
		escape(true)
		T.FadeIn(self, 0.18)
	end)
	f:SetScript("OnHide", function(self)
		-- The whole interface hidden (not the window): nothing to do.
		if self:IsShown() then return end
		if frame and frame.settings then frame.settings:Hide() end
		escape(false)
		sound("IG_CHARACTER_INFO_CLOSE")
	end)
	-- The pin follows you while it's open.
	local acc = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + elapsed
		if acc < 1 then return end
		acc = 0
		J.UpdateBanner()
	end)

	f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.bg:SetAllPoints()
	f.edge = T.Border(f, "windowEdge")

	f.banner = W.MapBanner(f, M_W - 2 * M_EDGE, M_BANNER)
	f.banner:SetPoint("TOPLEFT", M_EDGE, -M_EDGE)

	f.tabStrip = CreateFrame("Frame", nil, f)
	f.tabStrip:SetHeight(M_TAB)
	f.tabStrip:SetPoint("TOPLEFT", f.banner, "BOTTOMLEFT")
	f.tabStrip:SetPoint("TOPRIGHT", f.banner, "BOTTOMRIGHT")
	f.tabBg = f.tabStrip:CreateTexture(nil, "BACKGROUND")
	f.tabBg:SetAllPoints()
	local tabLine = T.Line(f.tabStrip, false, "line")
	tabLine:SetPoint("BOTTOMLEFT")
	tabLine:SetPoint("BOTTOMRIGHT")
	mapTabs()

	-- The two pages, side by side.
	f.panels = {}
	for i = 1, 2 do
		local p = W.Panel(f)
		p:SetSize(M_PANEL_W, M_PANEL_H)
		p:SetPoint("TOPLEFT", f.tabStrip, "BOTTOMLEFT", (i - 1) * (M_PANEL_W + M_GAP), -M_GAP)
		f.panels[i] = p
	end

	-- Close, settings and the Ko-fi cup, over the map.
	local top = f.banner:GetFrameLevel() + 20
	f.close = W.RoundButton(f, 22, "close", function() J.Close() end)
	f.close:SetPoint("TOPRIGHT", f.banner, "TOPRIGHT", -8, -8)
	f.close:SetFrameLevel(top)
	f.gear = W.RoundButton(f, 22, "Interface\\Icons\\INV_Misc_Gear_01", function()
		frame.settings:SetShown(not frame.settings:IsShown())
	end)
	f.gear:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
	f.gear:SetFrameLevel(top)
	f.gear:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Settings")
		GameTooltip:Show()
	end)
	f.gear:HookScript("OnLeave", function() GameTooltip:Hide() end)
	if ns.Support then
		f.kofi = ns.Support.Button(f)
		f.kofi:SetPoint("RIGHT", f.gear, "LEFT", -4, 0)
		f.kofi:SetFrameLevel(top)
	end

	T.OnTheme(function(look)
		local w = look.window
		f.bg:SetColorTexture(w[1], w[2], w[3], w[4] or 1)
		local e = look.windowEdge
		f.edge:SetColor(e[1], e[2], e[3], e[4])
		T.Fill(f.tabBg, look.tabBar or { 1, 1, 1, 0.025 })
	end)
end

-- Moves the pages' writing areas (and the settings) into the window in use.
local function attach()
	local want = mapOn() and "map" or "book"
	if attached == want then return end
	if want == "map" and not mframe then buildMap() end
	for i, page in ipairs({ book.left, book.right }) do
		local a = page.area
		a:ClearAllPoints()
		if want == "map" then
			local p = mframe.panels[i]
			a:SetParent(p)
			a:SetFrameLevel(p:GetFrameLevel() + 2)
			a:SetSize(AREA_W, AREA_H)
			a:SetPoint("TOPLEFT", M_PAD, -M_PAD)
		else
			local L = i == 1
			a:SetParent(page.inset)
			a:SetFrameLevel(page.inset:GetFrameLevel() + 1)
			a:SetPoint("TOPLEFT", INSET + (L and 0 or 6), -INSET)
			a:SetPoint("BOTTOMRIGHT", -INSET - (L and 6 or 0), INSET)
		end
	end
	local s = frame.settings
	s:ClearAllPoints()
	if want == "map" then
		s:SetParent(mframe)
		s:SetPoint("TOPRIGHT", mframe.gear, "BOTTOMRIGHT", 0, -6)
		s:SetFrameLevel(mframe:GetFrameLevel() + 60)
	else
		s:SetParent(frame)
		s:SetPoint("TOPRIGHT", book.right, "TOPRIGHT", -6, -30)
		s:SetFrameLevel(frame:GetFrameLevel() + 60)
	end
	attached = want
end

local function showMap(s, before)
	showOnly(s)
	mframe.tabs:Select(s.id)
	mframe:Show()
	refresh(s)
	J.UpdateBanner()
	if before and before ~= s then
		T.FadeIn(s.left, 0.2)
		T.FadeIn(s.right, 0.2)
	end
end

function J.CloseMap()
	if not (mframe and mframe:IsShown()) then return end
	if frame and frame.settings then frame.settings:Hide() end
	mframe:Hide()
end

-- Book or map: closes one and opens the other on the same page.
function J.SetShell(name)
	if not ns.db or (ns.db.settings.shell or "book") == name then return end
	local open = J.IsShown()
	local settingsOpen = frame and frame.settings and frame.settings:IsShown()
	if frame and frame:IsShown() then frame:Hide() end
	if mframe and mframe:IsShown() then mframe:Hide() end
	closing = false
	ns.db.settings.shell = name ~= "book" and name or nil
	T.Repaint()
	ns.Fire("LOOK_CHANGED")
	if open then
		J.Show(current and current.id)
		if settingsOpen then frame.settings:Show() end
	end
end

function J.Show(id)
	if not ns.db then return end
	if not frame then build() end
	local s = byId[id] or byId[ns.db.settings.page] or sections[1]
	if not available(s) then s = shown()[1] or s end
	local before = current
	-- A turn still under way finishes at once; the next one starts from there.
	if book.leaf:IsShown() and book.leaf.finish then book.leaf.finish() end
	current = s
	ns.db.settings.page = s.id
	ensure(s)
	for rid, r in pairs(frame.ribbons) do
		r:Rise(rid == s.id)
		r:Paint()
	end
	attach()
	if mapOn() then return showMap(s, before) end
	local opening = not frame:IsShown()
	-- Asked to open while it's closing: open again from where it is.
	if closing and animOn() then J.PlayOpen() end
	frame:Show()
	if before and before ~= s and not opening then
		turn(before, s)
	else
		showNow(s)
	end
end

function J.Toggle()
	if J.IsShown() and not closing then
		J.Close()
	else
		J.Show(ns.db.settings.page)
	end
end

function J.IsShown()
	return (frame and frame:IsShown()) or (mframe and mframe:IsShown()) or false
end

function J.Current() return current end

-- The book itself (for cards laid over it).
function J.Book() return mapOn() and mframe or book end

-- A section's two pages (for the demo, which sets what they show).
function J.Pages(id)
	local s = byId[id]
	if s then return s.left, s.right end
end

-- New entries, sightings and roster changes redraw the open section.
local pending = false
local function refreshSoon()
	if pending or not J.IsShown() then return end
	pending = true
	ns.After(0.25, function()
		pending = false
		if J.IsShown() and current then refresh(current) end
		J.UpdateBanner()
	end)
end
J.RefreshSoon = refreshSoon
ns.Listen("ENTRY_ADDED", refreshSoon)
ns.Listen("ENTRY_MERGED", refreshSoon)
ns.Listen("SIGHTING", refreshSoon)
ns.Listen("ROSTER", refreshSoon)
ns.Listen("MODE", function()
	if not frame then return end
	J.PlaceRibbons()
	if mframe then mapTabs() end
	if frame.settings and frame.settings:IsShown() then frame.settings:GetScript("OnShow")() end
	if current and not available(current) then
		if J.IsShown() then J.Show(shown()[1].id) else current = nil end
	elseif current and J.IsShown() then
		showNow(current)
	end
end)
ns.On("ZONE_CHANGED_NEW_AREA", refreshSoon)

-- /loe look [book|map]: switch between the book and the map window.
ns.Commands.look = function(rest)
	local name = (rest or ""):lower()
	if name ~= "book" and name ~= "map" then name = mapOn() and "book" or "map" end
	J.SetShell(name)
	ns.Print("look: " .. name)
end
