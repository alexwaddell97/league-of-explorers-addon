-- Widgets. Each paints itself for both looks through T.OnTheme.

local _, ns = ...

local T = ns.Theme
local WHITE = T.WHITE
local W = {}
ns.Widgets = W

local function sound(kit)
	if SOUNDKIT and SOUNDKIT[kit] then pcall(PlaySound, SOUNDKIT[kit]) end
end
W.Sound = sound

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------

-- A box ruled on the page: a faint wash and a fine ink edge.
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

-- A flat outlined button in ink.
function W.Button(parent, text, w, h, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w or 120, h or 24)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetTexture(WHITE)
	b.edge = T.Border(b)
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
		b.bg:SetVertexColor(T.Mix(look.btn, look.btnHover, p))
		b.edge:SetColor(T.Mix(look.btnEdge, look.btnEdgeHover, p))
		local r, g, bl, a = T.Mix(look.btnText, look.btnTextHover, p)
		b.label:SetTextColor(r, g, bl, b:IsEnabled() and a or a * 0.4)
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
				d:SetVertexColor(1, 1, 1, 0.14)
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
		local hasText = (o.emptyText or "x") ~= ""
		self.empty:SetShown(empty and hasText)
		self.emptyIcon:SetShown(empty and hasText)
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

---------------------------------------------------------------------------
-- The rank bar: like the game's experience bar, a long bar ticked into
-- twenty, with the rank you hold on the left and the next on the right.
---------------------------------------------------------------------------
function W.RankBar(parent, w)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, 52)
	f.rank = T.Text(f, "", "Title", "heading")
	f.rank:SetPoint("TOPLEFT")
	f.next = T.Text(f, "", "Small", "subtle")
	f.next:SetPoint("BOTTOMRIGHT", f.rank, "BOTTOMRIGHT", 0, 0)
	f.next:ClearAllPoints()
	f.next:SetPoint("TOPRIGHT", 0, -3)
	f.next:SetJustifyH("RIGHT")
	f.bar = W.Bar(f, w, 9)
	f.bar:SetPoint("TOPLEFT", 0, -24)
	f.ticks = {}
	for i = 1, 19 do
		local t = T.Line(f.bar, true, nil, "OVERLAY")
		t:SetPoint("TOP", f.bar, "TOPLEFT", w * i / 20, 0)
		t:SetPoint("BOTTOM", f.bar, "BOTTOMLEFT", w * i / 20, 0)
		f.ticks[i] = t
	end
	f.edge = T.Border(f.bar, "panelEdge")
	f.note = T.Text(f, "", "Small", "subtle", w)
	f.note:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -5)
	T.OnTheme(function(look)
		local c = look.line
		for _, t in ipairs(f.ticks) do t:SetVertexColor(c[1], c[2], c[3], (c[4] or 1) * 1.4) end
	end)
	-- who: the character whose player's rank to show. The note lists what
	-- the next rank asks for, with how far along each deed is.
	function f:SetWho(who)
		local P = ns.Points
		local _, cur, nxt, p, asks = P.RankOf(who)
		self.rank:SetText(cur.name)
		self.bar:SetProgress(p, 1, not nxt)
		if not nxt then
			self.next:SetText("Highest rank")
			self.note:SetText(("%s points earned"):format(T.Number(P.Total(who))))
			return
		end
		self.next:SetText("Next: " .. nxt.name)
		local look = T.Look()
		local bits = {}
		for _, a in ipairs(asks) do
			local done = a.have >= a.need
			local c = done and look.done or look.subtle
			bits[#bits + 1] = ("|cff%s%s %d/%d|r"):format(T.Hex(c), a.label, math.min(a.have, a.need), a.need)
		end
		self.note:SetText(table.concat(bits, "   "))
	end
	return f
end

---------------------------------------------------------------------------
-- A creature's portrait: the game's own 3D model of it in a small frame.
-- Two models: one lit as usual, for creatures you have found; one with
-- every light turned to nothing, which draws the creature as a solid black
-- shape, for the ones still in shadow.
---------------------------------------------------------------------------

-- No light at all on a model: it renders as its black silhouette. The
-- client takes a light description table (newer) or a list of numbers
-- (older); both are tried. Fog is added as a second shade where it works.
local function blackOut(m)
	local done = false
	if CreateColor and CreateVector3D then
		done = pcall(m.SetLight, m, true, {
			omnidirectional = false, point = CreateVector3D(-1, 1, -1),
			ambientIntensity = 0, ambientColor = CreateColor(0, 0, 0),
			diffuseIntensity = 0, diffuseColor = CreateColor(0, 0, 0),
		})
	end
	if not done then pcall(m.SetLight, m, true, false, -1, 1, -1, 0, 0, 0, 0, 0, 0, 0, 0) end
	pcall(m.SetFogColor, m, 0, 0, 0, 1)
	pcall(m.SetFogNear, m, 0)
	pcall(m.SetFogFar, m, 0.1)
	-- Flames, sparks and glowing parts light themselves, so no lighting
	-- darkens them: particles off, and what still glows drained of colour.
	if m.SetParticlesEnabled then pcall(m.SetParticlesEnabled, m, false) end
	if m.SetDesaturation then pcall(m.SetDesaturation, m, 1) end
end

-- How the camera frames the model: zoom 0 is the whole creature, 1 its
-- head; cam > 1 steps back. Loading a model resets both (and the lights),
-- so they are set again each time one comes in.
local function frame(m)
	if m.SetPortraitZoom then m:SetPortraitZoom(m.zoom or 0) end
	if m.SetCamDistanceScale then m:SetCamDistanceScale(m.cam or 1) end
end

-- Has the model anything in it yet?
local function hasModel(m)
	if m.loaded then return true end
	if m.GetModelFileID then
		local ok, id = pcall(m.GetModelFileID, m)
		if ok and type(id) == "number" and id > 0 then return true end
	end
	return false
end

-- Puts the wanted creature in the model. Its display ID first (read from
-- the creature when someone saw it); failing that, by creature ID, which
-- only works once the client has the creature's details, so it may take a
-- second try (see newModel).
local function apply(m, byId)
	local o = m.want
	if not o then return end
	m.loaded = false
	m:ClearModel()
	local done = false
	if o.display and not byId then done = pcall(m.SetDisplayInfo, m, o.display) end
	if not done and o.id then pcall(m.SetCreature, m, o.id) end
	frame(m)
	if m.dark then blackOut(m) end
end

-- Tries again a few times while the model is still empty: the game asks
-- the server about a creature it hasn't seen and fills it in later.
local RETRY = { 0.3, 1, 2.5, 5, 10 }
local function retry(m, n)
	n = n or 1
	local token = m.token
	ns.After(RETRY[n], function()
		if m.token ~= token or not m.want or hasModel(m) then return end
		if not m:IsVisible() then
			m.stale = true -- tried again when it's next shown
			return
		end
		-- Every other try by creature ID, in case the display ID is the problem.
		apply(m, n % 2 == 0)
		if RETRY[n + 1] then retry(m, n + 1) end
	end)
end

local function newModel(f, dark, zoom, cam)
	local ok, m = pcall(CreateFrame, "PlayerModel", nil, f)
	if not (ok and m) then return nil end
	m:SetPoint("TOPLEFT", 1, -1)
	m:SetPoint("BOTTOMRIGHT", -1, 1)
	m.zoom, m.cam, m.dark, m.token = zoom, cam, dark, 0
	if dark then blackOut(m) end
	m:SetScript("OnModelLoaded", function(self)
		self.loaded = true
		frame(self)
		if dark then blackOut(self) end
	end)
	-- A model given its creature while hidden (a page not open yet, the
	-- book shut) can come up empty: give it again when it shows.
	m:SetScript("OnShow", function(self)
		if self.want and (self.stale or not hasModel(self)) then
			self.stale = false
			self.token = self.token + 1
			apply(self)
			retry(self)
		end
	end)
	m:Hide()
	return m
end

-- zoom: 0 the whole creature (a large portrait), up to 1 its head (a
-- small tile); cam steps the camera back from it (1 is the game's own).
function W.Portrait(parent, size, zoom, cam)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(size, size)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.edge = T.Border(f)
	f.lit = newModel(f, false, zoom or 0.6, cam)
	f.dark = newModel(f, true, zoom or 0.6, cam)
	-- Words and marks sit on a layer above the models.
	f.top = CreateFrame("Frame", nil, f)
	f.top:SetAllPoints()
	f.top:SetFrameLevel(f:GetFrameLevel() + 5)
	f.mystery = f.top:CreateFontString(nil, "OVERLAY")
	f.mystery:SetFontObject(T.FONTS.Display)
	f.mystery:SetPoint("CENTER", 0, 2)
	f.mystery:SetText("?")
	f.name = T.Text(f.top, "", "Label", "text", size - 6)
	f.name:SetPoint("BOTTOM", 0, 4)
	f.name:SetJustifyH("CENTER")
	f.name:SetWordWrap(false)
	f.sel = f.top:CreateTexture(nil, "OVERLAY", nil, 2)
	f.sel:SetPoint("BOTTOMLEFT")
	f.sel:SetPoint("BOTTOMRIGHT")
	f.sel:SetHeight(2)
	f.sel:SetTexture(T.WHITE)
	f.sel:Hide()
	-- Hover wash on the top layer (a highlight texture there would never
	-- see the mouse, which goes to the button beneath).
	f.hl = f.top:CreateTexture(nil, "OVERLAY")
	f.hl:SetAllPoints()
	f.hl:Hide()
	f:SetScript("OnEnter", function() f.hl:Show() end)
	f:SetScript("OnLeave", function() f.hl:Hide() end)
	T.OnTheme(function(look)
		T.Fill(f.bg, look.panel)
		local e = look.panelEdge
		f.edge:SetColor(e[1], e[2], e[3], e[4])
		T.Fill(f.hl, look.hover)
		f.sel:SetVertexColor(look.accent[1], look.accent[2], look.accent[3], 1)
		local sb = look.subtle
		f.mystery:SetTextColor(sb[1], sb[2], sb[3], 0.85)
	end)
	f.top:EnableMouse(false)

	local function load(m, o, key)
		if not m then return end
		f.active = m
		if m.shownId ~= key or not hasModel(m) then
			m.shownId = key
			m.want = { id = o.id, display = o.display }
			m.token = m.token + 1
			m.stale = not m:IsVisible()
			apply(m)
			retry(m)
		end
		m:SetShown(not f.modelsOff)
	end

	-- 3D models ignore a scroll frame's edges and would draw over whatever
	-- is above or below it: a tile not wholly in view keeps its box but
	-- puts its creature away.
	function f:SetModelsOff(off)
		off = off and true or false
		if self.modelsOff == off then return end
		self.modelsOff = off
		if self.active then self.active:SetShown(not off) end
	end

	-- The models in a box of their own, centred: the game's camera fits a
	-- model to its frame's shape, and a wide frame crops tall creatures.
	function f:SetModelBox(w, h)
		for _, m in ipairs({ self.lit, self.dark }) do
			if m then
				m:ClearAllPoints()
				m:SetSize(w, h)
				m:SetPoint("CENTER")
			end
		end
	end

	-- o = { id, display, name, state, selected }: state "mine" (in full
	-- colour), "guild" (black silhouette, named) or "unknown" (black
	-- silhouette with a "?"). known = true means "mine".
	function f:Set(o)
		local state = o.state or (o.known and "mine" or "unknown")
		local key = o.display or o.id
		self.sel:SetShown(o.selected and true or false)
		self.name:SetText(state ~= "unknown" and (o.name or "") or "")
		self.mystery:SetShown(state == "unknown")
		if state == "mine" then
			if self.dark then self.dark:Hide() end
			load(self.lit, o, key)
		else
			if self.lit then self.lit:Hide() end
			load(self.dark, o, key)
		end
	end
	return f
end

---------------------------------------------------------------------------
-- Personal notes: a multi-line box written in, saved as you type.
---------------------------------------------------------------------------
function W.Notes(parent, w, h, placeholder, onChange)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.edge = T.Border(f)
	local sf = CreateFrame("ScrollFrame", nil, f)
	sf:SetPoint("TOPLEFT", 8, -6)
	sf:SetPoint("BOTTOMRIGHT", -8, 6)
	local edit = CreateFrame("EditBox", nil, sf)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(T.FONTS.Body)
	edit:SetWidth(w - 16)
	edit:SetMaxLetters(600)
	sf:SetScrollChild(edit)
	f.edit = edit
	f.hint = T.Text(f, placeholder or "", "Body", "subtle", w - 16)
	f.hint:SetPoint("TOPLEFT", 8, -6)
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() edit:SetFocus() end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnTextChanged", function(self, user)
		f.hint:SetShown(self:GetText() == "")
		if user and onChange then onChange(self:GetText()) end
	end)
	edit:SetScript("OnEditFocusGained", function()
		local a = T.Look().accent
		f.edge:SetColor(a[1], a[2], a[3], 0.9)
	end)
	edit:SetScript("OnEditFocusLost", function()
		local e = T.Look().panelEdge
		f.edge:SetColor(e[1], e[2], e[3], e[4])
	end)
	T.OnTheme(function(look)
		T.Fill(f.bg, look.panel)
		local e = look.panelEdge
		f.edge:SetColor(e[1], e[2], e[3], e[4])
		local t = look.text
		edit:SetTextColor(t[1], t[2], t[3])
	end)
	function f:SetText(text)
		edit:SetText(text or "")
		self.hint:SetShown((text or "") == "")
	end
	return f
end

---------------------------------------------------------------------------
-- A one-line text field with a placeholder, ruled like the page's boxes.
---------------------------------------------------------------------------
function W.Field(parent, w, placeholder, maxLetters, onChange)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, 26)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.edge = T.Border(f)
	local edit = CreateFrame("EditBox", nil, f)
	edit:SetPoint("TOPLEFT", 8, 0)
	edit:SetPoint("BOTTOMRIGHT", -8, 0)
	edit:SetAutoFocus(false)
	edit:SetFontObject(T.FONTS.Body)
	edit:SetMaxLetters(maxLetters or 48)
	f.edit = edit
	f.hint = T.Text(f, placeholder or "", "Body", "subtle")
	f.hint:SetPoint("LEFT", 8, 0)
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() edit:SetFocus() end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnTextChanged", function(self, user)
		f.hint:SetShown(self:GetText() == "")
		if user and onChange then onChange(self:GetText()) end
	end)
	local function edge(focus)
		local look = T.Look()
		local c = focus and look.accent or look.panelEdge
		f.edge:SetColor(c[1], c[2], c[3], focus and 0.9 or c[4])
	end
	edit:SetScript("OnEditFocusGained", function() edge(true) end)
	edit:SetScript("OnEditFocusLost", function() edge(false) end)
	T.OnTheme(function(look)
		T.Fill(f.bg, look.panel)
		edge(edit:HasFocus())
		local t = look.text
		edit:SetTextColor(t[1], t[2], t[3])
	end)
	function f:GetValue() return (edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "") end
	function f:SetValue(text)
		edit:SetText(text or "")
		self.hint:SetShown((text or "") == "")
	end
	return f
end

-- A small square tick box for list rows.
function W.Tick(parent, size)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(size or 14, size or 14)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.edge = T.Border(b)
	b.fill = b:CreateTexture(nil, "ARTWORK")
	b.fill:SetPoint("TOPLEFT", 3, -3)
	b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
	b.fill:SetTexture(T.WHITE)
	function b:SetChecked(on, color)
		local look = T.Look()
		T.Fill(self.bg, look.panel)
		local e = look.panelEdge
		self.edge:SetColor(e[1], e[2], e[3], 0.8)
		local c = color or look.accent
		self.fill:SetVertexColor(c[1], c[2], c[3], 1)
		self.fill:SetShown(on and true or false)
	end
	b:SetChecked(false)
	return b
end
