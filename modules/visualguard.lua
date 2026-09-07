BNP = BNP or {}

-- Safe one-shot native visual repair ---------------------------------------
-- Some UI/skin addons can alter the native Blizzard nameplate border or
-- border before BNP discovers the plate. Repair the native border only
-- when a plate is initialized/shown. There is intentionally NO heartbeat and
-- no layout/parent/anchor enforcement here, so BNP never fights WorldFrame
-- movement while the player/camera is moving.

local BORDER_TEXTURE = "Interface\\Tooltips\\Nameplate-Border"
local HEALTH_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

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

function BNP:RepairNativeNameplateVisuals(plate)
  if not plate then return end
  if IsTotemIconOnly(plate) then return end

  RestoreBorder(plate)
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    BNP:RepairNativeNameplateVisuals(plate or this)
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    BNP:RepairNativeNameplateVisuals(plate or this)
  end)
end
