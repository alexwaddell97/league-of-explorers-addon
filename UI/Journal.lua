-- The journal window: the map banner across the top, tabs beneath it, and
-- the open page below. A settings popover (the gear on the map) switches
-- between the Explorer and Blizzard looks and holds the few preferences.
--
-- Pages register with Journal.Register({ id, order, title, icon,
-- build(c), refresh(c), banner(c) }). c is the page's content frame
-- (CW x CH). banner(c) returns what the map shows for that page:
-- { map, focus = { x, y }, pin, live, kicker, title, sub, big, bigLabel,
--   bigRole, dots = { n, total, done } }; live = follow the player.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets
local J = {}
ns.Journal = J

-- One margin round the window, one gap between blocks: the page's edges
-- line up with the map's.
local WIN_W, EDGE, GAP = 880, 8, 12
local BANNER_H, TAB_H = 156, 38
local CW, CH = WIN_W - 2 * EDGE, 392
local RIM = 18 -- extra height under the Blizzard look, for the rim's title band
J.CW, J.CH = CW, CH
local WIN_H = EDGE + BANNER_H + TAB_H + GAP + CH + EDGE

local pages, byId = {}, {}
local frame, current

function J.Register(def)
	table.insert(pages, def)
	byId[def.id] = def
	table.sort(pages, function(a, b) return a.order < b.order end)
end

local function sound(kit)
	if SOUNDKIT and SOUNDKIT[kit] then pcall(PlaySound, SOUNDKIT[kit]) end
end

---------------------------------------------------------------------------
-- Settings popover
---------------------------------------------------------------------------
local function buildSettings(f)
	local s = W.Panel(f)
	s:SetSize(260, 188)
	s:SetFrameLevel(f:GetFrameLevel() + 40)
	s:EnableMouse(true)
	s:Hide()
	local bg = s:CreateTexture(nil, "BACKGROUND", nil, -1)
	bg:SetAllPoints()
	T.OnTheme(function(look) T.Fill(bg, { look.window[1], look.window[2], look.window[3], 1 }) end)

	local lookLabel = W.Label(s, "Look")
	lookLabel:SetPoint("TOPLEFT", 14, -14)
	local seg = W.Segments(s, function(key) T.SetLook(key) end)
	seg:Rebuild({ { key = "explorer", label = "Explorer" }, { key = "blizzard", label = "Blizzard" } })
	seg:SetPoint("TOPLEFT", lookLabel, "BOTTOMLEFT", 0, -8)

	local prefs = W.Label(s, "Preferences")
	prefs:SetPoint("TOPLEFT", seg, "BOTTOMLEFT", 0, -18)
	local settings = ns.db.settings
	local toggles = {
		W.Toggle(s, "Discovery pop-ups", 228, function() return settings.toasts end, function(v) settings.toasts = v end),
		W.Toggle(s, "Sounds", 228, function() return settings.sound end, function(v) settings.sound = v end),
		W.Toggle(s, "Minimap button", 228, function() return not settings.minimap.hide end, function(v)
			settings.minimap.hide = not v
			ns.Fire("MINIMAP_SETTING")
		end),
	}
	local prev = prefs
	for i, t in ipairs(toggles) do
		t:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -8 or -4)
		prev = t
	end
	s:SetScript("OnShow", function()
		seg:Select(settings.look or "explorer")
		for _, t in ipairs(toggles) do t:Refresh() end
	end)
	return s
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function build()
	local f = CreateFrame("Frame", "LeagueOfExplorersJournal", UIParent)
	frame = f
	f:SetSize(WIN_W, WIN_H)
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
	table.insert(UISpecialFrames, "LeagueOfExplorersJournal")
	f:SetScript("OnShow", function(self)
		sound("IG_CHARACTER_INFO_OPEN")
		T.FadeIn(self, 0.18)
	end)
	f:SetScript("OnHide", function()
		sound("IG_CHARACTER_INFO_CLOSE")
		if f.settings then f.settings:Hide() end
	end)

	-- Chrome: flat slate with a hairline, or the game's rock and metal rim.
	f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.bg:SetAllPoints()
	f.rock = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	f.rock:SetAllPoints()
	f.rock:SetTexture(T.Skin.ROCK, "REPEAT", "REPEAT")
	f.rock:SetHorizTile(true)
	f.rock:SetVertTile(true)
	f.edge = T.Border(f)

	f.banner = W.MapBanner(f, CW, BANNER_H)
	f.bannerEdge = T.Border(f.banner.text, "line")

	-- Tabs
	f.tabStrip = CreateFrame("Frame", nil, f)
	f.tabStrip:SetHeight(TAB_H)
	f.tabStrip:SetPoint("TOPLEFT", f.banner, "BOTTOMLEFT", 0, 0)
	f.tabStrip:SetPoint("TOPRIGHT", f.banner, "BOTTOMRIGHT", 0, 0)
	f.tabBg = f.tabStrip:CreateTexture(nil, "BACKGROUND")
	f.tabBg:SetAllPoints()
	local tabLine = T.Line(f.tabStrip, false, "line")
	tabLine:SetPoint("BOTTOMLEFT")
	tabLine:SetPoint("BOTTOMRIGHT")
	local items = {}
	for _, p in ipairs(pages) do items[#items + 1] = { id = p.id, label = p.title, icon = p.icon } end
	f.tabs = W.Tabs(f.tabStrip, items, function(id) J.Show(id) end)
	-- The first icon lines up with the text on the map and in the panels.
	f.tabs:SetPoint("LEFT", 2, 0)

	-- Buttons over the map: settings, and close (the Blizzard look puts
	-- close in the rim's corner instead).
	f.close = W.RoundButton(f, 24, "close", function() f:Hide() end)
	f.close:SetPoint("TOPRIGHT", f.banner, "TOPRIGHT", -10, -10)
	f.close:SetFrameLevel(f.banner:GetFrameLevel() + 20)
	f.gear = W.RoundButton(f, 24, "Interface\\Icons\\INV_Misc_Gear_01", function()
		f.settings:SetShown(not f.settings:IsShown())
		sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
	end)
	f.gear:SetFrameLevel(f.banner:GetFrameLevel() + 20)
	f.gear:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Look and preferences")
		GameTooltip:Show()
	end)
	f.gear:HookScript("OnLeave", function() GameTooltip:Hide() end)
	f.settings = buildSettings(f)
	f.settings:SetPoint("TOPRIGHT", f.gear, "BOTTOMRIGHT", 0, -6)

	for _, p in ipairs(pages) do
		local c = CreateFrame("Frame", nil, f)
		c:SetPoint("TOPLEFT", f.tabStrip, "BOTTOMLEFT", 0, -GAP)
		c:SetSize(CW, CH)
		c:Hide()
		p.content = c
	end

	T.OnTheme(function(look)
		local skin = look.skin
		if skin and f.rim == nil then
			f.rim = T.Skin.NineSlice(f, "ButtonFrameTemplateNoPortrait", 30) or false
			local ok, b = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
			f.rimClose = ok and b or false
			if f.rimClose then
				f.rimClose:SetScript("OnClick", function() f:Hide() end)
			end
		end
		local rim = skin and f.rim or nil
		local w = look.window
		f.bg:SetColorTexture(w[1], w[2], w[3], w[4])
		f.rock:SetShown(skin and true or false)
		f.rock:SetVertexColor(0.55, 0.55, 0.55, 0.9)
		if f.rim then f.rim:SetShown(rim and true or false) end
		f.edge:SetShown(not rim)
		local e = look.windowEdge
		f.edge:SetColor(e[1], e[2], e[3], e[4])
		T.Fill(f.tabBg, look.tabBar)

		f:SetHeight(WIN_H + (rim and RIM or 0))
		f.banner:ClearAllPoints()
		f.banner:SetPoint("TOPLEFT", EDGE, rim and -(EDGE + RIM) or -EDGE)
		local closeInRim = rim and f.rimClose
		if f.rimClose then
			f.rimClose:SetShown(closeInRim and true or false)
			if closeInRim then
				f.rimClose:ClearAllPoints()
				f.rimClose:SetPoint("TOPRIGHT", 2, 1)
				f.rimClose:SetFrameLevel(f.rim:GetFrameLevel() + 2)
			end
		end
		f.close:SetShown(not closeInRim)
		f.gear:ClearAllPoints()
		if closeInRim then
			f.gear:SetPoint("TOPRIGHT", f.banner, "TOPRIGHT", -10, -10)
		else
			f.gear:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
		end
	end)
end

---------------------------------------------------------------------------
-- Pages and the banner
---------------------------------------------------------------------------

local function ensure(p)
	if p.built then return p.ok end
	p.built = true
	local ok, err = pcall(p.build, p.content)
	p.ok = ok
	if not ok then
		geterrorhandler()(err)
		local msg = T.Text(p.content, "This page ran into a problem and couldn't open. The rest of the journal still works.", "Body", "subtle", CW - 80)
		msg:SetPoint("TOP", 0, -60)
		msg:SetJustifyH("CENTER")
	end
	return ok
end

local function updateBanner(p)
	if not (p and p.banner and p.ok) then return end
	local ok, b = pcall(p.banner, p.content)
	if not ok then
		geterrorhandler()(b)
		return
	end
	b = b or {}
	frame.banner:SetMap(b.map, b.focus, b.pin)
	frame.banner:SetHeadline(b)
	frame.live = b.live
end

local function refresh(p)
	if p and p.refresh and p.ok then
		local ok, err = pcall(p.refresh, p.content)
		if not ok then geterrorhandler()(err) end
	end
	updateBanner(p)
end

-- Pages call this when their selection changes what the map should show.
function J.UpdateBanner()
	if frame and frame:IsShown() then updateBanner(current) end
end

function J.Show(id)
	if not ns.db then return end
	if not frame then build() end
	local p = byId[id] or byId[ns.db.settings.page] or pages[1]
	local changed = current ~= p
	current = p
	ns.db.settings.page = p.id
	ensure(p)
	for _, other in ipairs(pages) do other.content:SetShown(other == p) end
	frame.tabs:Select(p.id)
	frame:Show()
	refresh(p)
	if changed then T.FadeIn(p.content, 0.25) end
end

function J.Toggle()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		J.Show(ns.db.settings.page)
	end
end

function J.IsShown()
	return frame and frame:IsShown()
end

-- New entries and sightings redraw the open page, a few times a second at most.
local pending = false
local function refreshSoon()
	if pending or not J.IsShown() then return end
	pending = true
	ns.After(0.25, function()
		pending = false
		if J.IsShown() then refresh(current) end
	end)
end
ns.Listen("ENTRY_ADDED", refreshSoon)
ns.Listen("SIGHTING", refreshSoon)
ns.Listen("LOOK_CHANGED", refreshSoon)

-- A map that follows the player keeps its pin where they are.
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
	acc = acc + elapsed
	if acc < 1 then return end
	acc = 0
	if frame and frame:IsShown() and frame.live then updateBanner(current) end
end)
ns.On("ZONE_CHANGED_NEW_AREA", refreshSoon)

ns.Commands.look = function(rest)
	local name = (rest or ""):lower()
	if not T.LOOKS[name] then
		name = (ns.db.settings.look == "blizzard") and "explorer" or "blizzard"
	end
	T.SetLook(name)
	ns.Print("look:", name)
end
