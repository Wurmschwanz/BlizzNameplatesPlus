BNP = BNP or {}

-- Safe one-shot native visual repair ---------------------------------------
-- UI texture patches can replace the files behind Blizzard's native
-- Nameplate-Border/Nameplate-Glow paths without changing the texture paths
-- returned by the client. Keep private copies of the original Vanilla assets
-- inside BNP so those patches cannot silently reskin or blank the plates.
--
-- Apply them only when a plate is initialized/shown. There is intentionally NO
-- heartbeat and no layout/parent/anchor enforcement here, so BNP never fights
-- WorldFrame movement while the player/camera is moving.

local BORDER_TEXTURE = "Interface\\AddOns\\BlizzNameplatesPlus\\media\\classic_nameplate_border.tga"
local GLOW_TEXTURE = "Interface\\AddOns\\BlizzNameplatesPlus\\media\\classic_nameplate_glow.tga"
local DARK_BORDER_R, DARK_BORDER_G, DARK_BORDER_B, DARK_BORDER_A = 0.3, 0.3, 0.3, 0.9

local function IsTotemIconOnly(plate)
  return plate and plate.BNPTotemLastKey and
    BNP.AreTotemIndicatorsEnabled and BNP:AreTotemIndicatorsEnabled()
end

local function RestoreBorder(plate)
  local border = plate and plate.border
  if not border then return end

  if border.GetTexture and border.SetTexture and border:GetTexture() ~= BORDER_TEXTURE then
    border:SetTexture(BORDER_TEXTURE)
  end

  local hidden = BNP.IsNameplateBorderHidden and BNP:IsNameplateBorderHidden()
  if hidden then
    if border.IsShown and border.Hide and border:IsShown() then border:Hide() end
    plate.BNPBorderHidden = true
    return
  end

  -- Restore only the visibility state BNP owns. The historical visual guard
  -- also repairs borders hidden by skin patches when the hide option is off.
  if border.IsShown and border.Show and not border:IsShown() then
    border:Show()
  end
  plate.BNPBorderHidden = nil
end

local function RestoreGlow(plate)
  local glow = plate and plate.glow
  if not glow then return end

  -- Do not show the region here. Blizzard/BNP still controls its visibility
  -- through the normal mouseover path; only its source art is protected.
  if glow.GetTexture and glow.SetTexture and glow:GetTexture() ~= GLOW_TEXTURE then
    glow:SetTexture(GLOW_TEXTURE)
  end
end

local function SetBorderVertexColor(border, r, g, b, a)
  if not border or not border.SetVertexColor then return end

  if border.GetVertexColor then
    local oldR, oldG, oldB, oldA = border:GetVertexColor()
    if math.abs((oldR or 1) - r) < 0.001
      and math.abs((oldG or 1) - g) < 0.001
      and math.abs((oldB or 1) - b) < 0.001
      and math.abs((oldA or 1) - a) < 0.001 then
      return
    end
  end

  border:SetVertexColor(r, g, b, a)
end

local function ApplyBorderStyle(plate)
  local border = plate and plate.border
  if not border then return end
  if BNP.IsNameplateBorderHidden and BNP:IsNameplateBorderHidden() then return end

  if BNP.IsDarkNameplateBorderEnabled and BNP:IsDarkNameplateBorderEnabled() then
    -- Match ShaguTweaks' default Darkened UI color, but touch only the native
    -- nameplate border. Healthbars, glows, castbars and icons stay unchanged.
    SetBorderVertexColor(border, DARK_BORDER_R, DARK_BORDER_G, DARK_BORDER_B, DARK_BORDER_A)
  else
    -- This option is authoritative for the nameplate border. In particular,
    -- switching it off must restore the original gold even when ShaguTweaks'
    -- global Darkened UI mode previously tinted this texture.
    SetBorderVertexColor(border, 1, 1, 1, 1)
  end
end

-- Public one-plate restore used by target-only border coloring. This keeps the
-- normal gold / Dark Nameplate Border behavior in one authoritative place.
function BNP:ApplyBaseNameplateBorderStyle(plate)
  if not plate then return end
  RestoreBorder(plate)
  ApplyBorderStyle(plate)
end

local function ApplyLevelVisibility(plate)
  local level = plate and plate.level
  if not level then return end

  local hidden = BNP.IsNameplateLevelHidden and BNP:IsNameplateLevelHidden()
  if hidden then
    if level.IsShown and level.Hide and level:IsShown() then level:Hide() end
    plate.BNPLevelHidden = true
    return
  end

  if plate.BNPLevelHidden then
    if level.Show then level:Show() end
    plate.BNPLevelHidden = nil
  end
end

local function ApplyOptionalNativeVisibility(plate)
  if not plate or IsTotemIconOnly(plate) then return end
  RestoreBorder(plate)
  ApplyLevelVisibility(plate)
end

local function ApplyHealthbarBackground(plate)
  local healthbar = plate and plate.healthbar
  if not healthbar then return end

  local enabled = BNP.IsBlackHealthbarBackgroundEnabled and
                  BNP:IsBlackHealthbarBackgroundEnabled()
  local background = plate.BNPHealthbarBackground

  -- Keep the default path allocation-free. The extra texture is created only
  -- after the user enables the option, then reused whenever this plate is
  -- recycled for another unit.
  if not enabled then
    if background and background.IsShown and background:IsShown() then
      background:Hide()
    end
    return
  end

  if not background then
    -- BORDER sits above BNP's target glow (BACKGROUND) but below the StatusBar
    -- fill, so the unfilled portion stays truly black even on the target.
    background = healthbar:CreateTexture(nil, "BORDER")
    background:SetTexture(0, 0, 0, 1)
    background:SetAllPoints(healthbar)
    plate.BNPHealthbarBackground = background
  end

  if background.GetParent and background:GetParent() ~= healthbar then
    background:SetParent(healthbar)
    background:ClearAllPoints()
    background:SetAllPoints(healthbar)
  end
  if background.IsShown and not background:IsShown() then background:Show() end
end

function BNP:RepairNativeNameplateVisuals(plate)
  if not plate then return end
  if IsTotemIconOnly(plate) then return end

  RestoreBorder(plate)
  RestoreGlow(plate)
  ApplyBorderStyle(plate)
  ApplyLevelVisibility(plate)
  ApplyHealthbarBackground(plate)
end

function BNP:RefreshNameplateBorderStyle()
  local plate
  for plate in pairs(BNP.plates or {}) do
    self:RepairNativeNameplateVisuals(plate)
  end

  -- The custom Elite / World Boss dragon is visually part of BNP's border.
  -- Keep it in sync immediately when Hide Border is toggled.
  if self.RefreshEliteDragonVisibility then
    self:RefreshEliteDragonVisibility()
  end
  if self.RefreshPersonalNameplateStyle then self:RefreshPersonalNameplateStyle() end
end

function BNP:RefreshNameplateLevelVisibility()
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate then
      ApplyLevelVisibility(plate)
      if BNP.RefreshAuraLayoutForPlate then BNP:RefreshAuraLayoutForPlate(plate) end
      if BNP.RefreshImmunityLayoutForPlate then BNP:RefreshImmunityLayoutForPlate(plate) end
    end
  end
  if self.RefreshPersonalNameplateStyle then self:RefreshPersonalNameplateStyle() end
end

function BNP:RefreshHealthbarBackground()
  local plate
  for plate in pairs(BNP.plates or {}) do
    ApplyHealthbarBackground(plate)
  end
  if self.RefreshPersonalNameplateStyle then self:RefreshPersonalNameplateStyle() end
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    BNP:RepairNativeNameplateVisuals(plate or this)
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    BNP:RepairNativeNameplateVisuals(plate or this)
  end)

  -- libnameplate already runs this list at 10 Hz. The default path returns
  -- immediately; only enabled hide options need to enforce native visibility
  -- against Blizzard recycling/show calls.
  table.insert(BNP.libnameplate.OnUpdate, function(plate)
    local current = plate or this
    if not current or not current.IsShown or not current:IsShown() then return end

    local hideBorder = BNP_DB and BNP_DB.hideNameplateBorder
    local hideLevel = BNP_DB and BNP_DB.hideNameplateLevel
    if not hideBorder and not hideLevel and not current.BNPBorderHidden and not current.BNPLevelHidden then
      return
    end

    ApplyOptionalNativeVisibility(current)
  end)
end
