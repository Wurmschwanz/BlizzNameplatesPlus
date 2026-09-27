BNP = BNP or {}

BNP.defaults = BNP.defaults or {
  nameplateScale = 1.0,
  nameplateYOffset = 0,
  comboPointsYOffset = 0,
  nameFontSize = 12,
  nameFontYOffset = 0,
  nonTargetAlpha = 1.0,
  iconSize = 18,
  auraFontSize = 8,
  cooldownSpiral = false,
  ccIconSize = 18,
  debuffYOffset = 0,
  ccYOffset = 0,
  debuffPosition = "top",
  ccPosition = "top",
  tankMode = false,
  invertTankColors = false,
  invertTankAggroColor = { r = 1.00, g = 0.00, b = 0.00 },
  invertTankNoAggroColor = { r = 0.00, g = 1.00, b = 0.00 },
  classColors = true,
  darkNameplateBorder = false,
  hideNameplateBorder = false,
  hideNameplateLevel = false,
  blackHealthbarBackground = false,
  darkComboPointBorder = false,
  hidePlayerNames = false,
  hideNPCNames = false,
  castbars = true,
  castbarIcon = true,
  debuffs = true,
  crowdControl = true,
  separateCCRow = true,
  showOtherCCs = true,
  pvpImmunities = true,
  immunityIconSize = 18,
  immunityPosition = "top",
  immunityYOffset = 0,
  castbarHeight = 6,
  castbarFontSize = 10,
  castbarStyle = "modern",
  castbarXOffset = 0,
  castbarYOffset = 0,
  minimapAngle = 225,
  healthPercent = false,
  healthText = "off",
  healthTextFontSize = 9,
  healthTextOutline = "outline",
  targetFocus = true,
  targetGlowColor = "white", -- legacy migration key
  targetColor = { r = 1.00, g = 1.00, b = 1.00 },
  targetGlowSize = 0,
  targetGlowOpacity = 1.0,
  targetArrows = false,
  -- Legacy Arrow color keys are retained only for SavedVariables migration.
  targetArrowColor = "match",
  targetArrowCustomColor = { r = 1.00, g = 1.00, b = 1.00 },
  targetArrowSize = 14,
  targetArrowThick = false,
  targetArrowStyle = "chevron",
  comboPoints = true,
  totemIndicators = true,
  totemIconSize = 24,
}

function BNP:InitConfig()
  BNP_DB = BNP_DB or {}

  if BNP_DB.nameplateScale == nil then BNP_DB.nameplateScale = self.defaults.nameplateScale end
  if BNP_DB.nameplateYOffset == nil then BNP_DB.nameplateYOffset = self.defaults.nameplateYOffset end
  if BNP_DB.comboPointsYOffset == nil then BNP_DB.comboPointsYOffset = self.defaults.comboPointsYOffset end
  -- nameFontSize intentionally stays nil until the user moves the slider.
  -- This preserves the exact font size provided by Blizzard/skin addons on update.
  if BNP_DB.nameFontYOffset == nil then BNP_DB.nameFontYOffset = self.defaults.nameFontYOffset end
  if BNP_DB.nonTargetAlpha == nil then BNP_DB.nonTargetAlpha = self.defaults.nonTargetAlpha end
  if BNP_DB.iconSize == nil then BNP_DB.iconSize = self.defaults.iconSize end
  if BNP_DB.auraFontSize == nil then BNP_DB.auraFontSize = self.defaults.auraFontSize end
  if BNP_DB.cooldownSpiral == nil then BNP_DB.cooldownSpiral = self.defaults.cooldownSpiral end
  if BNP_DB.ccIconSize == nil then BNP_DB.ccIconSize = BNP_DB.iconSize or self.defaults.ccIconSize end
  if BNP_DB.debuffYOffset == nil then BNP_DB.debuffYOffset = self.defaults.debuffYOffset end
  if BNP_DB.ccYOffset == nil then BNP_DB.ccYOffset = self.defaults.ccYOffset end
  if BNP_DB.debuffPosition == nil then BNP_DB.debuffPosition = self.defaults.debuffPosition end
  if BNP_DB.ccPosition == nil then BNP_DB.ccPosition = BNP_DB.debuffPosition or self.defaults.ccPosition end
  if BNP_DB.tankMode == nil then BNP_DB.tankMode = self.defaults.tankMode end
  if BNP_DB.invertTankColors == nil then BNP_DB.invertTankColors = self.defaults.invertTankColors end

  local function InitTankColor(key, fallback)
    local color = BNP_DB[key]
    if type(color) ~= "table" then
      color = {}
      BNP_DB[key] = color
    end
    if color.r == nil then color.r = fallback.r end
    if color.g == nil then color.g = fallback.g end
    if color.b == nil then color.b = fallback.b end
  end
  InitTankColor("invertTankAggroColor", self.defaults.invertTankAggroColor)
  InitTankColor("invertTankNoAggroColor", self.defaults.invertTankNoAggroColor)

  if BNP_DB.classColors == nil then BNP_DB.classColors = self.defaults.classColors end
  if BNP_DB.darkNameplateBorder == nil then BNP_DB.darkNameplateBorder = self.defaults.darkNameplateBorder end
  if BNP_DB.hideNameplateBorder == nil then BNP_DB.hideNameplateBorder = self.defaults.hideNameplateBorder end
  if BNP_DB.hideNameplateLevel == nil then BNP_DB.hideNameplateLevel = self.defaults.hideNameplateLevel end
  if BNP_DB.blackHealthbarBackground == nil then BNP_DB.blackHealthbarBackground = self.defaults.blackHealthbarBackground end
  if BNP_DB.darkComboPointBorder == nil then BNP_DB.darkComboPointBorder = self.defaults.darkComboPointBorder end
  if BNP_DB.hidePlayerNames == nil then BNP_DB.hidePlayerNames = self.defaults.hidePlayerNames end
  if BNP_DB.hideNPCNames == nil then BNP_DB.hideNPCNames = self.defaults.hideNPCNames end
  if BNP_DB.castbars == nil then BNP_DB.castbars = self.defaults.castbars end
  if BNP_DB.castbarIcon == nil then BNP_DB.castbarIcon = self.defaults.castbarIcon end
  -- Retired: castbar spark/end glow is now always enabled.
  BNP_DB.castbarEndGlow = nil
  if BNP_DB.debuffs == nil then BNP_DB.debuffs = self.defaults.debuffs end
  if BNP_DB.crowdControl == nil then BNP_DB.crowdControl = (BNP_DB.debuffs ~= false) and true or false end
  if BNP_DB.separateCCRow == nil then BNP_DB.separateCCRow = self.defaults.separateCCRow end
  if BNP_DB.showOtherCCs == nil then BNP_DB.showOtherCCs = self.defaults.showOtherCCs end
  if BNP_DB.pvpImmunities == nil then BNP_DB.pvpImmunities = self.defaults.pvpImmunities end
  if BNP_DB.immunityIconSize == nil then BNP_DB.immunityIconSize = BNP_DB.iconSize or self.defaults.immunityIconSize end
  if BNP_DB.immunityPosition == nil then BNP_DB.immunityPosition = self.defaults.immunityPosition end
  if BNP_DB.immunityYOffset == nil then BNP_DB.immunityYOffset = self.defaults.immunityYOffset end
  -- Position migration from the temporary all-Bottom test build.
  if BNP_DB.debuffPosition == "bottom" then BNP_DB.debuffPosition = "bottom_mid" end
  if BNP_DB.ccPosition == "bottom" then BNP_DB.ccPosition = "top" end
  if BNP_DB.immunityPosition == "bottom" then BNP_DB.immunityPosition = "top" end
  if BNP_DB.castbarHeight == nil then BNP_DB.castbarHeight = self.defaults.castbarHeight end
  -- Retired: Castbar Y Offset now owns vertical placement by itself.
  BNP_DB.castbarSpacing = nil
  if BNP_DB.castbarFontSize == nil then BNP_DB.castbarFontSize = self.defaults.castbarFontSize end
  if BNP_DB.castbarStyle == nil then BNP_DB.castbarStyle = self.defaults.castbarStyle end
  if BNP_DB.castbarXOffset == nil then BNP_DB.castbarXOffset = self.defaults.castbarXOffset end
  if BNP_DB.castbarYOffset == nil then BNP_DB.castbarYOffset = self.defaults.castbarYOffset end
  if BNP_DB.minimapAngle == nil then BNP_DB.minimapAngle = self.defaults.minimapAngle end
  if BNP_DB.healthPercent == nil then BNP_DB.healthPercent = self.defaults.healthPercent end
  if BNP_DB.healthText == nil then
    -- Backwards-compatible migration from the old Health % checkbox.
    BNP_DB.healthText = BNP_DB.healthPercent and "percent" or self.defaults.healthText
  end
  if BNP_DB.healthTextFontSize == nil then BNP_DB.healthTextFontSize = self.defaults.healthTextFontSize end
  if BNP_DB.healthTextOutline == nil then BNP_DB.healthTextOutline = self.defaults.healthTextOutline end
  if BNP_DB.targetFocus == nil then BNP_DB.targetFocus = self.defaults.targetFocus end
  if BNP_DB.targetGlowColor == nil then BNP_DB.targetGlowColor = self.defaults.targetGlowColor end
  if BNP_DB.targetGlowSize == nil then BNP_DB.targetGlowSize = self.defaults.targetGlowSize end
  if BNP_DB.targetGlowOpacity == nil then BNP_DB.targetGlowOpacity = self.defaults.targetGlowOpacity end
  if BNP_DB.targetArrows == nil then BNP_DB.targetArrows = self.defaults.targetArrows end
  if BNP_DB.targetArrowColor == nil then BNP_DB.targetArrowColor = self.defaults.targetArrowColor end

  -- One shared RGB color now drives BOTH Target Glow and Target Arrows.
  -- Migration prefers the user's current custom Arrow color (the newest color
  -- system). If that does not exist, fall back to the former Glow dropdown.
  if type(BNP_DB.targetColor) ~= "table" then
    local migrated
    if type(BNP_DB.targetArrowCustomColor) == "table" then
      migrated = {
        r = BNP_DB.targetArrowCustomColor.r,
        g = BNP_DB.targetArrowCustomColor.g,
        b = BNP_DB.targetArrowCustomColor.b,
      }
    end
    if not migrated or migrated.r == nil or migrated.g == nil or migrated.b == nil then
      local legacyColors = {
        white  = { r = 1.00, g = 1.00, b = 1.00 },
        gold   = { r = 1.00, g = 0.82, b = 0.10 },
        blue   = { r = 0.25, g = 0.55, b = 1.00 },
        green  = { r = 0.25, g = 1.00, b = 0.35 },
        red    = { r = 1.00, g = 0.20, b = 0.20 },
        purple = { r = 0.75, g = 0.35, b = 1.00 },
        black  = { r = 0.00, g = 0.00, b = 0.00 },
      }
      migrated = legacyColors[BNP_DB.targetGlowColor or self.defaults.targetGlowColor or "white"] or legacyColors.white
    end
    BNP_DB.targetColor = { r = migrated.r, g = migrated.g, b = migrated.b }
  else
    local fallback = self.defaults.targetColor or { r = 1, g = 1, b = 1 }
    if BNP_DB.targetColor.r == nil then BNP_DB.targetColor.r = fallback.r end
    if BNP_DB.targetColor.g == nil then BNP_DB.targetColor.g = fallback.g end
    if BNP_DB.targetColor.b == nil then BNP_DB.targetColor.b = fallback.b end
  end

  if BNP_DB.targetArrowSize == nil then BNP_DB.targetArrowSize = self.defaults.targetArrowSize end
  if BNP_DB.targetArrowThick == nil then BNP_DB.targetArrowThick = self.defaults.targetArrowThick end
  if BNP_DB.targetArrowStyle == nil then BNP_DB.targetArrowStyle = self.defaults.targetArrowStyle end
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


local function ClampVisualYOffset(value)
  value = tonumber(value) or 0
  if value < -50 then value = -50 end
  if value > 50 then value = 50 end
  return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

function BNP:GetComboPointsYOffset()
  return ClampVisualYOffset(BNP_DB and BNP_DB.comboPointsYOffset or self.defaults.comboPointsYOffset)
end

function BNP:GetNameFontSize()
  local explicit = BNP_DB and tonumber(BNP_DB.nameFontSize)
  local value = explicit or tonumber(self.defaultNameFontSize) or self.defaults.nameFontSize or 12
  if value < 8 then value = 8 end
  if value > 24 then value = 24 end
  return math.floor(value + 0.5)
end

function BNP:GetNameFontYOffset()
  return ClampVisualYOffset(BNP_DB and BNP_DB.nameFontYOffset or self.defaults.nameFontYOffset)
end

function BNP:GetDebuffYOffset()
  return ClampVisualYOffset(BNP_DB and BNP_DB.debuffYOffset or self.defaults.debuffYOffset)
end

function BNP:GetCCYOffset()
  return ClampVisualYOffset(BNP_DB and BNP_DB.ccYOffset or self.defaults.ccYOffset)
end

function BNP:GetImmunityYOffset()
  return ClampVisualYOffset(BNP_DB and BNP_DB.immunityYOffset or self.defaults.immunityYOffset)
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

function BNP:GetAuraFontSize()
  local value = (BNP_DB and tonumber(BNP_DB.auraFontSize)) or self.defaults.auraFontSize or 8
  if value < 6 then value = 6 end
  if value > 18 then value = 18 end
  return math.floor(value + 0.5)
end

function BNP:GetCCIconSize()
  local value = (BNP_DB and tonumber(BNP_DB.ccIconSize)) or self.defaults.ccIconSize or self:GetIconSize()
  if value < 12 then value = 12 end
  if value > 32 then value = 32 end
  return value
end

function BNP:GetDebuffPosition()
  local position = (BNP_DB and BNP_DB.debuffPosition) or self.defaults.debuffPosition or "top"
  -- Migrate the first Bottom implementation to the new centered Bottom option.
  if position == "bottom" then position = "bottom_mid" end
  if position ~= "top" and position ~= "top_left" and position ~= "top_right"
    and position ~= "left" and position ~= "right"
    and position ~= "bottom_mid" and position ~= "bottom_left" and position ~= "bottom_right" then
    position = "top"
  end
  return position
end

function BNP:GetCCPosition()
  local position = (BNP_DB and BNP_DB.ccPosition) or self.defaults.ccPosition or "top"
  -- Bottom is intentionally not supported for CCs.
  if position ~= "top" and position ~= "left" and position ~= "right" then
    position = "top"
  end
  return position
end

function BNP:GetImmunityIconSize()
  local value = (BNP_DB and tonumber(BNP_DB.immunityIconSize)) or self.defaults.immunityIconSize or self:GetIconSize()
  if value < 12 then value = 12 end
  if value > 32 then value = 32 end
  return value
end

function BNP:GetImmunityPosition()
  local position = (BNP_DB and BNP_DB.immunityPosition) or self.defaults.immunityPosition or "top"
  -- Bottom is intentionally not supported for immunities.
  if position ~= "top" and position ~= "left" and position ~= "right" then
    position = "top"
  end
  return position
end


function BNP:IsTankModeEnabled()
  return BNP_DB and BNP_DB.tankMode and true or false
end

function BNP:AreTankModeColorsInverted()
  return BNP_DB and BNP_DB.invertTankColors and true or false
end

local function ClampTankColor(value, fallback)
  value = tonumber(value)
  if value == nil then value = fallback or 0 end
  if value < 0 then value = 0 end
  if value > 1 then value = 1 end
  return value
end

function BNP:GetInvertTankAggroColor()
  local fallback = self.defaults.invertTankAggroColor or { r = 1, g = 0, b = 0 }
  local color = BNP_DB and BNP_DB.invertTankAggroColor or fallback
  return ClampTankColor(color and color.r, fallback.r),
         ClampTankColor(color and color.g, fallback.g),
         ClampTankColor(color and color.b, fallback.b)
end

function BNP:GetInvertTankNoAggroColor()
  local fallback = self.defaults.invertTankNoAggroColor or { r = 0, g = 1, b = 0 }
  local color = BNP_DB and BNP_DB.invertTankNoAggroColor or fallback
  return ClampTankColor(color and color.r, fallback.r),
         ClampTankColor(color and color.g, fallback.g),
         ClampTankColor(color and color.b, fallback.b)
end

function BNP:SetInvertTankAggroColor(r, g, b)
  if not BNP_DB then return end
  BNP_DB.invertTankAggroColor = {
    r = ClampTankColor(r, 1),
    g = ClampTankColor(g, 0),
    b = ClampTankColor(b, 0),
  }
  if self.UpdateTankMode then self:UpdateTankMode() end
end

function BNP:SetInvertTankNoAggroColor(r, g, b)
  if not BNP_DB then return end
  BNP_DB.invertTankNoAggroColor = {
    r = ClampTankColor(r, 0),
    g = ClampTankColor(g, 1),
    b = ClampTankColor(b, 0),
  }
  if self.UpdateTankMode then self:UpdateTankMode() end
end

function BNP:AreClassColorsEnabled()
  return not BNP_DB or BNP_DB.classColors ~= false
end

function BNP:IsDarkNameplateBorderEnabled()
  return BNP_DB and BNP_DB.darkNameplateBorder and true or false
end

function BNP:IsNameplateBorderHidden()
  return BNP_DB and BNP_DB.hideNameplateBorder and true or false
end

function BNP:IsNameplateLevelHidden()
  return BNP_DB and BNP_DB.hideNameplateLevel and true or false
end

function BNP:IsBlackHealthbarBackgroundEnabled()
  return BNP_DB and BNP_DB.blackHealthbarBackground and true or false
end

function BNP:HidePlayerNamesEnabled()
  return BNP_DB and BNP_DB.hidePlayerNames and true or false
end

function BNP:HideNPCNamesEnabled()
  return BNP_DB and BNP_DB.hideNPCNames and true or false
end

function BNP:AreCastbarsEnabled()
  return not BNP_DB or BNP_DB.castbars ~= false
end

function BNP:IsCastbarIconEnabled()
  return not BNP_DB or BNP_DB.castbarIcon ~= false
end

function BNP:GetCastbarHeight()
  local value = (BNP_DB and tonumber(BNP_DB.castbarHeight)) or self.defaults.castbarHeight
  local style = (BNP_DB and BNP_DB.castbarStyle) or self.defaults.castbarStyle or "modern"
  local minValue = style == "classic" and 8 or 4
  if value < minValue then value = minValue end
  if value > 20 then value = 20 end
  return value
end

function BNP:GetCastbarFontSize()
  local value = (BNP_DB and tonumber(BNP_DB.castbarFontSize)) or self.defaults.castbarFontSize or 10
  if value < 6 then value = 6 end
  if value > 18 then value = 18 end
  return math.floor(value + 0.5)
end

function BNP:GetCastbarStyle()
  local style = (BNP_DB and BNP_DB.castbarStyle) or self.defaults.castbarStyle or "modern"
  if style ~= "modern" and style ~= "classic" then style = "modern" end
  return style
end

function BNP:GetCastbarXOffset()
  return ClampVisualYOffset(BNP_DB and BNP_DB.castbarXOffset or self.defaults.castbarXOffset)
end

function BNP:GetCastbarYOffset()
  return ClampVisualYOffset(BNP_DB and BNP_DB.castbarYOffset or self.defaults.castbarYOffset)
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

function BNP:GetHealthTextFontSize()
  local value = (BNP_DB and tonumber(BNP_DB.healthTextFontSize)) or self.defaults.healthTextFontSize or 9
  if value < 8 then value = 8 end
  if value > 20 then value = 20 end
  return math.floor(value + 0.5)
end

function BNP:GetHealthTextOutline()
  local value = (BNP_DB and BNP_DB.healthTextOutline) or self.defaults.healthTextOutline or "outline"
  if value ~= "none" and value ~= "outline" and value ~= "thick" then
    value = "outline"
  end
  return value
end

function BNP:IsTargetFocusEnabled()
  return not BNP_DB or BNP_DB.targetFocus ~= false
end

-- Target Glow and Target Arrows intentionally share one freely selectable RGB
-- color. Tank Mode colors are stored separately and never touch this value.
function BNP:GetTargetColor()
  local fallback = self.defaults.targetColor or { r = 1, g = 1, b = 1 }
  local color = BNP_DB and BNP_DB.targetColor or fallback
  return ClampTankColor(color and color.r, fallback.r),
         ClampTankColor(color and color.g, fallback.g),
         ClampTankColor(color and color.b, fallback.b),
         "custom"
end

function BNP:SetTargetColor(r, g, b)
  if not BNP_DB then return end
  BNP_DB.targetColor = {
    r = ClampTankColor(r, 1),
    g = ClampTankColor(g, 1),
    b = ClampTankColor(b, 1),
  }
  if self.RefreshTargetFocus then self:RefreshTargetFocus() end
end

-- Compatibility aliases used by the rendering code. Both return the exact
-- same shared target color.
function BNP:GetTargetGlowColor()
  return self:GetTargetColor()
end

function BNP:GetTargetGlowSize()
  local value = (BNP_DB and tonumber(BNP_DB.targetGlowSize)) or self.defaults.targetGlowSize or 0
  if value < 0 then value = 0 end
  if value > 20 then value = 20 end
  return value
end

function BNP:GetTargetGlowOpacity()
  local value = (BNP_DB and tonumber(BNP_DB.targetGlowOpacity)) or self.defaults.targetGlowOpacity or 1.0
  if value < 0.20 then value = 0.20 end
  if value > 1.00 then value = 1.00 end
  return value
end

function BNP:AreTargetArrowsEnabled()
  return BNP_DB and BNP_DB.targetArrows == true
end

function BNP:GetTargetArrowColor()
  return self:GetTargetColor()
end

function BNP:SetTargetArrowColor(r, g, b)
  self:SetTargetColor(r, g, b)
end

function BNP:GetTargetArrowSize()
  local value = (BNP_DB and tonumber(BNP_DB.targetArrowSize)) or self.defaults.targetArrowSize or 14
  if value < 10 then value = 10 end
  if value > 24 then value = 24 end
  return value
end

function BNP:AreTargetArrowsThick()
  return BNP_DB and BNP_DB.targetArrowThick == true
end

function BNP:GetTargetArrowStyle()
  local style = (BNP_DB and BNP_DB.targetArrowStyle) or self.defaults.targetArrowStyle or "chevron"
  if style ~= "chevron" and style ~= "triangle" and style ~= "slim_triangle"
    and style ~= "double_chevron" and style ~= "diamond_tip" then
    style = "chevron"
  end
  return style
end

function BNP:AreComboPointsEnabled()
  return not BNP_DB or BNP_DB.comboPoints ~= false
end

function BNP:IsDarkComboPointBorderEnabled()
  return BNP_DB and BNP_DB.darkComboPointBorder == true
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

function BNP:IsAuraCooldownSpiralEnabled()
  return BNP_DB and BNP_DB.cooldownSpiral == true
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

function BNP:ArePvPImmunitiesEnabled()
  return not BNP_DB or BNP_DB.pvpImmunities ~= false
end
