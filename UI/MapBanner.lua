-- The map banner across the top of the journal: the real map of a zone,
-- drawn from the client's own map tiles, with the areas you have explored
-- painted in (exactly as the world map paints them), a pin for you or for a
-- find, and the page's headline over it.
--
-- Base tiles: C_Map.GetMapArtLayers / GetMapArtLayerTextures.
-- Explored areas: C_MapExplorationInfo.GetExploredMapTextures, each overlay
-- laid out in tiles from its offset, the last row and column cut from a
-- power-of-two file, as Blizzard's MapExplorationPinMixin does.
-- The map is scaled to the banner's width and slid so the pin sits in view.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets

local function pow2(n)
	local f = 16
	while f < n do f = f * 2 end
	return f
end

function W.MapBanner(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	if f.SetClipsChildren then f:SetClipsChildren(true) end

	f.fallback = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	f.fallback:SetAllPoints()

	f.canvas = CreateFrame("Frame", nil, f)
	f.canvas:SetPoint("TOPLEFT")
	f.canvas:SetSize(1, 1)
	f.base, f.overlay = {}, {}

	-- Shading so the words read over any map.
	local shade = CreateFrame("Frame", nil, f)
	shade:SetAllPoints()
	shade:SetFrameLevel(f.canvas:GetFrameLevel() + 2)
	f.wash = shade:CreateTexture(nil, "BACKGROUND")
	f.wash:SetAllPoints()
	f.wash:SetColorTexture(0, 0, 0, 0.30)
	f.bottom = shade:CreateTexture(nil, "BORDER")
	f.bottom:SetPoint("BOTTOMLEFT")
	f.bottom:SetPoint("BOTTOMRIGHT")
	f.bottom:SetHeight(h * 0.75)
	f.left = shade:CreateTexture(nil, "BORDER")
	f.left:SetPoint("TOPLEFT")
	f.left:SetPoint("BOTTOMLEFT")
	f.left:SetWidth(w * 0.55)
	f.shade = shade

	-- The pin: a dot with a slow pulse ring.
	f.pin = CreateFrame("Frame", nil, f)
	f.pin:SetSize(28, 28)
	f.pin:SetFrameLevel(shade:GetFrameLevel() + 1)
	f.pin.ring = T.Circle(f.pin, 26, "ARTWORK", 0)
	f.pin.ring:SetPoint("CENTER")
	f.pin.dot = T.Circle(f.pin, 10, "ARTWORK", 2)
	f.pin.dot:SetPoint("CENTER")
	f.pin.core = T.Circle(f.pin, 4, "ARTWORK", 3)
	f.pin.core:SetPoint("CENTER")
	f.pin.core:SetVertexColor(1, 1, 1, 0.95)
	local pulse = 0
	f.pin:SetScript("OnUpdate", function(self, elapsed)
		pulse = (pulse + elapsed * 0.6) % 1
		local s = 10 + 18 * pulse
		self.ring:SetSize(s, s)
		self.ring:SetAlpha(0.55 * (1 - pulse))
	end)
	f.pin:Hide()

	-- Headline
	local text = CreateFrame("Frame", nil, f)
	text:SetAllPoints()
	text:SetFrameLevel(shade:GetFrameLevel() + 2)
	f.text = text
	f.kicker = T.Text(text, "", "Label", "label", nil, true)
	f.kicker:SetPoint("BOTTOMLEFT", 14, 70)
	f.title = T.Text(text, "", "Huge", "heading", w * 0.6, true)
	f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -5)
	f.title:SetWordWrap(false)
	f.sub = T.Text(text, "", "Small", "text", w * 0.6, true)
	f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
	f.dots = W.Dots(text, 7, 4, 32)
	f.dots:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -9)
	f.big = T.Text(text, "", "Display", "accent", nil, true)
	f.big:SetPoint("BOTTOMRIGHT", -14, 30)
	f.big:SetJustifyH("RIGHT")
	f.bigLabel = T.Text(text, "", "Label", "label", nil, true)
	f.bigLabel:SetPoint("TOPRIGHT", f.big, "BOTTOMRIGHT", 0, -3)
	f.bigLabel:SetJustifyH("RIGHT")

	T.OnTheme(function(look)
		local p = look.window
		T.Gradient(f.bottom, "VERTICAL", p[1], p[2], p[3], 0.97, 0)
		T.Gradient(f.left, "HORIZONTAL", 0, 0, 0, 0.55, 0)
		f.fallback:SetColorTexture(look.panel[1], look.panel[2], look.panel[3], 1)
		local a = look.accent
		f.pin.ring:SetVertexColor(a[1], a[2], a[3], 1)
		f.pin.dot:SetVertexColor(a[1], a[2], a[3], 1)
	end)

	local function tex(pool, i)
		local t = pool[i]
		if not t then
			t = f.canvas:CreateTexture(nil, "ARTWORK", nil, pool == f.base and 0 or 1)
			pool[i] = t
		end
		t:Show()
		return t
	end

	-- Draws mapID; focus = { x, y } in 0-100 to keep in view and pin.
	function f:SetMap(mapID, focus, pin)
		local layers = mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
		local layer = layers and layers[1]
		local files = layer and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID, 1)
		for _, t in ipairs(self.base) do t:Hide() end
		for _, t in ipairs(self.overlay) do t:Hide() end
		if not (layer and files and #files > 0 and layer.layerWidth and layer.layerWidth > 0) then
			self.canvas:Hide()
			self.pin:Hide()
			self.mapID = nil
			return
		end
		local changed = self.mapID ~= mapID
		self.mapID = mapID
		self.canvas:Show()
		local lw, lh, tw, th = layer.layerWidth, layer.layerHeight, layer.tileWidth, layer.tileHeight
		local scale = w / lw
		self.canvas:SetScale(scale)
		self.canvas:SetSize(lw, lh)

		local cols = math.ceil(lw / tw)
		for i, file in ipairs(files) do
			local t = tex(self.base, i)
			t:SetTexture(file)
			t:SetSize(tw, th)
			t:SetTexCoord(0, 1, 0, 1)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", ((i - 1) % cols) * tw, -math.floor((i - 1) / cols) * th)
		end

		local n = 0
		local ok, explored = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
		if ok and type(explored) == "table" then
			for _, info in ipairs(explored) do
				if not info.isShownByMouseOver and info.fileDataIDs then
					local wide = math.ceil(info.textureWidth / tw)
					local tall = math.ceil(info.textureHeight / th)
					for j = 1, tall do
						local ph, fh = th, th
						if j == tall then
							ph = info.textureHeight % th
							if ph == 0 then ph = th end
							fh = pow2(ph)
						end
						for k = 1, wide do
							local pw, fw = tw, tw
							if k == wide then
								pw = info.textureWidth % tw
								if pw == 0 then pw = tw end
								fw = pow2(pw)
							end
							local file = info.fileDataIDs[(j - 1) * wide + k]
							if file then
								n = n + 1
								local t = tex(self.overlay, n)
								t:SetTexture(file)
								t:SetSize(pw, ph)
								t:SetTexCoord(0, pw / fw, 0, ph / fh)
								t:ClearAllPoints()
								t:SetPoint("TOPLEFT", self.canvas, "TOPLEFT",
									info.offsetX + (k - 1) * tw, -(info.offsetY + (j - 1) * th))
							end
						end
					end
				end
			end
		end

		-- Slide the map so the focus point sits a little above the middle.
		local fy = focus and focus.y and focus.y / 100 or 0.5
		local shown = lh * scale
		local y = math.max(0, math.min(shown - h, fy * shown - h * 0.42))
		self.canvas:ClearAllPoints()
		self.canvas:SetPoint("TOPLEFT", self, "TOPLEFT", 0, y / scale)

		if pin and focus and focus.x and focus.y then
			self.pin:ClearAllPoints()
			self.pin:SetPoint("CENTER", self, "TOPLEFT", focus.x / 100 * w, -(focus.y / 100 * shown - y))
			self.pin:Show()
		else
			self.pin:Hide()
		end
		if changed then T.FadeIn(self.canvas, 0.35) end
	end

	-- o = { kicker, title, sub, big, bigLabel, dots = { n, total, done }, bigRole }
	function f:SetHeadline(o)
		self.kicker:SetText((o.kicker or ""):upper())
		self.title:SetText(o.title or "")
		self.sub:SetText(o.sub or "")
		self.big:SetText(o.big or "")
		T.SetRole(self.big, o.bigRole or "accent")
		self.bigLabel:SetText((o.bigLabel or ""):upper())
		if o.dots and o.dots[2] and o.dots[2] > 0 then
			self.dots:Show()
			self.dots:SetProgress(o.dots[1], o.dots[2], o.dots[3])
		else
			self.dots:Hide()
		end
	end

	return f
end

-- Where the player is: their zone (or the map they're on) and position.
function W.PlayerFocus()
	local best = C_Map.GetBestMapForUnit("player")
	local zone = best and (ns.Exploration.ZoneOf(best) or best)
	if not zone then return nil end
	local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(zone, "player")
	if pos then
		local x, y = pos:GetXY()
		if x and y and not (x == 0 and y == 0) then return zone, { x = x * 100, y = y * 100 } end
	end
	return zone, nil
end
