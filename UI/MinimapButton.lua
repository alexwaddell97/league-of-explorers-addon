-- A minimap button: click to open the journal, drag to move it around the
-- minimap's edge (round or square minimaps alike).

local _, ns = ...

local button

local function place()
	local angle = math.rad(ns.db.settings.minimap.angle or 215)
	local x, y = math.cos(angle), math.sin(angle)
	local w = (Minimap:GetWidth() / 2) + 6
	local h = (Minimap:GetHeight() / 2) + 6
	local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
	if square then
		-- Push the point out to the square's edge.
		local m = math.max(math.abs(x), math.abs(y))
		x, y = x / m, y / m
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
end

local function create()
	button = CreateFrame("Button", "LeagueOfExplorersMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	button:SetScript("OnClick", function() ns.Journal.Toggle() end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local scale = Minimap:GetEffectiveScale()
			local cx, cy = GetCursorPosition()
			cx, cy = cx / scale, cy / scale
			ns.db.settings.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
			place()
		end)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("League of Explorers")
		local me = ns.Me()
		if me then
			local P = ns.Points
			GameTooltip:AddDoubleLine("Points this week", P.Total(me, P.WeekStart()), 1, 0.82, 0, 1, 1, 1)
			GameTooltip:AddDoubleLine("Points all time", P.Total(me), 1, 0.82, 0, 1, 1, 1)
		end
		GameTooltip:AddLine("Click to open your journal. Drag to move.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	place()
end

local function apply()
	if ns.db.settings.minimap.hide then
		if button then button:Hide() end
		return
	end
	if not button then create() end
	button:Show()
end

ns.Listen("READY", apply)
ns.Listen("MINIMAP_SETTING", apply)

ns.Commands.minimap = function()
	ns.db.settings.minimap.hide = not ns.db.settings.minimap.hide
	apply()
	ns.Print("minimap button", ns.db.settings.minimap.hide and "hidden" or "shown")
end
