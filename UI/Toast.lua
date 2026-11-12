-- Discovery toasts: a card near the top of the screen for each entry that
-- earns points, with a line along its foot that drains as it times out.
-- They stack, hold while hovered, and open the journal when clicked.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets

local KIND = {
	zone = { title = "Zone discovered", page = "atlas" },
	zonefull = { title = "Zone fully explored", page = "atlas" },
	continent = { title = "New continent", page = "atlas" },
	rare = { title = "Rare creature found", page = "bestiary" },
	treasure = { title = "Treasure found", page = "treasures" },
}

local TOAST_W, TOAST_H, TOP, MAX, HOLD = 320, 60, 150, 4, 5
local pool, active = {}, {}

local function layout()
	local y = -TOP
	for _, f in ipairs(active) do
		f.baseY = y
		f:ClearAllPoints()
		f:SetPoint("TOP", UIParent, "TOP", 0, y + (f.slide or 0))
		y = y - TOAST_H - 8
	end
end

local function release(f)
	for i, a in ipairs(active) do
		if a == f then
			table.remove(active, i)
			f:Hide()
			f:SetScript("OnUpdate", nil)
			pool[#pool + 1] = f
			layout()
			return
		end
	end
end

local function make()
	local f = CreateFrame("Button", nil, UIParent)
	f:SetSize(TOAST_W, TOAST_H)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.rock = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.rock:SetAllPoints()
	f.rock:SetTexture(T.Skin.ROCK, "REPEAT", "REPEAT")
	f.rock:SetHorizTile(true)
	f.rock:SetVertTile(true)
	f.edge = T.Border(f)
	f.ring = T.Circle(f, 40, "ARTWORK", 0)
	f.ring:SetPoint("LEFT", 12, 0)
	f.icon = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.icon:SetSize(36, 36)
	f.icon:SetPoint("CENTER", f.ring)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	T.Round(f.icon)
	f.kicker = T.Text(f, "", "Label", "label")
	f.kicker:SetPoint("TOPLEFT", f.ring, "TOPRIGHT", 12, -4)
	f.name = T.Text(f, "", "Title", "heading", TOAST_W - 150)
	f.name:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -5)
	f.name:SetWordWrap(false)
	f.big = T.Text(f, "", "Huge", "points")
	f.big:SetPoint("RIGHT", -16, 0)
	f.big:SetJustifyH("RIGHT")
	f.timer = f:CreateTexture(nil, "ARTWORK")
	f.timer:SetTexture(T.WHITE)
	f.timer:SetHeight(2)
	f.timer:SetPoint("BOTTOMLEFT", 1, 1)
	T.OnTheme(function(look)
		local w = look.window
		f.bg:SetColorTexture(w[1], w[2], w[3], 0.96)
		f.rock:SetShown(look.skin and true or false)
		f.rock:SetVertexColor(0.55, 0.55, 0.55, 0.9)
		local e = look.skin and look.windowEdge or look.panelEdge
		f.edge:SetColor(e[1], e[2], e[3], look.skin and 0.9 or 0.16)
	end)
	f:SetScript("OnEnter", function(self) self.hovered = true end)
	f:SetScript("OnLeave", function(self) self.hovered = false end)
	return f
end

local function playSound()
	if not ns.db.settings.sound or not SOUNDKIT then return end
	for _, kit in ipairs({ "UI_EPICLOOT_TOAST", "IG_QUEST_LIST_COMPLETE", "READY_CHECK" }) do
		if SOUNDKIT[kit] and pcall(PlaySound, SOUNDKIT[kit]) then return end
	end
end

function ns.Toast(e)
	local k = KIND[e.kind]
	if not k then return end
	local f = table.remove(pool) or make()
	local col = T.KindColor(e.kind)
	f.ring:SetVertexColor(col[1], col[2], col[3], 1)
	f.timer:SetVertexColor(col[1], col[2], col[3], 0.9)
	f.icon:SetTexture(ns.KIND_ICON and ns.KIND_ICON[e.kind] or "Interface\\Icons\\INV_Misc_Map_01")
	f.kicker:SetText(k.title:upper())
	f.name:SetText(e.name or (e.map and ns.MapName(e.map)) or "")
	f.big:SetText("+" .. ns.Points.Of(e))
	f:SetScript("OnClick", function()
		release(f)
		if ns.Journal then ns.Journal.Show(k.page) end
	end)

	table.insert(active, 1, f)
	while #active > MAX do release(active[#active]) end
	f.slide, f.hovered = 14, false
	f:SetAlpha(0)
	f.timer:SetWidth(TOAST_W - 2)
	f:Show()
	layout()
	playSound()

	local life, t = 0.35, 0
	f:SetScript("OnUpdate", function(self, elapsed)
		if self.hovered and t > life then return end
		t = t + elapsed
		if t < life then
			local p = T.Ease.outQuart(t / life)
			self:SetAlpha(p)
			self.slide = 14 * (1 - p)
			self:SetPoint("TOP", UIParent, "TOP", 0, self.baseY + self.slide)
		elseif t < life + HOLD then
			if self.slide ~= 0 then
				self.slide = 0
				self:SetAlpha(1)
				self:SetPoint("TOP", UIParent, "TOP", 0, self.baseY)
			end
			self.timer:SetWidth(math.max(0.01, (TOAST_W - 2) * (1 - (t - life) / HOLD)))
		elseif t < life + HOLD + 0.4 then
			self:SetAlpha(1 - (t - life - HOLD) / 0.4)
		else
			release(self)
		end
	end)
end

ns.Listen("ENTRY_ADDED", function(e)
	if not KIND[e.kind] or ns.Points.Of(e) <= 0 then return end
	ns.Print(("%s: %s (+%d)"):format(KIND[e.kind].title, e.name or ns.MapName(e.map) or "?", ns.Points.Of(e)))
	if ns.db.settings.toasts then ns.Toast(e) end
end)
