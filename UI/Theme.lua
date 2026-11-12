-- The look. Two of them:
--   explorer  the League's own: dark slate panels, a turquoise cartographer's
--             accent, amber for points, and the real map of where you are
--             across the top of the window.
--   blizzard  the game's own windows: the metal rim, the rock backdrop, red
--             buttons and gold headings, worn from the client's own art.
-- Every widget paints itself through T.OnTheme, so switching looks (in the
-- journal's settings, or /loe look) repaints the whole addon at once.

local _, ns = ...

local T = {}
ns.Theme = T

local WHITE = "Interface\\Buttons\\WHITE8X8"
T.WHITE = WHITE

T.LOOKS = {
	explorer = {
		window     = { 0.050, 0.060, 0.070, 0.97 },
		windowEdge = { 1, 1, 1, 0.09 },
		tabBar     = { 1, 1, 1, 0.025 },
		panel      = { 0.095, 0.110, 0.125, 0.94 },
		panelEdge  = { 1, 1, 1, 0.07 },
		panelTop   = { 1, 1, 1, 0.05 },             -- a faint lit edge along each panel's top
		line       = { 1, 1, 1, 0.07 },
		text       = { 0.90, 0.92, 0.93 },
		subtle     = { 0.56, 0.62, 0.66 },
		heading    = { 0.97, 0.98, 0.98 },
		label      = { 0.42, 0.70, 0.67 },          -- small capitals above numbers
		accent     = { 0.27, 0.82, 0.75 },          -- turquoise
		points     = { 1.00, 0.76, 0.33 },          -- amber
		done       = { 0.47, 0.84, 0.43 },
		hover      = { 0.27, 0.82, 0.75, 0.07 },
		select     = { 0.27, 0.82, 0.75, 0.14 },
		stripe     = { 1, 1, 1, 0.018 },
		track      = { 1, 1, 1, 0.08 },
		thumb      = { 0.27, 0.82, 0.75, 0.45 },
		btn        = { 0.27, 0.82, 0.75, 0.12 },    btnHover = { 0.27, 0.82, 0.75, 0.24 },
		btnEdge    = { 0.27, 0.82, 0.75, 0.45 },    btnEdgeHover = { 0.27, 0.82, 0.75, 0.9 },
		btnText    = { 0.80, 0.95, 0.92 },          btnTextHover = { 1, 1, 1 },
		kinds = {
			zone = { 0.27, 0.82, 0.75 }, zonefull = { 0.47, 0.84, 0.43 }, continent = { 1.00, 0.76, 0.33 },
			area = { 0.45, 0.52, 0.56 }, rare = { 0.78, 0.58, 1.00 }, treasure = { 1.00, 0.84, 0.40 },
		},
	},
	blizzard = {
		skin = true,
		window     = { 0.06, 0.055, 0.05, 0.97 },
		windowEdge = { 0.62, 0.48, 0.27, 0.60 },
		tabBar     = { 0, 0, 0, 0.25 },
		panel      = { 0.02, 0.02, 0.02, 0.70 },
		panelEdge  = { 0.62, 0.48, 0.27, 0.45 },
		panelTop   = { 1, 1, 1, 0 },
		line       = { 0.62, 0.48, 0.27, 0.30 },
		text       = { 0.93, 0.92, 0.89 },
		subtle     = { 0.66, 0.64, 0.60 },
		heading    = { 1, 0.82, 0 },
		label      = { 1, 0.82, 0, 0.75 },
		accent     = { 1, 0.82, 0 },
		points     = { 1, 0.82, 0 },
		done       = { 0.12, 1, 0.12 },
		hover      = { 1, 0.82, 0, 0.07 },
		select     = { 1, 0.82, 0, 0.14 },
		stripe     = { 1, 1, 1, 0.025 },
		track      = { 1, 1, 1, 0.06 },
		thumb      = { 0.62, 0.48, 0.27, 0.65 },
		btn        = { 0.36, 0.05, 0.03, 1 },       btnHover = { 0.48, 0.08, 0.05, 1 },
		btnEdge    = { 0.70, 0.55, 0.30, 0.65 },    btnEdgeHover = { 0.95, 0.80, 0.45, 0.9 },
		btnText    = { 1, 0.82, 0 },                btnTextHover = { 1, 1, 1 },
		-- Item-quality colours, as the game uses for its own finds.
		kinds = {
			zone = { 1, 0.82, 0 }, zonefull = { 0.12, 1, 0.12 }, continent = { 1, 0.5, 0 },
			area = { 0.62, 0.62, 0.62 }, rare = { 0.0, 0.44, 0.87 }, treasure = { 0.64, 0.21, 0.93 },
		},
	},
}

function T.Look()
	local s = ns.db and ns.db.settings
	return T.LOOKS[s and s.look or "explorer"] or T.LOOKS.explorer
end

function T.Skinned() return T.Look().skin == true end

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

function T.SetLook(name)
	if not T.LOOKS[name] then return end
	ns.db.settings.look = name
	local look = T.Look()
	for _, fn in ipairs(painters) do
		local ok, err = pcall(fn, look)
		if not ok then geterrorhandler()(err) end
	end
	ns.Fire("LOOK_CHANGED", name)
end

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
		f:SetShadowColor(0, 0, 0, strong and 0.95 or 0.5)
		f:SetShadowOffset(1, -1)
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
-- The game's own frame art, for the Blizzard look. Nothing is shipped: the
-- art is read from the client's templates, and anything this client lacks
-- falls back to flat drawing.
---------------------------------------------------------------------------
local Skin = {}
T.Skin = Skin

-- One of the game's nine-slice layouts on a frame above `f`'s content, or nil.
function Skin.NineSlice(f, layout, lift)
	local NS = rawget(_G, "NineSliceUtil")
	if not (NS and NS.ApplyLayoutByName) then return nil end
	local ok, frame = pcall(CreateFrame, "Frame", nil, f, "NineSlicePanelTemplate")
	if not ok or not frame then return nil end
	frame:SetAllPoints()
	local applied = pcall(NS.ApplyLayoutByName, frame, layout)
	local piece = applied and (frame.TopLeftCorner or frame.TopEdge)
	if not (piece and ((piece.GetAtlas and piece:GetAtlas()) or piece:GetTexture())) then
		frame:Hide()
		return nil
	end
	frame:EnableMouse(false)
	frame:SetFrameLevel(f:GetFrameLevel() + (lift or 1))
	return frame
end

Skin.ROCK = "Interface\\FrameGeneral\\UI-Background-Rock"

-- What a texture is drawing right now (atlas, or file and coords), or nil.
local function snap(tex)
	if not tex then return nil end
	local atlas = tex.GetAtlas and tex:GetAtlas()
	if atlas and atlas ~= "" then return { atlas = atlas } end
	local file = tex:GetTexture()
	if not file then return nil end
	return { file = file, coords = { tex:GetTexCoord() } }
end

function Skin.Paint(tex, s)
	if not s then
		tex:Hide()
		return
	end
	if s.atlas then
		tex:SetAtlas(s.atlas)
	else
		tex:SetTexture(s.file)
		tex:SetTexCoord(unpack(s.coords))
	end
	tex:Show()
end

-- The red panel button's three pieces, read once from the game's template.
local buttonArt
function Skin.ButtonArt()
	if buttonArt == nil then
		buttonArt = false
		local ok, b = pcall(CreateFrame, "Button", nil, UIParent, "UIPanelButtonTemplate")
		if ok and b then
			b:Hide()
			b:SetSize(110, 22)
			if type(b.Left) == "table" and type(b.Middle) == "table" and type(b.Right) == "table" then
				local art = { cap = b.Left:GetWidth(), snap(b.Left), snap(b.Middle), snap(b.Right),
					highlight = snap(b:GetHighlightTexture()) }
				if not (art.cap and art.cap > 1) then art.cap = 12 end
				if art[1] and art[2] and art[3] then buttonArt = art end
			end
		end
	end
	return buttonArt or nil
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
