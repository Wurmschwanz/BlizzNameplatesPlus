BNP = BNP or {}

-- Independent name visibility controls for Blizzard nameplates.
-- BNP only hides the name FontString; health bars, level text, raid icons,
-- auras, immunities and click behavior remain untouched.

local function ResolvePlateType(plate)
  if not plate or not plate.GetName then return nil end

  local token = plate:GetName(1)
  if not token then return nil end

  local exists = UnitExists(token)
  if not exists then return nil end

  if UnitIsPlayer and UnitIsPlayer(token) then
    return "player"
  end

  return "npc"
end

local function ShouldHide(unitType)
  if unitType == "player" then
    if BNP.HidePlayerNamesEnabled then return BNP:HidePlayerNamesEnabled() end
    return BNP_DB and BNP_DB.hidePlayerNames and true or false
  elseif unitType == "npc" then
    if BNP.HideNPCNamesEnabled then return BNP:HideNPCNamesEnabled() end
    return BNP_DB and BNP_DB.hideNPCNames and true or false
  end
  return false
end

-- Authoritative query used by aura/immunity layout.  Do not rely only on the
-- transient BNPNameHidden marker: on recycled/projected Vanilla nameplates the
-- name FontString and aura module callbacks can update in a different order.
function BNP:IsPlateNameHidden(plate)
  if not plate then return false end

  local unitType = ResolvePlateType(plate) or plate.BNPNameUnitType
  if unitType then
    return ShouldHide(unitType)
  end

  -- If identity is momentarily unresolved, keep the last BNP-owned state so a
  -- recycled plate does not jump vertically for a single scan.
  return plate.BNPNameHidden and true or false
end

local function RefreshPlateAuraLayout(plate)
  if not plate then return end
  if BNP.RefreshAuraLayoutForPlate then BNP:RefreshAuraLayoutForPlate(plate) end
  if BNP.RefreshImmunityLayoutForPlate then BNP:RefreshImmunityLayoutForPlate(plate) end
end

local function RestoreIfBNPHid(plate)
  if not plate or not plate.name then return end
  if plate.BNPNameHidden then
    plate.name:Show()
    plate.BNPNameHidden = nil
  end
end

local function UpdatePlateName(plate, resetIdentity)
  if not plate or not plate.name then return end

  if resetIdentity then
    -- Blizzard reuses nameplate frames. Never carry a hidden name from the
    -- previous unit into a newly shown plate while its projected token is not
    -- resolved yet.
    plate.BNPNameUnitType = nil
    RestoreIfBNPHid(plate)
  end

  local unitType = ResolvePlateType(plate)
  if unitType then
    plate.BNPNameUnitType = unitType
  else
    unitType = plate.BNPNameUnitType
  end

  if not unitType then return end

  if ShouldHide(unitType) then
    if not plate.BNPNameHidden then
      plate.name:Hide()
      plate.BNPNameHidden = true
    elseif plate.name.IsShown and plate.name:IsShown() then
      -- The client may re-show Blizzard regions while updating/recycling a
      -- plate. Re-enforce only names BNP explicitly owns as hidden.
      plate.name:Hide()
    end
  else
    RestoreIfBNPHid(plate)
  end
end

function BNP:RefreshNameVisibility()
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate.IsShown and plate:IsShown() then
      UpdatePlateName(plate, false)
      -- Re-anchor immediately when the option is toggled instead of waiting
      -- for the aura module's next identity/update cycle.
      RefreshPlateAuraLayout(plate)
    elseif plate then
      RestoreIfBNPHid(plate)
      plate.BNPNameUnitType = nil
    end
  end
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    local current = plate or this
    if not current then return end
    UpdatePlateName(current, true)
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    local current = plate or this
    if not current then return end
    UpdatePlateName(current, true)
  end)

  -- libnameplate updates are already throttled to 0.10s. This is deliberate:
  -- if Blizzard re-shows the name FontString, the configured hidden state is
  -- restored without adding a per-frame OnUpdate to every nameplate.
  table.insert(BNP.libnameplate.OnUpdate, function(plate)
    local current = plate or this
    if not current or not current:IsShown() then return end
    UpdatePlateName(current, false)
  end)
end
