-- Bestiary and Treasures: the same page for two kinds of find. The list on
-- the left; the find's record and its sightings on the right; the map above
-- shows where it was last seen, with a pin on the spot.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets

local LIST_W = 340

local function placeText(s)
	if not s then return "-" end
	local zone = s.zone and ns.MapName(s.zone) or (s.map and ns.MapName(s.map)) or "Somewhere unknown"
	local xy = T.Coords(s.x, s.y)
	return xy and (zone .. "  " .. xy) or zone
end

-- The game's own map marker, where this client has one.
local function canMark(s)
	return s and s.map and s.x and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates
		and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(s.map)) and true or false
end

local function mark(s)
	if not canMark(s) then return end
	local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(s.map, s.x / 100, s.y / 100))
	if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
	end
	ns.Print(ok and "marked on your map." or "this map can't take a marker.")
end

local function makePage(def)
	local function build(c)
		local CW, CH = ns.Journal.CW, ns.Journal.CH
		c.list = W.List(c, LIST_W, CH, 44, {
			emptyText = def.empty,
			emptyIcon = def.icon,
			build = function(row)
				row.icon = row:CreateTexture(nil, "ARTWORK")
				row.icon:SetSize(28, 28)
				row.icon:SetPoint("LEFT", 8, 0)
				row.icon:SetTexture(def.icon)
				row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				T.Round(row.icon)
				row.name = T.Text(row, "", "Header", "text")
				row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 1)
				row.name:SetPoint("RIGHT", -48, 0)
				row.name:SetWordWrap(false)
				row.where = T.Text(row, "", "Small", "subtle")
				row.where:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
				row.where:SetPoint("RIGHT", -48, 0)
				row.where:SetWordWrap(false)
				row.count = W.Chip(row)
				row.count:SetPoint("RIGHT", -8, 0)
			end,
			fill = function(row, f)
				row.name:SetText(f.name or "Unknown")
				local c1 = T.KindColor(def.kind)
				row.name:SetTextColor(c1[1], c1[2], c1[3])
				local last = f.sightings[#f.sightings]
				local zone = last and last.zone and ns.MapName(last.zone) or ""
				row.where:SetText(zone ~= "" and (zone .. "  /  " .. T.Date(last.t)) or T.Date(last and last.t))
				row.count:Set(f.count > 1 and ("x" .. f.count) or nil)
			end,
			onClick = function(f)
				c.selected = f
				c.list:Render()
				c.ShowFind()
				ns.Journal.UpdateBanner()
			end,
			isSelected = function(f) return f == c.selected end,
		})
		c.list:SetPoint("TOPLEFT")

		-- The record ----------------------------------------------------------
		local d = W.Panel(c)
		local DW = CW - LIST_W - 12
		d:SetPoint("TOPRIGHT")
		d:SetSize(DW, CH)
		local iw = DW - 28
		local detail = {}
		local function keep(x)
			detail[#detail + 1] = x
			return x
		end

		local rl = keep(W.Label(d, "Record"))
		rl:SetPoint("TOPLEFT", 14, -14)
		c.rows = {}
		local prev = rl
		for i, label in ipairs({ "First sighted", "Times seen", "Last seen", "Where", "Found by you" }) do
			local s = keep(W.Stat(d, label, iw))
			s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -10 or -4)
			local rule = keep(W.Divider(d))
			rule:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
			rule:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
			c.rows[i] = s
			prev = s
		end

		c.markBtn = keep(W.Button(d, "Mark on my map", 150, 24, function()
			if c.selected then mark(c.selected.sightings[#c.selected.sightings]) end
		end))
		c.markBtn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
		c.note = keep(T.Text(d, "", "Small", "subtle", iw - 164))
		c.note:SetPoint("LEFT", c.markBtn, "RIGHT", 12, 0)

		local sl = keep(W.Label(d, "Sightings"))
		sl:SetPoint("TOPLEFT", c.markBtn, "BOTTOMLEFT", 0, -20)
		c.sightings = keep(W.List(d, iw + 8, 150, 28, {
			bare = true,
			stripes = false,
			build = W.TimelineBuild,
			fill = function(row, si, i, last)
				W.TimelineFill(row, def.kind, T.Date(si.t), ns.ShortName(si.who) .. "  /  " .. placeText(si),
					si.dead and "slain" or "", i == 1, last)
				T.SetRole(row.right, "subtle")
			end,
		}))
		c.sightings:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", -4, -6)

		c.blank = T.Text(d, def.blank, "Body", "subtle", iw)
		c.blank:SetPoint("CENTER")
		c.blank:SetJustifyH("CENTER")

		function c.ShowFind()
			local f = c.selected
			for _, x in ipairs(detail) do x:SetShown(f ~= nil) end
			c.blank:SetShown(f == nil)
			if not f then return end
			local fs, last = f.first, f.sightings[#f.sightings]
			c.rows[1].value:SetText(("%s, %s"):format(T.Date(fs and fs.t, true), ns.ShortName(fs and fs.who)))
			c.rows[2].value:SetText(f.count)
			c.rows[3].value:SetText(T.Date(last and last.t, true))
			c.rows[4].value:SetText(placeText(last))
			local mine = ns.Ledger.Has(def.kind, f.id)
			if mine then
				c.rows[5].value:SetText(("%s  +%d"):format(T.Date(mine.t, true), ns.Points.Of(mine)))
				T.SetRole(c.rows[5].value, "points")
			else
				c.rows[5].value:SetText(def.notMine)
				T.SetRole(c.rows[5].value, "subtle")
			end
			local markable = canMark(last)
			c.markBtn:SetEnabled(markable)
			c.note:SetText(markable and "" or "No position was noted for this sighting.")
			local rev = {}
			for i = #f.sightings, 1, -1 do rev[#rev + 1] = f.sightings[i] end
			c.sightings:SetItems(rev)
		end
	end

	local function refresh(c)
		local finds = ns.Rares.List(def.kind)
		c.count = #finds
		if c.selected and not ns.db.finds[def.kind .. ":" .. tostring(c.selected.id)] then c.selected = nil end
		c.selected = c.selected or finds[1]
		c.list:SetItems(finds, true)
		c.ShowFind()
	end

	-- The map: where the chosen find was last seen, pinned.
	local function banner(c)
		local f = c.selected
		if not f then
			local zone, focus = W.PlayerFocus()
			return { map = zone, focus = focus, pin = true, live = true, kicker = def.title, title = def.none,
				sub = def.noneSub }
		end
		local last = f.sightings[#f.sightings]
		local zone = last and (last.zone or last.map)
		local focus
		if last and last.x and last.y and last.map == zone then focus = { x = last.x, y = last.y } end
		return {
			map = zone, focus = focus, pin = focus ~= nil,
			kicker = def.kicker,
			title = f.name or "Unknown",
			sub = ("Last seen %s in %s"):format(T.Date(last and last.t, true), placeText(last)),
			big = tostring(f.count), bigLabel = f.count == 1 and "sighting" or "sightings",
			bigRole = "points",
		}
	end

	ns.Journal.Register({
		id = def.id,
		order = def.order,
		title = def.title,
		icon = def.icon,
		build = build,
		refresh = refresh,
		banner = banner,
	})
end

makePage({
	id = "bestiary",
	kind = "rare",
	order = 3,
	title = "Bestiary",
	kicker = "Rare creature",
	icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	notMine = "Only seen slain",
	none = "No rares sighted yet",
	noneSub = "Rares are noted when they show on your minimap, by nameplate, or when you target one.",
	empty = "No rares sighted yet. A rare creature is written here the moment you see one.",
	blank = "Choose a creature from the list.",
})

makePage({
	id = "treasures",
	kind = "treasure",
	order = 4,
	title = "Treasures",
	kicker = "Treasure",
	icon = "Interface\\Icons\\INV_Misc_TreasureChest01b",
	notMine = "-",
	none = "No treasures found yet",
	noneSub = "Treasures are noted when the game marks one on your minimap.",
	empty = "No treasures noted yet. When the game marks a treasure on your minimap, it is written here.",
	blank = "Choose a treasure from the list.",
})
