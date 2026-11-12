-- Widgets. Each paints itself for both looks through T.OnTheme.

local _, ns = ...

local T = ns.Theme
local WHITE, Skin = T.WHITE, T.Skin
local W = {}
ns.Widgets = W

local function sound(kit)
	if SOUNDKIT and SOUNDKIT[kit] then pcall(PlaySound, SOUNDKIT[kit]) end
end
W.Sound = sound

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------

-- A slate panel with a faint lit top edge; under the Blizzard look, the
-- game's inset frame on a dark wash.
function W.Panel(parent)
	local p = CreateFrame("Frame", nil, parent)
	p.bg = p:CreateTexture(nil, "BACKGROUND")
	p.bg:SetAllPoints()
	p.top = p:CreateTexture(nil, "BORDER")
	p.top:SetTexture(WHITE)
	p.top:SetPoint("TOPLEFT", 1, -1)
	p.top:SetPoint("TOPRIGHT", -1, -1)
	p.top:SetHeight(1)
	p.edge = T.Border(p)
	T.OnTheme(function(look)
		T.Fill(p.bg, look.panel)
		p.top:SetVertexColor(look.panelTop[1], look.panelTop[2], look.panelTop[3], look.panelTop[4])
		if look.skin and p.inset == nil then p.inset = Skin.NineSlice(p, "InsetFrameTemplate", 3) or false end
		local inset = look.skin and p.inset or nil
		if p.inset then p.inset:SetShown(inset and true or false) end
		p.edge:SetShown(not inset)
		local e = look.panelEdge
		p.edge:SetColor(e[1], e[2], e[3], e[4])
	end)
	return p
end

-- SMALL CAPITALS over a number or a list.
function W.Label(parent, text)
	return T.Text(parent, (text or ""):upper(), "Label", "label")
end

function W.Divider(parent)
	return T.Line(parent, false, "line", "ARTWORK")
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

-- A flat outlined button in the Explorer look; the game's red button in
-- the Blizzard look.
function W.Button(parent, text, w, h, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w or 120, h or 24)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetTexture(WHITE)
	b.edge = T.Border(b)
	b.pieces = {}
	for i = 1, 3 do
		b.pieces[i] = b:CreateTexture(nil, "BACKGROUND", nil, 1)
		b.pieces[i]:Hide()
	end
	b.pieces[1]:SetPoint("TOPLEFT")
	b.pieces[1]:SetPoint("BOTTOMLEFT")
	b.pieces[3]:SetPoint("TOPRIGHT")
	b.pieces[3]:SetPoint("BOTTOMRIGHT")
	b.pieces[2]:SetPoint("TOPLEFT", b.pieces[1], "TOPRIGHT")
	b.pieces[2]:SetPoint("BOTTOMRIGHT", b.pieces[3], "BOTTOMLEFT")
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints()
	b.hl:Hide()
	b.label = b:CreateFontString(nil, "OVERLAY")
	b.label:SetFontObject(T.FONTS.Small)
	b.label:SetPoint("LEFT", 8, 0)
	b.label:SetPoint("RIGHT", -8, 0)
	b.label:SetWordWrap(false)
	b:SetFontString(b.label)
	b:SetPushedTextOffset(0, -1)
	b:SetText(text or "")

	local function paint(p)
		local look = T.Look()
		local art = look.skin and Skin.ButtonArt()
		for i = 1, 3 do
			if art then Skin.Paint(b.pieces[i], art[i]) else b.pieces[i]:Hide() end
		end
		if art then
			b.pieces[1]:SetWidth(art.cap)
			b.pieces[3]:SetWidth(art.cap)
			Skin.Paint(b.hl, art.highlight)
		else
			b.hl:Hide()
		end
		b.bg:SetShown(not art)
		b.edge:SetShown(not art)
		b.bg:SetVertexColor(T.Mix(look.btn, look.btnHover, p))
		b.edge:SetColor(T.Mix(look.btnEdge, look.btnEdgeHover, p))
		local r, g, bl, a = T.Mix(look.btnText, look.btnTextHover, p)
		b.label:SetTextColor(r, g, bl, b:IsEnabled() and a or a * 0.4)
		for i = 1, 3 do b.pieces[i]:SetDesaturated(not b:IsEnabled()) end
	end
	b:SetScript("OnEnter", function(self) if self:IsEnabled() then T.Tween(self, 1, 0.12, paint) end end)
	b:SetScript("OnLeave", function(self) T.Tween(self, 0, 0.12, paint) end)
	b:SetScript("OnEnable", function(self) paint(T.Progress(self)) end)
	b:SetScript("OnDisable", function(self) T.Tween(self, 0, 0.01, paint) end)
	b:SetScript("OnClick", function(self)
		sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
		if onClick then onClick(self) end
	end)
	T.OnTheme(function() paint(T.Progress(b)) end)
	return b
end

-- A small round button over the map (close, settings): a dark disc with a
-- drawn glyph or an icon.
function W.RoundButton(parent, size, glyph, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.disc = T.Circle(b, size, "BACKGROUND")
	b.disc:SetPoint("CENTER")
	b.parts = {}
	if glyph == "close" then
		for i, angle in ipairs({ 45, -45 }) do
			local l = b:CreateTexture(nil, "ARTWORK")
			l:SetTexture(WHITE)
			l:SetSize(size * 0.42, math.max(1.5, size / 14))
			l:SetPoint("CENTER")
			l:SetRotation(math.rad(angle))
			b.parts[i] = l
		end
	else
		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:SetSize(size * 0.62, size * 0.62)
		icon:SetPoint("CENTER")
		icon:SetTexture(glyph)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		T.Round(icon)
		b.parts[1] = icon
		b.isIcon = true
	end
	local function paint(p)
		b.disc:SetVertexColor(0, 0, 0, 0.45 + 0.25 * p)
		local a = T.Look().accent
		for _, part in ipairs(b.parts) do
			if b.isIcon then
				part:SetVertexColor(1, 1, 1, 0.75 + 0.25 * p)
			else
				part:SetVertexColor(T.Mix({ 1, 1, 1, 0.8 }, { a[1], a[2], a[3], 1 }, p))
			end
		end
	end
	b:SetScript("OnEnter", function(self) T.Tween(self, 1, 0.12, paint) end)
	b:SetScript("OnLeave", function(self) T.Tween(self, 0, 0.12, paint) end)
	b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
	T.OnTheme(function() paint(T.Progress(b)) end)
	return b
end

---------------------------------------------------------------------------
-- Tabs: icon and name, with an accent underline on the open one.
-- items = { { id, label, icon }, ... }
---------------------------------------------------------------------------
function W.Tabs(parent, items, onSelect)
	local bar = CreateFrame("Frame", nil, parent)
	bar.tabs = {}
	local x = 0
	for i, item in ipairs(items) do
		local t = CreateFrame("Button", nil, bar)
		t.id = item.id
		t.icon = t:CreateTexture(nil, "ARTWORK")
		t.icon:SetSize(16, 16)
		t.icon:SetPoint("LEFT", 12, 0)
		t.icon:SetTexture(item.icon)
		t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		T.Round(t.icon)
		t.text = t:CreateFontString(nil, "OVERLAY")
		t.text:SetFontObject(T.FONTS.Header)
		t.text:SetPoint("LEFT", t.icon, "RIGHT", 7, 0)
		t.text:SetText(item.label)
		t.line = t:CreateTexture(nil, "ARTWORK")
		t.line:SetTexture(WHITE)
		t.line:SetHeight(2)
		t.line:SetPoint("BOTTOMLEFT", 8, 0)
		t.line:SetPoint("BOTTOMRIGHT", -8, 0)
		t.glow = t:CreateTexture(nil, "BACKGROUND")
		t.glow:SetPoint("BOTTOMLEFT")
		t.glow:SetPoint("BOTTOMRIGHT")
		t.glow:SetHeight(18)
		local w = math.ceil(t.text:GetStringWidth()) + 47
		t:SetSize(w, 36)
		t:SetPoint("LEFT", x, 0)
		x = x + w
		t:SetScript("OnEnter", function(self) self.hover = true; bar:Paint() end)
		t:SetScript("OnLeave", function(self) self.hover = false; bar:Paint() end)
		t:SetScript("OnClick", function(self)
			sound("IG_CHARACTER_INFO_TAB")
			onSelect(self.id)
		end)
		bar.tabs[i] = t
	end
	bar:SetSize(math.max(1, x), 36)
	function bar:Paint()
		local look = T.Look()
		local a = look.accent
		for _, t in ipairs(self.tabs) do
			local sel = t.id == self.selected
			local c = sel and look.heading or (t.hover and look.text or look.subtle)
			t.text:SetTextColor(c[1], c[2], c[3], 1)
			t.icon:SetAlpha(sel and 1 or (t.hover and 0.85 or 0.55))
			t.icon:SetDesaturated(not sel and not t.hover)
			t.line:SetVertexColor(a[1], a[2], a[3], sel and 1 or (t.hover and 0.35 or 0))
			T.Gradient(t.glow, "VERTICAL", a[1], a[2], a[3], sel and 0.14 or 0, 0)
		end
	end
	function bar:Select(id)
		self.selected = id
		self:Paint()
	end
	T.OnTheme(function() bar:Paint() end)
	return bar
end

-- Joined choices, one selected; Rebuild(items) swaps them ({ key, label }).
function W.Segments(parent, onSelect)
	local h = 24
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetHeight(h)
	holder.bg = holder:CreateTexture(nil, "BACKGROUND")
	holder.bg:SetAllPoints()
	holder.edge = T.Border(holder, "line")
	holder.buttons = {}
	function holder:Paint()
		local look = T.Look()
		self.bg:SetColorTexture(0, 0, 0, 0.30)
		local a = look.accent
		for _, b in ipairs(self.buttons) do
			if b:IsShown() then
				local sel = b.key == self.selected
				b.fill:SetVertexColor(a[1], a[2], a[3], sel and 0.16 or (b.hover and 0.07 or 0))
				b.bar:SetVertexColor(a[1], a[2], a[3], sel and 1 or 0)
				local c = sel and look.heading or (b.hover and look.text or look.subtle)
				b.text:SetTextColor(c[1], c[2], c[3], 1)
				if b.div then
					local l = look.line
					b.div:SetVertexColor(l[1], l[2], l[3], l[4])
				end
			end
		end
	end
	function holder:Select(key)
		self.selected = key
		self:Paint()
	end
	function holder:Rebuild(items)
		local x = 0
		for i, item in ipairs(items) do
			local b = self.buttons[i]
			if not b then
				b = CreateFrame("Button", nil, self)
				b:SetHeight(h)
				b.fill = b:CreateTexture(nil, "BACKGROUND", nil, 1)
				b.fill:SetAllPoints()
				b.fill:SetTexture(WHITE)
				b.bar = b:CreateTexture(nil, "ARTWORK")
				b.bar:SetTexture(WHITE)
				b.bar:SetHeight(2)
				b.bar:SetPoint("BOTTOMLEFT", 1, 1)
				b.bar:SetPoint("BOTTOMRIGHT", -1, 1)
				b.text = b:CreateFontString(nil, "OVERLAY")
				b.text:SetFontObject(T.FONTS.Small)
				b.text:SetPoint("CENTER")
				b.text:SetWordWrap(false)
				if i > 1 then
					b.div = T.Line(b, true)
					b.div:SetPoint("TOPLEFT", 0, -4)
					b.div:SetPoint("BOTTOMLEFT", 0, 4)
				end
				b:SetScript("OnEnter", function(s) s.hover = true; holder:Paint() end)
				b:SetScript("OnLeave", function(s) s.hover = false; holder:Paint() end)
				b:SetScript("OnClick", function(s)
					sound("IG_CHARACTER_INFO_TAB")
					holder:Select(s.key)
					onSelect(s.key)
				end)
				self.buttons[i] = b
			end
			b.key = item.key
			b.text:SetText(item.label)
			local bw = math.ceil(b.text:GetStringWidth()) + 22
			b:SetWidth(bw)
			b:ClearAllPoints()
			b:SetPoint("LEFT", x, 0)
			b:Show()
			x = x + bw
		end
		for i = #items + 1, #self.buttons do self.buttons[i]:Hide() end
		self:SetWidth(math.max(1, x))
		self:Paint()
	end
	T.OnTheme(function() holder:Paint() end)
	return holder
end

-- An on/off switch with a label (settings).
function W.Toggle(parent, label, width, get, set)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(width, 24)
	row.label = T.Text(row, label, "Body", "text")
	row.label:SetPoint("LEFT")
	local sw = CreateFrame("Frame", nil, row)
	sw:SetSize(32, 16)
	sw:SetPoint("RIGHT")
	sw.bg = sw:CreateTexture(nil, "BACKGROUND")
	sw.bg:SetAllPoints()
	sw.bg:SetTexture(WHITE)
	sw.knob = sw:CreateTexture(nil, "ARTWORK")
	sw.knob:SetTexture(WHITE)
	sw.knob:SetSize(12, 12)
	local function paint(p)
		local a = T.Look().accent
		sw.bg:SetVertexColor(T.Mix({ 1, 1, 1, 0.12 }, { a[1], a[2], a[3], 0.85 }, p))
		sw.knob:ClearAllPoints()
		sw.knob:SetPoint("LEFT", 2 + p * 16, 0)
		sw.knob:SetVertexColor(1, 1, 1, 0.8 + 0.2 * p)
	end
	function row:Refresh()
		local p = get() and 1 or 0
		T.Tween(self, p, 0.01, paint)
	end
	row:SetScript("OnClick", function(self)
		local v = not get()
		set(v)
		sound(v and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
		T.Tween(self, v and 1 or 0, 0.14, paint, T.Ease.outQuart)
	end)
	T.OnTheme(function() paint(T.Progress(row)) end)
	return row
end

---------------------------------------------------------------------------
-- Progress
---------------------------------------------------------------------------

-- A dotted trail: one dot per step, filled up to n. Past `max` dots it
-- becomes a thin bar instead.
function W.Dots(parent, size, gap, max)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(1, size)
	f.dots = {}
	f.bar = W.Bar(f, 1, 3)
	f.bar:SetPoint("LEFT")
	f.bar:Hide()
	function f:SetProgress(n, total, done)
		total = total or 0
		if total > (max or 30) then
			for _, d in ipairs(self.dots) do d:Hide() end
			local width = (max or 30) * (size + gap)
			self.bar:SetWidth(width)
			self:SetWidth(width)
			self.bar:Show()
			self.bar:SetProgress(n, total, done)
			return
		end
		self.bar:Hide()
		local look = T.Look()
		local on = done and look.done or look.accent
		for i = 1, total do
			local d = self.dots[i]
			if not d then
				d = T.Circle(self, size)
				d:SetPoint("LEFT", (i - 1) * (size + gap), 0)
				self.dots[i] = d
			end
			if i <= (n or 0) then
				d:SetVertexColor(on[1], on[2], on[3], 1)
			else
				d:SetVertexColor(1, 1, 1, look.skin and 0.18 or 0.14)
			end
			d:Show()
		end
		for i = total + 1, #self.dots do self.dots[i]:Hide() end
		self:SetWidth(math.max(1, total * (size + gap) - gap))
	end
	return f
end

-- A thin flat bar: a faint track and an accent fill, green when done.
function W.Bar(parent, w, h)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(w, h)
	bar:SetStatusBarTexture(WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	function bar:SetProgress(n, total, done)
		self.n, self.total, self.done = n, total, done
		self:SetMinMaxValues(0, math.max(total or 1, 1))
		self:SetValue(n or 0)
		local look = T.Look()
		local c = done and look.done or look.accent
		self:SetStatusBarColor(c[1], c[2], c[3], 0.95)
		T.Fill(self.bg, look.track)
	end
	T.OnTheme(function() bar:SetProgress(bar.n or 0, bar.total or 1, bar.done) end)
	return bar
end

-- A label on the left and a value on the right.
function W.Stat(parent, label, w)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(w, 22)
	row.label = T.Text(row, label, "Body", "subtle")
	row.label:SetPoint("LEFT")
	row.value = T.Text(row, "", "Header", "text")
	row.value:SetPoint("RIGHT")
	row.value:SetJustifyH("RIGHT")
	return row
end

-- A panel with a small-capitals label, a big number and a note: the
-- journal's at-a-glance figures.
function W.Tile(parent, label, w, h, icon)
	local p = W.Panel(parent)
	p:SetSize(w, h or 78)
	p.label = W.Label(p, label)
	p.label:SetPoint("TOPLEFT", 14, -14)
	p.value = T.Text(p, "0", "Display", "heading")
	p.value:SetPoint("TOPLEFT", p.label, "BOTTOMLEFT", 0, -6)
	p.note = T.Text(p, "", "Small", "subtle")
	p.note:SetPoint("BOTTOMLEFT", p.value, "BOTTOMRIGHT", 8, 3)
	if icon then
		p.icon = p:CreateTexture(nil, "ARTWORK")
		p.icon:SetSize(30, 30)
		p.icon:SetPoint("TOPRIGHT", -14, -14)
		p.icon:SetTexture(icon)
		p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		T.Round(p.icon)
		p.icon:SetAlpha(0.85)
	end
	return p
end

-- A small pill ("Fully explored", "+20").
function W.Chip(parent, font)
	local c = CreateFrame("Frame", nil, parent)
	c:SetSize(40, 18)
	c.bg = c:CreateTexture(nil, "BACKGROUND")
	c.bg:SetAllPoints()
	c.bg:SetTexture(WHITE)
	c.edge = T.Border(c)
	c.text = c:CreateFontString(nil, "OVERLAY")
	c.text:SetFontObject(T.FONTS[font or "Label"])
	c.text:SetPoint("CENTER", 0, 0)
	function c:Set(text, color)
		color = color or T.Look().accent
		self.text:SetText(text or "")
		self.text:SetTextColor(color[1], color[2], color[3])
		self.bg:SetVertexColor(color[1], color[2], color[3], 0.14)
		self.edge:SetColor(color[1], color[2], color[3], 0.55)
		self:SetWidth(math.ceil(self.text:GetStringWidth()) + 14)
		self:SetShown(text ~= nil and text ~= "")
	end
	return c
end

---------------------------------------------------------------------------
-- Scrolling
---------------------------------------------------------------------------
function W.ScrollBar(sf, step)
	local bar = CreateFrame("Frame", nil, sf:GetParent())
	bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 3, 0)
	bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 3, 0)
	bar:SetWidth(8)
	bar.track = bar:CreateTexture(nil, "BACKGROUND")
	bar.track:SetTexture(WHITE)
	bar.track:SetPoint("TOP")
	bar.track:SetPoint("BOTTOM")
	bar.track:SetWidth(2)
	local thumb = CreateFrame("Button", nil, bar)
	thumb:SetWidth(8)
	thumb.tex = thumb:CreateTexture(nil, "ARTWORK")
	thumb.tex:SetTexture(WHITE)
	thumb.tex:SetPoint("TOP")
	thumb.tex:SetPoint("BOTTOM")
	thumb.tex:SetWidth(2)

	local function range()
		local child = sf:GetScrollChild()
		return math.max(0, (child and child:GetHeight() or 0) - sf:GetHeight())
	end
	local function update()
		local r, h = range(), sf:GetHeight()
		if r < 1 or h <= 0 then
			bar:Hide()
			return
		end
		bar:Show()
		local th = math.max(24, h * h / (h + r))
		thumb:SetHeight(th)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", bar, "TOP", 0, -(h - th) * math.min(1, sf:GetVerticalScroll() / r))
	end
	bar.Update = update

	local anim = CreateFrame("Frame", nil, sf)
	local target
	local function smooth(self, elapsed)
		local cur = sf:GetVerticalScroll()
		local diff = target - cur
		if math.abs(diff) < 0.5 then
			sf:SetVerticalScroll(target)
			target = nil
			self:SetScript("OnUpdate", nil)
		else
			sf:SetVerticalScroll(cur + diff * math.min(1, 12 * elapsed))
		end
	end
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(_, delta)
		local r = range()
		if r <= 0 then return end
		local at = target or sf:GetVerticalScroll()
		target = math.max(0, math.min(r, at - delta * (step or 48)))
		anim:SetScript("OnUpdate", smooth)
	end)
	thumb:SetScript("OnMouseDown", function(self)
		local _, y = GetCursorPosition()
		self.dragY, self.from = y / self:GetEffectiveScale(), sf:GetVerticalScroll()
		target = nil
		anim:SetScript("OnUpdate", nil)
		self:SetScript("OnUpdate", function()
			local _, cy = GetCursorPosition()
			cy = cy / self:GetEffectiveScale()
			local free, r = sf:GetHeight() - self:GetHeight(), range()
			if free > 0 then sf:SetVerticalScroll(math.max(0, math.min(r, self.from + (self.dragY - cy) / free * r))) end
		end)
	end)
	thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	local function paint(p)
		local look = T.Look()
		T.Fill(bar.track, look.track)
		local k = look.thumb
		thumb.tex:SetVertexColor(k[1], k[2], k[3], math.min(1, k[4] + 0.35 * p))
		thumb.tex:SetWidth(2 + 2 * p)
	end
	thumb:SetScript("OnEnter", function(self) T.Tween(self, 1, 0.12, paint) end)
	thumb:SetScript("OnLeave", function(self) T.Tween(self, 0, 0.12, paint) end)
	T.OnTheme(function() paint(T.Progress(thumb)) end)
	sf:HookScript("OnVerticalScroll", update)
	sf:HookScript("OnScrollRangeChanged", update)
	sf:HookScript("OnSizeChanged", update)
	bar:Hide()
	return bar
end

-- A list. Only the visible rows are built; items are drawn into them.
--   o.build(row), o.fill(row, item, i), o.onClick(item, row),
--   o.isSelected(item), o.emptyText, o.emptyIcon, o.bare (no panel),
--   o.stripes (default on)
function W.List(parent, w, h, rowH, o)
	local box = o.bare and CreateFrame("Frame", nil, parent) or W.Panel(parent)
	box:SetSize(w, h)
	local pad, barW = o.bare and 0 or 6, 12
	local sf = CreateFrame("ScrollFrame", nil, box)
	sf:SetPoint("TOPLEFT", pad, -pad)
	sf:SetPoint("BOTTOMRIGHT", -(pad + barW), pad)
	local cw = w - 2 * pad - barW
	box.rowWidth = cw
	local content = CreateFrame("Frame", nil, sf)
	content:SetSize(cw, 1)
	sf:SetScrollChild(content)
	box.items, box.rows = {}, {}

	box.emptyIcon = box:CreateTexture(nil, "ARTWORK")
	box.emptyIcon:SetSize(40, 40)
	box.emptyIcon:SetPoint("CENTER", 0, 26)
	box.emptyIcon:SetTexture(o.emptyIcon or "Interface\\Icons\\INV_Misc_Spyglass_02")
	box.emptyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	T.Round(box.emptyIcon)
	box.emptyIcon:SetAlpha(0.45)
	box.emptyIcon:SetDesaturated(true)
	box.empty = T.Text(box, o.emptyText or "Nothing here yet.", "Body", "subtle", math.min(w - 40, 300))
	box.empty:SetPoint("TOP", box.emptyIcon, "BOTTOM", 0, -12)
	box.empty:SetJustifyH("CENTER")
	box.empty:SetSpacing(3)

	local visible = math.ceil(h / rowH) + 1
	for i = 1, visible do
		local row = CreateFrame("Button", nil, content)
		row:SetSize(cw, rowH)
		row.stripe = row:CreateTexture(nil, "BACKGROUND")
		row.stripe:SetAllPoints()
		row.hl = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.hl:SetAllPoints()
		row.hl:Hide()
		row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 2)
		row.sel:SetAllPoints()
		row.selBar = row:CreateTexture(nil, "BORDER")
		row.selBar:SetTexture(WHITE)
		row.selBar:SetWidth(2)
		row.selBar:SetPoint("TOPLEFT")
		row.selBar:SetPoint("BOTTOMLEFT")
		T.OnTheme(function(look)
			T.Fill(row.stripe, look.stripe)
			T.Fill(row.hl, look.hover)
			local s = look.select
			T.Gradient(row.sel, "HORIZONTAL", s[1], s[2], s[3], s[4], s[4] * 0.2)
			row.selBar:SetVertexColor(look.accent[1], look.accent[2], look.accent[3], 1)
		end)
		row:SetScript("OnEnter", function(self) self.hl:Show() end)
		row:SetScript("OnLeave", function(self) self.hl:Hide() end)
		row:SetScript("OnClick", function(self)
			if self.item and o.onClick then
				sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
				o.onClick(self.item, self)
			end
		end)
		o.build(row)
		row:Hide()
		box.rows[i] = row
	end

	function box:Render()
		local offset = math.floor(sf:GetVerticalScroll() / rowH)
		for i, row in ipairs(self.rows) do
			local idx = offset + i
			local item = self.items[idx]
			if item then
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -(idx - 1) * rowH)
				row.item = item
				row.stripe:SetShown(o.stripes ~= false and idx % 2 == 0)
				local selected = o.isSelected and o.isSelected(item) or false
				row.sel:SetShown(selected)
				row.selBar:SetShown(selected)
				o.fill(row, item, idx, idx == #self.items)
				row:Show()
			else
				row:Hide()
			end
		end
	end

	function box:SetItems(items, keepScroll)
		self.items = items or {}
		local total = #self.items * rowH
		content:SetHeight(math.max(1, total))
		local maxScroll = math.max(0, total - sf:GetHeight())
		if not keepScroll then
			sf:SetVerticalScroll(0)
		elseif sf:GetVerticalScroll() > maxScroll then
			sf:SetVerticalScroll(maxScroll)
		end
		local empty = #self.items == 0
		self.empty:SetShown(empty)
		self.emptyIcon:SetShown(empty)
		self:Render()
		self.scrollBar.Update()
	end

	box.scrollBar = W.ScrollBar(sf, rowH * 2)
	sf:HookScript("OnVerticalScroll", function() box:Render() end)
	return box
end

---------------------------------------------------------------------------
-- Timeline rows: a thread down the left with a dot per entry, coloured by
-- what kind of entry it is. Use as a list's build/fill pair.
---------------------------------------------------------------------------
function W.TimelineBuild(row)
	row.thread = T.Line(row, true, "line")
	row.thread:SetPoint("TOP", row, "TOPLEFT", 14, 0)
	row.thread:SetPoint("BOTTOM", row, "BOTTOMLEFT", 14, 0)
	row.dot = T.Circle(row, 9, "ARTWORK", 2)
	row.dot:SetPoint("CENTER", row, "LEFT", 14, 0)
	row.date = T.Text(row, "", "Small", "subtle")
	row.date:SetPoint("LEFT", 30, 0)
	row.date:SetWidth(50)
	row.date:SetWordWrap(false)
	row.text = T.Text(row, "", "Body", "text")
	row.text:SetPoint("LEFT", 84, 0)
	row.text:SetPoint("RIGHT", -48, 0)
	row.text:SetWordWrap(false)
	row.right = T.Text(row, "", "Header", "points")
	row.right:SetPoint("RIGHT", -8, 0)
	row.right:SetJustifyH("RIGHT")
end

-- kind colours the dot; first/last trim the thread so it starts and ends at a dot.
function W.TimelineFill(row, kind, dateText, text, rightText, first, last)
	local c = T.KindColor(kind)
	row.dot:SetVertexColor(c[1], c[2], c[3], 1)
	row.date:SetText(dateText or "")
	row.text:SetText(text or "")
	row.right:SetText(rightText or "")
	row.thread:ClearAllPoints()
	row.thread:SetPoint("TOP", row, first and "LEFT" or "TOPLEFT", 14, 0)
	row.thread:SetPoint("BOTTOM", row, last and "LEFT" or "BOTTOMLEFT", 14, 0)
	row.thread:SetShown(not (first and last))
end
