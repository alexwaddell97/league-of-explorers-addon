-- Pins on the world map and the minimap:
--   * rares spotted by you or a guildmate in the last few minutes (pulsing)
--   * rares you're asked to kill (this week's hunt, bounties, expeditions),
--     where you or the guild last saw them. Never their spawn points from
--     the rare list: finding them is the point.
--   * guild places (approved submissions), faded once you've been
-- Hover for what it is; click to set a waypoint.

local _, ns = ...

local T = ns.Theme
local MP = {}
ns.MapPins = MP

local PIN = 20
local WHY = {
	weekly = "Weekly hunt target",
	bounty = "Bounty",
	expedition = "Expedition target",
}

---------------------------------------------------------------------------
-- What goes on the maps: { kind, map, x, y, title, lines, pulse, faded }
---------------------------------------------------------------------------
function MP.Items()
	local out = {}
	local A, Wk, P = ns.Alerts, ns.Work, ns.Points
	local me = ns.Me()
	if not (A and Wk and me) then return out end
	local targets = A.Targets()
	local shown = {}

	local function targetLine(t)
		if t.why == "weekly" then return ("%s  +%d"):format(WHY.weekly, t.reward) end
		return ("%s: %s  +%d"):format(WHY[t.why] or t.why, t.title or "", t.reward or 0)
	end

	for _, a in ipairs(A.Spotted()) do
		local t = targets[a.id]
		local lines = { ("Spotted by %s, %s"):format(ns.ShortName(a.who), ns.UI.Ago(a.t)) }
		if t then lines[#lines + 1] = targetLine(t) end
		out[#out + 1] = { kind = "alert", map = a.map, x = a.x, y = a.y, title = a.name, lines = lines, pulse = true }
		shown[a.id] = true
	end

	local want = {}
	for id in pairs(targets) do
		if not shown[id] then want[id] = true end
	end
	for id, seen in pairs(A.LastSeen(want)) do
		local t = targets[id]
		local r = ns.RareList and ns.RareList[id]
		local lvl = r and r[5] and (r[6] and r[6] ~= r[5] and (r[5] .. "-" .. r[6]) or tostring(r[5]))
		out[#out + 1] = {
			kind = t.why, map = seen.map, x = seen.x, y = seen.y, title = A.RareName(id),
			lines = {
				targetLine(t),
				("Last seen by %s, %s"):format(seen.who == me and "you" or ns.ShortName(seen.who), ns.UI.Ago(seen.t)),
				lvl and ("Level " .. lvl) or nil,
			},
		}
	end

	local player = P.Player(me)
	local been = {}
	for _, e in ipairs(P.Deeds(player)) do
		if e.kind == "place" then been[e.key] = true end
	end
	for _, s in ipairs(Wk.Places()) do
		local yours = P.Player(s.who) == player
		local visited = yours or been[s.id]
		out[#out + 1] = {
			kind = "place", map = s.map, x = s.x, y = s.y, title = s.title,
			lines = {
				"Guild place, suggested by " .. ns.ShortName(s.who),
				yours and "Your place" or (visited and "Visited" or ("+%d for visiting"):format(P.Value("place"))),
			},
			faded = visited,
		}
	end
	return out
end

---------------------------------------------------------------------------
-- A pin
---------------------------------------------------------------------------
local function onEnter(self)
	local item = self.item
	if not item then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(item.title or "?", 1, 0.82, 0)
	for _, line in ipairs(item.lines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
	GameTooltip:AddLine(("%s %s"):format(ns.MapName(item.map) or "", T.Coords(item.x, item.y) or ""), 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Click to set a waypoint.", 0.55, 0.85, 0.55)
	GameTooltip:Show()
end

local function onLeave() GameTooltip:Hide() end

local function onClick(self)
	local item = self.item
	if item then ns.Alerts.Waypoint(item.map, item.x, item.y, item.title) end
end

local function makePin(parent)
	local p = CreateFrame("Button", nil, parent)
	p:SetSize(PIN, PIN)
	p.glow = T.Circle(p, PIN + 14, "BACKGROUND")
	p.glow:SetPoint("CENTER")
	p.ring = T.Circle(p, PIN, "ARTWORK", 0)
	p.ring:SetPoint("CENTER")
	p.icon = p:CreateTexture(nil, "ARTWORK", nil, 1)
	p.icon:SetSize(PIN - 4, PIN - 4)
	p.icon:SetPoint("CENTER")
	p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	T.Round(p.icon)
	p:SetScript("OnEnter", onEnter)
	p:SetScript("OnLeave", onLeave)
	p:SetScript("OnClick", onClick)
	-- Fresh sightings breathe.
	p:SetScript("OnUpdate", function(self)
		if not (self.item and self.item.pulse) then return end
		local t = (GetTime() * 1.6) % 1
		self.glow:SetAlpha(0.55 * (1 - t))
		self.glow:SetSize(PIN + 4 + 16 * t, PIN + 4 + 16 * t)
	end)
	return p
end

local function dress(p, item)
	p.item = item
	local c = T.KindColor(item.kind)
	p.ring:SetVertexColor(c[1], c[2], c[3], 1)
	p.glow:SetVertexColor(c[1], c[2], c[3], 1)
	p.glow:SetShown(item.pulse and true or false)
	p.icon:SetTexture((ns.KIND_ICON and ns.KIND_ICON[item.kind]) or ns.KIND_ICON.rare)
	p.icon:SetDesaturated(item.faded and true or false)
	p:SetAlpha(item.faded and 0.6 or 1)
end

local function newPool(parent)
	local pool = { list = {}, used = 0 }
	function pool:Acquire()
		self.used = self.used + 1
		local p = self.list[self.used]
		if not p then
			p = makePin(parent)
			self.list[self.used] = p
		end
		p:Show()
		return p
	end
	function pool:ReleaseAll()
		for _, p in ipairs(self.list) do p:Hide() end
		self.used = 0
	end
	return pool
end

-- Where (x, y in 0-1) a point on `from` lies on map `to`, or nil.
local function translate(from, x, y, to)
	if from == to then return x, y end
	if not (C_Map.GetMapRectOnMap) then return nil end
	local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, from, to)
	if not ok or not minX or maxX == minX or maxY == minY then return nil end
	local tx, ty = minX + x * (maxX - minX), minY + y * (maxY - minY)
	if tx < 0 or tx > 1 or ty < 0 or ty > 1 then return nil end
	return tx, ty
end
MP.Translate = translate

-- Zones, their sub-maps and continents show pins; the whole world doesn't.
local function showsPins(mapID)
	local info = mapID and C_Map.GetMapInfo(mapID)
	local types = Enum and Enum.UIMapType
	if not (info and types) then return info ~= nil end
	return info.mapType ~= types.World and info.mapType ~= types.Cosmic
end

---------------------------------------------------------------------------
-- World map: a data provider, the way the game's own pins are drawn.
---------------------------------------------------------------------------
local provider, worldPool

local function buildWorldMap()
	if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin) then return end
	provider = CreateFromMixins(MapCanvasDataProviderMixin)

	function provider:RemoveAllData()
		if worldPool then worldPool:ReleaseAll() end
	end

	function provider:RefreshAllData()
		self:RemoveAllData()
		local map = self:GetMap()
		if not (map and ns.db and ns.db.settings.mapPins) then return end
		local mapID = map:GetMapID()
		if not showsPins(mapID) then return end
		local canvas = map:GetCanvas()
		worldPool = worldPool or newPool(canvas)
		local scale = 1 / (map:GetCanvasScale() or 1)
		local w, h = canvas:GetWidth(), canvas:GetHeight()
		for _, item in ipairs(MP.Items()) do
			local x, y = translate(item.map, item.x / 100, item.y / 100, mapID)
			if x then
				local p = worldPool:Acquire()
				dress(p, item)
				p:SetScale(scale)
				p:SetFrameLevel(canvas:GetFrameLevel() + 2500 + (item.pulse and 10 or 0))
				p:ClearAllPoints()
				p:SetPoint("CENTER", canvas, "TOPLEFT", x * w / scale, -y * h / scale)
			end
		end
	end

	function provider:OnCanvasScaleChanged() self:RefreshAllData() end

	WorldMapFrame:AddDataProvider(provider)
end

local pending = false
MP.BuildWorldMap = function() buildWorldMap(); return provider end

function MP.Refresh()
	if pending then return end
	pending = true
	ns.After(0.2, function()
		pending = false
		if provider and WorldMapFrame and WorldMapFrame:IsShown() then provider:RefreshAllData() end
		MP.MinimapItems()
	end)
end

---------------------------------------------------------------------------
-- Minimap: pins placed by distance from you. The minimap shows a fixed
-- number of yards across for each zoom level (fewer indoors); pins out of
-- range sit on the edge if they're something to hunt, and hide otherwise.
---------------------------------------------------------------------------
local YARDS = {
	indoor = { [0] = 300, 240, 180, 120, 80, 50 },
	outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
}
local miniPool, miniItems = nil, {}
local indoors, checking = false, false

local function cvar(name)
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	return get and get(name)
end

-- The game doesn't say whether the minimap is in its indoor mode; the two
-- zoom settings do, unless they're equal, when a quick nudge tells.
local function checkIndoors()
	if checking or not (Minimap and Minimap.GetZoom) then return end
	local zoom = Minimap:GetZoom()
	local outside, inside = tonumber(cvar("minimapZoom")), tonumber(cvar("minimapInsideZoom"))
	if not (outside and inside and zoom) then return end
	if outside ~= inside then
		indoors = inside == zoom
		return
	end
	checking = true
	Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
	indoors = tonumber(cvar("minimapInsideZoom")) == Minimap:GetZoom()
	Minimap:SetZoom(zoom)
	checking = false
end

-- Yards across the player's zone map.
local function zoneYards(zone)
	if C_Map.GetMapWorldSize then
		local ok, w, h = pcall(C_Map.GetMapWorldSize, zone)
		if ok and w and w > 0 then return w, h end
	end
	if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
	local ok0, _, a = pcall(C_Map.GetWorldPosFromMapPos, zone, CreateVector2D(0, 0))
	local ok1, _, b = pcall(C_Map.GetWorldPosFromMapPos, zone, CreateVector2D(1, 1))
	if not (ok0 and ok1 and a and b) then return nil end
	local ax, ay = a:GetXY()
	local bx, by = b:GetXY()
	-- One world axis runs across the map and the other down it.
	return math.abs(by - ay), math.abs(bx - ax)
end

-- The items in the player's zone, with positions on the zone map (0-1).
function MP.MinimapItems()
	miniItems = {}
	if not (ns.db and ns.db.settings.minimapPins) then
		if miniPool then miniPool:ReleaseAll() end
		return miniItems
	end
	local zone = ns.Exploration.CurrentZone()
	if not zone then return miniItems end
	for _, item in ipairs(MP.Items()) do
		local x, y = translate(item.map, item.x / 100, item.y / 100, zone)
		if x then miniItems[#miniItems + 1] = { item = item, x = x, y = y } end
	end
	return miniItems
end

-- Where each item sits on the minimap, in pixels from its centre (east
-- and south): { item, dx, dy, far }. px, py: you on the zone map (0-1);
-- zw, zh: the zone's size in yards; across: yards the minimap shows;
-- facing: radians, when the minimap turns with you.
function MP.Layout(items, px, py, zw, zh, across, radius, facing, square)
	local out = {}
	local perYard = radius * 2 / across
	local cosF, sinF = math.cos(facing or 0), math.sin(facing or 0)
	local edge = radius - 6
	for _, m in ipairs(items) do
		local dx = (m.x - px) * zw * perYard
		local dy = (m.y - py) * zh * perYard
		if facing and facing ~= 0 then dx, dy = dx * cosF - dy * sinF, dx * sinF + dy * cosF end
		local far
		if square then far = math.abs(dx) > edge or math.abs(dy) > edge else far = dx * dx + dy * dy > edge * edge end
		-- Out of range: things to hunt wait on the edge; places hide.
		if not far or m.item.kind ~= "place" then
			if far then
				local k = square and edge / math.max(math.abs(dx), math.abs(dy)) or edge / math.sqrt(dx * dx + dy * dy)
				dx, dy = dx * k, dy * k
			end
			out[#out + 1] = { item = m.item, dx = dx, dy = dy, far = far }
		end
	end
	return out
end

local function placeMinimap()
	if not miniPool then return end
	miniPool:ReleaseAll()
	if #miniItems == 0 or not Minimap:IsVisible() then return end
	local zone = ns.Exploration.CurrentZone()
	local pos = zone and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(zone, "player")
	if not pos then return end
	local px, py = pos:GetXY()
	if not px or (px == 0 and py == 0) then return end
	local zw, zh = zoneYards(zone)
	if not zw then return end
	local zoom = Minimap:GetZoom() or 0
	local across = (indoors and YARDS.indoor or YARDS.outdoor)[zoom] or YARDS.outdoor[0]
	local radius = Minimap:GetWidth() / 2
	local facing = 0
	if cvar("rotateMinimap") == "1" and GetPlayerFacing then facing = ns.Readable(GetPlayerFacing()) or 0 end
	local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
	for _, m in ipairs(MP.Layout(miniItems, px, py, zw, zh, across, radius, facing, square)) do
		local p = miniPool:Acquire()
		dress(p, m.item)
		p:SetScale(0.7)
		p:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
		if m.far then p:SetAlpha(0.55) end
		p:ClearAllPoints()
		p:SetPoint("CENTER", Minimap, "CENTER", m.dx / 0.7, -m.dy / 0.7)
	end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
ns.Listen("READY", function()
	buildWorldMap()
	if Minimap then
		miniPool = newPool(Minimap)
		local ticker = CreateFrame("Frame", nil, Minimap)
		local wait = 0
		ticker:SetScript("OnUpdate", function(_, elapsed)
			wait = wait - elapsed
			if wait > 0 then return end
			wait = 0.1
			placeMinimap()
		end)
		ns.On("MINIMAP_UPDATE_ZOOM", checkIndoors)
		ns.On("ZONE_CHANGED", checkIndoors)
		ns.On("ZONE_CHANGED_INDOORS", checkIndoors)
		ns.On("ZONE_CHANGED_NEW_AREA", function()
			checkIndoors()
			MP.Refresh()
		end)
		checkIndoors()
	end
	MP.Refresh()
	-- Sightings age off the map.
	if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(30, MP.Refresh) end
end)

for _, signal in ipairs({ "ALERTS_CHANGED", "ENTRY_ADDED", "ENTRY_MERGED", "MAP_PINS_SETTING" }) do
	ns.Listen(signal, MP.Refresh)
end
