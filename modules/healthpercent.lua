BNP = BNP or {}

local function Enabled()
  return BNP.IsHealthTextEnabled and BNP:IsHealthTextEnabled()
end

local function CreateHealthText(plate)
  if plate.BNPHealthPercent then return plate.BNPHealthPercent end
  if not plate or not plate.healthbar then return nil end

  -- Parent the text directly to the Blizzard health StatusBar. This keeps it
  -- above the bar texture and automatically follows every frame-level change
  -- made for Target Glow / permanent target priority. No separate holder can
  -- become stale during target switches or nameplate recycling.
  local anchor = plate.healthbar
  local text = anchor:CreateFontString(nil, "OVERLAY")
  text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  text:SetPoint("CENTER", anchor, "CENTER", 3, 0)
  text:SetTextColor(1, 1, 1)
  text:Hide()

  plate.BNPHealthPercent = text
  return text
end

local function GetPercentFromBar(plate)
  if not plate or not plate.healthbar then return nil end

  local minValue, maxValue = plate.healthbar:GetMinMaxValues()
  local value = plate.healthbar:GetValue()

  if value and minValue and maxValue and maxValue > minValue then
    local pct = ((value - minValue) / (maxValue - minValue)) * 100
    return math.floor(pct + 0.5)
  end

  return nil
end

local function GetPercentFromUnit(plate)
  if not plate or not plate.GetName then return nil end

  local token = plate:GetName(1)
  if not token or not UnitExists(token) then return nil end
  if not UnitHealth or not UnitHealthMax then return nil end

  local health = UnitHealth(token)
  local maxHealth = UnitHealthMax(token)

  if health and maxHealth and maxHealth > 0 then
    return math.floor((health / maxHealth) * 100 + 0.5)
  end

  return nil
end

local function GetHealthFromUnit(plate)
  if not plate or not plate.GetName then return nil, nil end

  local token = plate:GetName(1)
  if not token or not UnitExists(token) then return nil, nil end
  if not UnitHealth or not UnitHealthMax then return nil, nil end

  local health = tonumber(UnitHealth(token))
  local maxHealth = tonumber(UnitHealthMax(token))

  if health and maxHealth and maxHealth > 0 then
    return health, maxHealth
  end

  return nil, nil
end

local function GetHealthFromBar(plate)
  if not plate or not plate.healthbar then return nil, nil end

  local minValue, maxValue = plate.healthbar:GetMinMaxValues()
  local value = plate.healthbar:GetValue()

  value = tonumber(value)
  minValue = tonumber(minValue)
  maxValue = tonumber(maxValue)

  if value and minValue and maxValue and maxValue > minValue then
    return value - minValue, maxValue - minValue
  end

  return nil, nil
end

local function FormatHealth(value)
  value = tonumber(value)
  if not value then return nil end
  if value < 0 then value = 0 end

  -- Keep boss/player values readable inside the compact Blizzard healthbar.
  if value >= 1000000 then
    local shown = math.floor((value / 1000000) * 10 + 0.5) / 10
    return tostring(shown) .. "m"
  elseif value >= 10000 then
    return tostring(math.floor(value / 1000 + 0.5)) .. "k"
  elseif value >= 1000 then
    local shown = math.floor((value / 1000) * 10 + 0.5) / 10
    return tostring(shown) .. "k"
  end

  return tostring(math.floor(value + 0.5))
end

local function UpdatePlate(plate)
  if not plate or not plate.healthbar then return end

  local text = plate.BNPHealthPercent

  if not Enabled() or not plate:IsShown() then
    if text then text:Hide() end
    return
  end

  text = text or CreateHealthText(plate)
  if not text then return end

  local mode = BNP:GetHealthTextMode()
  local health, maxHealth = GetHealthFromUnit(plate)

  -- Fallback for clients/units where the SuperWoW unit token is temporarily
  -- unavailable. This may be normalized health on stock Vanilla.
  if health == nil or maxHealth == nil then
    health, maxHealth = GetHealthFromBar(plate)
  end

  local pct = nil
  if health and maxHealth and maxHealth > 0 then
    pct = math.floor((health / maxHealth) * 100 + 0.5)
  else
    pct = GetPercentFromBar(plate)
    if pct == nil then pct = GetPercentFromUnit(plate) end
  end

  if pct ~= nil then
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
  end

  local hpText = FormatHealth(health)
  local display = nil

  if mode == "percent" then
    if pct ~= nil then display = tostring(pct) .. "%" end
  elseif mode == "hp" then
    display = hpText
  elseif mode == "both" then
    if hpText and pct ~= nil then
      display = hpText .. " | " .. tostring(pct) .. "%"
    elseif hpText then
      display = hpText
    elseif pct ~= nil then
      display = tostring(pct) .. "%"
    end
  end

  if not display or display == "" then
    text:Hide()
    return
  end

  if text.BNPLastHealthText ~= display then
    text:SetText(display)
    text.BNPLastHealthText = display
  end
  text:Show()
end

-- Intentionally simple fallback: only reads values and updates text.
-- No SetScript calls on healthbar, no SetAlpha, no color changes.
local updater = CreateFrame("Frame")
local elapsed = 0
updater:SetScript("OnUpdate", function()
  elapsed = elapsed + arg1
  if elapsed < 0.10 then return end
  elapsed = 0

  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate:IsShown() then
      UpdatePlate(plate)
    elseif plate.BNPHealthPercent then
      plate.BNPHealthPercent:Hide()
    end
  end
end)

function BNP:RefreshHealthPercent()
  local plate
  for plate in pairs(self.plates or {}) do
    if plate and plate:IsShown() then
      UpdatePlate(plate)
    elseif plate and plate.BNPHealthPercent then
      plate.BNPHealthPercent:Hide()
    end
  end
end

-- Refresh immediately when Blizzard reuses a nameplate instead of waiting for
-- the next 0.10 s fallback pass.
if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnShow, function(plate)
    local current = plate or this
    if current then UpdatePlate(current) end
  end)
end

-- Target switches can change nameplate frame levels in the same frame. Because
-- the text now belongs to the healthbar this is only a value/visibility refresh,
-- not a layering workaround.
local healthEvents = CreateFrame("Frame")
healthEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
healthEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
healthEvents:SetScript("OnEvent", function()
  if BNP.RefreshHealthPercent then
    BNP:RefreshHealthPercent()
  end
end)
