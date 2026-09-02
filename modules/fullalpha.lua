BNP = BNP or {}

local NON_TARGET_ALPHA = 0.55
local TARGET_RESOLVE_CACHE_TIME = 0.05
local ALPHA_IDENTITY_HOLD_TIME = 0.20

local targetResolveCacheGUID = nil
local targetResolveCacheAt = -100
local targetResolveCacheFound = false
local classicTargetCacheGUID = nil
local classicTargetCacheAt = -100
local classicTargetCachePlate = nil
local classicTargetCacheAvailable = false

local function GetPlateGUID(plate)
  if not plate or not plate.GetName then return nil end
  local token = plate:GetName(1)
  if not token then return nil end
  local exists, guid = UnitExists(token)
  if exists and guid then return guid end
  return token
end

local function GetVerifiedPlateGUID(plate)
  if not plate or not plate.GetName then return nil end
  local token = plate:GetName(1)
  if not token then return nil end

  -- Alpha must only be lowered after SuperWoW has positively resolved the
  -- projected plate token. While rotating the camera Blizzard can recycle and
  -- re-show a plate before its token is live again. During that short window
  -- treating nil/stale identity as "non-target" caused random low-alpha pops.
  local exists, guid = UnitExists(token)
  if exists and guid then return guid end
  return nil
end

local function GetTargetGUID()
  local exists, guid = UnitExists("target")
  if exists and guid then return guid end
  return nil
end

local function InvalidateTargetResolution()
  targetResolveCacheGUID = nil
  targetResolveCacheAt = -100
  targetResolveCacheFound = false
  classicTargetCacheGUID = nil
  classicTargetCacheAt = -100
  classicTargetCachePlate = nil
  classicTargetCacheAvailable = false
end

local function GetClassicAPITargetPlate(targetGUID)
  local now = GetTime()
  if classicTargetCacheGUID == targetGUID and
     now - classicTargetCacheAt < TARGET_RESOLVE_CACHE_TIME then
    return classicTargetCachePlate, classicTargetCacheAvailable
  end

  local available = C_NamePlate and
                    type(C_NamePlate.GetNamePlateForUnit) == "function"
  local targetPlate = nil

  if available then
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok then targetPlate = plate end
  end

  classicTargetCacheGUID = targetGUID
  classicTargetCacheAt = now
  classicTargetCachePlate = targetPlate
  classicTargetCacheAvailable = available and true or false
  return targetPlate, classicTargetCacheAvailable
end

local function GetPlateToken(plate)
  if not plate or not plate.GetName then return nil end
  return plate:GetName(1)
end

local function GetRegionText(region)
  if not region or not region.GetText then return nil end
  return region:GetText()
end

local function PlateMatchesTargetVisual(plate)
  if not UnitName then return false end

  local targetName = UnitName("target")
  local plateName = GetRegionText(plate and plate.name)
  if not targetName or not plateName or targetName ~= plateName then
    return false
  end

  -- Same-name mobs are common. A known, different level therefore rules the
  -- plate out. If the level is hidden/"??", keeping another same-name plate at
  -- full alpha is the safe failure mode; it is preferable to dimming the real
  -- target because a projected token still carries its previous GUID.
  if UnitLevel then
    local targetLevel = UnitLevel("target")
    local plateLevel = tonumber(GetRegionText(plate and plate.level))
    if targetLevel and targetLevel > 0 and plateLevel and plateLevel > 0 and
       targetLevel ~= plateLevel then
      return false
    end
  end

  return true
end

local function IsPlateCurrentTarget(plate, targetGUID)
  if not plate or not targetGUID then return false end

  local token = GetPlateToken(plate)
  if token and UnitIsUnit then
    local ok, sameUnit = pcall(UnitIsUnit, token, "target")
    if ok and sameUnit then return true end
  end

  local plateGUID = GetVerifiedPlateGUID(plate)
  if plateGUID and plateGUID == targetGUID then return true end

  -- SuperWoW can briefly return the old, but still syntactically valid, GUID
  -- for a recycled projected nameplate. The displayed Blizzard name/level has
  -- already switched by then and protects the actual target from being dimmed.
  return PlateMatchesTargetVisual(plate)
end

local function HasResolvedVisibleTarget(targetGUID)
  local now = GetTime()
  if targetResolveCacheGUID == targetGUID and
     now - targetResolveCacheAt < TARGET_RESOLVE_CACHE_TIME then
    return targetResolveCacheFound
  end

  local found = false
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate.IsShown and plate:IsShown() and
       IsPlateCurrentTarget(plate, targetGUID) then
      found = true
      break
    end
  end

  targetResolveCacheGUID = targetGUID
  targetResolveCacheAt = now
  targetResolveCacheFound = found
  return found
end

local function IsForeignTagged(plate)
  if not plate or not plate.GetName then return false end
  local token = plate:GetName(1)
  if not token then return false end

  local exists = UnitExists(token)
  if not exists then return false end

  if UnitCanAttack and not UnitCanAttack("player", token) then
    return false
  end

  if not UnitIsTapped or not UnitIsTapped(token) then
    return false
  end

  if UnitIsTappedByPlayer and UnitIsTappedByPlayer(token) then
    return false
  end

  return true
end

local function DesiredAlpha(plate)
  -- No selected target: keep all nameplates fully visible.
  local targetGUID = GetTargetGUID()
  if not targetGUID then return 1 end

  local classicTargetPlate, classicTargetAvailable =
    GetClassicAPITargetPlate(targetGUID)

  if classicTargetAvailable then
    -- Exact ClassicAPI frame resolution makes the old transition hold
    -- unnecessary. More importantly, it lets us keep alpha stable even when a
    -- crowded projected nameplate token briefly stops resolving. The previous
    -- code treated an unresolved non-target token as alpha 1 and then faded it
    -- again on the next tick, which made both the plate and its aura children
    -- visibly pulse/flash in large stacked raids.
    if not classicTargetPlate then return 1 end

    -- The exact target frame is authoritative and must always stay opaque,
    -- even while its SuperWoW token is transiently unavailable.
    if plate == classicTargetPlate then return 1 end

    -- GUID equality remains as a conservative fallback in case a client build
    -- returns a wrapper/alias for the target nameplate rather than the exact
    -- frame object tracked by BNP.
    local plateGUID = GetVerifiedPlateGUID(plate)
    if plateGUID and plateGUID == targetGUID then return 1 end

    -- Once ClassicAPI has positively identified the real target frame, every
    -- other visible plate is safely a non-target. Do not bounce it to alpha 1
    -- merely because its projected token was nil for one raid-stack tick.
    if BNP.GetNonTargetAlpha then
      return BNP:GetNonTargetAlpha()
    end
    return 1
  end

  -- On target changes and recycled OnShow transitions, the projected token can
  -- temporarily expose its previous valid GUID. Keep the plate neutral until
  -- Blizzard/SuperWoW have had time to publish the new identity. This is only
  -- the legacy path used when exact ClassicAPI nameplate resolution is absent.
  if plate.BNPAlphaIdentityHoldUntil and
     GetTime() < plate.BNPAlphaIdentityHoldUntil then
    return 1
  end

  -- GUID equality is preferred. UnitIsUnit and the displayed Blizzard
  -- name/level are conservative fallbacks for the stale-valid-GUID window.
  if IsPlateCurrentTarget(plate, targetGUID) then
    return 1
  end

  -- Do not dim anything until the selected target itself can be associated
  -- with a currently visible plate. Uncertainty must fail to full opacity.
  if not HasResolvedVisibleTarget(targetGUID) then
    return 1
  end

  -- A recycled/reappearing plate can exist for a moment before SuperWoW has
  -- attached a trustworthy GUID again. Never dim an unidentified plate; doing
  -- so is what caused the random low-alpha flash when rotating the camera.
  local plateGUID = GetVerifiedPlateGUID(plate)
  if not plateGUID then return 1 end

  -- Current target always stays fully visible.
  if plateGUID == targetGUID then
    return 1
  end

  -- Only positively identified non-target plates use the configured alpha.
  if BNP.GetNonTargetAlpha then
    return BNP:GetNonTargetAlpha()
  end

  return 1
end

local function SetLevelSafe(frame, level)
  if frame and frame.SetFrameLevel and level then
    if frame:GetFrameLevel() ~= level then
      frame:SetFrameLevel(level)
    end
  end
end

local function ApplyTargetFrameLevel(plate)
  if not plate or not plate:IsShown() then return end

  -- IMPORTANT:
  -- Never change the FrameStrata of projected Vanilla nameplates.
  -- Their native client/world layer keeps them behind Blizzard UI frames.
  -- Permanent target priority is therefore implemented only with FrameLevel.

  if plate.BNPBaseFrameLevel == nil then
    plate.BNPBaseFrameLevel = plate:GetFrameLevel() or 0
  end

  local wrapper = plate.BNPScaleWrapper
  if wrapper and plate.BNPBaseWrapperLevel == nil then
    plate.BNPBaseWrapperLevel = wrapper:GetFrameLevel() or plate.BNPBaseFrameLevel
  end

  local healthbar = plate.healthbar
  if healthbar and plate.BNPBaseHealthbarLevel == nil then
    plate.BNPBaseHealthbarLevel = healthbar:GetFrameLevel() or 1
  end

  -- ApplyTargetAlpha runs immediately before this function and publishes the
  -- exact ClassicAPI/SuperWoW target identity on the plate.
  local target = plate.BNPIsCurrentTarget and true or false

  local plateLevel = plate.BNPBaseFrameLevel
  local wrapperLevel = plate.BNPBaseWrapperLevel or plateLevel
  local healthbarLevel = plate.BNPBaseHealthbarLevel or 1

  if target then
    -- Raise the target only relative to other nameplates while preserving the
    -- native projected-nameplate strata beneath the Blizzard interface.
    plateLevel = plateLevel + 50
    wrapperLevel = wrapperLevel + 50
    healthbarLevel = healthbarLevel + 50
  end

  SetLevelSafe(plate, plateLevel)
  if wrapper then
    SetLevelSafe(wrapper, wrapperLevel)
  end
  if healthbar then
    -- The Blizzard border/name are regions of the raised wrapper, but the
    -- actual StatusBar is its own frame and must be raised explicitly.
    SetLevelSafe(healthbar, healthbarLevel)
  end
end

local function ApplyForeignTagVisual(plate)
  if not plate or not plate:IsShown() then return end

  local bar = plate.healthbar
  if not bar or not bar.SetStatusBarColor then return end

  local foreign = IsForeignTagged(plate)

  if foreign then
    if not plate.BNPForeignTagGrey then
      local r, g, b, a = bar:GetStatusBarColor()
      plate.BNPForeignTagOldR = r
      plate.BNPForeignTagOldG = g
      plate.BNPForeignTagOldB = b
      plate.BNPForeignTagOldA = a
      plate.BNPForeignTagGrey = true
    end

    -- Neutral grey: visually distinct from Target Focus transparency.
    bar:SetStatusBarColor(0.45, 0.45, 0.45, plate.BNPForeignTagOldA or 1)
  elseif plate.BNPForeignTagGrey then
    -- Restore the color that BNP/Shagu/class-color logic had before the mob
    -- became foreign-tagged. Clear state so future color changes can be learned.
    bar:SetStatusBarColor(
      plate.BNPForeignTagOldR or 1,
      plate.BNPForeignTagOldG or 0,
      plate.BNPForeignTagOldB or 0,
      plate.BNPForeignTagOldA or 1
    )
    plate.BNPForeignTagGrey = nil
    plate.BNPForeignTagOldR = nil
    plate.BNPForeignTagOldG = nil
    plate.BNPForeignTagOldB = nil
    plate.BNPForeignTagOldA = nil
  end
end

local function GetGlowVisualParent(plate)
  if not plate then return nil end

  local anchor = plate.healthbar or plate
  local visualParent = plate.BNPScaleWrapper

  if not visualParent and anchor and anchor.GetParent then
    visualParent = anchor:GetParent()
  end

  return visualParent or plate
end

local function EnsureTargetGlow(plate)
  if not plate then return nil end
  if plate.BNPTargetGlow then return plate.BNPTargetGlow end

  local anchor = plate.healthbar or plate
  if not anchor then return nil end

  -- Keep Blizzard's original healthbar/frame layering completely untouched.
  -- The glow belongs to the healthbar itself on BACKGROUND, so it stays behind
  -- the statusbar fill without raising/reparenting the Blizzard healthbar.
  --
  -- Direct port of ShaguPlates' target glow geometry:
  --   nameplate.glow = nameplate:CreateTexture(nil, "BACKGROUND")
  --   glow anchored to health CENTER
  --   width  = health width  + 60
  --   height = health height + 30
  --
  -- BNP's only intentional visual change is +3 px on X.
  local glow = anchor:CreateTexture(nil, "BACKGROUND")
  glow:SetTexture("Interface\\AddOns\\BlizzNameplatesPlus\\media\\shagu_target_glow.tga")
  glow:SetPoint("CENTER", anchor, "CENTER", 3, 0)

  local width = anchor.GetWidth and anchor:GetWidth() or 120
  local height = anchor.GetHeight and anchor:GetHeight() or 8
  glow:SetWidth(width + 60)
  glow:SetHeight(height + 30)

  local r, g, b = 1, 1, 1
  if BNP.GetTargetGlowColor then
    r, g, b = BNP:GetTargetGlowColor()
  end
  glow:SetVertexColor(r, g, b, 1)
  glow:Hide()

  plate.BNPTargetGlow = glow
  return glow
end

local function ApplyTargetGlow(plate)
  if not plate or not plate:IsShown() then return end

  local glow = EnsureTargetGlow(plate)
  if not glow then return end

  local enabled = BNP.IsTargetFocusEnabled and BNP:IsTargetFocusEnabled()
  if not enabled then
    glow:Hide()
    return
  end

  local targetGUID = GetTargetGUID()
  local plateGUID = GetPlateGUID(plate)

  if targetGUID and plateGUID and targetGUID == plateGUID then
    local anchor = plate.healthbar or plate
    local width = anchor.GetWidth and anchor:GetWidth() or 120
    local height = anchor.GetHeight and anchor:GetHeight() or 8

  
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", anchor, "CENTER", 3, 0)
    glow:SetWidth(width + 60)
    glow:SetHeight(height + 30)

    if BNP.GetTargetGlowColor then
      local r, g, b = BNP:GetTargetGlowColor()
      glow:SetVertexColor(r, g, b, 1)
    end

    glow:SetAlpha(1)
    glow:Show()
  else
    glow:Hide()
  end
end

local function ApplyTargetAlpha(plate)
  if not plate or not plate:IsShown() then return end
  local totemIconOnly = plate.BNPTotemLastKey and
                        BNP.AreTotemIndicatorsEnabled and BNP:AreTotemIndicatorsEnabled()
  local wanted = totemIconOnly and 1 or DesiredAlpha(plate)
  if plate:GetAlpha() ~= wanted then
    plate:SetAlpha(wanted)
  end

  -- Publish the same resolved target identity for detached aura containers.
  -- They cannot inherit it through their shared WorldFrame parent.
  local targetGUID = GetTargetGUID()
  local targetPlate = nil
  local targetAvailable = false
  local isCurrentTarget = false
  if targetGUID then
    targetPlate, targetAvailable = GetClassicAPITargetPlate(targetGUID)
    if targetAvailable and targetPlate then
      isCurrentTarget = plate == targetPlate
      if not isCurrentTarget then
        local plateGUID = GetVerifiedPlateGUID(plate)
        isCurrentTarget = plateGUID and plateGUID == targetGUID
      end
    else
      isCurrentTarget = IsPlateCurrentTarget(plate, targetGUID)
    end
  end
  plate.BNPIsCurrentTarget = isCurrentTarget and true or false

  -- ClassicAPI returns the underlying target nameplate frame itself. Force it
  -- opaque after every alpha application. Even if SuperWoW momentarily reports
  -- the recycled frame's previous valid GUID, both writes happen in the same
  -- Lua update and the real target finishes the frame at alpha 1.
  if targetGUID then
    if targetAvailable and targetPlate and targetPlate.GetAlpha and targetPlate.SetAlpha then
      targetPlate.BNPIsCurrentTarget = true
      local ok, alpha = pcall(targetPlate.GetAlpha, targetPlate)
      if not ok or alpha ~= 1 then
        pcall(targetPlate.SetAlpha, targetPlate, 1)
      end
    end
  end
end

local function InstallAlphaGuard(plate)
  plate = plate or this
  if not plate or plate.BNPFullAlphaGuard then return end

  plate.BNPAlphaIdentityHoldUntil = GetTime() + ALPHA_IDENTITY_HOLD_TIME

  local oldOnUpdate = plate:GetScript("OnUpdate")
  plate:SetScript("OnUpdate", function()
    if oldOnUpdate then oldOnUpdate() end
    local current = this or plate

    -- Apply the optional Y-offset after Blizzard has had a chance to update
    -- the projected nameplate for this frame. This uses the OnUpdate BNP
    -- already needs for alpha/glow/target-level handling.
    if BNP.MaintainNameplateYOffset then
      BNP:MaintainNameplateYOffset(current)
    end

    ApplyTargetAlpha(current)
    ApplyTargetGlow(current)
    ApplyForeignTagVisual(current)
    ApplyTargetFrameLevel(current)
  end)

  plate.BNPFullAlphaGuard = true
  ApplyTargetAlpha(plate)
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    InstallAlphaGuard(plate or this)
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    local current = plate or this
    if not current then return end
    InvalidateTargetResolution()
    current.BNPAlphaIdentityHoldUntil = GetTime() + ALPHA_IDENTITY_HOLD_TIME
    if current.GetAlpha and current.SetAlpha and current:GetAlpha() ~= 1 then
      current:SetAlpha(1)
    end
    InstallAlphaGuard(current)
    ApplyTargetAlpha(current)
    ApplyTargetGlow(current)
    ApplyForeignTagVisual(current)
    ApplyTargetFrameLevel(current)
  end)
end

local targetEvents = CreateFrame("Frame")
targetEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
targetEvents:SetScript("OnEvent", function()
  InvalidateTargetResolution()

  local targetGUID = GetTargetGUID()
  local _, classicTargetAvailable = GetClassicAPITargetPlate(targetGUID)
  local holdUntil = GetTime() + ALPHA_IDENTITY_HOLD_TIME
  local plate
  for plate in pairs(BNP.plates or {}) do
    if classicTargetAvailable then
      plate.BNPAlphaIdentityHoldUntil = nil
      ApplyTargetAlpha(plate)
    else
      plate.BNPAlphaIdentityHoldUntil = holdUntil
      if plate.GetAlpha and plate.SetAlpha and plate:GetAlpha() ~= 1 then
        plate:SetAlpha(1)
      end
    end
    ApplyTargetFrameLevel(plate)
  end

  if BNP.RefreshAuraPriorityAlpha then BNP:RefreshAuraPriorityAlpha() end
end)

function BNP:RefreshTargetFocus()
  InvalidateTargetResolution()
  local plate
  for plate in pairs(self.plates or {}) do
    ApplyTargetAlpha(plate)
    ApplyTargetGlow(plate)
    ApplyForeignTagVisual(plate)
  end
end

function BNP:RefreshNonTargetAlpha()
  InvalidateTargetResolution()
  local plate
  for plate in pairs(self.plates or {}) do
    ApplyTargetAlpha(plate)
  end
end
