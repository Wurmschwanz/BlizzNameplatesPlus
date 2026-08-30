BNP = BNP or {}

BNP.defaults = BNP.defaults or {
  nameplateScale = 1.0,
  nameplateYOffset = 0,
  nonTargetAlpha = 1.0,
  iconSize = 18,
  ccIconSize = 18,
  debuffPosition = "top",
  tankMode = false,
  classColors = true,
  castbars = true,
  debuffs = true,
  crowdControl = true,
  separateCCRow = true,
  showOtherCCs = true,
  castbarHeight = 6,
  castbarSpacing = 4,
  minimapAngle = 225,
  healthPercent = false,
  healthText = "off",
  targetFocus = true,
  targetGlowColor = "white",
  comboPoints = true,
  totemIndicators = true,
  totemIconSize = 24,
}

function BNP:InitConfig()
  BNP_DB = BNP_DB or {}

  if BNP_DB.nameplateScale == nil then BNP_DB.nameplateScale = self.defaults.nameplateScale end
  if BNP_DB.nameplateYOffset == nil then BNP_DB.nameplateYOffset = self.defaults.nameplateYOffset end
  if BNP_DB.nonTargetAlpha == nil then BNP_DB.nonTargetAlpha = self.defaults.nonTargetAlpha end
  if BNP_DB.iconSize == nil then BNP_DB.iconSize = self.defaults.iconSize end
  if BNP_DB.ccIconSize == nil then BNP_DB.ccIconSize = BNP_DB.iconSize or self.defaults.ccIconSize end
  if BNP_DB.debuffPosition == nil then BNP_DB.debuffPosition = self.defaults.debuffPosition end
  if BNP_DB.tankMode == nil then BNP_DB.tankMode = self.defaults.tankMode end
  if BNP_DB.classColors == nil then BNP_DB.classColors = self.defaults.classColors end
  if BNP_DB.castbars == nil then BNP_DB.castbars = self.defaults.castbars end
  if BNP_DB.debuffs == nil then BNP_DB.debuffs = self.defaults.debuffs end
  if BNP_DB.crowdControl == nil then BNP_DB.crowdControl = (BNP_DB.debuffs ~= false) and true or false end
  if BNP_DB.separateCCRow == nil then BNP_DB.separateCCRow = self.defaults.separateCCRow end
  if BNP_DB.showOtherCCs == nil then BNP_DB.showOtherCCs = self.defaults.showOtherCCs end
  if BNP_DB.castbarHeight == nil then BNP_DB.castbarHeight = self.defaults.castbarHeight end
  if BNP_DB.castbarSpacing == nil then BNP_DB.castbarSpacing = self.defaults.castbarSpacing end
  if BNP_DB.minimapAngle == nil then BNP_DB.minimapAngle = self.defaults.minimapAngle end
  if BNP_DB.healthPercent == nil then BNP_DB.healthPercent = self.defaults.healthPercent end
  if BNP_DB.healthText == nil then
    -- Backwards-compatible migration from the old Health % checkbox.
    BNP_DB.healthText = BNP_DB.healthPercent and "percent" or self.defaults.healthText
  end
  if BNP_DB.targetFocus == nil then BNP_DB.targetFocus = self.defaults.targetFocus end
  if BNP_DB.targetGlowColor == nil then BNP_DB.targetGlowColor = self.defaults.targetGlowColor end
  if BNP_DB.comboPoints == nil then BNP_DB.comboPoints = self.defaults.comboPoints end
  if BNP_DB.totemIndicators == nil then BNP_DB.totemIndicators = self.defaults.totemIndicators end
  if BNP_DB.totemIconSize == nil then BNP_DB.totemIconSize = self.defaults.totemIconSize end
end

function BNP:GetNameplateScale()
  return (BNP_DB and tonumber(BNP_DB.nameplateScale)) or self.defaults.nameplateScale
end

function BNP:GetNameplateYOffset()
  local value = (BNP_DB and tonumber(BNP_DB.nameplateYOffset)) or self.defaults.nameplateYOffset or 0
  if value < 0 then value = 0 end
  if value > 50 then value = 50 end
  return value
end

function BNP:GetNonTargetAlpha()
  local value = (BNP_DB and tonumber(BNP_DB.nonTargetAlpha)) or self.defaults.nonTargetAlpha or 1.0
  if value < 0.30 then value = 0.30 end
  if value > 1.00 then value = 1.00 end
  return value
end

function BNP:GetIconSize()
  return (BNP_DB and tonumber(BNP_DB.iconSize)) or self.defaults.iconSize
end

function BNP:GetCCIconSize()
  local value = (BNP_DB and tonumber(BNP_DB.ccIconSize)) or self.defaults.ccIconSize or self:GetIconSize()
  if value < 12 then value = 12 end
  if value > 32 then value = 32 end
  return value
end

function BNP:GetDebuffPosition()
  local position = (BNP_DB and BNP_DB.debuffPosition) or self.defaults.debuffPosition or "top"
  if position ~= "top" and position ~= "left" and position ~= "right" then
    position = "top"
  end
  return position
end

function BNP:IsTankModeEnabled()
  return BNP_DB and BNP_DB.tankMode and true or false
end

function BNP:AreClassColorsEnabled()
  return not BNP_DB or BNP_DB.classColors ~= false
end

function BNP:AreCastbarsEnabled()
  return not BNP_DB or BNP_DB.castbars ~= false
end

function BNP:GetCastbarHeight()
  local value = (BNP_DB and tonumber(BNP_DB.castbarHeight)) or self.defaults.castbarHeight
  if value < 4 then value = 4 end
  if value > 14 then value = 14 end
  return value
end

function BNP:GetCastbarSpacing()
  local value = (BNP_DB and tonumber(BNP_DB.castbarSpacing)) or self.defaults.castbarSpacing or 4
  if value < 0 then value = 0 end
  if value > 10 then value = 10 end
  return value
end

function BNP:GetHealthTextMode()
  local mode = (BNP_DB and BNP_DB.healthText) or self.defaults.healthText or "off"
  if mode ~= "off" and mode ~= "percent" and mode ~= "hp" and mode ~= "both" then
    mode = "off"
  end
  return mode
end

function BNP:IsHealthPercentEnabled()
  local mode = self:GetHealthTextMode()
  return mode == "percent" or mode == "both"
end

function BNP:IsHealthTextEnabled()
  return self:GetHealthTextMode() ~= "off"
end

function BNP:IsTargetFocusEnabled()
  return not BNP_DB or BNP_DB.targetFocus ~= false
end

function BNP:GetTargetGlowColor()
  local key = (BNP_DB and BNP_DB.targetGlowColor) or self.defaults.targetGlowColor or "white"

  local colors = {
    white  = { 1.00, 1.00, 1.00 },
    gold   = { 1.00, 0.82, 0.10 },
    blue   = { 0.25, 0.55, 1.00 },
    green  = { 0.25, 1.00, 0.35 },
    red    = { 1.00, 0.20, 0.20 },
    purple = { 0.75, 0.35, 1.00 },
  }

  local c = colors[key] or colors.white
  return c[1], c[2], c[3], key
end

function BNP:AreComboPointsEnabled()
  return not BNP_DB or BNP_DB.comboPoints ~= false
end

function BNP:AreTotemIndicatorsEnabled()
  return not BNP_DB or BNP_DB.totemIndicators ~= false
end

function BNP:GetTotemIconSize()
  local value = (BNP_DB and tonumber(BNP_DB.totemIconSize)) or self.defaults.totemIconSize or 24
  if value < 16 then value = 16 end
  if value > 36 then value = 36 end
  return value
end


function BNP:AreDebuffsEnabled()
  return not BNP_DB or BNP_DB.debuffs ~= false
end

function BNP:AreCrowdControlEnabled()
  return not BNP_DB or BNP_DB.crowdControl ~= false
end

function BNP:AreAnyAurasEnabled()
  return self:AreDebuffsEnabled() or self:AreCrowdControlEnabled()
end

function BNP:IsSeparateCCRowEnabled()
  return not BNP_DB or BNP_DB.separateCCRow ~= false
end

function BNP:ShowOtherPlayersCCs()
  return not BNP_DB or BNP_DB.showOtherCCs ~= false
end
