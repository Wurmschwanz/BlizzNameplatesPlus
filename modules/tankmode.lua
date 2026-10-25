BNP = BNP or {}

-- Tank Mode for SuperWoW GUID nameplates.
-- Default: GREEN = hostile NPC currently targets the player, RED = another unit.
-- Normal Tank Mode is fixed: GREEN = aggro, RED = no aggro.
-- Invert Tank Colors uses two independently user-selectable colors.
-- Optional third color for in-combat NPCs temporarily unable to attack.
-- The existing two-color behavior is preserved while this option is disabled.

local GREEN_R, GREEN_G, GREEN_B = 0.00, 1.00, 0.00
local RED_R, RED_G, RED_B = 1.00, 0.00, 0.00

-- Only effects that prevent attacking; roots, snares, silence and disarm
-- alone do not qualify. Shared with the existing aura snapshot reader.
BNP.TankDisablingCC = {
  fear=true, howl_of_terror=true, banish=true, death_coil=true,
  freezing_trap_effect=true, scatter_shot=true, wyvern_sting=true,
  intimidation=true, scare_beast=true, improved_concussive_shot=true,
  polymorph=true, impact=true, psychic_scream=true, blackout=true,
  shackle_undead=true, hammer_of_justice=true, repentance=true, turn_undead=true,
  gouge=true, kidney_shot=true, cheap_shot=true, sap=true, blind=true,
  bash=true, pounce=true, hibernate=true, intimidating_shout=true,
  charge_stun=true, intercept_stun=true, concussion_blow=true, revenge_stun=true,
}

local function HasFlag(flags, mask)
  -- Lua 5.0 compatible, without requiring a bit library.
  return math.mod(math.floor(flags / mask), 2) == 1
end

local function HasCachedControl(plate, guid, now)
  -- Authoritative UNIT_AURA snapshot, independent of CC icon visibility.
  if plate.BNPClassicAuraEventDriven and plate.BNPTankControlGUID ~= guid
    and BNP.PrimeTankControlSnapshot then
    BNP:PrimeTankControlSnapshot(plate, guid, now)
  end
  if plate.BNPTankControlGUID == guid and plate.BNPClassicAuraEventDriven then
    return plate.BNPTankControlled and true or false, plate.BNPTankChargeStun and true or false
  end
  local cache = BNP.guidAuras and BNP.guidAuras[guid]
  local controlled = false
  local key, aura
  if cache then
    for key, aura in pairs(cache) do
      if BNP.TankDisablingCC[key] and aura.expires and aura.expires > now then
        controlled = true
        if key == "charge_stun" then return true, true end
      end
    end
  end
  cache = BNP.guidLiveCCs and BNP.guidLiveCCs[guid]
  if cache then
    for key, aura in pairs(cache) do
      if BNP.TankDisablingCC[key] and (aura.eventDriven or now - (aura.lastSeen or 0) <= 0.60) then
        controlled = true
        if key == "charge_stun" and aura.expires and aura.expires > now then return true, true end
      end
    end
  end
  return controlled, false
end

-- Share a single combat-state read across the normal two-color Tank Mode and
-- the optional CC/fleeing third color. A valid out-of-combat result must never
-- be mistaken for a live threat/target (NPCs can retain targets after combat).
local function GetCombatState(guid)
  local flags
  if GetUnitField then
    local ok, value = pcall(GetUnitField, guid, "flags")
    if ok and type(value) == "number" then flags = value end
  end
  if flags then return HasFlag(flags, 524288), flags end
  if UnitAffectingCombat then
    return UnitAffectingCombat(guid) and true or false, nil
  end
  return nil, nil  -- Unknown: keep legacy handling for hostile NPCs.
end

local function IsTemporarilyInactive(plate, guid, now, targetExists, flags, inCombat)
  -- One optional descriptor read covers combat, stun, confusion and fleeing,
  -- including low-health fleeing with a retained target. No tooltip/aura scan.
  if not inCombat then
    -- Do not wait for the combat flag when the actual opening Charge stun
    -- is already in the harmful-aura snapshot. Pre-pull sheep/sap stay out.
    local controlled, chargeStun = HasCachedControl(plate, guid, now)
    return controlled and chargeStun
  end
  if flags and (HasFlag(flags, 262144) or HasFlag(flags, 4194304) or HasFlag(flags, 8388608)) then
    return true
  end
  if HasCachedControl(plate, guid, now) then return true end

  -- Fleeing to seek assistance can clear the target without a CC aura or a
  -- fleeing flag, and GetUnitField is optional (Nampower). Keep this fallback
  -- deliberately narrow: in combat, no target, alive, <= 30% HP, not casting.
  -- This is a heuristic, not proof of fleeing. No per-frame scan or timer.
  if targetExists or not UnitHealth or not UnitHealthMax then return false end
  local health = UnitHealth(guid)
  if not health or health <= 0 then return false end
  local maximum = UnitHealthMax(guid)
  if not maximum or maximum <= 0 or health / maximum > 0.30 then return false end
  if UnitCastingInfo and UnitCastingInfo(guid) then return false end
  if UnitChannelInfo and UnitChannelInfo(guid) then return false end
  return true
end

local playerGUID = nil

local function GetPlayerGUID()
  local exists, guid = UnitExists("player")
  if exists and guid then playerGUID = guid end
  return playerGUID
end

local function GetPlateGUID(plate)
  if not plate or not plate.GetName then return nil end
  -- The ClassicAPI token is stable across camera projection changes. Only
  -- use it while the API maps it back to this exact frame.
  local token = plate.BNPClassicUnitToken
  if token and BNP._ClassicUnitGUID and BNP._ClassicGetNamePlateForUnit
    and BNP._ClassicGetNamePlateForUnit(token) == plate then
    local stableGUID = BNP._ClassicUnitGUID(token)
    if stableGUID then return stableGUID end
  end
  local guid = plate:GetName(1)
  if guid and guid ~= "" then return guid end
  return nil
end

local function GetTargetGUID(guid)
  if not guid then return nil, false end
  local exists, targetGUID = UnitExists(guid .. "target")
  -- An existing target whose GUID is temporarily unavailable is not "none".
  if exists then return targetGUID, true end
  return nil, false
end

local function GetBar(plate)
  return plate and (plate.healthbar or plate.healthBar) or nil
end

local function HasZeroHealth(bar)
  -- Read the existing bar only; no extra unit/aura query on the frame loop.
  -- Ignore uninitialized bars and positive minima (which may represent 1 HP).
  if not bar or not bar.GetValue or not bar.GetMinMaxValues then return false end
  if bar:GetValue() ~= 0 then return false end
  local minimum, maximum = bar:GetMinMaxValues()
  return minimum == 0 and maximum and maximum > 0
end

local function IsLiveNPC(guid)
  if not guid or not UnitExists(guid) then return false end
  if UnitIsPlayer and UnitIsPlayer(guid) then return false end
  -- Player-controlled pets/guardians have their own color renderer.
  if UnitPlayerControlled and UnitPlayerControlled(guid) then return false end
  return true
end

local function IsHostileNPC(guid)
  return IsLiveNPC(guid) and UnitCanAttack("player", guid) and true or false
end

local function IsForeignTaggedGUID(guid)
  if not guid or not UnitExists(guid) then return false end
  if UnitCanAttack and not UnitCanAttack("player", guid) then return false end
  if not UnitIsTapped or not UnitIsTapped(guid) then return false end
  if UnitIsTappedByPlayer and UnitIsTappedByPlayer(guid) then return false end
  return true
end

local function RestoreNormalColor(plate, bar)
  -- Undo ANY color applied by Tank Mode, not only the optional third color.
  -- Previously the standard GREEN/RED colors could survive combat ending.
  -- Derive the normal color from the CURRENT NPC reaction, never from a
  -- cached RGB value that might belong to a recycled nameplate.
  if plate.BNPTankActive and bar then
    local guid = GetPlateGUID(plate)
    if guid and IsLiveNPC(guid) and not IsForeignTaggedGUID(guid) then
      local r, g, b = bar:GetStatusBarColor()
      local stillOurColor = plate.BNPTankR
        and math.abs(r - plate.BNPTankR) < 0.01
        and math.abs(g - plate.BNPTankG) < 0.01
        and math.abs(b - plate.BNPTankB) < 0.01
      -- On a recycled plate, repair only if its bar still carries our color.
      if guid == plate.BNPTankColorGUID or stillOurColor then
        local reaction = UnitReaction and UnitReaction(guid, "player")
        if reaction then
          if reaction > 4 then bar:SetStatusBarColor(0, 1, 0, 1)
          elseif reaction == 4 then bar:SetStatusBarColor(1, 1, 0, 1)
          else bar:SetStatusBarColor(1, 0, 0, 1) end
        end
      end
    end
  end
  plate.BNPTankNoTargetActive = nil
  plate.BNPTankNoTargetSince = nil
  plate.BNPTankUnitGUID = nil
  plate.BNPTankColorGUID = nil
  plate.BNPTankActive = nil
  plate.BNPTankR = nil
  plate.BNPTankG = nil
  plate.BNPTankB = nil
end

local function ClearTankState(plate)
  if not plate then return end
  plate.BNPTankNoTargetActive = nil
  plate.BNPTankNoTargetSince = nil
  plate.BNPTankUnitGUID = nil
  plate.BNPTankColorGUID = nil
  plate.BNPTankActive = nil
  plate.BNPTankR = nil
  plate.BNPTankG = nil
  plate.BNPTankB = nil
end

local function ApplyTankColor(plate, bar, r, g, b)
  bar:SetStatusBarColor(r, g, b, 1)
  plate.BNPTankColorGUID = GetPlateGUID(plate)
  plate.BNPTankActive = true
  plate.BNPTankR = r
  plate.BNPTankG = g
  plate.BNPTankB = b
end

local function EnforceTankColor(plate)
  if not plate or not plate.BNPTankActive then return end
  -- Never paint a previous unit's cached color onto a recycled plate.
  if not BNP:IsTankModeEnabled() or plate.BNPTankColorGUID ~= GetPlateGUID(plate) then
    RestoreNormalColor(plate, GetBar(plate))
    return
  end
  local bar = GetBar(plate)
  if not bar or not plate.BNPTankR then return end
  if plate.BNPTankNoTargetActive and HasZeroHealth(bar) then
    RestoreNormalColor(plate, bar)
    return
  end

  local r, g, b = bar:GetStatusBarColor()
  if math.abs(r - plate.BNPTankR) > 0.01
    or math.abs(g - plate.BNPTankG) > 0.01
    or math.abs(b - plate.BNPTankB) > 0.01 then
    bar:SetStatusBarColor(plate.BNPTankR, plate.BNPTankG, plate.BNPTankB, 1)
  end
end

function BNP:UpdateTankModePlate(plate)
  if not plate or not plate:IsShown() then return end

  local bar = GetBar(plate)
  if not bar then return end

  if not self:IsTankModeEnabled() then
    RestoreNormalColor(plate, bar)
    return
  end

  local guid = GetPlateGUID(plate)
  if not IsHostileNPC(guid) then
    -- Player-controlled/friendly/recycled plates are never Tank Mode targets.
    -- Their own class/native or foreign-tag renderer remains authoritative.
    RestoreNormalColor(plate, bar)
    return
  end

  -- Foreign-tag grey has priority over Tank Mode. Previously Tank Mode wrote
  -- RED every 0.10s while fullalpha.lua restored GREY every frame, producing
  -- the visible grey/red flicker. Clear any cached tank color and let the
  -- foreign-tag renderer own the bar until the mob is ours/untapped again.
  if IsForeignTaggedGUID(guid) then
    ClearTankState(plate)
    return
  end

  local thirdColor = self:IsTankNoTargetEnabled()
  local inCombat, flags = GetCombatState(guid)
  local reaction = UnitReaction and UnitReaction(guid, "player")

  -- UnitCanAttack also returns true for neutral/yellow NPCs. Only recolor
  -- those NPCs once they actually enter combat. Likewise, an out-of-combat
  -- hostile mob must keep its native RED, not stale Tank Mode GREEN.
  -- The only pre-combat exception is the existing opening Charge stun color.
  if inCombat == false or (reaction and reaction >= 4 and inCombat ~= true) then
    if thirdColor then
      local controlled, chargeStun = HasCachedControl(plate, guid, GetTime())
      if controlled and chargeStun then
        if plate.BNPTankUnitGUID ~= guid then RestoreNormalColor(plate, bar) end
        plate.BNPTankUnitGUID = guid
        local r, g, b = self:GetTankNoTargetColor()
        ApplyTankColor(plate, bar, r, g, b)
        plate.BNPTankNoTargetActive = true
        return
      end
    end
    RestoreNormalColor(plate, bar)
    return
  end

  if thirdColor then
    if plate.BNPTankUnitGUID ~= guid then ClearTankState(plate) end
    plate.BNPTankUnitGUID = guid
    if HasZeroHealth(bar) or (UnitIsDead and UnitIsDead(guid)) then
      RestoreNormalColor(plate, bar)
      return
    end
  elseif plate.BNPTankNoTargetSince or plate.BNPTankNoTargetActive then
    RestoreNormalColor(plate, bar)
  end

  local myGUID = GetPlayerGUID()
  if not myGUID then return end

  local targetGUID, targetExists = GetTargetGUID(guid)
  local now = thirdColor and GetTime()
  if thirdColor and IsTemporarilyInactive(plate, guid, now, targetExists, flags, inCombat) then
    local r, g, b = self:GetTankNoTargetColor()
    ApplyTankColor(plate, bar, r, g, b)
    plate.BNPTankNoTargetActive = true
    return
  end
  plate.BNPTankNoTargetSince = nil
  if thirdColor and not targetGUID then
    -- No active control and no readable target: relinquish the third color.
    RestoreNormalColor(plate, bar)
    return
  end
  plate.BNPTankNoTargetActive = nil
  local inverted = self:AreTankModeColorsInverted()

  if targetGUID and targetGUID == myGUID then
    if inverted then
      local r, g, b = self:GetInvertTankAggroColor()
      ApplyTankColor(plate, bar, r, g, b)
    else
      ApplyTankColor(plate, bar, GREEN_R, GREEN_G, GREEN_B)
    end
  elseif targetGUID then
    if inverted then
      local r, g, b = self:GetInvertTankNoAggroColor()
      ApplyTankColor(plate, bar, r, g, b)
    else
      ApplyTankColor(plate, bar, RED_R, RED_G, RED_B)
    end
  else
    RestoreNormalColor(plate, bar)
  end
end

function BNP:RefreshTankMode()
  local plate
  for plate in pairs(self.plates or {}) do
    if plate and plate:IsShown() then
      self:UpdateTankModePlate(plate)
    end
  end
end

function BNP:UpdateTankMode()
  local enabled = self:IsTankModeEnabled() and self:IsTankNoTargetEnabled()
  if not enabled then
    local plate
    for plate in pairs(self.plates or {}) do
      plate.BNPTankControlGUID = nil
      plate.BNPTankControlled = nil
      plate.BNPTankChargeStun = nil
    end
  end
  self:RefreshTankMode()
end

function BNP:InstallTankMode()
  if self.BNPTankModeInstalled then return end
  if not self.libnameplate or not self.libnameplate.OnUpdate then return end

  GetPlayerGUID()

  table.insert(self.libnameplate.OnInit, function(plate)
    local current = plate or this
    if not current then return end

    ClearTankState(current)

    local bar = GetBar(current)
    if bar and not current.BNPTankColorHooked then
      local old = bar:GetScript("OnValueChanged")
      bar:SetScript("OnValueChanged", function()
        if old then old() end
        EnforceTankColor(current)
      end)
      -- Blizzard may repaint on camera movement without changing HP. Keep
      -- only the cached color in sync here; combat/aura reads stay throttled.
      local oldUpdate = bar:GetScript("OnUpdate")
      bar:SetScript("OnUpdate", function()
        if oldUpdate then oldUpdate() end
        EnforceTankColor(current)
      end)
      current.BNPTankColorHooked = true
    end
  end)

  table.insert(self.libnameplate.OnShow, function(plate)
    local current = plate or this
    if not current then return end
    -- Recycled nameplate frames can still show the previous mob's Tank color.
    -- Repair that RGB only when it is demonstrably still BNP-owned.
    if current.BNPTankActive then RestoreNormalColor(current, GetBar(current)) end
    ClearTankState(current)
    current.BNPTankControlGUID = nil
    current.BNPTankControlled = nil
    current.BNPTankChargeStun = nil
    BNP:UpdateTankModePlate(current)
  end)

  table.insert(self.libnameplate.OnUpdate, function(plate, elapsed)
    local current = plate or this
    if not current then return end

    -- Tank Mode is optional. Avoid all GUID/target/tap queries while it is off.
    -- Only clean an old BNP-owned state if one is still present.
    if not BNP:IsTankModeEnabled() then
      if current.BNPTankActive or current.BNPTankNoTargetSince then
        RestoreNormalColor(current, GetBar(current))
      end
      return
    end

    BNP:UpdateTankModePlate(current)
    EnforceTankColor(current)
  end)

  self.BNPTankModeInstalled = true
end
