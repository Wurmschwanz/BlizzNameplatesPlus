BNP = BNP or {}

local function CaptureDefaultNameFontSize(plate)
  if BNP.defaultNameFontSize then return end
  if not plate or not plate.name or not plate.name.GetFont then return end

  local _, size = plate.name:GetFont()
  if size then BNP.defaultNameFontSize = size end
end

-- Vanilla's native name FontString can be recolored directly by the client
-- (for example when threat/aggro changes). Lua method wrappers are not enough
-- to stop those internal updates. When Custom Name Color is enabled, BNP draws
-- its own FontString directly above the native name instead. The Blizzard text
-- may still change color underneath, but the visible BNP copy stays stable.
local function EnsureCustomNameOverlay(plate)
  if not plate or not plate.name then return nil end
  if plate.BNPCustomNameOverlay then return plate.BNPCustomNameOverlay end
  if not plate.CreateFontString then return nil end

  local parent = plate.name.GetParent and plate.name:GetParent() or plate
  local overlay = parent:CreateFontString(nil, "OVERLAY")
  if not overlay then return nil end

  overlay:ClearAllPoints()
  overlay:SetPoint("CENTER", plate.name, "CENTER", 0, 0)
  overlay:Hide()

  plate.BNPCustomNameOverlay = overlay
  return overlay
end

-- The custom name uses a separate FontString so Blizzard cannot recolor it.
-- A newly-created FontString does not automatically inherit the native
-- nameplate text shadow, so mirror that presentation here as well.
local function SyncCustomNameShadow(source, target)
  if not source or not target then return end

  local shadowCopied = false
  if source.GetShadowColor and target.SetShadowColor then
    local r, g, b, a = source:GetShadowColor()
    if r ~= nil and g ~= nil and b ~= nil then
      target:SetShadowColor(r, g, b, a or 1)
      shadowCopied = true
    end
  end

  -- Vanilla/older clients or replacement FontStrings may not expose the
  -- shadow getters. Keep the classic Blizzard-style drop shadow in that case.
  if not shadowCopied and target.SetShadowColor then
    target:SetShadowColor(0, 0, 0, 1)
  end

  local offsetCopied = false
  if source.GetShadowOffset and target.SetShadowOffset then
    local x, y = source:GetShadowOffset()
    if x ~= nil and y ~= nil then
      target:SetShadowOffset(x, y)
      offsetCopied = true
    end
  end

  if not offsetCopied and target.SetShadowOffset then
    target:SetShadowOffset(1, -1)
  end
end

local function SyncCustomNameOverlay(plate)
  if not plate or not plate.name then return end

  local enabled
  if BNP.IsCustomNameColorEnabled then
    enabled = BNP:IsCustomNameColorEnabled()
  else
    enabled = BNP_DB and BNP_DB.customNameColor == true
  end

  local overlay = plate.BNPCustomNameOverlay
  if not enabled then
    if overlay then overlay:Hide() end
    if plate.BNPNameHiddenByCustomColor then
      plate.BNPNameHiddenByCustomColor = nil
      if not plate.BNPNameHidden and plate.name.Show then
        plate.name:Show()
      end
    end
    plate.BNPCustomNameColorApplied = nil
    return
  end

  overlay = EnsureCustomNameOverlay(plate)
  if not overlay then return end

  -- Mirror only presentation data that belongs to the native name. Keeping the
  -- copy anchored to plate.name means Name Y Offset and nameplate scaling keep
  -- working automatically without a second positioning system.
  if plate.name.GetFont and overlay.SetFont then
    local font, size, flags = plate.name:GetFont()
    if font and size then overlay:SetFont(font, size, flags) end
  end

  SyncCustomNameShadow(plate.name, overlay)

  if plate.name.GetText and overlay.SetText then
    overlay:SetText(plate.name:GetText() or "")
  end

  local r, g, b = 1, 1, 1
  if BNP.GetNameColor then r, g, b = BNP:GetNameColor() end
  overlay:SetTextColor(r, g, b, 1)

  if plate.BNPNameHidden then
    overlay:Hide()
    if plate.name.Hide then plate.name:Hide() end
  else
    overlay:Show()
    -- Hide Blizzard's native name while the custom copy is active. This is
    -- the important part: the client is free to recolor the hidden native
    -- FontString internally, but there is no red frame left underneath that
    -- can flash through between Lua updates.
    if plate.name.Hide then plate.name:Hide() end
    plate.BNPNameHiddenByCustomColor = true
  end

  plate.BNPCustomNameColorApplied = true
end

local function ApplyNameColor(plate)
  SyncCustomNameOverlay(plate)
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
      ApplyNameColor(plate)
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

  -- Keep player-controlled pets separate from the NPC/Mob name filter. A pet
  -- plate should not suddenly lose its name just because "Hide NPC/Mob Names"
  -- is enabled.
  if UnitPlayerControlled and UnitPlayerControlled(token) then
    return "pet"
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
  SyncCustomNameOverlay(plate)
end

local function UpdatePlateName(plate, resetIdentity)
  if not plate or not plate.name then return end

  ApplyNameFont(plate)
  ApplyNameColor(plate)
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
      if plate.BNPCustomNameOverlay then plate.BNPCustomNameOverlay:Hide() end
    elseif plate.name.IsShown and plate.name:IsShown() then
      -- The client may re-show Blizzard regions while updating/recycling a
      -- plate. Re-enforce only names BNP explicitly owns as hidden.
      plate.name:Hide()
      if plate.BNPCustomNameOverlay then plate.BNPCustomNameOverlay:Hide() end
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
    local customColorEnabled = BNP_DB and BNP_DB.customNameColor == true
    if not anyHideEnabled and not customColorEnabled and not current.BNPNameHidden and not current.BNPCustomNameColorApplied then return end

    UpdatePlateName(current, false)
  end)
end
