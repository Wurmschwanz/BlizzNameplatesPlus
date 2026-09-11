BNP = BNP or {}

local function CaptureDefaultNameFontSize(plate)
  if BNP.defaultNameFontSize then return end
  if not plate or not plate.name or not plate.name.GetFont then return end

  local _, size = plate.name:GetFont()
  if size then BNP.defaultNameFontSize = size end
end

local function ApplyNameFont(plate)
  if not plate or not plate.name or not plate.name.GetFont or not plate.name.SetFont then return end
  CaptureDefaultNameFontSize(plate)

  -- Nil means the user has never touched the new size control. Keep the
  -- exact current Blizzard/skin-addon font size for backwards compatibility.
  local configured = BNP_DB and tonumber(BNP_DB.nameFontSize)
  if not configured then return end

  local font, currentSize, flags = plate.name:GetFont()
  if not font then return end

  local size = BNP.GetNameFontSize and BNP:GetNameFontSize() or configured
  if currentSize ~= size then
    -- Keep the font face and flags exactly as they currently are. Only the
    -- point size belongs to BNP, so DarkMode/font addons remain compatible.
    plate.name:SetFont(font, size, flags)
  end
end

function BNP:RefreshNameAppearance()
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate then
      ApplyNameFont(plate)
      if BNP.ApplyNameFontYOffset then BNP:ApplyNameFontYOffset(plate) end
    end
  end
end

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

  -- This helper is queried by the aura renderer at 20 Hz. In the default state
  -- (both hide-name options off) return immediately without resolving a unit
  -- token for every visible plate.
  if not BNP_DB or (not BNP_DB.hidePlayerNames and not BNP_DB.hideNPCNames) then
    return false
  end

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

  ApplyNameFont(plate)
  if BNP.ApplyNameFontYOffset then BNP:ApplyNameFontYOffset(plate) end

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

    -- Both hide options are disabled by default. In that common case avoid
    -- UnitExists/UnitIsPlayer work for every visible plate on every 0.10s pass.
    -- If BNP previously hid this specific name, still run once to restore it.
    local anyHideEnabled = BNP_DB and (BNP_DB.hidePlayerNames or BNP_DB.hideNPCNames)
    if not anyHideEnabled and not current.BNPNameHidden then return end

    UpdatePlateName(current, false)
  end)
end
