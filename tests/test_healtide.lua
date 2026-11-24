-- Offline mock harness for HealTide.
-- Run from the repository root: lua tests/test_healtide.lua

local ADDON_FILE = os.getenv("HEALTIDE_LUA") or "HealTide.lua"

local failures = 0
local checks = 0
local function check(condition, message)
    checks = checks + 1
    if condition then
        print("PASS  " .. message)
    else
        failures = failures + 1
        print("FAIL  " .. message)
    end
end

-- ---------------------------------------------------------------------------
-- Mock widgets
-- ---------------------------------------------------------------------------

local function NewTexture()
    local t = {}
    function t:SetPoint(point, relativeTo, relPoint, x, y) self.point = { point, relativeTo, relPoint, x, y } end
    function t:GetPoint(i) local p = self.point; if not p then return nil end; return p[1], p[2], p[3], p[4], p[5] end
    function t:ClearAllPoints() self.point = nil end
    function t:SetTexture(v) self.texture = v end
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:Show() self.__shown = true end
    function t:Hide() self.__shown = false end
    function t:IsShown() return self.__shown and true or false end
    function t:SetVertexColor() end
    function t:SetBlendMode() end
    function t:SetHorizTile() end
    function t:SetVertTile() end
    function t:SetAllPoints() end
    function t:SetSize(w, h) self.width, self.height = w, h end
    function t:SetWidth(w) self.width = w end
    function t:SetHeight(h) self.height = h end
    function t:GetWidth() return self.width or 0 end
    function t:GetHeight() return self.height or 0 end
    function t:SetAlpha(a) self.alpha = a end
    function t:GetAlpha() return self.alpha or 1 end
    function t:SetAlphaFromBoolean(v, a, b) self.alpha = v and a or b end
    function t:SetDrawLayer() end
    function t:GetDrawLayer() return "ARTWORK", 0 end
    function t:SetFont() end
    function t:SetText(v) self.text = v end
    function t:GetText() return self.text or "" end
    function t:SetTextColor(r, g, b) self.textColor = { r, g, b } end
    function t:SetShadowColor() end
    function t:SetShadowOffset() end
    function t:SetJustifyH() end
    return t
end

local createdFrames = {}
local function NewFrame(frameType, name, parent, template)
    local f = {
        __type = frameType or "Frame",
        __name = name,
        __parent = parent,
        __template = template,
        __events = {},
        __scripts = {},
        __points = {},
        __shown = false,
        __width = 0,
        __height = 0,
        __level = 1,
        __mouseEnabled = false,
        __children = {},
    }
    function f:SetSize(w, h) self.__width, self.__height = w, h end
    function f:GetWidth() return self.__width end
    function f:GetHeight() return self.__height end
    function f:SetWidth(w) self.__width = w end
    function f:SetHeight(h) self.__height = h end
    function f:SetPoint(point, relativeTo, relPoint, x, y) self.__points[#self.__points + 1] = { point, relativeTo, relPoint, x, y } end
    function f:GetPoint(i) local p = self.__points[i or 1]; if not p then return nil end; return p[1], p[2], p[3], p[4], p[5] end
    function f:ClearAllPoints() self.__points = {} end
    function f:Show() self.__shown = true end
    function f:Hide() self.__shown = false end
    function f:IsShown() return self.__shown end
    function f:SetFrameStrata() end
    function f:SetFrameLevel(v) self.__level = v end
    function f:GetFrameLevel() return self.__level end
    function f:SetClampedToScreen() end
    function f:SetMovable() end
    function f:RegisterForDrag() end
    function f:EnableMouse(v) self.__mouseEnabled = v and true or false end
    function f:IsMouseEnabled() return self.__mouseEnabled end
    function f:SetScript(k, v) self.__scripts[k] = v end
    function f:GetScript(k) return self.__scripts[k] end
    function f:RegisterEvent(e) self.__events[e] = true end
    function f:RegisterUnitEvent(e) self.__events[e] = true end
    function f:UnregisterAllEvents() self.__events = {} end
    function f:SetBackdrop() end
    function f:SetBackdropColor() end
    function f:SetBackdropBorderColor(r, g, b, a) self.__borderColor = { r, g, b, a } end
    function f:GetBackdropBorderColor() return unpack(self.__borderColor or { 0, 0, 0, 1 }) end
    function f:SetClipsChildren(v) self.__clipsChildren = v and true or false end
    function f:SetStatusBarTexture(v) self.__texture = NewTexture(); self.__texture:SetTexture(v) end
    function f:GetStatusBarTexture() if not self.__texture then self.__texture = NewTexture() end; return self.__texture end
    function f:SetStatusBarColor(r, g, b, a) self.__color = { r, g, b, a } end
    function f:GetStatusBarColor() return unpack(self.__color or { 0, 0, 0, 1 }) end
    function f:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
    function f:GetMinMaxValues() return self.__min or 0, self.__max or 0 end
    function f:SetValue(v) self.__value = v end
    function f:GetValue() return self.__value or 0 end
    function f:SetAllPoints() end
    function f:SetAlpha(a) self.__alpha = a end
    function f:GetAlpha() return self.__alpha or 1 end
    function f:SetAlphaFromBoolean(v, a, b) self.__alpha = v and a or b end
    function f:SetColorTexture() end
    function f:SetTexture() end
    function f:SetVertexColor() end
    function f:SetBlendMode() end
    function f:SetHorizTile() end
    function f:SetDrawLayer() end
    function f:GetDrawLayer() return "ARTWORK", 0 end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:CreateTexture() local t = NewTexture(); self.__children[#self.__children + 1] = t; return t end
    function f:CreateFontString()
        local t = NewTexture()
        t.__type = "FontString"
        t.text = ""
        function t:SetText(v) self.text = v end
        function t:GetText() return self.text end
        function t:SetTextColor(r, g, b) self.textColor = { r, g, b } end
        function t:GetTextColor() return unpack(self.textColor or { 1, 1, 1 }) end
        function t:SetShadowColor() end
        function t:SetShadowOffset() end
        function t:SetJustifyH() end
        function t:SetWordWrap() end
        function t:SetWidth() end
        function t:SetFontObject() end
        self.__children[#self.__children + 1] = t
        return t
    end
    createdFrames[#createdFrames + 1] = f
    return f
end

UIParent = NewFrame("Frame", "UIParent")
function CreateFrame(frameType, name, parent, template) return NewFrame(frameType, name, parent, template) end

-- ---------------------------------------------------------------------------
-- Mock game state
-- ---------------------------------------------------------------------------

local mockTime = 1000
function GetTime() return mockTime end
function GetBuildInfo() return "1.60.1", "70338", "Nov 23 2026", 16001 end

local secretMode = false
function issecretvalue(v)
    if not secretMode then return false end
    local t = type(v)
    return t == "number" or t == "string"
end

local units = {
    player = { guid = "Player-1", name = "Moi", class = "PRIEST", className = "Priest", health = 500, healthMax = 1000,
        prediction = { total = 0, mine = 0, others = 0, max = 1000 } },
    target = { guid = "Target-1", name = "Cible", class = "WARRIOR", className = "Warrior", health = 400, healthMax = 1000,
        prediction = { total = 250, mine = 200, others = 50, max = 1000 } },
    party1 = { guid = "Party-1", name = "Ami", class = "DRUID", className = "Druid", health = 800, healthMax = 1000,
        prediction = { total = 100, mine = 100, others = 0, max = 1000 } },
    mouseover = { guid = "Party-1", name = "Ami", class = "DRUID", className = "Druid", health = 800, healthMax = 1000,
        prediction = { total = 100, mine = 100, others = 0, max = 1000 } },
}

function UnitExists(u) return units[u] ~= nil end
function UnitCanAssist() return true end
function UnitIsUnit(a, b) return a == b end
function UnitGUID(u) local v = units[u]; return v and v.guid or nil end
function UnitName(u) local v = units[u]; return v and v.name or nil end
function UnitFullName(u) local v = units[u]; return v and v.name or nil, nil end
function UnitClass(u)
    local v = units[u]
    if not v then return nil end
    return v.className, v.class, 1
end
function UnitHealth(u) local v = units[u]; return v and v.health or nil end
function UnitHealthMax(u) local v = units[u]; return v and v.healthMax or nil end
function IsInRaid() return false end

local castEnd = nil
function UnitCastingInfo(u)
    if u == "player" and castEnd then
        return "Heal", "", 1, 0, castEnd * 1000, false, "cast1", false, 2060
    end
    return nil
end
function UnitChannelInfo() return nil end

function UnitHealthPercent(u)
    local v = units[u]
    if not v then return { GetRGB = function() return 1, 0, 0 end } end
    local hp = v.health / v.healthMax
    return { GetRGB = function() return 1 - hp, hp, 0 end }
end

-- ---------------------------------------------------------------------------
-- Mock prediction calculators
-- ---------------------------------------------------------------------------

local function NewCalculator()
    local c = {
        current = { total = 0, mine = 0, others = 0, max = 1000, totalAll = 0, totalFromHealer = 0, clamped = false },
        lastClampMode = nil,
    }
    function c:SetMaximumHealthMode() end
    function c:SetIncomingHealClampMode(mode) self.lastClampMode = mode end
    function c:SetIncomingHealOverflowPercent() end
    function c:SetDamageAbsorbClampMode() end
    function c:GetMaximumHealth() return self.current.max end
    function c:GetIncomingHeals() return self.current.total, self.current.mine, self.current.others, self.current.clamped end
    function c:GetTotalIncomingHeals() return self.current.totalAll end
    function c:GetTotalIncomingHealsFromHealer() return self.current.totalFromHealer end
    return c
end

function CreateUnitHealPredictionCalculator() return NewCalculator() end
function UnitGetDetailedHealPrediction(u, _, calc)
    local v = units[u]
    if not v then
        calc.current = { total = 0, mine = 0, others = 0, max = 1000, totalAll = 0, totalFromHealer = 0, clamped = false }
        return
    end
    local p = v.prediction
    local missing = p.max - v.health
    local boundary = missing
    if calc.lastClampMode == Enum.UnitIncomingHealClampMode.MaximumHealth then boundary = p.max end
    local function clamp(n)
        if n > boundary then return boundary, true end
        return n, false
    end
    local total, tc = clamp(p.total)
    local mine, mc = clamp(p.mine)
    local others, oc = clamp(p.others)
    calc.current = {
        total = total, mine = mine, others = others, max = p.max,
        totalAll = p.total, totalFromHealer = p.mine or 0, clamped = tc or mc or oc,
    }
end

C_Spell = {
    GetSpellName = function(id)
        local names = { [2060] = "Greater Heal", [17] = "Power Word: Shield" }
        return names[id]
    end,
}

RAID_CLASS_COLORS = {
    PRIEST = { r = 1, g = 1, b = 1 },
    DRUID = { r = 1, g = 0.5, b = 0.25 },
    PALADIN = { r = 1, g = 0.6, b = 0.8 },
    SHAMAN = { r = 0, g = 0.5, b = 1 },
    WARRIOR = { r = 0.8, g = 0.6, b = 0.4 },
}

Enum = {
    LuaCurveType = { Linear = 1 },
    UnitMaximumHealthMode = { Default = 1 },
    UnitIncomingHealClampMode = { MissingHealth = 0, MaximumHealth = 1 },
    UnitDamageAbsorbClampMode = { MissingHealth = 0 },
}
C_CurveUtil = {
    CreateColorCurve = function()
        return { SetType = function() end, AddPoint = function() end }
    end,
}
function CreateColor(r, g, b)
    return { r = r, g = g, b = b, GetRGB = function() return r, g, b end }
end

local chat = { messages = {} }
function chat:AddMessage(msg) self.messages[#self.messages + 1] = msg; print("CHAT  " .. tostring(msg)) end
DEFAULT_CHAT_FRAME = chat

GameTooltip = {
    SetOwner = function() end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
}

SlashCmdList = {}

-- ---------------------------------------------------------------------------
-- Load addon
-- ---------------------------------------------------------------------------

dofile(ADDON_FILE)

local function FindFrame(predicate)
    for _, f in ipairs(createdFrames) do if predicate(f) then return f end end
    return nil
end
local eventFrame = FindFrame(function(f) return f.__events and f.__events["ADDON_LOADED"] end)
local driver = FindFrame(function(f) return f.__scripts and f.__scripts["OnUpdate"] end)
check(eventFrame ~= nil, "event frame created")
check(driver ~= nil, "driver frame created")

local function Fire(event, ...)
    eventFrame.__scripts.OnEvent(eventFrame, event, ...)
end
local function CardFor(unit)
    for _, c in ipairs(HealTideDebug.cards) do if c.unit == unit then return c end end
    return nil
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

Fire("ADDON_LOADED", "HealTide")
check(HealTideDebug ~= nil, "debug surface exists")
check(HealTideDebug.calcMax() ~= nil, "max calculator created")
check(HealTideDebug.calcMissing() ~= nil, "missing calculator created")
check(HealTideDebug.calcMax().lastClampMode == Enum.UnitIncomingHealClampMode.MaximumHealth,
    "max calculator uses MaximumHealth")
check(HealTideDebug.calcMissing().lastClampMode == Enum.UnitIncomingHealClampMode.MissingHealth,
    "missing calculator uses MissingHealth")
check(HealTideDebug.db() ~= nil, "database created")
check(HealTideDebug.db().healsOnly == true, "healsonly default on")

-- Overheal colour scale.
local addon = HealTideDebug.addon
local r, g, b = addon:OverhealColor(600, 600)
check(r == 0.25 and g == 0.95 and b == 0.45, "overheal colour green")
r, g, b = addon:OverhealColor(600, 480)
check(r == 0.95 and g == 0.90 and b == 0.25, "overheal colour yellow")
r, g, b = addon:OverhealColor(600, 300)
check(r == 1.00 and g == 0.62 and b == 0.15, "overheal colour orange")
r, g, b = addon:OverhealColor(600, 100)
check(r == 1.00 and g == 0.25 and b == 0.20, "overheal colour red")

-- A mouseover heal must resolve to a stable party unit, not the mouseover token.
Fire("PLAYER_ENTERING_WORLD")
Fire("UNIT_SPELLCAST_SENT", "player", "Ami", "castMouse", 2060)
check(CardFor("party1") ~= nil, "mouseover heal resolves to party1")
check(CardFor("mouseover") == nil, "no mouseover card")
Fire("PLAYER_ENTERING_WORLD")

Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "cast1", 2060)
check(#HealTideDebug.cards == 1, "one outgoing card after cast")
local targetCard = CardFor("target")
check(targetCard ~= nil, "target card resolved")
check(targetCard and targetCard:IsShown(), "target card shown")
check(targetCard and targetCard.healthStrip:GetValue() == 400, "target health = 400")
check(targetCard and targetCard:GetWidth() == 220, "card width = 220")
check(targetCard and targetCard:GetHeight() == 16, "card height = 16")
check(targetCard and targetCard.otherRibbon:GetValue() == 50, "others heal = 50")
check(targetCard and targetCard.mineRibbon:GetValue() == 200, "my heal = 200")
check(targetCard and targetCard.otherRibbon:GetWidth() == 218, "heal frame width = 218")
check(targetCard and targetCard.healEdge:IsShown(), "heal edge shown")
check(targetCard and not targetCard.overCap:IsShown(), "no overheal cap when heal fits")
check(targetCard and targetCard.sparkHealth:IsShown(), "health spark shown")
check(targetCard and targetCard.sparkHeal:IsShown(), "heal spark shown")
local tr, tg, tb = targetCard.mineRibbon:GetStatusBarColor()
check(tr == 0.25 and tg == 0.95 and tb == 0.45, "target heal segment green")
check(targetCard and targetCard.amount:GetText() == "+250", "amount = +250")
check(targetCard and targetCard.title:GetText() == "Cible", "title = Cible")
check(targetCard and targetCard.kind == "out", "target card kind = out")

castEnd = mockTime + 2
Fire("UNIT_SPELLCAST_START", "player", "cast1", 2060)
check(targetCard and targetCard.expires == mockTime + 4.5, "cast start duration 4.5s")
castEnd = nil
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast1", 2060)
check(targetCard and targetCard.expires == mockTime + 1.5, "success tail 1.5s")
Fire("UNIT_SPELLCAST_STOP", "player", "cast1", 2060)
check(targetCard and targetCard.expires == mockTime + 0.8, "stop shortens 0.8s")
Fire("UNIT_HEAL_PREDICTION", "target")
check(targetCard and targetCard.expires <= mockTime + 0.65, "post-cast prediction tail 0.6s")
castEnd = mockTime + 4
driver.__scripts.OnUpdate(driver, 0.1)
check(targetCard and targetCard.expires <= mockTime + 0.65, "resolved cast ignores stale cast end")
castEnd = nil

-- Pushback/delay: the card must survive to the new cast end.
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castPush", 2060)
castEnd = mockTime + 4
Fire("UNIT_SPELLCAST_DELAYED", "player", "castPush", 2060)
check(targetCard and targetCard.expires >= mockTime + 6, "delayed cast extends card")
Fire("UNIT_SPELLCAST_STOP", "player", "castPush", 2060)
check(targetCard and targetCard.expires > mockTime + 3, "stop during active cast does not hide")
castEnd = nil

-- B1: a foreign instant or non-heal cast must not steal the active heal cast.
Fire("PLAYER_ENTERING_WORLD")
units.target.health = 400
units.target.prediction = { total = 250, mine = 200, others = 50, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "healLong", 2060)
local b1Card = CardFor("target")
castEnd = mockTime + 3
Fire("UNIT_SPELLCAST_START", "player", "healLong", 2060)
check(b1Card and b1Card:IsShown(), "long heal card shown")
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "shieldCast", 17)
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "shieldCast", 17)
Fire("UNIT_SPELLCAST_STOP", "player", "shieldCast", 17)
check(HealTideDebug.addon.castUnit == "target" and HealTideDebug.addon.castGUID == "healLong", "foreign shield ignored")
check(b1Card and not b1Card.castResolved, "foreign shield does not resolve heal card")
units.party1.prediction = { total = 100, mine = 100, others = 0, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Ami", "instantHeal", 2060)
check(CardFor("party1") ~= nil, "instant heal gets its own card")
check(HealTideDebug.addon.castUnit == "target", "instant heal does not steal long cast")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "instantHeal", 2060)
check(b1Card and not b1Card.castResolved, "foreign instant success ignored")
castEnd = nil
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "healLong", 2060)
Fire("UNIT_SPELLCAST_STOP", "player", "healLong", 2060)
check(b1Card and b1Card.castResolved, "long heal resolves with its own GUID")
check(HealTideDebug.addon.castUnit == nil, "cast state cleared after resolution")

-- H7: a new cast on the same card clears the previous hadHeal flag.
Fire("PLAYER_ENTERING_WORLD")
units.target.prediction = { total = 250, mine = 200, others = 50, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castH7a", 2060)
local h7Card = CardFor("target")
check(h7Card and h7Card.hadHeal, "first cast marked hadHeal")
units.target.prediction = { total = 0, mine = 0, others = 0, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castH7b", 2060)
check(h7Card and h7Card.expires and h7Card.expires > mockTime + 2.5, "new cast clears stale hadHeal")
Fire("PLAYER_ENTERING_WORLD")

-- AoE: a group prediction during the heal cast window creates a card even
-- when the player's contribution is secret.
units.target.prediction = { total = 250, mine = 200, others = 50, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castAoe", 2060)
units.party1.prediction = { total = 100, mine = 0, others = 100, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "party1")
check(CardFor("party1") ~= nil, "AoE prediction creates group card")
Fire("PLAYER_ENTERING_WORLD")

units.player.prediction = { total = 300, mine = 0, others = 300, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "player")
local incoming = HealTideDebug.incoming()
check(incoming ~= nil and incoming:IsShown(), "incoming card shown")
check(incoming and incoming.healthStrip:GetValue() == 500, "incoming health = 500")
check(incoming and incoming.otherRibbon:GetValue() == 300, "incoming heal = 300")
check(incoming and incoming.mineRibbon:GetValue() == 0, "incoming has no mine heal")
check(incoming and incoming.amount:GetText() == "+300", "incoming amount = +300")
check(incoming and incoming.title:GetText() == "Incoming", "incoming title = Incoming")
check(incoming and incoming.kind == "in", "incoming card kind = in")

-- At full health the raw heal still fills the extension past the bar.
units.player.health = 1000
units.player.prediction = { total = 300, mine = 0, others = 300, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "player")
check(incoming and incoming.healthStrip:GetValue() == 1000, "incoming full health = 1000")
check(incoming and incoming.otherRibbon:GetValue() == 300, "incoming full-health heal = 300")
check(incoming and incoming.amount:GetText() == "+300", "incoming full-health amount = +300")
units.player.health = 500
units.player.prediction = { total = 0, mine = 0, others = 0, max = 1000 }
Fire("UNIT_HEALTH", "player")
check(not incoming:IsShown(), "incoming hides when heal lands")

-- A self-heal clamped above max must not hide other players' incoming heals.
Fire("PLAYER_ENTERING_WORLD")
units.player.health = 1000
units.player.prediction = { total = 1500, mine = 1200, others = 300, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "player")
local clampedIncoming = HealTideDebug.incoming()
check(clampedIncoming and clampedIncoming:IsShown(), "incoming shown when mine clamps above max")
check(clampedIncoming and clampedIncoming.otherRibbon:GetValue() == 300, "incoming raw others = 300")
check(clampedIncoming and clampedIncoming.amount:GetText() == "+300", "incoming raw amount = +300")

-- A new prediction refreshes the incoming card; a health update gives it a
-- short tail so it does not linger after the heal lands.
mockTime = mockTime + 4
units.player.prediction = { total = 1500, mine = 1200, others = 300, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "player")
check(clampedIncoming and clampedIncoming:IsShown(), "long incoming refresh shown")
check(clampedIncoming and clampedIncoming.expires and clampedIncoming.expires >= mockTime + 4.9, "incoming refreshed to 5s")
Fire("UNIT_HEALTH", "player")
check(clampedIncoming and clampedIncoming.expires and clampedIncoming.expires <= mockTime + 0.55, "incoming shortens after health update")

-- A self-heal is "mine", so the incoming card hides it when solo; it must
-- appear on the outgoing card for the player instead.
Fire("PLAYER_ENTERING_WORLD")
local savedParty1, savedMouseover = units.party1, units.mouseover
units.party1 = nil
units.mouseover = nil
units.player.prediction = { total = 0, mine = 0, others = 0, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Moi", "castSelf", 2060)
local selfCard = CardFor("player")
check(selfCard ~= nil and selfCard:IsShown(), "self-heal outgoing card shown")
units.player.prediction = { total = 400, mine = 400, others = 0, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "player")
check(selfCard and selfCard.mineRibbon:GetValue() == 400, "self-heal prediction updates outgoing card")
check(selfCard and selfCard.amount:GetText() == "+400", "self-heal amount = +400")
check(selfCard and selfCard.title:GetText() == "You", "self-heal title = You")
check(HealTideDebug.incoming() and HealTideDebug.incoming().otherRibbon:GetValue() == 0, "self-heal has no incoming ribbon")
check(HealTideDebug.incoming() and not HealTideDebug.incoming().healthStrip:IsShown(), "incoming chrome hidden")

-- Even with other healers mixed in, the incoming bar is independent and
-- shows their heals while the outgoing You card shows the self-heal.
units.player.prediction = { total = 400, mine = 300, others = 100, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "player")
check(HealTideDebug.incoming() and HealTideDebug.incoming().otherRibbon:GetValue() == 100, "incoming others = 100 during self-heal")
check(selfCard and selfCard.otherRibbon:GetValue() == 100, "self-heal outgoing others = 100")
check(selfCard and selfCard.mineRibbon:GetValue() == 300, "self-heal outgoing mine = 300")
units.party1 = savedParty1
units.mouseover = savedMouseover

-- A lingering prediction event after the cast must not extend the card to 3s.
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "castSelf", 2060)
Fire("UNIT_HEAL_PREDICTION", "player")
check(selfCard and selfCard.expires <= mockTime + 0.65, "self-heal card does not linger after cast")

-- Non-heal cast is filtered.
Fire("PLAYER_ENTERING_WORLD")
local beforeShield = #HealTideDebug.cards
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castShield", 17)
check(#HealTideDebug.cards == beforeShield, "non-heal cast filtered")

-- The heals-only filter can be disabled.
SlashCmdList["HEALTIDE"]("healsonly")
Fire("PLAYER_ENTERING_WORLD")
local beforeAny = #HealTideDebug.cards
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castShield2", 17)
check(HealTideDebug.db().healsOnly == false, "healsonly toggled off")
check(#HealTideDebug.cards == beforeAny + 1, "healsonly off allows any friendly cast")
SlashCmdList["HEALTIDE"]("healsonly")
check(HealTideDebug.db().healsOnly == true, "healsonly toggled on")

-- Spacing command changes the vertical gap.
SlashCmdList["HEALTIDE"]("spacing 10")
check(HealTideDebug.db().gap == 10, "spacing = 10")
Fire("PLAYER_ENTERING_WORLD")
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castGap1", 2060)
Fire("UNIT_SPELLCAST_SENT", "player", "Ami", "castGap2", 2060)
local gapTarget = CardFor("target")
local gapParty = CardFor("party1")
check(gapTarget ~= nil and gapParty ~= nil, "two cards for spacing test")
local _, _, _, _, yTarget = gapTarget:GetPoint(1)
local _, _, _, _, yParty = gapParty:GetPoint(1)
check(yTarget and yParty and math.abs((yTarget - yParty) - 26) < 0.1, "spacing offset = 26")
SlashCmdList["HEALTIDE"]("spacing 2")
Fire("PLAYER_ENTERING_WORLD")

-- H8: disabling outgoing hides active cards and blocks new outgoing cards.
units.target.prediction = { total = 250, mine = 200, others = 50, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castOutToggle", 2060)
local toggleCard = CardFor("target")
check(toggleCard and toggleCard:IsShown(), "outgoing card before toggle")
SlashCmdList["HEALTIDE"]("outgoing")
check(toggleCard and not toggleCard:IsShown(), "outgoing off hides card")
units.target.prediction = { total = 300, mine = 250, others = 50, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "target")
check(CardFor("target") == nil, "outgoing off blocks prediction card")
SlashCmdList["HEALTIDE"]("outgoing")
check(HealTideDebug.db().showOutgoing == true, "outgoing back on")
Fire("PLAYER_ENTERING_WORLD")

-- Full-health overheal: no heal fill, red end cap.
Fire("PLAYER_ENTERING_WORLD")
units.target.health = 1000
units.target.prediction = { total = 600, mine = 600, others = 0, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castOver", 2060)
Fire("UNIT_HEAL_PREDICTION", "target")
local overCard = CardFor("target")
check(overCard and overCard.healthStrip:GetValue() == 1000, "overheal health = 1000")
check(overCard and overCard.otherRibbon:GetValue() == 0, "no others heal at full health")
check(overCard and overCard.mineRibbon:GetValue() == 600, "raw mine heal at full health = 600")
check(overCard and overCard.sparkHeal:IsShown(), "heal spark stays visible at full health")
local br, bg, bb = overCard:GetBackdropBorderColor()
check(br == 1 and bg == 0.25 and bb == 0.20, "overheal border red")
check(overCard and overCard.overCap:IsShown(), "overheal cap shown")
check(overCard and overCard.overCap:GetAlpha() == 1, "overheal cap alpha = 1")
check(overCard and overCard.amount:GetText() == "+600", "overheal amount = +600")

-- A smaller heal at full health must produce a shorter extension.
units.target.prediction = { total = 150, mine = 150, others = 0, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "target")
check(overCard and overCard.mineRibbon:GetValue() == 150, "small heal value = 150")
check(overCard and overCard.amount:GetText() == "+150", "small heal amount = +150")

-- A consumed prediction must not linger for the full timeout.
units.target.prediction = { total = 0, mine = 0, others = 0, max = 1000 }
Fire("UNIT_HEALTH", "target")
check(overCard and overCard.expires and overCard.expires <= mockTime + 0.35, "card expires quickly when heal lands")
mockTime = mockTime + 0.5
driver.__scripts.OnUpdate(driver, 0.1)
check(overCard and not overCard:IsShown(), "outgoing card hides when heal lands")

-- Demo mode.
SlashCmdList["HEALTIDE"]("test")
local demoCard = nil
for _, c in ipairs(HealTideDebug.cards) do if c.sim then demoCard = c; break end end
check(demoCard ~= nil, "demo outgoing card exists")
check(demoCard and demoCard.healthStrip:GetValue() == 500, "demo health = 500")
check(demoCard and demoCard.mineRibbon:GetValue() == 350, "demo mine = 350")
check(demoCard and demoCard.otherRibbon:GetValue() == 250, "demo others = 250")
local dr, dg, db = demoCard.mineRibbon:GetStatusBarColor()
check(dr == 0.95 and dg == 0.90 and db == 0.25, "demo heal segment yellow")
check(demoCard and demoCard.amount:GetText() == "+600", "demo amount = +600")
check(demoCard and demoCard.title:GetText() == "Demo target", "demo title = Demo target")
Fire("GROUP_ROSTER_UPDATE")
check(demoCard and demoCard:IsShown(), "demo survives roster update")
local demoIncoming = HealTideDebug.incoming()
check(demoIncoming and demoIncoming.sim ~= nil, "demo incoming simulated")
check(demoIncoming and demoIncoming.healthStrip:GetValue() == 700, "demo incoming health = 700")
check(demoIncoming and demoIncoming.otherRibbon:GetValue() == 300, "demo incoming heal = 300")
SlashCmdList["HEALTIDE"]("stop")
check(not demoCard:IsShown(), "demo stop hides outgoing")
check(demoIncoming and not demoIncoming:IsShown(), "demo stop hides incoming")

-- Expiration.
Fire("PLAYER_ENTERING_WORLD")
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castExpire", 2060)
local expireCard = CardFor("target")
mockTime = mockTime + 5
driver.__scripts.OnUpdate(driver, 0.1)
check(expireCard and not expireCard:IsShown(), "expired card hidden")

-- Secret path.
secretMode = true
Fire("PLAYER_ENTERING_WORLD")
units.mouseover = nil
units.target.health = 400
units.target.prediction = { total = 250, mine = 200, others = 50, max = 1000 }
Fire("UNIT_SPELLCAST_SENT", "player", "Cible", "castSecret", 2060)
Fire("UNIT_HEAL_PREDICTION", "target")
local secretCard = CardFor("target")
check(secretCard ~= nil, "secret path card exists")
check(secretCard and secretCard.healthStrip:GetValue() == 400, "secret health accepted")
check(secretCard and secretCard.otherRibbon:IsShown(), "secret others bar shown")
check(secretCard and secretCard.mineRibbon:IsShown(), "secret mine bar shown")
check(secretCard and secretCard.otherRibbon:GetValue() == 50, "secret others accepted")
check(secretCard and secretCard.mineRibbon:GetValue() == 200, "secret mine accepted")
check(secretCard and secretCard.amount:GetText() == "", "secret amount hidden")
check(secretCard and secretCard.otherOver:GetAlpha() == 0, "secret normal overlay alpha 0")
check(secretCard and secretCard.mineOver:GetAlpha() == 0, "secret mine overlay alpha 0")
check(secretCard and secretCard.title:GetText() == "Target", "secret title fallback")
units.target.prediction = { total = 700, mine = 700, others = 0, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "target")
check(secretCard and secretCard.mineRibbon:GetValue() == 700, "secret raw heal accepted = 700")
check(secretCard and secretCard.overCap:IsShown(), "secret overheal cap shown")
check(secretCard and secretCard.otherOver:GetAlpha() == 1, "secret overheal overlay alpha 1")
check(secretCard and secretCard.mineOver:GetAlpha() == 1, "secret mine overheal overlay alpha 1")

-- Secret values: incoming is a minimal ribbon; a self-heal has no fill.
Fire("PLAYER_ENTERING_WORLD")
units.player.health = 500
local savedSecretParty = units.party1
units.party1 = nil
units.mouseover = nil
units.player.prediction = { total = 400, mine = 400, others = 0, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "player")
check(HealTideDebug.incoming() and HealTideDebug.incoming().otherRibbon:GetValue() == 0, "secret self-only incoming ribbon 0")
check(HealTideDebug.incoming() and not HealTideDebug.incoming().healthStrip:IsShown(), "secret incoming chrome hidden")
units.player.prediction = { total = 450, mine = 350, others = 100, max = 1000 }
Fire("UNIT_HEAL_PREDICTION", "player")
check(HealTideDebug.incoming() and HealTideDebug.incoming().otherRibbon:GetValue() == 100, "secret solo incoming outsiders = 100")
units.party1 = savedSecretParty
secretMode = false

-- B3: OnUpdate must catch and report errors instead of spamming every frame.
local originalRefresh = HealTideDebug.addon.Refresh
HealTideDebug.addon.Refresh = function() error("test refresh error") end
HealTideDebug.addon.lastErrorAt = GetTime()
driver.__scripts.OnUpdate(driver, 0.1)
check(tostring(HealTideDebug.db().diagnostics.lastError):find("test refresh error", 1, true) ~= nil,
    "OnUpdate errors are caught")
HealTideDebug.addon.Refresh = originalRefresh

SlashCmdList["HEALTIDE"]("secrets")
local sawB2 = false
for _, msg in ipairs(chat.messages) do
    if tostring(msg):find("B2 calc secret", 1, true) then sawB2 = true end
end
check(sawB2, "secrets command prints B2 diagnostics")

local errors = 0
for _, msg in ipairs(chat.messages) do if tostring(msg):find("Error", 1, true) then errors = errors + 1 end end
check(errors == 0, "no addon errors")

print(string.format("\n%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
