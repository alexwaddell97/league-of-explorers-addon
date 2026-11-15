-- The look: an open book drawn flat and crisp, a dark cover, paper pages
-- in dark ink, and a coloured ribbon bookmark for each section. Every
-- widget paints itself through T.OnTheme with these colours.

local _, ns = ...

local T = {}
ns.Theme = T

local WHITE = "Interface\\Buttons\\WHITE8X8"
T.WHITE = WHITE

T.LOOKS = {
	explorer = {
		cover      = { 0.150, 0.098, 0.075, 0.99 },  -- the book's cover
		coverEdge  = { 0.86, 0.66, 0.40, 0.35 },     -- a brass hairline round it
		coverText  = { 0.93, 0.84, 0.66 },           -- buttons and words on the cover
		page       = { 0.945, 0.915, 0.845, 1 },      -- paper
		pageEdge   = { 0.55, 0.45, 0.33, 0.55 },      -- the stacked edges of the leaves
		spine      = { 0.30, 0.20, 0.10 },            -- shading into the fold
		window     = { 0.945, 0.915, 0.845, 1 },      -- (popovers sit on paper)
		windowEdge = { 0.55, 0.45, 0.33, 0.55 },
		panel      = { 0.30, 0.20, 0.10, 0.045 },     -- boxes ruled on the page
		panelEdge  = { 0.30, 0.20, 0.10, 0.22 },
		panelTop   = { 1, 1, 1, 0 },
		line       = { 0.30, 0.20, 0.10, 0.18 },
		text       = { 0.19, 0.14, 0.10 },
		subtle     = { 0.45, 0.38, 0.31 },
		heading    = { 0.13, 0.09, 0.06 },
		label      = { 0.55, 0.36, 0.18 },            -- small capitals
		accent     = { 0.10, 0.42, 0.46 },            -- sea-green ink
		points     = { 0.66, 0.38, 0.05 },            -- amber ink
		done       = { 0.20, 0.50, 0.22 },
		hover      = { 0.30, 0.20, 0.10, 0.06 },
		select     = { 0.10, 0.42, 0.46, 0.14 },
		stripe     = { 0.30, 0.20, 0.10, 0.03 },
		track      = { 0.30, 0.20, 0.10, 0.12 },
		thumb      = { 0.30, 0.20, 0.10, 0.40 },
		btn        = { 0.10, 0.42, 0.46, 0.10 },      btnHover = { 0.10, 0.42, 0.46, 0.20 },
		btnEdge    = { 0.10, 0.42, 0.46, 0.55 },      btnEdgeHover = { 0.10, 0.42, 0.46, 1 },
		btnText    = { 0.08, 0.34, 0.37 },            btnTextHover = { 0.03, 0.22, 0.24 },
		-- One ribbon colour per bookmark.
		ribbons = {
			guild = { 0.55, 0.16, 0.14 }, journal = { 0.18, 0.40, 0.30 }, bestiary = { 0.20, 0.30, 0.52 },
			expeditions = { 0.62, 0.42, 0.12 }, leaders = { 0.42, 0.22, 0.48 }, submissions = { 0.30, 0.34, 0.38 },
		},
		kinds = {
			zone = { 0.10, 0.42, 0.46 }, zonefull = { 0.20, 0.50, 0.22 }, continent = { 0.66, 0.38, 0.05 },
			area = { 0.55, 0.48, 0.40 }, rare = { 0.42, 0.22, 0.60 }, treasure = { 0.70, 0.50, 0.08 },
			place = { 0.62, 0.24, 0.30 }, milestone = { 0.80, 0.58, 0.12 }, weekly = { 0.10, 0.42, 0.46 },
			alert = { 0.78, 0.30, 0.12 }, bounty = { 0.70, 0.50, 0.08 }, expedition = { 0.10, 0.42, 0.46 },
		},
	},
}

-- The map look: the earlier map-first design's dark slate, a turquoise
-- accent and amber points, with the book's own parts given its colours.
T.LOOKS.map = {
	window     = { 0.050, 0.060, 0.070, 0.97 },
	windowEdge = { 1, 1, 1, 0.09 },
	tabBar     = { 1, 1, 1, 0.025 },
	panel      = { 0.095, 0.110, 0.125, 0.94 },
	panelEdge  = { 1, 1, 1, 0.07 },
	panelTop   = { 1, 1, 1, 0.05 },
	line       = { 1, 1, 1, 0.07 },
	text       = { 0.90, 0.92, 0.93 },
	subtle     = { 0.56, 0.62, 0.66 },
	heading    = { 0.97, 0.98, 0.98 },
	label      = { 0.42, 0.70, 0.67 },
	accent     = { 0.27, 0.82, 0.75 },
	points     = { 1.00, 0.76, 0.33 },
	done       = { 0.47, 0.84, 0.43 },
	hover      = { 0.27, 0.82, 0.75, 0.07 },
	select     = { 0.27, 0.82, 0.75, 0.14 },
	stripe     = { 1, 1, 1, 0.018 },
	track      = { 1, 1, 1, 0.08 },
	thumb      = { 0.27, 0.82, 0.75, 0.45 },
	btn        = { 0.27, 0.82, 0.75, 0.12 },    btnHover = { 0.27, 0.82, 0.75, 0.24 },
	btnEdge    = { 0.27, 0.82, 0.75, 0.45 },    btnEdgeHover = { 0.27, 0.82, 0.75, 0.9 },
	btnText    = { 0.80, 0.95, 0.92 },          btnTextHover = { 1, 1, 1 },
	-- The book's parts, for things shared with it (cards, the cover, pop-ups).
	page       = { 0.075, 0.087, 0.098, 1 },
	pageEdge   = { 1, 1, 1, 0.10 },
	spine      = { 0, 0, 0 },
	cover      = { 0.050, 0.060, 0.070, 0.99 },
	coverEdge  = { 0.27, 0.82, 0.75, 0.35 },
	coverText  = { 0.80, 0.95, 0.92 },
	ribbons    = T.LOOKS.explorer.ribbons,
	kinds = {
		zone = { 0.27, 0.82, 0.75 }, zonefull = { 0.47, 0.84, 0.43 }, continent = { 1.00, 0.76, 0.33 },
		area = { 0.45, 0.52, 0.56 }, rare = { 0.78, 0.58, 1.00 }, treasure = { 1.00, 0.84, 0.40 },
		place = { 0.95, 0.50, 0.58 }, milestone = { 1.00, 0.76, 0.33 }, weekly = { 0.27, 0.82, 0.75 },
		alert = { 1.00, 0.58, 0.32 }, bounty = { 1.00, 0.84, 0.40 }, expedition = { 0.27, 0.82, 0.75 },
	},
}

-- The book's colours, or the map window's (settings.shell).
function T.Look()
	local s = ns.db and ns.db.settings
	return (s and s.shell == "map") and T.LOOKS.map or T.LOOKS.explorer
end

function T.KindColor(kind)
	local k = T.Look().kinds
	return k[kind] or k.area
end

-- "rrggbb" for inline |cff colour codes.
function T.Hex(c)
	local function b(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
	return ("%02x%02x%02x"):format(b(c[1]), b(c[2]), b(c[3]))
end

function T.Mix(a, b, p)
	local aa, ba = a[4] or 1, b[4] or 1
	return a[1] + (b[1] - a[1]) * p, a[2] + (b[2] - a[2]) * p, a[3] + (b[3] - a[3]) * p, aa + (ba - aa) * p
end

local function set(tex, c) tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
T.Fill = set

---------------------------------------------------------------------------
-- Theme registry
---------------------------------------------------------------------------
local painters = {}

function T.OnTheme(fn)
	painters[#painters + 1] = fn
	local ok, err = pcall(fn, T.Look())
	if not ok then geterrorhandler()(err) end
end

-- Paints everything again, after the look changes.
function T.Repaint()
	local look = T.Look()
	for _, fn in ipairs(painters) do
		local ok, err = pcall(fn, look)
		if not ok then geterrorhandler()(err) end
	end
end

-- Things made before the saved settings loaded take the right look then.
ns.Listen("DB_READY", function()
	if ns.db.settings.shell == "map" then T.Repaint() end
end)

---------------------------------------------------------------------------
-- Fonts: the game's reading font in fixed sizes. "Shadow" variants are for
-- text over the map and the window; text in panels has a lighter shadow.
---------------------------------------------------------------------------
local SIZES = { Display = 28, Huge = 22, Title = 16, Header = 14, Body = 13, Small = 12, Label = 10 }
T.FONTS = {}
local face = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
for name, size in pairs(SIZES) do
	for _, strong in ipairs({ false, true }) do
		local f = CreateFont("LeagueOfExplorersFont" .. name .. (strong and "Shadow" or ""))
		f:SetFont(face, size, "")
		f:SetTextColor(1, 1, 1)
		f:SetShadowColor(0, 0, 0, 0.95)
		f:SetShadowOffset(strong and 1 or 0, strong and -1 or 0)
		T.FONTS[name .. (strong and "Shadow" or "")] = f
	end
end

-- role: a colour name from the look ("text", "subtle", "heading", "label",
-- "accent", "points", "done"). shadow = set over the map art.
function T.Text(parent, text, font, role, width, shadow)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(T.FONTS[(font or "Body") .. (shadow and "Shadow" or "")])
	fs:SetJustifyH("LEFT")
	fs:SetText(text or "")
	if width then fs:SetWidth(width) end
	fs.role = role or "text"
	T.OnTheme(function(look)
		local c = look[fs.role] or look.text
		fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	end)
	return fs
end

function T.SetRole(fs, role)
	fs.role = role
	local c = T.Look()[role] or T.Look().text
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

---------------------------------------------------------------------------
-- Pixel-fine lines and borders, re-snapped when the UI scale changes.
---------------------------------------------------------------------------
local function pixel()
	local _, ph = GetPhysicalScreenSize()
	local es = UIParent:GetEffectiveScale()
	if not ph or ph <= 0 or not es or es <= 0 then return 1 end
	return 768 / ph / es
end

local function noSnap(t)
	if t.SetSnapToPixelGrid then
		t:SetSnapToPixelGrid(false)
		t:SetTexelSnappingBias(0)
	end
end

local borders, lines = {}, {}

local function layoutBorder(b)
	local e = pixel()
	b.T:SetHeight(e)
	b.B:SetHeight(e)
	b.L:SetWidth(e)
	b.R:SetWidth(e)
	b.L:ClearAllPoints()
	b.L:SetPoint("TOPLEFT", 0, -e)
	b.L:SetPoint("BOTTOMLEFT", 0, e)
	b.R:ClearAllPoints()
	b.R:SetPoint("TOPRIGHT", 0, -e)
	b.R:SetPoint("BOTTOMRIGHT", 0, e)
end

-- role: the look's colour for the edge (followed on theme change), or nil
-- to colour it yourself with :SetColor.
function T.Border(frame, role)
	local b = {}
	for _, k in ipairs({ "T", "B", "L", "R" }) do
		local t = frame:CreateTexture(nil, "BORDER", nil, 7)
		t:SetTexture(WHITE)
		noSnap(t)
		b[k] = t
	end
	b.T:SetPoint("TOPLEFT")
	b.T:SetPoint("TOPRIGHT")
	b.B:SetPoint("BOTTOMLEFT")
	b.B:SetPoint("BOTTOMRIGHT")
	function b:SetColor(r, g, bl, a)
		for _, k in ipairs({ "T", "B", "L", "R" }) do self[k]:SetVertexColor(r, g, bl, a or 1) end
	end
	function b:SetShown(v)
		for _, k in ipairs({ "T", "B", "L", "R" }) do self[k]:SetShown(v) end
	end
	layoutBorder(b)
	borders[#borders + 1] = b
	if role then
		T.OnTheme(function(look)
			local c = look[role]
			b:SetColor(c[1], c[2], c[3], c[4] or 1)
		end)
	end
	return b
end

function T.Line(parent, vertical, role, layer)
	local l = parent:CreateTexture(nil, layer or "BORDER")
	l:SetTexture(WHITE)
	noSnap(l)
	l.vertical = vertical
	if vertical then l:SetWidth(pixel()) else l:SetHeight(pixel()) end
	lines[#lines + 1] = l
	if role then
		T.OnTheme(function(look)
			local c = look[role]
			l:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		end)
	end
	return l
end

local scaleWatch = CreateFrame("Frame")
scaleWatch:RegisterEvent("UI_SCALE_CHANGED")
scaleWatch:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
scaleWatch:SetScript("OnEvent", function()
	ns.After(0, function()
		for _, b in ipairs(borders) do layoutBorder(b) end
		for _, l in ipairs(lines) do
			if l.vertical then l:SetWidth(pixel()) else l:SetHeight(pixel()) end
		end
	end)
end)

-- A soft fade from one colour to clear, across a texture.
function T.Gradient(tex, orientation, r, g, b, a1, a2)
	tex:SetTexture(WHITE)
	if tex.SetGradient and CreateColor then
		tex:SetGradient(orientation, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2))
	else
		tex:SetVertexColor(r, g, b, (a1 + a2) / 2)
	end
end

---------------------------------------------------------------------------
-- Circles: round-masked squares (dots, pins, icons).
---------------------------------------------------------------------------
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

function T.Round(tex)
	if not tex.AddMaskTexture then return end
	local mask = tex:GetParent():CreateMaskTexture()
	mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(tex)
	tex:AddMaskTexture(mask)
end

function T.Circle(parent, size, layer, sub)
	local c = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
	c:SetTexture(WHITE)
	c:SetSize(size, size)
	T.Round(c)
	return c
end

---------------------------------------------------------------------------
-- Motion: one driver runs every tween; apply() gets the eased progress.
---------------------------------------------------------------------------
local tweens, progress = {}, setmetatable({}, { __mode = "k" })
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, elapsed)
	for key, tw in pairs(tweens) do
		local step = elapsed / tw.dur
		if tw.p < tw.target then tw.p = math.min(tw.target, tw.p + step) else tw.p = math.max(tw.target, tw.p - step) end
		progress[key] = tw.p
		local ok, err = pcall(tw.apply, tw.ease and tw.ease(tw.p) or tw.p)
		if not ok then
			tweens[key] = nil
			geterrorhandler()(err)
		elseif tw.p == tw.target then
			tweens[key] = nil
		end
	end
	if not next(tweens) then self:Hide() end
end)

T.Ease = { outQuart = function(p) return 1 - (1 - p) ^ 4 end }

function T.Tween(key, target, dur, apply, ease)
	tweens[key] = { p = progress[key] or 0, target = target, dur = dur, apply = apply, ease = ease }
	driver:Show()
end

function T.Progress(key) return progress[key] or 0 end
function T.SetProgress(key, p) progress[key] = p end

function T.FadeIn(frame, dur)
	progress[frame] = 0
	frame:SetAlpha(0)
	T.Tween(frame, 1, dur or 0.2, function(p) frame:SetAlpha(p) end)
end

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
function T.Date(t, long)
	if not t or t == 0 then return "" end
	return date(long and "%d %b %Y" or "%d %b", t)
end

function T.Coords(x, y)
	if not x or not y then return nil end
	return ("%.1f, %.1f"):format(x, y)
end

function T.Number(n)
	local s = tostring(math.floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
