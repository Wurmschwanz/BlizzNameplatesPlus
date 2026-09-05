BNP = BNP or {}

local fallbackColors = {
  WARRIOR = { 0.78, 0.61, 0.43 },
  MAGE = { 0.41, 0.80, 0.94 },
  ROGUE = { 1.00, 0.96, 0.41 },
  DRUID = { 1.00, 0.49, 0.04 },
  HUNTER = { 0.67, 0.83, 0.45 },
  SHAMAN = { 0.00, 0.44, 0.87 },
  PRIEST = { 1.00, 1.00, 1.00 },
  WARLOCK = { 0.58, 0.51, 0.79 },
  PALADIN = { 0.96, 0.55, 0.73 },
}

local function GetColor(class)
  if RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
    local c = RAID_CLASS_COLORS[class]
    return c.r, c.g, c.b
  end

  local c = fallbackColors[class]
  if c then return c[1], c[2], c[3] end
end

local function Enabled()
  if BNP.AreClassColorsEnabled then return BNP:AreClassColorsEnabled() end
  return not BNP_DB or BNP_DB.classColors ~= false
end

local function ClearClassCache(plate)
  if not plate then return end
  plate.BNPClassColorApplied = nil
  plate.BNPClassColorToken = nil
  plate.BNPClassGUID = nil
  plate.BNPClassR = nil
  plate.BNPClassG = nil
  plate.BNPClassB = nil
end

local function ClearNativeColor(plate)
  if not plate then return end
  plate.BNPClassNativeGUID = nil
  plate.BNPClassNativeR = nil
  plate.BNPClassNativeG = nil
  plate.BNPClassNativeB = nil
  plate.BNPClassNativeA = nil
end

local function ResolvePlateUnit(plate)
  if not plate or not plate.GetName then return nil, nil end

  local token = plate:GetName(1)
  if not token or not UnitExists(token) then
    return token, nil
  end

  local exists, guid = UnitExists(token)
  if exists then
    return token, guid
  end

  return token, nil
end

local function CaptureNativeColor(plate, guid)
  if not plate or not plate.healthbar or not guid then return end
  if plate.BNPClassNativeGUID == guid and plate.BNPClassNativeR then return end

  local r, g, b, a = plate.healthbar:GetStatusBarColor()
  plate.BNPClassNativeGUID = guid
  plate.BNPClassNativeR = r
  plate.BNPClassNativeG = g
  plate.BNPClassNativeB = b
  plate.BNPClassNativeA = a or 1
end

local function GetFallbackNativeColor(token)
  if not token or not UnitExists(token) then return nil end

  if UnitCanAttack and UnitCanAttack("player", token) then
    return 1, 0, 0, 1
  end

  if UnitIsFriend and UnitIsFriend("player", token) then
    return 0, 1, 0, 1
  end

  return 1, 1, 0, 1
end

local function RestoreNativeColor(plate)
  if not plate or not plate.healthbar then
    ClearClassCache(plate)
    return false
  end

  local token, guid = ResolvePlateUnit(plate)

  if token and guid and UnitIsPlayer(token) then
    if plate.BNPClassNativeGUID == guid and plate.BNPClassNativeR then
      plate.healthbar:SetStatusBarColor(
        plate.BNPClassNativeR,
        plate.BNPClassNativeG,
        plate.BNPClassNativeB,
        plate.BNPClassNativeA or 1
      )
    else
      local r, g, b, a = GetFallbackNativeColor(token)
      if r then plate.healthbar:SetStatusBarColor(r, g, b, a or 1) end
    end
  end

  ClearClassCache(plate)
  return true
end

local function ApplyClassColor(plate)
  if not Enabled() then
    RestoreNativeColor(plate)
    return false
  end

  if not plate or not plate.healthbar then return false end

  local token, guid = ResolvePlateUnit(plate)

  -- BNP only owns PLAYER class colors.
  -- NPC/neutral/friendly-NPC colors stay completely under Blizzard control.
  if not token or not guid or not UnitIsPlayer(token) then
    ClearClassCache(plate)
    return false
  end

  local _, class = UnitClass(token)
  local r, g, b = GetColor(class)
  if not r then
    ClearClassCache(plate)
    return false
  end

  -- Remember Blizzard's original player color before BNP overwrites it so the
  -- Class Colors checkbox can restore the plate immediately without /reload.
  CaptureNativeColor(plate, guid)

  plate.BNPClassColorApplied = true
  plate.BNPClassColorToken = token
  plate.BNPClassGUID = guid
  plate.BNPClassR = r
  plate.BNPClassG = g
  plate.BNPClassB = b

  plate.healthbar:SetStatusBarColor(r, g, b)
  return true
end

BNP.ApplyClassColor = ApplyClassColor
BNP.RestoreClassColor = RestoreNativeColor

function BNP:RefreshClassColors()
  local plate
  for plate in pairs(self.plates or {}) do
    if plate and plate:IsShown() and plate.healthbar then
      if Enabled() then
        ClearClassCache(plate)
        ApplyClassColor(plate)
      else
        RestoreNativeColor(plate)
      end
    end
  end
end

local function EnforceClassColor(plate)
  if not Enabled() then return end
  if not plate or not plate.healthbar or not plate.BNPClassGUID then return end

  local token, guid = ResolvePlateUnit(plate)

  -- Never enforce a cached color after Blizzard recycled the frame.
  if not token or not guid or guid ~= plate.BNPClassGUID or not UnitIsPlayer(token) then
    ClearClassCache(plate)
    ClearNativeColor(plate)
    return
  end

  local r, g, b, a = plate.healthbar:GetStatusBarColor()
  if math.abs(r - plate.BNPClassR) > 0.01
    or math.abs(g - plate.BNPClassG) > 0.01
    or math.abs(b - plate.BNPClassB) > 0.01 then
    -- Blizzard can rewrite a player plate back to its native reaction color.
    -- Keep that latest native value so disabling class colors restores cleanly.
    plate.BNPClassNativeGUID = guid
    plate.BNPClassNativeR = r
    plate.BNPClassNativeG = g
    plate.BNPClassNativeB = b
    plate.BNPClassNativeA = a or 1

    plate.healthbar:SetStatusBarColor(
      plate.BNPClassR,
      plate.BNPClassG,
      plate.BNPClassB
    )
  end
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    local current = plate or this
    if not current then return end

    ClearClassCache(current)
    ClearNativeColor(current)
    ApplyClassColor(current)

    local bar = current.healthbar
    if bar and not current.BNPClassColorHooked then
      local oldValueChanged = bar:GetScript("OnValueChanged")
      bar:SetScript("OnValueChanged", function()
        if oldValueChanged then oldValueChanged() end
        EnforceClassColor(current)
      end)
      current.BNPClassColorHooked = true
    end
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    local current = plate or this
    if not current then return end
    ClearClassCache(current)
    ClearNativeColor(current)
    ApplyClassColor(current)
  end)
end

-- Blizzard may rewrite player colors during combat/threat updates.
-- Re-apply only while the plate still resolves to the SAME player GUID.
-- If a recycled frame now represents an NPC/neutral unit, drop the cache
-- immediately and never touch its Blizzard color.
local elapsed = 0
local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function()
  elapsed = elapsed + arg1
  if elapsed < 0.10 then return end
  elapsed = 0

  if not Enabled() then return end

  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate:IsShown() and plate.healthbar then
      local token, guid = ResolvePlateUnit(plate)

      if plate.BNPClassGUID then
        EnforceClassColor(plate)
      elseif token and guid and UnitIsPlayer(token) then
        ApplyClassColor(plate)
      end
    end
  end
end)
