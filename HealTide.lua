-- HealTide
-- A cast-style single-bar heal prediction HUD for World of Warcraft: Forever.
--
-- Each card is one bar:
--   health fill : current health, green -> yellow -> red
--   heal fill   : extends from current health; brighter for your heal, darker for others
--   overheal    : green / yellow / orange / red extension and border
--
-- Uses the native Forever heal prediction API (UnitGetDetailedHealPrediction).
-- Direct heals only; Forever does not expose HoTs to addons.

local ADDON = "HealTide"
local HT = {}

local secret = issecretvalue or function() return false end
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetTime = GetTime
local UnitExists = UnitExists
local UnitCanAssist = UnitCanAssist
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitFullName = UnitFullName
local UnitClass = UnitClass
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitHealthPercent = UnitHealthPercent
local IsInRaid = IsInRaid
local GetBuildInfo = GetBuildInfo
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CreateColor = CreateColor
local C_CurveUtil = C_CurveUtil
local Enum = Enum

local CARD_INSET = 1

local HEAL_IDS = {
    2050, 2054, 2060, 2061, 139, 596, 19236, 32546, 34861, 47540, 64843, 15237, 33076,
    5185, 8936, 774, 740, 33763, 50464, 48438, 18562,
    635, 19750, 20473, 633,
    331, 8004, 1064, 61295,
    755, 28880, 55428,
}

local healNames

local DEFAULTS = {
    width = 220,
    height = 16,
    gap = 2,
    locked = true,
    showOutgoing = true,
    showIncoming = true,
    healsOnly = true,
    outgoingAnchor = { point = "CENTER", relPoint = "CENTER", x = 0, y = -200 },
    incomingAnchor = { point = "CENTER", relPoint = "CENTER", x = 0, y = -265 },
    diagnostics = {
        loaded = false,
        interface = 0,
        calc = false,
        clampMode = "",
        clampModeInBar = "",
        twoCalculators = false,
        secretMax = false,
        secretMissing = false,
        events = 0,
        casts = 0,
        predictions = 0,
        cards = 0,
        lastError = "",
        lastErrorEvent = "",
        lastErrorAt = "",
    },
}

HT.db = nil
HT.calcMax = nil
HT.calcMissing = nil
HT.cards = {}
HT.byKey = {}
HT.incomingCard = nil
HT.castUnit = nil
HT.castGUID = nil
HT.castSpellID = nil
HT.castIsHeal = nil
HT.healCastUntil = 0
HT.selfHealUntil = 0
HT.lastCastRefresh = 0
HT.lastErrorAt = 0
HT.curve = nil

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------

local function Try(fn, ...)
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if ok then return a, b, c, d, e, f end
end

local function IsSecret(value)
    return secret(value) and true or false
end

local function Readable(value)
    if IsSecret(value) then return false end
    return value ~= nil
end

local function Str(value)
    if not Readable(value) then return false end
    return type(value) == "string" and value ~= ""
end

local function Num(value)
    if not Readable(value) then return false end
    return type(value) == "number"
end

local function Keep(value, fallback)
    if IsSecret(value) then return value end
    if type(value) == "number" then return value end
    return fallback
end

-- Secret numbers cannot be compared directly, but the client's C formatter
-- turns them into non-secret digit strings. This lets us tell "others = 0"
-- from "others > 0" without doing arithmetic on secret values.
local function CountValue(value)
    if Num(value) then return value end
    if not IsSecret(value) then return nil end
    local ok, text = pcall(string.format, "%.0f", value)
    if not ok or type(text) ~= "string" or IsSecret(text) then return nil end
    local number = tonumber(text)
    if number then return number end
    return nil
end

local function Above(value, fallback)
    if IsSecret(value) then return value end
    if type(value) == "number" and value > 0 then return value end
    return fallback
end

local function ClampNumber(value, minimum, maximum, fallback)
    if type(value) ~= "number" or value ~= value then return fallback end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function Exists(unit)
    if not unit then return false end
    local ok, value = pcall(UnitExists, unit)
    if not ok then return false end
    if IsSecret(value) then return true end
    return value and true or false
end

local function Friendly(unit)
    if not Exists(unit) then return false end
    local ok, value = pcall(UnitCanAssist, "player", unit)
    if not ok then return true end
    if IsSecret(value) then return true end
    return value and true or false
end

local function Same(a, b)
    if not a or not b then return false end
    local ok, value = pcall(UnitIsUnit, a, b)
    if not ok then return false end
    if IsSecret(value) then return true end
    return value and true or false
end

local function Copy(value)
    local out = {}
    for k, v in pairs(value) do
        if type(v) == "table" then out[k] = Copy(v) else out[k] = v end
    end
    return out
end

local function Say(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff41e2c6HealTide|r: " .. tostring(text))
    else
        print("HealTide: " .. tostring(text))
    end
end

function HT:LoadDB()
    if type(HealTideDB) ~= "table" then HealTideDB = {} end
    self.db = HealTideDB
    for k, v in pairs(DEFAULTS) do
        if self.db[k] == nil then
            self.db[k] = type(v) == "table" and Copy(v) or v
        end
    end
    if type(self.db.outgoingAnchor) ~= "table" then self.db.outgoingAnchor = Copy(DEFAULTS.outgoingAnchor) end
    if type(self.db.incomingAnchor) ~= "table" then self.db.incomingAnchor = Copy(DEFAULTS.incomingAnchor) end
    if type(self.db.diagnostics) ~= "table" then self.db.diagnostics = Copy(DEFAULTS.diagnostics) end
    for k, v in pairs(DEFAULTS.diagnostics) do
        if self.db.diagnostics[k] == nil then self.db.diagnostics[k] = v end
    end
    if type(self.db.layoutVersion) ~= "number" then self.db.layoutVersion = 1 end
    if self.db.layoutVersion < 3 then
        local w, h = self.db.width, self.db.height
        if (w == 300 and h == 40) or (w == 280 and h == 46) or (w == 260 and h == 22) then
            self.db.width = DEFAULTS.width
            self.db.height = DEFAULTS.height
        end
        self.db.gap = DEFAULTS.gap

        local out = self.db.outgoingAnchor
        if type(out) == "table" and out.point == "CENTER" and out.relPoint == "CENTER"
            and (out.x or 0) == 0 and (out.y == -170 or out.y == -200) then
            self.db.outgoingAnchor = Copy(DEFAULTS.outgoingAnchor)
        end

        local inc = self.db.incomingAnchor
        if type(inc) == "table" and inc.point == "CENTER" and inc.relPoint == "CENTER"
            and (inc.x or 0) == 0 and (inc.y == -300 or inc.y == -265 or inc.y == -330) then
            self.db.incomingAnchor = Copy(DEFAULTS.incomingAnchor)
        end

        self.db.layoutVersion = 3
    end

    self.db.width = ClampNumber(self.db.width, 120, 500, DEFAULTS.width)
    self.db.height = ClampNumber(self.db.height, 10, 40, DEFAULTS.height)
    self.db.gap = ClampNumber(self.db.gap, 0, 20, DEFAULTS.gap)
    if type(self.db.locked) ~= "boolean" then self.db.locked = DEFAULTS.locked end
    if type(self.db.showOutgoing) ~= "boolean" then self.db.showOutgoing = DEFAULTS.showOutgoing end
    if type(self.db.showIncoming) ~= "boolean" then self.db.showIncoming = DEFAULTS.showIncoming end
    if type(self.db.healsOnly) ~= "boolean" then self.db.healsOnly = DEFAULTS.healsOnly end
    for _, key in ipairs({ "outgoingAnchor", "incomingAnchor" }) do
        local anchor = self.db[key]
        if type(anchor) ~= "table" or not Str(anchor.point) or not Str(anchor.relPoint)
            or not Num(anchor.x) or not Num(anchor.y) then
            self.db[key] = Copy(DEFAULTS[key])
        end
    end
end

function HT:Ready()
    if not self.db then self:LoadDB() end
    return self.db
end

function HT:BarWidth()
    return math.max(40, (self.db and self.db.width or DEFAULTS.width) - 2)
end

function HT:OverhealColor(raw, effective)
    local rawNum = CountValue(raw)
    local effectiveNum = CountValue(effective)
    if not rawNum or rawNum <= 0 or not effectiveNum then return 0.35, 0.85, 0.55, 0 end
    local eff = math.max(0, effectiveNum)
    local ratio = math.max(0, rawNum - eff) / rawNum
    if ratio <= 0.01 then return 0.25, 0.95, 0.45, ratio end
    if ratio <= 0.20 then return 0.95, 0.90, 0.25, ratio end
    if ratio <= 0.50 then return 1.00, 0.62, 0.15, ratio end
    return 1.00, 0.25, 0.20, ratio
end

-- ---------------------------------------------------------------------------
-- Native prediction
-- ---------------------------------------------------------------------------

function HT:ClampModes()
    local maxMode, missMode = 1, 0
    if Enum and Enum.UnitIncomingHealClampMode then
        if Enum.UnitIncomingHealClampMode.MaximumHealth ~= nil then
            maxMode = Enum.UnitIncomingHealClampMode.MaximumHealth
        end
        if Enum.UnitIncomingHealClampMode.MissingHealth ~= nil then
            missMode = Enum.UnitIncomingHealClampMode.MissingHealth
        end
    end
    return maxMode, missMode
end

function HT:MakeCalculator(mode)
    if not CreateUnitHealPredictionCalculator or not UnitGetDetailedHealPrediction then return nil end
    local ok, calc = pcall(CreateUnitHealPredictionCalculator)
    if not ok or not calc then return nil end

    if calc.SetMaximumHealthMode and Enum and Enum.UnitMaximumHealthMode then
        pcall(calc.SetMaximumHealthMode, calc, Enum.UnitMaximumHealthMode.Default)
    end
    if calc.SetIncomingHealClampMode then
        pcall(calc.SetIncomingHealClampMode, calc, mode)
    end
    if calc.SetIncomingHealOverflowPercent then
        pcall(calc.SetIncomingHealOverflowPercent, calc, 1)
    end
    if calc.SetDamageAbsorbClampMode and Enum and Enum.UnitDamageAbsorbClampMode then
        pcall(calc.SetDamageAbsorbClampMode, calc, Enum.UnitDamageAbsorbClampMode.MissingHealth)
    end
    return calc
end

function HT:CalculatorHasSecrets(calc)
    if not calc or not calc.HasSecretValues then return false end
    local ok, value = pcall(calc.HasSecretValues, calc)
    if ok and not IsSecret(value) then return value and true or false end
    return false
end

function HT:EnsureCalculators()
    local maxMode, missMode = self:ClampModes()
    if not self.calcMax then self.calcMax = self:MakeCalculator(maxMode) end
    if not self.calcMissing then self.calcMissing = self:MakeCalculator(missMode) end
    if self.db and self.db.diagnostics then
        local d = self.db.diagnostics
        d.calc = (self.calcMax ~= nil or self.calcMissing ~= nil)
        d.clampMode = self.calcMax and "MaximumHealth" or ""
        d.clampModeInBar = self.calcMissing and "MissingHealth" or ""
        d.twoCalculators = (self.calcMax ~= nil and self.calcMissing ~= nil and self.calcMax ~= self.calcMissing)
        d.secretMax = self:CalculatorHasSecrets(self.calcMax)
        d.secretMissing = self:CalculatorHasSecrets(self.calcMissing)
    end
end

function HT:Read(unit, calc)
    if not calc or not unit then return nil, nil, nil, nil, nil, nil, nil end
    if not pcall(UnitGetDetailedHealPrediction, unit, "player", calc) then
        return nil, nil, nil, nil, nil, nil, nil
    end
    local healthMax = Try(calc.GetMaximumHealth, calc)
    local total, mine, others, clamped = Try(calc.GetIncomingHeals, calc)
    local totalBase = Try(calc.GetTotalIncomingHeals, calc)
    local totalFromHealer = Try(calc.GetTotalIncomingHealsFromHealer, calc)
    return total, mine, others, healthMax, totalBase, clamped, totalFromHealer
end

function HT:OthersBase(mine, others, totalBase, totalFromHealer)
    local totalNum = CountValue(totalBase)
    local fromHealerNum = CountValue(totalFromHealer)
    if totalNum and fromHealerNum then
        local value = totalNum - fromHealerNum
        if value < 0 then value = 0 end
        return value
    end
    local mineNum = CountValue(mine)
    if totalNum and mineNum then
        local value = totalNum - mineNum
        if value < 0 then value = 0 end
        return value
    end
    local othersNum = CountValue(others)
    if othersNum then return othersNum end
    if totalNum then return totalNum end
    return others
end

function HT:HealNames()
    if healNames then return healNames end
    healNames = {}
    if C_Spell and C_Spell.GetSpellName then
        for _, id in ipairs(HEAL_IDS) do
            local name = C_Spell.GetSpellName(id)
            if Str(name) then healNames[name] = true end
        end
    end
    return healNames
end

function HT:IsHeal(spellID)
    if not Num(spellID) then return true end
    if not (C_Spell and C_Spell.GetSpellName) then return true end
    local names = self:HealNames()
    if not names or next(names) == nil then return true end
    local name = C_Spell.GetSpellName(spellID)
    if not Str(name) then return true end
    return names[name] == true
end

function HT:HealthCurve()
    if self.curve then return self.curve end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType and CreateColor) then return nil end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateColorCurve()
        c:SetType(Enum.LuaCurveType.Linear)
        c:AddPoint(0, CreateColor(1, 0, 0))
        c:AddPoint(0.5, CreateColor(1, 1, 0))
        c:AddPoint(1, CreateColor(0, 1, 0))
        return c
    end)
    if ok then self.curve = curve end
    return self.curve
end

-- ---------------------------------------------------------------------------
-- Cards
-- ---------------------------------------------------------------------------

function HT:SizeCard(card)
    local w = self.db.width
    local h = self.db.height

    card:SetSize(w, h)

    card.healthStrip:ClearAllPoints()
    card.healthStrip:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_INSET, -CARD_INSET)
    card.healthStrip:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -CARD_INSET, CARD_INSET)

    card.otherRibbon:ClearAllPoints()
    card.otherRibbon:SetPoint("TOPLEFT", card.healthStrip:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    card.otherRibbon:SetPoint("BOTTOMLEFT", card.healthStrip:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    card.otherRibbon:SetWidth(self:BarWidth())

    card.mineRibbon:ClearAllPoints()
    card.mineRibbon:SetPoint("TOPLEFT", card.otherRibbon:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    card.mineRibbon:SetPoint("BOTTOMLEFT", card.otherRibbon:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    card.mineRibbon:SetWidth(self:BarWidth())

    card.otherOver:ClearAllPoints()
    card.otherOver:SetPoint("TOPLEFT", card.healthStrip:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    card.otherOver:SetPoint("BOTTOMLEFT", card.healthStrip:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    card.otherOver:SetWidth(self:BarWidth())

    card.mineOver:ClearAllPoints()
    card.mineOver:SetPoint("TOPLEFT", card.otherRibbon:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    card.mineOver:SetPoint("BOTTOMLEFT", card.otherRibbon:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    card.mineOver:SetWidth(self:BarWidth())

    card.healEdge:ClearAllPoints()
    card.healEdge:SetPoint("TOPLEFT", card.healthStrip:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    card.healEdge:SetPoint("BOTTOMLEFT", card.healthStrip:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)

    card.overCap:ClearAllPoints()
    card.overCap:SetPoint("TOPRIGHT", card.healthStrip, "TOPRIGHT", 0, 0)
    card.overCap:SetPoint("BOTTOMRIGHT", card.healthStrip, "BOTTOMRIGHT", 0, 0)
    card.overCap:SetWidth(2)

    card.title:ClearAllPoints()
    card.title:SetPoint("LEFT", card, "LEFT", 5, 0)
    card.title:SetWidth(w - 78)

    card.amount:ClearAllPoints()
    card.amount:SetPoint("RIGHT", card, "RIGHT", -5, 0)
    card.amount:SetWidth(64)

    card.sparkHealth:ClearAllPoints()
    card.sparkHealth:SetPoint("CENTER", card.healthStrip:GetStatusBarTexture(), "RIGHT", 0, 0)
    local sparkW = math.max(8, math.floor(h * 0.75))
    card.sparkHealth:SetSize(sparkW, h * 1.4)
    card.sparkHeal:ClearAllPoints()
    if card.kind == "out" then
        card.sparkHeal:SetPoint("CENTER", card.mineRibbon:GetStatusBarTexture(), "RIGHT", 0, 0)
    else
        card.sparkHeal:SetPoint("CENTER", card.otherRibbon:GetStatusBarTexture(), "RIGHT", 0, 0)
    end
    card.sparkHeal:SetSize(sparkW, h * 1.4)
end

function HT:CreateCard(kind)
    local card = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    card.kind = kind
    card:SetFrameStrata("HIGH")
    card:SetClampedToScreen(true)
    card:SetMovable(true)
    card:RegisterForDrag("LeftButton")
    if card.SetBackdrop then
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        card:SetBackdropColor(0, 0, 0, 0.55)
        card:SetBackdropBorderColor(0, 0, 0, 0.90)
    end

    card.overlay = CreateFrame("Frame", nil, card)
    card.overlay:SetAllPoints(card)
    card.overlay:EnableMouse(false)

    card.title = card.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    card.title:SetTextColor(1, 1, 1)
    card.title:SetShadowColor(0, 0, 0, 1)
    card.title:SetShadowOffset(1, -1)

    card.amount = card.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.amount:SetJustifyH("RIGHT")
    card.amount:SetTextColor(1, 1, 1)
    card.amount:SetShadowColor(0, 0, 0, 1)
    card.amount:SetShadowOffset(1, -1)

    card.healthStrip = CreateFrame("StatusBar", nil, card)
    card.healthStrip:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    card.healthStrip:SetStatusBarColor(0, 1, 0, 1)
    card.healthStrip:SetMinMaxValues(0, 1)
    card.healthStrip:SetValue(0)

    card.otherRibbon = CreateFrame("StatusBar", nil, card)
    card.otherRibbon:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    card.otherRibbon:SetStatusBarColor(0.25, 0.95, 0.45, 0.95)
    card.otherRibbon:SetMinMaxValues(0, 1)
    card.otherRibbon:SetValue(1)
    card.otherRibbon:Hide()

    card.mineRibbon = CreateFrame("StatusBar", nil, card)
    card.mineRibbon:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    card.mineRibbon:SetStatusBarColor(0.25, 0.95, 0.45, 1)
    card.mineRibbon:SetMinMaxValues(0, 1)
    card.mineRibbon:SetValue(1)
    card.mineRibbon:Hide()

    card.otherOver = CreateFrame("StatusBar", nil, card)
    card.otherOver:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    card.otherOver:SetStatusBarColor(1.0, 0.55, 0.12, 0.95)
    card.otherOver:SetMinMaxValues(0, 1)
    card.otherOver:SetValue(1)
    card.otherOver:Hide()

    card.mineOver = CreateFrame("StatusBar", nil, card)
    card.mineOver:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    card.mineOver:SetStatusBarColor(1.0, 0.55, 0.12, 0.95)
    card.mineOver:SetMinMaxValues(0, 1)
    card.mineOver:SetValue(1)
    card.mineOver:Hide()

    card.healEdge = card.overlay:CreateTexture(nil, "OVERLAY")
    card.healEdge:SetWidth(1)
    card.healEdge:SetColorTexture(1, 1, 1, 0.55)
    card.healEdge:Hide()

    card.overCap = card.overlay:CreateTexture(nil, "ARTWORK")
    card.overCap:SetWidth(2)
    card.overCap:SetColorTexture(1, 0.55, 0.12, 0.95)
    card.overCap:Hide()

    card.sparkHealth = card.overlay:CreateTexture(nil, "ARTWORK")
    card.sparkHealth:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    card.sparkHealth:SetBlendMode("ADD")
    card.sparkHealth:SetAlpha(0.75)
    card.sparkHealth:SetSize(12, 22)
    card.sparkHealth:Hide()

    card.sparkHeal = card.overlay:CreateTexture(nil, "ARTWORK")
    card.sparkHeal:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    card.sparkHeal:SetBlendMode("ADD")
    card.sparkHeal:SetAlpha(0.85)
    card.sparkHeal:SetSize(12, 22)
    card.sparkHeal:Hide()

    card.healthStrip:SetFrameLevel(card:GetFrameLevel() + 1)
    card.otherRibbon:SetFrameLevel(card:GetFrameLevel() + 2)
    card.mineRibbon:SetFrameLevel(card:GetFrameLevel() + 3)
    card.otherOver:SetFrameLevel(card:GetFrameLevel() + 4)
    card.mineOver:SetFrameLevel(card:GetFrameLevel() + 5)
    card.overlay:SetFrameLevel(card:GetFrameLevel() + 20)

    card:SetScript("OnDragStart", function(self)
        if HT.db and not HT.db.locked then self:StartMoving() end
    end)
    card:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not HT.db then return end
        local point, _, relPoint, x, y = self:GetPoint(1)
        if not point then return end
        local pos = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
        if self.kind == "in" then
            HT.db.incomingAnchor = pos
            HT:PlaceIncoming()
        else
            HT.db.outgoingAnchor = pos
            HT:Layout()
        end
    end)
    card:SetScript("OnEnter", function(self)
        if not self.unit and not self.sim then return end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.kind == "in" and "Incoming heals" or "Heal target")
        local unit = self.unit
        if self.sim then
            GameTooltip:AddLine("Health: " .. tostring(math.floor(self.sim.health)) .. " / " .. tostring(math.floor(self.sim.max)), 1, 1, 1)
            if (self.sim.mine or 0) > 0 then
                GameTooltip:AddLine("Your heal: +" .. tostring(math.floor(self.sim.mine)), 0.2, 1, 0.8)
            end
            GameTooltip:AddLine("Others: +" .. tostring(math.floor(self.sim.others or 0)), 0.45, 0.75, 0.95)
        elseif unit then
            local hp, max = Try(UnitHealth, unit), Try(UnitHealthMax, unit)
            if Num(hp) and Num(max) then
                GameTooltip:AddLine("Health: " .. tostring(math.floor(hp)) .. " / " .. tostring(math.floor(max)), 1, 1, 1)
            end
            local _, mine, others, _, totalBase = HT:Read(unit, HT.calcMax)
            if Num(mine) then GameTooltip:AddLine("Your heal: +" .. tostring(math.floor(mine)), 0.2, 1, 0.8) end
            if Num(others) then GameTooltip:AddLine("Others: +" .. tostring(math.floor(others)), 0.45, 0.75, 0.95) end
            if Num(totalBase) then GameTooltip:AddLine("Total: +" .. tostring(math.floor(totalBase)), 1, 1, 0.4) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Drag when unlocked.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    card:EnableMouse(false)
    card:Hide()
    self:SizeCard(card)
    return card
end

function HT:PlaceIncoming()
    if not self.incomingCard or not self.db then return end
    local a = self.db.incomingAnchor or DEFAULTS.incomingAnchor
    self.incomingCard:ClearAllPoints()
    self.incomingCard:SetPoint(a.point or "CENTER", UIParent, a.relPoint or "CENTER", a.x or 0, a.y or -265)
end

function HT:Layout()
    if not self.db then return end
    local a = self.db.outgoingAnchor or DEFAULTS.outgoingAnchor
    local step = (self.db.height or DEFAULTS.height) + (self.db.gap or DEFAULTS.gap)
    for i, card in ipairs(self.cards) do
        card:ClearAllPoints()
        card:SetPoint(a.point or "CENTER", UIParent, a.relPoint or "CENTER", a.x or 0, (a.y or -200) - (i - 1) * step)
    end
end

function HT:Key(unit)
    if not unit then return nil end
    local guid = Try(UnitGUID, unit)
    if Str(guid) then return "g:" .. guid end
    local name, realm = Try(UnitFullName, unit)
    if Str(name) then
        if Str(realm) and realm ~= "" then name = name .. "-" .. realm end
        return "n:" .. name
    end
    return "u:" .. unit
end

function HT:Find(unit)
    if not unit then return nil end
    local key = self:Key(unit)
    local card = key and self.byKey[key]
    if card then return card end
    for _, c in ipairs(self.cards) do
        if c.unit == unit then return c end
    end
    return nil
end

function HT:ShowOutgoing(unit, duration)
    self:Ready()
    if not self.db.showOutgoing or not unit or not Friendly(unit) then return end
    local key = self:Key(unit)
    local card = self:Find(unit)
    if not card then
        card = self:CreateCard("out")
        card.kind = "out"
        card.unit = unit
        card.key = key
        self.cards[#self.cards + 1] = card
        if self.db.diagnostics then self.db.diagnostics.cards = (self.db.diagnostics.cards or 0) + 1 end
        self:Layout()
    else
        card.unit = unit
        card.key = key
    end
    for k, c in pairs(self.byKey) do
        if c == card then self.byKey[k] = nil end
    end
    self.byKey[key] = card
    card:EnableMouse(not self.db.locked)
    card:Show()
    card.expires = GetTime() + (duration or 2)
    self:UpdateCard(card, unit)
end

function HT:ShowIncoming(duration)
    self:Ready()
    if not self.db.showIncoming then return end
    if not self.incomingCard then
        self.incomingCard = self:CreateCard("in")
        self.incomingCard.kind = "in"
        self:PlaceIncoming()
    end
    self.incomingCard:EnableMouse(not self.db.locked)
    self.incomingCard:Show()
    self.incomingCard.unit = "player"
    self.incomingCard.expires = GetTime() + (duration or 3)
    self:UpdateCard(self.incomingCard, "player")
end

function HT:HideCard(card)
    if not card then return end
    card:Hide()
    card.expires = nil
    card.unit = nil
    card.key = nil
    card.sim = nil
    card.hadHeal = nil
    card.castResolved = nil
    if card == self.incomingCard then return end
    for i = #self.cards, 1, -1 do
        if self.cards[i] == card then table.remove(self.cards, i) end
    end
    for k, c in pairs(self.byKey) do
        if c == card then self.byKey[k] = nil end
    end
    self:Layout()
end

function HT:Format(value)
    local number = CountValue(value)
    if not number or number <= 0 then return "" end
    return "+" .. tostring(math.floor(number + 0.5))
end

function HT:SetTitle(card, unit)
    if card.sim then
        card.title:SetText(card.kind == "in" and "Demo you" or "Demo target")
        card.title:SetTextColor(0.95, 0.90, 0.70)
        return
    end
    if card.kind == "in" then
        card.title:SetText("Incoming")
        card.title:SetTextColor(1, 1, 1)
        return
    end
    local name = (unit == "player") and "You" or Try(UnitName, unit)
    if not Str(name) then name = "Target" end
    if #name > 16 then name = name:sub(1, 14) .. "..." end
    card.title:SetText(name)
    if unit ~= "player" then
        local _, class = Try(UnitClass, unit)
        local color = Str(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then
            card.title:SetTextColor(color.r, color.g, color.b)
        else
            card.title:SetTextColor(1, 1, 1)
        end
    else
        card.title:SetTextColor(1, 1, 1)
    end
end

function HT:UpdateCard(card, unit)
    if not card then return end
    local sim = card.sim
    if not sim and (not unit or not Exists(unit)) then
        card:Hide()
        return
    end
    if not sim then
        local key = self:Key(unit)
        if card.key and key and card.key ~= key then return end
    end

    local health, healthMax, maxMine, maxOthers, totalBase, totalFromHealer, missTotal, missMine, missOthers, missClamped

    if sim then
        health = sim.health
        healthMax = sim.max
        maxMine = sim.mine or 0
        maxOthers = sim.others or 0
        totalBase = maxMine + maxOthers
        totalFromHealer = maxMine
        local missing = math.max(0, healthMax - health)
        missMine = math.min(maxMine, missing)
        missOthers = math.min(maxOthers, missing - missMine)
        missTotal = missMine + missOthers
        missClamped = (maxMine + maxOthers) > missing
    else
        card.unit = unit
        local unitMax = Try(UnitHealthMax, unit)
        local _, calcMine, calcOthers, calcMaxHealth, calcTotal, _, calcTotalFromHealer = self:Read(unit, self.calcMax)
        local calcMissTotal, calcMissMine, calcMissOthers, _, _, calcMissClamped = self:Read(unit, self.calcMissing)
        health = Try(UnitHealth, unit, false)
        healthMax = Above(calcMaxHealth, Above(unitMax, 1))
        maxMine, maxOthers, totalBase = calcMine, calcOthers, calcTotal
        totalFromHealer = calcTotalFromHealer
        missTotal, missMine, missOthers, missClamped = calcMissTotal, calcMissMine, calcMissOthers, calcMissClamped
    end

    card.healthStrip:SetMinMaxValues(0, healthMax)
    if IsSecret(health) then
        card.healthStrip:SetValue(health)
    elseif health ~= nil then
        card.healthStrip:SetValue(health)
    end

    local r, g, b = 0, 1, 0
    if sim then
        local hp = health / healthMax
        r = hp < 0.5 and 1.0 or 2.0 * (1.0 - hp)
        g = hp > 0.5 and 0.8 or 1.6 * hp
    else
        local curve = self:HealthCurve()
        if curve and UnitHealthPercent then
            local ok, cr, cg, cb = pcall(function()
                local color = UnitHealthPercent(unit, false, curve)
                if type(color) ~= "table" and type(color) ~= "userdata" then return nil end
                return color:GetRGB()
            end)
            if ok and cr ~= nil then
                if IsSecret(cr) then
                    r, g, b = cr, cg, cb
                else
                    r, g, b = cr, cg, cb
                end
            end
        end
    end
    card.healthStrip:SetStatusBarColor(r, g, b, 1)

    local raw, effective
    if card.kind == "in" then
        raw = self:OthersBase(maxMine, maxOthers, totalBase, totalFromHealer)
        effective = missOthers
    else
        raw = totalBase
        effective = missTotal
    end

    local cr, cg, cb, ratio = self:OverhealColor(raw, effective)
    local secretValues = IsSecret(raw) or IsSecret(effective) or IsSecret(missClamped)
    local otherScale = card.kind == "out" and 0.78 or 1
    local otherValue
    if card.kind == "in" then
        otherValue = Keep(raw, maxOthers)
    else
        otherValue = Keep(maxOthers, 0)
    end
    local mineValue = Keep(maxMine, 0)

    -- Once a heal has been seen, a zero prediction means it landed. This only
    -- works with readable values; with secret values the cast tails handle it.
    local totalCount = CountValue(raw)
    if totalCount ~= nil and totalCount > 0 then card.hadHeal = true end
    if card.hadHeal and totalCount ~= nil and totalCount <= 0 then
        local castingThis = self.castIsHeal ~= false and self.castUnit == card.unit and self:CastEnd() ~= nil
        if not castingThis then
            card.expires = math.min(card.expires or (GetTime() + 0.3), GetTime() + 0.3)
        end
    end

    -- Feed the heal values straight into the StatusBars. In this client the
    -- values are secret: only the native renderer can draw the lengths.
    card.otherRibbon:SetMinMaxValues(0, healthMax)
    if secretValues then
        card.otherRibbon:SetStatusBarColor(0.22, 0.62, 0.38, 0.95)
    else
        card.otherRibbon:SetStatusBarColor(cr * otherScale, cg * otherScale, cb * otherScale, 0.95)
    end
    card.otherRibbon:SetValue(otherValue)
    card.otherRibbon:Show()

    card.mineRibbon:SetMinMaxValues(0, healthMax)
    if card.kind == "out" then
        if secretValues then
            card.mineRibbon:SetStatusBarColor(0.20, 0.92, 0.55, 1)
        else
            card.mineRibbon:SetStatusBarColor(cr, cg, cb, 1)
        end
        card.mineRibbon:SetValue(mineValue)
        card.mineRibbon:Show()
    else
        card.mineRibbon:SetValue(0)
        card.mineRibbon:Hide()
    end

    -- Secret-safe binary overheal: an orange copy of each segment is shown via
    -- the secret `clamped` boolean. With readable values we keep the detailed
    -- severity colors instead.
    card.otherOver:SetMinMaxValues(0, healthMax)
    card.otherOver:SetValue(otherValue)
    card.mineOver:SetMinMaxValues(0, healthMax)
    card.mineOver:SetValue(card.kind == "out" and mineValue or 0)
    if secretValues then
        card.otherOver:Show()
        local okOther = pcall(card.otherOver.SetAlphaFromBoolean, card.otherOver, missClamped, 1, 0)
        if not okOther then card.otherOver:Hide() end
        if card.kind == "out" then
            card.mineOver:Show()
            local okMine = pcall(card.mineOver.SetAlphaFromBoolean, card.mineOver, missClamped, 1, 0)
            if not okMine then card.mineOver:Hide() end
        else
            card.mineOver:Hide()
        end
    else
        card.otherOver:Hide()
        card.mineOver:Hide()
    end

    card.healEdge:Show()
    card.sparkHealth:Show()
    card.sparkHeal:Show()

    if secretValues then
        card.overCap:SetColorTexture(1, 0.55, 0.12, 0.95)
        card.overCap:SetAlpha(0)
        card.overCap:Show()
        local ok = pcall(card.overCap.SetAlphaFromBoolean, card.overCap, missClamped, 1, 0)
        if not ok then card.overCap:Hide() end
        card:SetBackdropBorderColor(0, 0, 0, 0.90)
    elseif ratio > 0.01 then
        card:SetBackdropBorderColor(cr, cg, cb, 0.90)
        card.overCap:SetColorTexture(cr, cg, cb, 0.95)
        card.overCap:SetAlpha(1)
        card.overCap:Show()
    elseif missClamped then
        card:SetBackdropBorderColor(1, 0.55, 0.12, 0.90)
        card.overCap:SetColorTexture(1, 0.55, 0.12, 0.95)
        card.overCap:SetAlpha(1)
        card.overCap:Show()
    else
        card:SetBackdropBorderColor(0, 0, 0, 0.90)
        card.overCap:Hide()
    end

    card.amount:SetText(self:Format(raw))
    self:SetTitle(card, unit)
end

-- ---------------------------------------------------------------------------
-- Unit target resolution
-- ---------------------------------------------------------------------------

function HT:DefaultFriendly()
    for _, unit in ipairs({ "mouseover", "target", "focus" }) do
        if Exists(unit) and Friendly(unit) then return unit end
    end
    return "player"
end

function HT:GroupUnits()
    local out = { "player" }
    local raid = false
    if IsInRaid then
        local ok, value = pcall(IsInRaid)
        if ok and not IsSecret(value) then raid = value and true or false end
    end
    if raid then
        for i = 1, 40 do
            local u = "raid" .. i
            if Exists(u) then out[#out + 1] = u end
        end
    else
        for i = 1, 4 do
            local u = "party" .. i
            if Exists(u) then out[#out + 1] = u end
        end
    end
    return out
end

function HT:Stable(unit)
    if not unit then return unit end
    if unit == "player" then return "player" end

    local guid = Try(UnitGUID, unit)
    if Str(guid) then
        for _, u in ipairs(self:GroupUnits()) do
            local ug = Try(UnitGUID, u)
            if Str(ug) and ug == guid then return u end
        end
    end

    local okPlayer, isPlayer = pcall(UnitIsUnit, unit, "player")
    if okPlayer and not IsSecret(isPlayer) and isPlayer then return "player" end

    for _, u in ipairs(self:GroupUnits()) do
        if u ~= "player" then
            local ok, same = pcall(UnitIsUnit, unit, u)
            if ok and not IsSecret(same) and same then return u end
        end
    end
    return unit
end

function HT:Resolve(name)
    local short
    if Str(name) then short = name:match("^([^%-]+)") or name end

    for _, unit in ipairs({ "mouseover", "target", "focus", "player" }) do
        if Exists(unit) then
            local n, realm = Try(UnitFullName, unit)
            if Str(n) then
                local full = n
                if Str(realm) and realm ~= "" then full = n .. "-" .. realm end
                if Str(name) and (name == n or name == full or short == n) then return self:Stable(unit) end
            end
        end
    end

    if Str(name) then
        for _, unit in ipairs(self:GroupUnits()) do
            local n, realm = Try(UnitFullName, unit)
            if Str(n) then
                local full = n
                if Str(realm) and realm ~= "" then full = n .. "-" .. realm end
                if name == n or name == full or short == n then return unit end
            end
        end
        local ok, guid = pcall(UnitGUID, name)
        if ok and Str(guid) then
            for _, unit in ipairs(self:GroupUnits()) do
                local ug = Try(UnitGUID, unit)
                if Str(ug) and ug == guid then return unit end
            end
        end
    end
    return self:Stable(self:DefaultFriendly())
end

function HT:GroupUnit(unit)
    if not unit then return false end
    if unit == "player" then return true end
    return (unit:match("^party%d+$") ~= nil) or (unit:match("^raid%d+$") ~= nil)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

function HT:OnCastSent(targetName, castGUID, spellID)
    local healsOnly = (not self.db) or self.db.healsOnly
    local isHeal = (not healsOnly) or self:IsHeal(spellID)
    local activeHeal = self.castIsHeal ~= false and self.castUnit and Exists(self.castUnit) and self:CastEnd()

    if not isHeal then
        if not activeHeal then
            self.castUnit = nil
            self.castGUID = nil
            self.castSpellID = nil
            self.castIsHeal = false
        end
        return
    end

    local unit = self:Resolve(targetName)
    if not unit then return end

    -- An instant heal sent during a hard-cast heal gets its own short card;
    -- it must not steal the active cast's target or GUID.
    if activeHeal and self.castGUID and castGUID and castGUID ~= self.castGUID then
        self:ShowOutgoing(unit, 2)
        self.healCastUntil = math.max(self.healCastUntil or 0, GetTime() + 2)
        if unit == "player" then
            self.selfHealUntil = math.max(self.selfHealUntil or 0, GetTime() + 2)
        end
        return
    end

    self.castUnit = unit
    self.castGUID = castGUID
    self.castSpellID = spellID
    self.castIsHeal = true
    self.healCastUntil = GetTime() + 3
    if unit == "player" then
        self.selfHealUntil = GetTime() + 3
    else
        self.selfHealUntil = 0
    end
    local existing = self:Find(unit)
    if existing then
        existing.castResolved = nil
        existing.hadHeal = nil
    end
    self:ShowOutgoing(unit, 3)
end

function HT:CastEnd()
    local _, _, _, _, endTime = Try(UnitCastingInfo, "player")
    if Num(endTime) then return endTime / 1000 end
    local _, _, _, _, channelEnd = Try(UnitChannelInfo, "player")
    if Num(channelEnd) then return channelEnd / 1000 end
    return nil
end

function HT:ShowCurrentCast(extra)
    local unit = self.castUnit
    if not unit or not Exists(unit) then
        unit = self:Stable(self:DefaultFriendly())
        self.castUnit = unit
    end
    if not unit then return end
    local endSec = self:CastEnd()
    local duration = 2.5
    if endSec then duration = math.max(1, endSec - GetTime() + (extra or 2.5)) end
    self.healCastUntil = math.max(self.healCastUntil or 0, (endSec and endSec + 2) or (GetTime() + 3))
    if unit == "player" then
        self.selfHealUntil = (endSec and endSec + 2.5) or (GetTime() + 3)
    end
    local existing = self:Find(unit)
    if existing then
        existing.castResolved = nil
        existing.hadHeal = nil
    end
    self:ShowOutgoing(unit, duration)
end

function HT:OnCastStart(castGUID, spellID)
    if self.castIsHeal == false then return end
    if castGUID and self.castGUID and castGUID ~= self.castGUID then return end
    if not self.castGUID and castGUID then self.castGUID = castGUID end
    if spellID and not self.castSpellID then self.castSpellID = spellID end
    self:ShowCurrentCast(2.5)
end

function HT:OnCastDelayed(castGUID)
    if self.castIsHeal == false then return end
    if castGUID and self.castGUID and castGUID ~= self.castGUID then return end
    if not self.castGUID and castGUID then self.castGUID = castGUID end
    if not self.castUnit or not Exists(self.castUnit) then return end

    local endSec = self:CastEnd()
    local duration = 2.5
    if endSec then duration = math.max(1, endSec - GetTime() + 2.5) end
    self.healCastUntil = math.max(self.healCastUntil or 0, (endSec and endSec + 2) or (GetTime() + 3))
    if self.castUnit == "player" then
        self.selfHealUntil = (endSec and endSec + 2.5) or (GetTime() + 3)
    end

    local card = self:Find(self.castUnit)
    if card then
        card.castResolved = nil
        card.expires = GetTime() + duration
        card:Show()
        self:UpdateCard(card, self.castUnit)
    else
        self:ShowOutgoing(self.castUnit, duration)
    end
end

function HT:OnCastDone(castGUID)
    if self.castIsHeal == false then return end
    if castGUID and self.castGUID and castGUID ~= self.castGUID then return end
    if not self.castUnit then return end
    if self.castUnit == "player" then
        self.selfHealUntil = math.max(self.selfHealUntil or 0, GetTime() + 2.5)
    end
    if self:CastEnd() then
        self:OnCastDelayed(castGUID)
        return
    end
    local card = self:Find(self.castUnit)
    if card then card.castResolved = true end
    self.healCastUntil = math.max(self.healCastUntil or 0, GetTime() + 2)
    if card and card.expires then
        card.expires = math.min(card.expires, GetTime() + 0.8)
        self:UpdateCard(card, self.castUnit)
    end

    -- The cast is over. Keep the card tail, but stop treating this cast as
    -- active so OnUpdate and later cast events cannot extend it.
    self.castUnit = nil
    self.castGUID = nil
    self.castSpellID = nil
    self.castIsHeal = nil
end

function HT:OnPrediction(unit)
    if not unit then return end
    self:Ready()
    if unit ~= "player" then unit = self:Stable(unit) end

    if unit == "player" then
        local grouped = #self:GroupUnits() > 1
        if grouped then
            if self.db.showIncoming then self:ShowIncoming(5) end
        elseif self.incomingCard then
            self.incomingCard:Hide()
            self.incomingCard.expires = nil
            self.incomingCard.sim = nil
        end
        local bar = self:Find("player")
        if bar then
            local tail = bar.castResolved and 0.6 or 3
            bar.expires = GetTime() + tail
            self:UpdateCard(bar, "player")
        end
        return
    end

    if not self.db.showOutgoing then return end

    local card = self:Find(unit)
    if card then
        local tail = card.castResolved and 0.6 or 3
        card.expires = GetTime() + tail
        card:Show()
        self:UpdateCard(card, unit)
        return
    end

    if self.healCastUntil and GetTime() <= self.healCastUntil
        and self:GroupUnit(unit) and Friendly(unit) then
        self:ShowOutgoing(unit, 3)
    end
end

function HT:Touch(unit)
    if not unit then return end
    if unit ~= "player" then unit = self:Stable(unit) end
    if unit == "player" and self.incomingCard and self.incomingCard:IsShown() then
        local _, mine, others, _, totalBase, _, totalFromHealer = self:Read("player", self.calcMax)
        local amount = self:OthersBase(mine, others, totalBase, totalFromHealer)
        local count = CountValue(amount)
        if count ~= nil and count <= 0 then
            self.incomingCard:Hide()
            self.incomingCard.expires = nil
            self.incomingCard.sim = nil
        else
            self.incomingCard.expires = math.min(self.incomingCard.expires or (GetTime() + 0.5), GetTime() + 0.5)
            self:UpdateCard(self.incomingCard, "player")
        end
    end
    if not self.db.showOutgoing then return end
    local card = self:Find(unit)
    if card and card:IsShown() then
        local activeCast = self.castIsHeal ~= false and self.castUnit == unit and self:CastEnd()
        if not activeCast then
            card.expires = math.min(card.expires or (GetTime() + 0.6), GetTime() + 0.6)
        end
        self:UpdateCard(card, unit)
    end
end

function HT:Validate()
    for i = #self.cards, 1, -1 do
        local card = self.cards[i]
        if not card.sim and card.unit and not Exists(card.unit) then
            local replacement = nil
            if Str(card.key) and card.key:sub(1, 2) == "g:" then
                local guid = card.key:sub(3)
                for _, u in ipairs(self:GroupUnits()) do
                    local ug = Try(UnitGUID, u)
                    if Str(ug) and ug == guid then replacement = u; break end
                end
            end
            if replacement then
                card.unit = replacement
                self:UpdateCard(card, replacement)
            else
                self:HideCard(card)
            end
        end
    end
end

function HT:Handle(event, ...)
    if self.db and self.db.diagnostics then
        self.db.diagnostics.events = (self.db.diagnostics.events or 0) + 1
    end

    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON then
            self:LoadDB()
            self:EnsureCalculators()
            local _, _, _, interface = GetBuildInfo()
            self.db.diagnostics.loaded = true
            self.db.diagnostics.interface = interface or 0
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        self:EnsureCalculators()
        self.selfHealUntil = 0
        self.healCastUntil = 0
        self.castUnit = nil
        self.castGUID = nil
        self.castSpellID = nil
        self.castIsHeal = nil
        if self.db then
            for i = #self.cards, 1, -1 do self:HideCard(self.cards[i]) end
            if self.incomingCard then self.incomingCard:Hide(); self.incomingCard.expires = nil end
        end
        return
    end

    if event == "UNIT_SPELLCAST_SENT" then
        local unit, targetName, castGUID, spellID = ...
        if unit == "player" then
            if self.db and self.db.diagnostics then
                self.db.diagnostics.casts = (self.db.diagnostics.casts or 0) + 1
            end
            self:OnCastSent(targetName, castGUID, spellID)
        end
        return
    end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, castGUID, spellID = ...
        if unit == "player" then self:OnCastStart(castGUID, spellID) end
        return
    end

    if event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local unit, castGUID = ...
        if unit == "player" then self:OnCastDelayed(castGUID) end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID = ...
        if unit == "player" and self.castIsHeal ~= false and self.castUnit and Exists(self.castUnit) then
            if self.castGUID and castGUID and castGUID ~= self.castGUID then return end
            self:ShowOutgoing(self.castUnit, 1.5)
            local card = self:Find(self.castUnit)
            if card then card.castResolved = true end
        end
        return
    end

    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit, castGUID = ...
        if unit == "player" then self:OnCastDone(castGUID) end
        return
    end

    if event == "UNIT_HEAL_PREDICTION" then
        if self.db and self.db.diagnostics then
            self.db.diagnostics.predictions = (self.db.diagnostics.predictions or 0) + 1
        end
        self:OnPrediction(...)
        return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_MAXHEALTH"
        or event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" then
        self:Touch(...)
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
        self:Validate()
        return
    end
end

-- ---------------------------------------------------------------------------
-- Demo / test mode
-- ---------------------------------------------------------------------------

function HT:Demo()
    self:Ready()
    self:StopDemo()
    local out = self:CreateCard("out")
    out.kind = "out"
    out.unit = "healtide_demo_target"
    out.key = "demo:out"
    out.sim = { health = 500, max = 1000, mine = 350, others = 250 }
    out:EnableMouse(not self.db.locked)
    out:Show()
    out.expires = GetTime() + 15
    self.cards[#self.cards + 1] = out
    self.byKey["demo:out"] = out
    self:Layout()
    self:UpdateCard(out, out.unit)

    if not self.incomingCard then self.incomingCard = self:CreateCard("in"); self:PlaceIncoming() end
    self.incomingCard.kind = "in"
    self.incomingCard.unit = "healtide_demo_player"
    self.incomingCard.sim = { health = 700, max = 1000, mine = 0, others = 300 }
    self.incomingCard:EnableMouse(not self.db.locked)
    self.incomingCard:Show()
    self.incomingCard.expires = GetTime() + 15
    self:UpdateCard(self.incomingCard, self.incomingCard.unit)
end

function HT:StopDemo()
    for i = #self.cards, 1, -1 do
        if self.cards[i].sim then self:HideCard(self.cards[i]) end
    end
    if self.incomingCard and self.incomingCard.sim then
        self.incomingCard:Hide()
        self.incomingCard.expires = nil
        self.incomingCard.sim = nil
    end
end

function HT:Live(duration)
    self:Ready()
    local unit = self:DefaultFriendly()
    if unit then self:ShowOutgoing(unit, duration or 10) end
    self:ShowIncoming(duration or 10)
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

function HT:ApplyLock()
    for _, card in ipairs(self.cards) do card:EnableMouse(not self.db.locked) end
    if self.incomingCard then self.incomingCard:EnableMouse(not self.db.locked) end
end

function HT:Resize()
    for _, card in ipairs(self.cards) do
        self:SizeCard(card)
        if card:IsShown() and (card.unit or card.sim) then self:UpdateCard(card, card.unit) end
    end
    if self.incomingCard then
        self:SizeCard(self.incomingCard)
        self:PlaceIncoming()
        if self.incomingCard:IsShown() then self:UpdateCard(self.incomingCard, self.incomingCard.unit or "player") end
    end
    self:Layout()
    self:ApplyLock()
end

function HT:Reset()
    self:Ready()
    self.db.width = DEFAULTS.width
    self.db.height = DEFAULTS.height
    self.db.gap = DEFAULTS.gap
    self.db.locked = DEFAULTS.locked
    self.db.showOutgoing = DEFAULTS.showOutgoing
    self.db.showIncoming = DEFAULTS.showIncoming
    self.db.healsOnly = DEFAULTS.healsOnly
    self.db.outgoingAnchor = Copy(DEFAULTS.outgoingAnchor)
    self.db.incomingAnchor = Copy(DEFAULTS.incomingAnchor)
    self:Resize()
end

function HT:Status()
    local version, build, _, interface = GetBuildInfo()
    Say("WoW " .. tostring(version) .. " build " .. tostring(build) .. ", interface " .. tostring(interface))
    Say("Prediction: " .. ((self.calcMax or self.calcMissing) and "OK" or "MISSING")
        .. " | clamps: " .. tostring(self.db.diagnostics.clampMode or "?")
        .. " / " .. tostring(self.db.diagnostics.clampModeInBar or "?")
        .. " | two calculators: " .. (self.db.diagnostics.twoCalculators and "yes" or "no"))
    Say("Secret values: max=" .. (self.db.diagnostics.secretMax and "yes" or "no")
        .. " | missing=" .. (self.db.diagnostics.secretMissing and "yes" or "no"))
    Say("Outgoing: " .. (self.db.showOutgoing and "on" or "off")
        .. " | Incoming: " .. (self.db.showIncoming and "on" or "off")
        .. " | locked: " .. (self.db.locked and "yes" or "no")
        .. " | heals only: " .. (self.db.healsOnly and "yes" or "no"))
    Say("Size: " .. tostring(self.db.width) .. "x" .. tostring(self.db.height)
        .. " | spacing: " .. tostring(self.db.gap)
        .. " | active cards: " .. tostring(#self.cards))
    Say("Diagnostics: events=" .. tostring(self.db.diagnostics.events or 0)
        .. ", casts=" .. tostring(self.db.diagnostics.casts or 0)
        .. ", predictions=" .. tostring(self.db.diagnostics.predictions or 0)
        .. ", cards=" .. tostring(self.db.diagnostics.cards or 0))
    if self.db.diagnostics.lastError and self.db.diagnostics.lastError ~= "" then
        Say("Last error (" .. tostring(self.db.diagnostics.lastErrorEvent) .. ") at "
            .. tostring(self.db.diagnostics.lastErrorAt or "?") .. ": " .. tostring(self.db.diagnostics.lastError))
    end
end

function HT:SecretCheck()
    self:Ready()
    local function Flag(value)
        if IsSecret(value) then return "secret" end
        if value == nil then return "nil" end
        return tostring(value)
    end
    local function Fmt(value)
        if not IsSecret(value) then
            if value == nil then return "nil" end
            return tostring(value)
        end
        if type(value) ~= "number" then return "secret(non-number)" end
        local ok, text = pcall(string.format, "%.0f", value)
        if not ok then return "secret(format-error)" end
        return "secret(" .. tostring(text) .. ",text-secret=" .. tostring(IsSecret(text)) .. ")"
    end

    Say("B2 health: " .. Flag(Try(UnitHealth, "player"))
        .. " | current-only: " .. Flag(Try(UnitHealth, "player", false)))

    local curve = self:HealthCurve()
    if curve and UnitHealthPercent then
        local ok, color = pcall(UnitHealthPercent, "player", false, curve)
        if not ok then
            Say("B2 health percent: error")
        else
            local rgb = "?"
            local okRGB, r = pcall(function()
                if type(color) ~= "table" and type(color) ~= "userdata" then return nil end
                return color:GetRGB()
            end)
            if okRGB then rgb = Flag(r) end
            Say("B2 health percent: secret=" .. (IsSecret(color) and "yes" or "no")
                .. " | rgb=" .. rgb)
        end
    end

    if not CreateUnitHealPredictionCalculator or not UnitGetDetailedHealPrediction then
        Say("B2 calculator: unavailable")
        return
    end
    local okCalc, calc = pcall(CreateUnitHealPredictionCalculator)
    if not okCalc or not calc then
        Say("B2 calculator: create failed")
        return
    end
    if not pcall(UnitGetDetailedHealPrediction, "player", "player", calc) then
        Say("B2 calculator: prediction call failed")
        return
    end

    local hasSecret = "?"
    if calc.HasSecretValues then
        local okSecret, value = pcall(calc.HasSecretValues, calc)
        if okSecret then hasSecret = Flag(value) end
    end
    local total, mine, others, clamped = Try(calc.GetIncomingHeals, calc)
    local totalBase = Try(calc.GetTotalIncomingHeals, calc)
    local totalFromHealer = Try(calc.GetTotalIncomingHealsFromHealer, calc)
    Say("B2 calc secret: " .. hasSecret)
    Say("B2 incoming: total=" .. Fmt(total) .. " | mine=" .. Fmt(mine)
        .. " | others=" .. Fmt(others) .. " | clamped=" .. Flag(clamped))
    Say("B2 raw: total=" .. Fmt(totalBase) .. " | fromHealer=" .. Fmt(totalFromHealer))
end

SLASH_HEALTIDE1 = "/ht"
SLASH_HEALTIDE2 = "/healtide"
function HT:Command(message)
    HT:Ready()
    local text = (message or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = text:match("^(%S*)%s*(.*)$")
    cmd = cmd or ""

    if cmd == "" or cmd == "help" then
        Say("Commands: /ht test | live | stop | lock | unlock | outgoing | incoming | healsonly | width <n> | height <n> | spacing <n> | reset | status | secrets")
    elseif cmd == "test" then
        HT:Demo()
        Say("Demo cards shown for 15 s (target 50%: 250 others + 350 you; you 70%: 300 incoming).")
    elseif cmd == "live" then
        HT:Live(10)
        Say("Live cards shown for 10 s.")
    elseif cmd == "stop" then
        HT:StopDemo()
        Say("Demo cards hidden.")
    elseif cmd == "lock" then
        HT.db.locked = true; HT:ApplyLock(); Say("Cards locked.")
    elseif cmd == "unlock" then
        HT.db.locked = false; HT:ApplyLock(); Say("Cards unlocked; drag them with the mouse.")
    elseif cmd == "outgoing" then
        HT.db.showOutgoing = not HT.db.showOutgoing
        if not HT.db.showOutgoing then
            for i = #HT.cards, 1, -1 do HT:HideCard(HT.cards[i]) end
        end
        Say("Outgoing cards: " .. (HT.db.showOutgoing and "on" or "off"))
    elseif cmd == "incoming" then
        HT.db.showIncoming = not HT.db.showIncoming
        if not HT.db.showIncoming and HT.incomingCard then HT.incomingCard:Hide() end
        Say("Incoming cards: " .. (HT.db.showIncoming and "on" or "off"))
    elseif cmd == "healsonly" then
        HT.db.healsOnly = not HT.db.healsOnly
        Say("Heals only: " .. (HT.db.healsOnly and "on" or "off"))
    elseif cmd == "width" then
        local v = tonumber(arg)
        if v and v >= 120 and v <= 500 then HT.db.width = v; HT:Resize(); Say("Width: " .. v) else Say("Width must be 120-500.") end
    elseif cmd == "height" then
        local v = tonumber(arg)
        if v and v >= 10 and v <= 40 then HT.db.height = v; HT:Resize(); Say("Height: " .. v) else Say("Height must be 10-40.") end
    elseif cmd == "spacing" then
        local v = tonumber(arg)
        if v and v >= 0 and v <= 20 then HT.db.gap = v; HT:Layout(); Say("Spacing: " .. v) else Say("Spacing must be 0-20.") end
    elseif cmd == "reset" then
        HT:Reset(); Say("Settings reset.")
    elseif cmd == "status" then
        HT:Status()
    elseif cmd == "secrets" then
        HT:SecretCheck()
    else
        Say("Unknown command. /ht help")
    end
end

SlashCmdList["HEALTIDE"] = function(message)
    local ok, err = pcall(HT.Command, HT, message)
    if not ok then HT:ReportError("Slash", err) end
end

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

function HT:ReportError(event, err)
    if self.db and self.db.diagnostics then
        self.db.diagnostics.lastError = tostring(err)
        self.db.diagnostics.lastErrorEvent = tostring(event)
        self.db.diagnostics.lastErrorAt = (date and date("%Y-%m-%d %H:%M:%S")) or tostring(GetTime())
    end
    local now = GetTime()
    if now - (self.lastErrorAt or 0) > 5 then
        self.lastErrorAt = now
        Say("Error (" .. tostring(event) .. "): " .. tostring(err))
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(HT.Handle, HT, event, ...)
    if not ok then HT:ReportError(event, err) end
end)

for _, event in ipairs({
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_HEAL_PREDICTION",
    "UNIT_HEALTH",
    "UNIT_HEALTH_FREQUENT",
    "UNIT_MAXHEALTH",
    "UNIT_ABSORB_AMOUNT_CHANGED",
    "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
    "GROUP_ROSTER_UPDATE",
    "RAID_ROSTER_UPDATE",
}) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end

function HT:Refresh(now)
    if not self.db then return end

    -- Keep the target card alive and refresh it while the heal is being cast
    -- or channelled. Once the cast is resolved, prediction events use a short
    -- tail; a stale UnitCastingInfo must not extend it again.
    if self.castIsHeal ~= false and self.castUnit and Exists(self.castUnit) then
        local card = self:Find(self.castUnit)
        if card and not card.castResolved then
            local endSec = self:CastEnd()
            if endSec and now - (self.lastCastRefresh or 0) > 0.1 then
                self.lastCastRefresh = now
                card.expires = math.max(card.expires or 0, endSec + 2.5)
                self:UpdateCard(card, self.castUnit)
            end
        end
    end

    for i = #self.cards, 1, -1 do
        local card = self.cards[i]
        if card.expires and now > card.expires then self:HideCard(card) end
    end
    if self.incomingCard and self.incomingCard.expires and now > self.incomingCard.expires then
        self.incomingCard:Hide()
        self.incomingCard.expires = nil
        self.incomingCard.sim = nil
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    local ok, err = pcall(HT.Refresh, HT, GetTime())
    if not ok then HT:ReportError("OnUpdate", err) end
end)

_G.HealTideDebug = {
    cards = HT.cards,
    incoming = function() return HT.incomingCard end,
    db = function() return HT.db end,
    calcMax = function() return HT.calcMax end,
    calcMissing = function() return HT.calcMissing end,
    addon = HT,
}
