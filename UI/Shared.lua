-- Small things several pages share: icons for each kind of entry, who
-- counts as the guild, names in class colours, and the board's rows.

local _, ns = ...

local T, W = ns.Theme, ns.Widgets
local U = {}
ns.UI = U

ns.KIND_ICON = {
	zone = "Interface\\Icons\\INV_Misc_Map_01",
	zonefull = "Interface\\Icons\\INV_Misc_Map02",
	continent = "Interface\\Icons\\INV_Misc_Spyglass_02",
	area = "Interface\\Icons\\INV_Misc_Note_02",
	rare = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	treasure = "Interface\\Icons\\INV_Misc_TreasureChest01b",
	place = "Interface\\Icons\\Ability_Tracking",
	weekly = "Interface\\Icons\\INV_Misc_Spyglass_03",
	weeklyall = "Interface\\Icons\\INV_Crown_01",
	bestiary = "Interface\\Icons\\INV_Misc_Book_07",
	atlas = "Interface\\Icons\\INV_Misc_Map02",
	expedition = "Interface\\Icons\\INV_Misc_Spyglass_03",
	bounty = "Interface\\Icons\\INV_Misc_Coin_02",
	milestone = "Interface\\Icons\\INV_Banner_02",
	alert = "Interface\\Icons\\Ability_Hunter_SniperShot",
}

-- The guild as a set of "Name-Realm": everyone on the roster, plus you.
-- Outside a guild, or solo, just this account's characters.
function U.Members()
	local set = {}
	if not ns.Solo() and (ns.Guild.InGuild() or (ns.Work and ns.Work.demo)) then
		for who in pairs(ns.Guild.members) do set[who] = true end
	else
		for who in pairs(ns.db.chars) do set[who] = true end
	end
	local me = ns.Me()
	if me then set[me] = true end
	return set
end

-- How many members have written in the journal at all.
function U.SignedUp(members)
	local seen, n = {}, 0
	for _, e in ipairs(ns.db.entries) do
		if members[e.who] and not seen[e.who] then
			seen[e.who] = true
			n = n + 1
		end
	end
	return n
end

function U.ClassName(who, class)
	local name = ns.ShortName(who)
	local m = ns.Guild.Member(who)
	class = class or (m and m.class) or (ns.db.chars[who] and ns.db.chars[who].class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if not c then return name end
	-- Deepened so it reads on paper and parchment alike.
	local k = 0.58
	return ("|cff%s%s|r"):format(T.Hex({ c.r * k, c.g * k, c.b * k }), name)
end

function U.Ago(t)
	if not t then return "" end
	local s = ns.Now() - t
	if s < 90 then return "just now" end
	if s < 3600 then return math.floor(s / 60) .. "m ago" end
	if s < 86400 then return math.floor(s / 3600) .. "h ago" end
	local d = math.floor(s / 86400)
	if d == 1 then return "yesterday" end
	if d < 14 then return d .. " days ago" end
	return T.Date(t, true)
end

-- A heading inside a page: a title with a thin rule running after it.
function U.Heading(parent, text)
	local fs = T.Text(parent, text, "Title", "heading")
	local rule = W.Divider(parent)
	rule:SetPoint("LEFT", fs, "RIGHT", 10, -1)
	rule:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	rule:SetPoint("TOP", fs, "CENTER", 0, 0)
	fs.rule = rule
	return fs
end

-- A ruled box with an icon and a short message: for pages still to come,
-- and for empty boards.
function U.Note(parent, w, h, icon, title, body)
	local p = W.Panel(parent)
	p:SetSize(w, h)
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetSize(36, 36)
	p.icon:SetPoint("TOP", 0, -18)
	p.icon:SetTexture(icon)
	p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	T.Round(p.icon)
	p.icon:SetAlpha(0.6)
	p.title = T.Text(p, title, "Header", "heading", w - 40)
	p.title:SetPoint("TOP", p.icon, "BOTTOM", 0, -10)
	p.title:SetJustifyH("CENTER")
	p.body = T.Text(p, body or "", "Small", "subtle", w - 40)
	p.body:SetPoint("TOP", p.title, "BOTTOM", 0, -6)
	p.body:SetJustifyH("CENTER")
	p.body:SetSpacing(3)
	return p
end

-- Board rows. Left: the place (a gold, silver or bronze medal for the top
-- three), the class icon, the name in ink, and beneath it the explorer rank
-- (and guild rank, when it differs). Right: points, and beneath them where
-- the member is now, with a green dot, when they're online.
local MEDALS = { { 0.83, 0.64, 0.18 }, { 0.62, 0.64, 0.68 }, { 0.71, 0.45, 0.24 } }
local CLASS_ICONS = "Interface\\WorldStateFrame\\ICONS-CLASSES"

function U.BoardBuild(row)
	row.medal = T.Circle(row, 22, "ARTWORK", 0)
	row.medal:SetPoint("LEFT", 6, 0)
	row.place = T.Text(row, "", "Header", "subtle")
	row.place:SetPoint("CENTER", row.medal, "CENTER", 0, 0)
	row.place:SetJustifyH("CENTER")
	row.class = row:CreateTexture(nil, "ARTWORK")
	row.class:SetSize(18, 18)
	row.class:SetPoint("LEFT", row.medal, "RIGHT", 10, 0)
	row.name = T.Text(row, "", "Header", "text")
	row.name:SetPoint("TOPLEFT", row.class, "TOPRIGHT", 8, 3)
	row.name:SetPoint("RIGHT", -110, 0)
	row.name:SetWordWrap(false)
	row.sub = T.Text(row, "", "Label", "subtle")
	row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
	row.sub:SetPoint("RIGHT", -110, 0)
	row.sub:SetWordWrap(false)
	row.pts = T.Text(row, "", "Title", "points")
	row.pts:SetPoint("TOPRIGHT", -8, -4)
	row.pts:SetJustifyH("RIGHT")
	row.where = T.Text(row, "", "Label", "subtle")
	row.where:SetPoint("TOPRIGHT", row.pts, "BOTTOMRIGHT", 0, -3)
	row.where:SetJustifyH("RIGHT")
	row.where:SetWordWrap(false)
	row.online = T.Circle(row, 6, "ARTWORK")
	row.online:SetPoint("RIGHT", row.where, "LEFT", -4, 0)
end

function U.BoardFill(row, r, i)
	local look = T.Look()
	local medal = MEDALS[i]
	row.place:SetText(i)
	row.medal:SetShown(medal ~= nil)
	if medal then
		row.medal:SetVertexColor(medal[1], medal[2], medal[3], 1)
		row.place:SetTextColor(1, 0.98, 0.92)
	else
		T.SetRole(row.place, "subtle")
	end

	local m = ns.Guild.Member(r.who)
	local class = (m and m.class) or (ns.db.chars[r.who] and ns.db.chars[r.who].class)
	local tc = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if tc then
		row.class:SetTexture(CLASS_ICONS)
		row.class:SetTexCoord(tc[1] + 0.015, tc[2] - 0.015, tc[3] + 0.015, tc[4] - 0.015)
		row.class:Show()
	else
		row.class:Hide()
	end

	local you = r.who == ns.Me()
	row.name:SetText(ns.ShortName(r.who) .. (you and ("  |cff%s(you)|r"):format(T.Hex(look.subtle)) or ""))
	local _, rank = ns.Points.RankOf(r.who)
	local bits = { rank.name }
	if r.alts and r.alts > 0 then bits[#bits + 1] = r.alts == 1 and "and 1 alt" or ("and " .. r.alts .. " alts") end
	if m and m.rank and m.rank ~= rank.name then bits[#bits + 1] = m.rank end
	row.sub:SetText(table.concat(bits, "  /  "))

	row.pts:SetText(T.Number(r.points))
	local online = m and m.online and m.zone and m.zone ~= ""
	row.where:SetText(online and m.zone or "")
	row.online:SetShown(online and true or false)
	row.online:SetVertexColor(look.done[1], look.done[2], look.done[3], 1)
	-- No highlight band: "(you)" marks your row.
	row.sel:Hide()
	row.selBar:Hide()
end
