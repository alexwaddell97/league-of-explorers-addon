-- Discovery toasts: a card near the top of the screen for each entry that
-- earns points, with a line along its foot that drains as it times out.
-- They stack, hold while hovered, and open the journal when clicked.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets

local KIND = {
	zone = { title = "Zone discovered", page = "journal" },
	zonefull = { title = "Zone fully explored", page = "journal" },
	continent = { title = "New continent", page = "journal" },
	rare = { title = "Rare creature found", page = "bestiary" },
	treasure = { title = "Treasure found", page = "journal" },
	expedition = { title = "Expedition complete", page = "expeditions" },
	place = { title = "Guild place found", page = "submissions" },
	weekly = { title = "Weekly hunt target", page = "expeditions" },
	weeklyall = { title = "Weekly hunt complete", page = "expeditions" },
	bestiary = { title = "Collection complete", page = "bestiary" },
	atlas = { title = "Collection complete", page = "journal" },
	bounty = { title = "Bounty claimed", page = "expeditions" },
	alert = { title = "Rare spotted", page = "bestiary" },
}

local TOAST_W, TOAST_H, MAX, HOLD, GAP = 320, 60, 3, 5, 8
local pool, active = {}, {}

---------------------------------------------------------------------------
-- Where pop-ups appear: the top of the screen, clear of the game's own
-- zone names and error text, unless moved. In the lower half of the
-- screen they stack upwards.
---------------------------------------------------------------------------
local holder

local function anchor()
	if holder then return holder end
	holder = CreateFrame("Frame", "LeagueOfExplorersToastAnchor", UIParent)
	holder:SetSize(TOAST_W, TOAST_H)
	holder:SetFrameStrata("DIALOG")
	holder:SetMovable(true)
	holder:SetClampedToScreen(true)
	local pos = ns.db.settings.toastPos
	if type(pos) == "table" and pos[1] then
		holder:SetPoint(pos[1], UIParent, pos[1], pos[2] or 0, pos[3] or 0)
	else
		holder:SetPoint("TOP", UIParent, "TOP", 0, -24)
	end
	-- Shown only while moving it.
	holder.bg = holder:CreateTexture(nil, "BACKGROUND")
	holder.bg:SetAllPoints()
	holder.bg:SetColorTexture(0.10, 0.42, 0.46, 0.45)
	holder.edge = T.Border(holder)
	holder.text = T.Text(holder, "Pop-ups appear here. Drag to move, right-click when done.", "Small", "text", TOAST_W - 20)
	holder.text:SetPoint("CENTER")
	holder.text:SetJustifyH("CENTER")
	holder:SetScript("OnMouseDown", function(self, button)
		if button == "RightButton" then ns.MoveToasts(false) else self:StartMoving() end
	end)
	holder:SetScript("OnMouseUp", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint()
		ns.db.settings.toastPos = { point, x, y }
	end)
	ns.MoveToasts(false)
	return holder
end

-- Shows the pop-up area so it can be dragged (or hides it again).
function ns.MoveToasts(on)
	local h = anchor()
	h.moving = on and true or false
	h:EnableMouse(h.moving)
	h.bg:SetShown(h.moving)
	h.text:SetShown(h.moving)
	if h.edge.SetShown then h.edge:SetShown(h.moving) end
	if h.moving then ns.Print("drag the pop-up area where you want it, then right-click it.") end
end

function ns.ResetToasts()
	ns.db.settings.toastPos = nil
	local h = anchor()
	h:ClearAllPoints()
	h:SetPoint("TOP", UIParent, "TOP", 0, -24)
end

local function growsUp()
	local top, height = holder and holder:GetTop(), UIParent:GetHeight()
	return type(top) == "number" and type(height) == "number" and top < height / 2
end

local function place(f)
	local up = growsUp()
	f:ClearAllPoints()
	if up then
		f:SetPoint("BOTTOM", holder, "BOTTOM", 0, -f.baseY - (f.slide or 0))
	else
		f:SetPoint("TOP", holder, "TOP", 0, f.baseY + (f.slide or 0))
	end
end

local function layout()
	local y = 0
	for _, f in ipairs(active) do
		f.baseY = y
		place(f)
		y = y - TOAST_H - GAP
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
		local e = look.windowEdge
		f.edge:SetColor(e[1], e[2], e[3], e[4])
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

-- The game's own big zone names: a pop-up waits until they've gone (a few
-- seconds at most), so the two never sit on top of each other.
local function gameBusy()
	for _, name in ipairs({ "ZoneTextFrame", "SubZoneTextFrame", "RaidWarningFrame" }) do
		local fr = rawget(_G, name)
		if type(fr) == "table" and fr.IsShown and fr:IsShown() and (not fr.GetAlpha or (fr:GetAlpha() or 0) > 0.05) then
			return true
		end
	end
	return false
end

function ns.Toast(e, waited)
	local k = KIND[e.kind]
	if not k then return end
	waited = waited or 0
	if waited < 8 and gameBusy() then
		ns.After(0.5, function() ns.Toast(e, waited + 0.5) end)
		return
	end
	anchor()
	local f = table.remove(pool) or make()
	local col = T.KindColor(e.kind)
	f.ring:SetVertexColor(col[1], col[2], col[3], 1)
	f.timer:SetVertexColor(col[1], col[2], col[3], 0.9)
	f.icon:SetTexture(ns.KIND_ICON and ns.KIND_ICON[e.kind] or "Interface\\Icons\\INV_Misc_Map_01")
	f.kicker:SetText((e.kicker or k.title):upper())
	f.name:SetText(e.name or (e.map and ns.MapName(e.map)) or "")
	f.big:SetText(e.big or ("+" .. (e.points or ns.Points.Of(e))))
	f:SetScript("OnClick", function()
		release(f)
		if e.onClick then e.onClick() elseif ns.Journal then ns.Journal.Show(k.page) end
	end)
	local HOLD = e.hold or HOLD

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
			place(self)
		elseif t < life + HOLD then
			if self.slide ~= 0 then
				self.slide = 0
				self:SetAlpha(1)
				place(self)
			end
			self.timer:SetWidth(math.max(0.01, (TOAST_W - 2) * (1 - (t - life) / HOLD)))
		elseif t < life + HOLD + 0.4 then
			self:SetAlpha(1 - (t - life - HOLD) / 0.4)
		else
			release(self)
		end
	end)
end

-- Finishing an expedition (or claiming a bounty) gets its own toast.
ns.Listen("EXPEDITION_DONE", function(x)
	local first = ns.Work.Finishers(x)[1]
	local mine = first and first.who == ns.Me()
	if x.bounty and not mine then return end
	local pts = x.reward + ((not x.bounty and mine) and math.floor(x.reward / 2) or 0)
	ns.Print(("%s: %s (+%d)"):format(x.bounty and "Bounty claimed" or "Expedition complete", x.title, pts))
	if ns.db.settings.toasts then ns.Toast({ kind = x.bounty and "bounty" or "expedition", name = x.title, points = pts }) end
end)

-- The weekly hunt: each target, and all five.
ns.Listen("WEEKLY_HIT", function(g, band)
	local name = ns.Work.WeeklyName(g)
	local P = ns.Points
	ns.Print(("Weekly hunt: %s (+%d)"):format(name, P.Value("weekly")))
	if ns.db.settings.toasts then ns.Toast({ kind = "weekly", name = name, points = P.Value("weekly") }) end
	local hits = ns.Work.WeeklyHits(P.Player(ns.Me()))
	local n = 0
	for _ in pairs(hits) do n = n + 1 end
	if n == #ns.Work.Weekly(nil, band) then
		ns.Print(("Weekly hunt complete! (+%d)"):format(P.Value("weeklyall")))
		if ns.db.settings.toasts then ns.Toast({ kind = "weeklyall", name = "All five found", points = P.Value("weeklyall") }) end
	end
end)

-- Collections: toast each newly completed one (not those already done).
local knownCollections
ns.Listen("ENTRY_ADDED", function(e)
	if e.who ~= ns.Me() or not (e.kind == "rare" or e.kind == "zonefull") then return end
	local player = ns.Points.Player(ns.Me())
	local now = {}
	for _, c in ipairs(ns.Work.Collections(player)) do now[c.kind .. c.key] = c end
	if knownCollections then
		for k, c in pairs(now) do
			if not knownCollections[k] and c.points > 0 then
				ns.Print(("Collection complete: %s (+%d)"):format(c.label, c.points))
				if ns.db.settings.toasts then ns.Toast({ kind = c.kind, name = c.label, points = c.points }) end
			end
		end
	end
	knownCollections = now
end)
ns.Listen("READY", function()
	ns.After(5, function()
		local me = ns.Me()
		if not me then return end
		knownCollections = {}
		for _, c in ipairs(ns.Work.Collections(ns.Points.Player(me))) do knownCollections[c.kind .. c.key] = c end
	end)
end)

ns.Listen("ENTRY_ADDED", function(e)
	if not KIND[e.kind] or ns.Points.Of(e) <= 0 then return end
	ns.Print(("%s: %s (+%d)"):format(KIND[e.kind].title, e.name or ns.MapName(e.map) or "?", ns.Points.Of(e)))
	if ns.db.settings.toasts then ns.Toast(e) end
end)

-- A guildmate spotted a rare: a pop-up that sets a waypoint when clicked,
-- held a little longer than the others.
local WHY = { weekly = "weekly hunt", bounty = "bounty", expedition = "expedition" }
ns.Listen("RARE_ALERT", function(a, target)
	local where = ("%s %s"):format(ns.MapName(a.map) or "?", T.Coords(a.x, a.y))
	local extra = target and (" (%s, +%d)"):format(WHY[target.why] or target.why, target.reward or 0) or ""
	ns.Print(("%s spotted %s in %s%s."):format(ns.ShortName(a.who), a.name, where, extra))
	ns.Toast({
		kind = "alert", kicker = "Spotted by " .. ns.ShortName(a.who), name = a.name,
		big = target and ("+" .. (target.reward or 0)) or "", hold = 10,
		onClick = function() ns.Alerts.Waypoint(a.map, a.x, a.y, a.name) end,
	})
end)
