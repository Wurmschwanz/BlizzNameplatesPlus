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

  if border.IsShown and border.Show and not border:IsShown() then
    border:Show()
  end
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

local function ShaguDarkModeActive()
  return ShaguTweaks and ShaguTweaks.DarkMode and ShaguTweaks.DarkenFrame
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

  if BNP.IsDarkNameplateBorderEnabled and BNP:IsDarkNameplateBorderEnabled() then
    -- Match ShaguTweaks' default Darkened UI color, but touch only the native
    -- nameplate border. Healthbars, glows, castbars and icons stay unchanged.
    SetBorderVertexColor(border, DARK_BORDER_R, DARK_BORDER_G, DARK_BORDER_B, DARK_BORDER_A)
  elseif not ShaguDarkModeActive() then
    -- Do not undo ShaguTweaks when its full Darkened UI module owns the tint.
    SetBorderVertexColor(border, 1, 1, 1, 1)
  end
end

function BNP:RepairNativeNameplateVisuals(plate)
  if not plate then return end
  if IsTotemIconOnly(plate) then return end

  RestoreBorder(plate)
  RestoreGlow(plate)
  ApplyBorderStyle(plate)
end

function BNP:RefreshNameplateBorderStyle()
  local plate
  for plate in pairs(BNP.plates or {}) do
    self:RepairNativeNameplateVisuals(plate)
  end
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    BNP:RepairNativeNameplateVisuals(plate or this)
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    BNP:RepairNativeNameplateVisuals(plate or this)
  end)
end
