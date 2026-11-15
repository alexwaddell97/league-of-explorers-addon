-- Supporting the journal's maker on Ko-fi (the journal is made for the
-- League of Explorers guild; the support goes to its maker, not the
-- guild). The game can't open web pages, so the link is shown in a box,
-- already selected, ready to copy. It's offered
-- quietly: a small cup in the corner of the journal beside the cog, a line
-- at the foot of the settings, and /loe kofi.

local ADDON, ns = ...

local T, W = ns.Theme, ns.Widgets
local S = {}
ns.Support = S

S.URL = "https://ko-fi.com/vaxorus"
S.ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Kofi.tga"

local function build()
	-- The screen behind dims; clicking it closes the box.
	local m = CreateFrame("Frame", nil, UIParent)
	m:SetAllPoints()
	m:SetFrameStrata("DIALOG")
	m:EnableMouse(true)
	m.dim = m:CreateTexture(nil, "BACKGROUND")
	m.dim:SetAllPoints()
	m.dim:SetColorTexture(0, 0, 0, 0.45)
	m:SetScript("OnMouseDown", function() m:Hide() end)

	local card = CreateFrame("Frame", nil, m)
	card:SetSize(400, 200)
	card:SetPoint("CENTER", 0, 40)
	card:EnableMouse(true)
	card.bg = card:CreateTexture(nil, "BACKGROUND")
	card.bg:SetAllPoints()
	T.Border(card, "coverEdge")
	T.OnTheme(function(look) T.Fill(card.bg, { look.page[1], look.page[2], look.page[3], 1 }) end)

	local icon = card:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(S.ICON)
	icon:SetSize(26, 26)
	icon:SetPoint("TOPLEFT", 20, -18)
	local title = T.Text(card, "Support the addon", "Title", "heading", 320)
	title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	local note = T.Text(card, "I make this addon for the League of Explorers in my spare time. If you'd like to support it, "
		.. "you can buy me a coffee on Ko-fi.", "Small", "subtle", 360)
	note:SetPoint("TOPLEFT", 20, -58)
	note:SetSpacing(2)
	local how = T.Text(card, "Press Ctrl+C to copy the link, then paste it into your browser.", "Small", "subtle", 360)
	how:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -8)

	m.field = W.Field(card, 360, "", 80)
	m.field:SetPoint("BOTTOMLEFT", 20, 50)
	local edit = m.field.edit
	-- The link stays as it is, and stays selected, whatever is typed.
	edit:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= S.URL then self:SetText(S.URL) end
		m.field.hint:Hide()
		self:HighlightText()
	end)
	edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	edit:SetScript("OnEnterPressed", function() m:Hide() end)
	edit:SetScript("OnEscapePressed", function() m:Hide() end)

	local close = W.Button(card, "Close", 90, 24, function() m:Hide() end)
	close:SetPoint("BOTTOMRIGHT", -16, 14)
	m:Hide()
	S.box = m
	return m
end

function S.Show()
	local m = S.box or build()
	m:Show()
	m.field.edit:SetText(S.URL)
	m.field.edit:SetFocus()
	m.field.edit:HighlightText()
end

-- A small, quiet text link with the cup.
function S.Link(parent)
	local b = CreateFrame("Button", nil, parent)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(S.ICON)
	b.icon:SetSize(14, 14)
	b.icon:SetPoint("LEFT", 0, 0)
	b.icon:SetAlpha(0.8)
	b.text = T.Text(b, "Support the addon on Ko-fi", "Small", "subtle")
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
	b:SetSize(b.text:GetStringWidth() + 22, 16)
	b:SetScript("OnEnter", function(self)
		T.SetRole(self.text, "accent")
		self.icon:SetAlpha(1)
	end)
	b:SetScript("OnLeave", function(self)
		T.SetRole(self.text, "subtle")
		self.icon:SetAlpha(0.8)
	end)
	b:SetScript("OnClick", function() S.Show() end)
	return b
end

-- The cup in the journal's corner: a round button like the cog beside it.
function S.Button(parent)
	local b = W.RoundButton(parent, 18, S.ICON, function() S.Show() end)
	b.parts[1]:SetTexCoord(0, 1, 0, 1)
	b:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Support the addon", 1, 0.82, 0)
		GameTooltip:AddLine("Shows my Ko-fi link to copy into your browser.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:HookScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

ns.Commands.kofi = function() S.Show() end
ns.Commands.support = ns.Commands.kofi
