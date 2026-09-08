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

function BNP:RepairNativeNameplateVisuals(plate)
  if not plate then return end
  if IsTotemIconOnly(plate) then return end

  RestoreBorder(plate)
  RestoreGlow(plate)
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    BNP:RepairNativeNameplateVisuals(plate or this)
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    BNP:RepairNativeNameplateVisuals(plate or this)
  end)
end
