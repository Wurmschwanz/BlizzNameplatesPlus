if not BNP.libnameplate then return end
if not CombatLogAdd or not SpellInfo then return end

local _, playerClass = UnitClass("player")
local UI = BNP.UI or {}
local ICON_SIZE = UI.ICON_SIZE or 18
local function GetIconSize()
  return (BNP.GetIconSize and BNP:GetIconSize()) or ICON_SIZE
end
local function GetCCIconSize()
  return (BNP.GetCCIconSize and BNP:GetCCIconSize()) or GetIconSize()
end
local ICON_OFFSET_Y = UI.ICON_OFFSET_Y or 15
local COMBO_LAYOUT_CLASS = (playerClass == "ROGUE" or playerClass == "DRUID")
local COMBO_LAYOUT_OFFSET = 16
local ROW_SPACING = 2

local function GetBaseAuraOffsetY()
  if COMBO_LAYOUT_CLASS and BNP.AreComboPointsEnabled and BNP:AreComboPointsEnabled() then
    return ICON_OFFSET_Y + COMBO_LAYOUT_OFFSET
  end
  return ICON_OFFSET_Y
end

local function GetDebuffPosition()
  if BNP.GetDebuffPosition then return BNP:GetDebuffPosition() end
  return "top"
end

local function GetCCPosition()
  if BNP.GetCCPosition then return BNP:GetCCPosition() end
  return GetDebuffPosition()
end

local function UseSeparateCCRow()
  -- The old extra row remains meaningful only when both aura groups are Top.
  if GetDebuffPosition() ~= "top" or GetCCPosition() ~= "top" then
    return false
  end
  return BNP.IsSeparateCCRowEnabled and BNP:IsSeparateCCRowEnabled()
end

local function UseDedicatedCCContainer()
  -- Different positions must always use the independent CC container.
  return GetCCPosition() ~= GetDebuffPosition() or UseSeparateCCRow()
end

local function GetAuraOffsetY()
  return GetBaseAuraOffsetY()
end

local function GetCCOffsetY()
  local y = GetBaseAuraOffsetY()
  if UseSeparateCCRow() and BNP.AreCrowdControlEnabled and BNP:AreCrowdControlEnabled() then
    y = y + GetIconSize() + ROW_SPACING
  end
  return y
end
local ICON_SPACING = UI.ICON_SPACING or 2
local SIDE_SPACING = 4
local UPDATE_INTERVAL = 0.05

local function GetSideCCOffsetY()
  if UseSeparateCCRow() and BNP.AreCrowdControlEnabled and BNP:AreCrowdControlEnabled() then
    return GetIconSize() + ROW_SPACING
  end
  return 0
end

local function GetLevelRegionWidth(region)
  if not region then return 0 end
  if region.IsShown and not region:IsShown() then return 0 end
  if region.GetStringWidth then
    local width = tonumber(region:GetStringWidth()) or 0
    if width > 0 then return width end
  end
  if region.GetWidth then
    return math.max(0, tonumber(region:GetWidth()) or 0)
  end
  return 0
end

local function GetRightAuraSpacing(plate)
  local extra = 0
  if plate then
    extra = extra + GetLevelRegionWidth(plate.level)
    extra = extra + GetLevelRegionWidth(plate.levelicon)
  end

  if extra > 0 then
    extra = extra + 6
  end

  return SIDE_SPACING + extra
end

local function AnchorAuraContainer(plate, container, isCC)
  if not plate or not container then return end
  container:ClearAllPoints()

  local position = isCC and GetCCPosition() or GetDebuffPosition()
  if plate.healthbar then
    if position == "left" then
      container:SetPoint("RIGHT", plate.healthbar, "LEFT", -SIDE_SPACING, isCC and GetSideCCOffsetY() or 0)
    elseif position == "right" then
      container:SetPoint("LEFT", plate.healthbar, "RIGHT", GetRightAuraSpacing(plate), isCC and GetSideCCOffsetY() or 0)
    else
      container:SetPoint("BOTTOM", plate.healthbar, "TOP", 0, isCC and GetCCOffsetY() or GetAuraOffsetY())
    end
  else
    if position == "left" then
      container:SetPoint("RIGHT", plate, "LEFT", -SIDE_SPACING, isCC and GetSideCCOffsetY() or 0)
    elseif position == "right" then
      container:SetPoint("LEFT", plate, "RIGHT", GetRightAuraSpacing(plate), isCC and GetSideCCOffsetY() or 0)
    else
      container:SetPoint("BOTTOM", plate, "BOTTOM", 0, 24 + (isCC and (GetCCOffsetY() - GetAuraOffsetY()) or 0))
    end
  end
end

-- Aura rows are anchored to the projected nameplate but parented beside it.
-- That keeps their opacity independent from transient Vanilla nameplate alpha
-- changes while preserving the native world/nameplate layer.

-- SuperWoW GUID cache. Auras are learned while a unit is the current target
-- and remain attached to that unit's unique GUID after the target changes.
BNP.guidAuras = BNP.guidAuras or {}
BNP.guidNames = BNP.guidNames or {}
BNP.guidLiveCCs = BNP.guidLiveCCs or {}
-- Shadow Vulnerability is a shared proc aura whose refresh can be invisible to
-- vanilla UnitDebuff (same spell ID, same stack count, no duration data). Keep
-- its countdown in a dedicated GUID state so generic shared-aura scans can
-- never accidentally replace or freeze the timer.
BNP.svExpiryByGUID = BNP.svExpiryByGUID or {}
-- Fully isolated Shadow Vulnerability state. Generic shared-aura code may
-- mirror this state for rendering, but it must never own or rewrite the timer.
BNP.svStateByGUID = BNP.svStateByGUID or {}
-- Monotonic render revision per GUID. A confirmed refresh increments this so
-- the normal nameplate renderer can invalidate any cached timer text safely.
BNP.svRenderRevisionByGUID = BNP.svRenderRevisionByGUID or {}

BNP.pvpAuraProtection = BNP.pvpAuraProtection or {}
local PVP_AURA_PROTECTION_TIME = 6.0

local function ProtectAuraCache(guid, reason)
  if not guid then return end
  BNP.pvpAuraProtection[guid] = {
    untilTime = GetTime() + PVP_AURA_PROTECTION_TIME,
    reason = reason,
  }
end

local function AuraCacheProtected(guid, now)
  local state = guid and BNP.pvpAuraProtection[guid]
  if not state then return false end
  if now <= (state.untilTime or 0) then return true end
  BNP.pvpAuraProtection[guid] = nil
  return false
end

local CLASS_AURAS = {
  WARLOCK = BNP.WarlockAuras,
  PRIEST = BNP.PriestAuras,
  WARRIOR = BNP.WarriorAuras,
  ROGUE = BNP.RogueAuras,
  HUNTER = BNP.HunterAuras,
  MAGE = BNP.MageAuras,
  DRUID = BNP.DruidAuras,
  SHAMAN = BNP.ShamanAuras,
  PALADIN = BNP.PaladinAuras,
}
local AURA_DEFS = CLASS_AURAS[playerClass] or {}
local HAS_SHARED_AURAS = false
do
  local _, def
  for _, def in ipairs(AURA_DEFS) do
    if def.shared then
      HAS_SHARED_AURAS = true
      break
    end
  end
end
local MAX_VISIBLE_ICONS = 8

local function PositionAuraIcon(icon, container, index, visibleCount, iconSize, isCC)
  if not icon or not container then return end
  local position = isCC and GetCCPosition() or GetDebuffPosition()
  local step = iconSize + ICON_SPACING

  icon:ClearAllPoints()

  if position == "left" then
    icon:SetPoint("RIGHT", container, "RIGHT", -((index - 1) * step), 0)
  elseif position == "right" then
    icon:SetPoint("LEFT", container, "LEFT", (index - 1) * step, 0)
  else
    local maxWidth = iconSize * MAX_VISIBLE_ICONS + ICON_SPACING * (MAX_VISIBLE_ICONS - 1)
    local rowWidth = 0
    if visibleCount and visibleCount > 0 then
      rowWidth = iconSize * visibleCount + ICON_SPACING * (visibleCount - 1)
    end
    local startX = (maxWidth - rowWidth) / 2
    icon:SetPoint("LEFT", container, "LEFT", startX + (index - 1) * step, 0)
  end
end

local function GetAuraFrameLevel(plate)
  local plateLevel = 0
  if plate and plate.GetFrameLevel then
    plateLevel = tonumber(plate:GetFrameLevel()) or plateLevel
  end
  return math.max(0, plateLevel + 1)
end

local function ApplyAuraFrameLevel(plate, container)
  if not container then return end

  -- Aura containers are siblings of the projected plate (not children) so they
  -- do not inherit transient plate alpha. Mirror only the plate's native strata
  -- and relative level; never modify the projected nameplate's own strata.
  if plate and plate.GetFrameStrata and container.GetFrameStrata and container.SetFrameStrata then
    local strata = plate:GetFrameStrata()
    if strata and container:GetFrameStrata() ~= strata then
      container:SetFrameStrata(strata)
    end
  end

  local level = GetAuraFrameLevel(plate)
  if container.GetFrameLevel and container.SetFrameLevel and
     container:GetFrameLevel() ~= level then
    container:SetFrameLevel(level)
  end

  local i
  for i = 1, table.getn(container.icons or {}) do
    local icon = container.icons[i]
    if icon and icon.GetFrameLevel and icon.SetFrameLevel and
       icon:GetFrameLevel() ~= level then
      icon:SetFrameLevel(level)
    end
  end
end

-- Target auras stay opaque and non-target auras remain consistently faded.
-- This is identity-based and never changes with camera or screen position.
local TARGET_PRIORITY_AURA_ALPHA = 0.35
local TARGET_PRIORITY_PLATE_HOLD = 0.25
local targetPriorityPlate = nil
local targetPriorityGUID = nil
local targetPriorityPlateSeenAt = -100

local function RefreshTargetPriorityIdentity()
  local exists, guid = UnitExists("target")
  if not exists or not guid then
    targetPriorityPlate = nil
    targetPriorityGUID = nil
    targetPriorityPlateSeenAt = -100
    return
  end

  local now = GetTime()

  -- A real target switch invalidates the previous frame immediately. For the
  -- same GUID, however, keep the last exact ClassicAPI target plate through a
  -- very short nil result. Dense raid stacks can make projected plate lookup
  -- flicker for a frame; dropping the cached target here made its DoTs/Banish
  -- alternate between opaque and the 0.35 non-target alpha.
  if targetPriorityGUID ~= guid then
    targetPriorityPlate = nil
    targetPriorityPlateSeenAt = -100
  end
  targetPriorityGUID = guid

  local resolved = nil
  if C_NamePlate and
     type(C_NamePlate.GetNamePlateForUnit) == "function" then
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and plate then resolved = plate end
  end

  if resolved then
    targetPriorityPlate = resolved
    targetPriorityPlateSeenAt = now
  elseif targetPriorityPlate and
         now - targetPriorityPlateSeenAt > TARGET_PRIORITY_PLATE_HOLD then
    targetPriorityPlate = nil
  end
end

local function SetTargetPriorityAuraAlpha(container, alpha)
  if not container then return end
  alpha = alpha or 1
  if container.SetAlpha and
     (not container.GetAlpha or container:GetAlpha() ~= alpha) then
    container:SetAlpha(alpha)
  end
end

local function ApplyTargetAuraPriority(plate, container)
  if not container then return end

  -- Flicker fix: aura opacity must not depend on transient target/nameplate
  -- resolution. In dense raid stacks ClassicAPI/SuperWoW can briefly resolve
  -- a projected plate differently, which previously made the whole debuff/CC
  -- row alternate between alpha 1.0 and 0.35. This alpha is separate from the
  -- user-facing Non-Target Alpha slider, so setting that slider to 100% did
  -- not disable the flicker. Keep aura containers fully opaque and let target
  -- priority be handled by nameplate layering only.
  SetTargetPriorityAuraAlpha(container, 1)
end

function BNP:RefreshAuraPriorityAlpha()
  RefreshTargetPriorityIdentity()

  local plate
  for plate in pairs(self.plates or {}) do
    ApplyAuraFrameLevel(plate, plate.BNPAuraContainer)
    ApplyAuraFrameLevel(plate, plate.BNPCCContainer)
    ApplyTargetAuraPriority(plate, plate.BNPAuraContainer)
    ApplyTargetAuraPriority(plate, plate.BNPCCContainer)
  end
end

local function CleanText(text)
  if not text then return nil end
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  return text
end

local function NameMatches(def, name)
  if not name then return false end
  local lower = string.lower(name)
  for _, known in ipairs(def.names) do
    if lower == string.lower(known) then return true end
  end
  return false
end

local function AuraMatches(def, effect, texture)
  if NameMatches(def, effect) then return true end
  if texture and def.textureMatch then
    return string.find(string.lower(texture), def.textureMatch) and true or false
  end
  return false
end

local function ScanSpellbook()
  if table.getn(AURA_DEFS) == 0 then return end

  local i = 1
  while true do
    local name = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end

    local texture = GetSpellTexture(i, BOOKTYPE_SPELL)
    local lowerTexture = texture and string.lower(texture) or ""

    for _, def in ipairs(AURA_DEFS) do
      if NameMatches(def, name) or (def.textureMatch and string.find(lowerTexture, def.textureMatch)) then
        def.localizedName = name
        def.texture = texture or def.texture
      end
    end

    i = i + 1
  end
  if BNP.RefreshSpellbookDurations then BNP:RefreshSpellbookDurations() end
end

local function CreateAuraIcon(parent, index)
  local icon = CreateFrame("Frame", nil, parent)
  local size = GetIconSize()
  icon:SetWidth(size)
  icon:SetHeight(size)
  icon:SetFrameLevel(parent.GetFrameLevel and parent:GetFrameLevel() or 0)

  local texture = icon:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(icon)
  icon.texture = texture

  local timer = icon:CreateFontString(nil, "OVERLAY")
  timer:SetFont(UI.TIMER_FONT or "Fonts\\FRIZQT__.TTF", UI.TIMER_SIZE or 8, "OUTLINE")
  timer:SetPoint("CENTER", icon, "CENTER", UI.TIMER_OFFSET_X or 0, UI.TIMER_OFFSET_Y or 0)
  timer:SetTextColor(1, 1, 1)
  icon.timer = timer

  local stack = icon:CreateFontString(nil, "OVERLAY")
  stack:SetFont(UI.TIMER_FONT or "Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
  stack:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
  stack:SetTextColor(1, 1, 1)
  stack:SetText("")
  icon.stack = stack

  icon.index = index
  icon:Hide()

  return icon
end

local function HidePlateAuraFrames(plate)
  if not plate then return end

  local containers = { plate.BNPAuraContainer, plate.BNPCCContainer }
  local _, container, i
  for _, container in ipairs(containers) do
    if container then
      for i = 1, table.getn(container.icons or {}) do
        container.icons[i]:Hide()
      end
      container:Hide()
    end
  end
end

local function InstallAuraHideGuard(plate)
  if not plate or plate.BNPAuraHideGuard then return end

  local oldOnHide = plate:GetScript("OnHide")
  plate:SetScript("OnHide", function()
    if oldOnHide then oldOnHide() end
    local current = this or plate
    HidePlateAuraFrames(current)
    -- If Blizzard reuses this frame for another unit, do not hold the old GUID
    -- through the next OnShow. The next visible identity must be reconfirmed.
    current.BNPAuraForceFreshIdentity = true
    current.BNPAuraGUIDCandidate = nil
    current.BNPAuraGUIDCandidateCount = 0
  end)
  plate.BNPAuraHideGuard = true
end

local function GetAuraVisualParent(plate)
  -- Aura rows must not inherit the projected nameplate's alpha. In large raids
  -- the Vanilla client can transiently adjust/recycle a non-target plate's alpha
  -- while resolving dense stacks. A child frame inherits that alpha even when
  -- its own alpha is forced to 1, which made debuffs pulse grey/colored.
  -- Use the nameplate's native parent (normally WorldFrame) as a sibling parent
  -- and keep anchoring to the real healthbar so position still follows the plate.
  if plate and plate.GetParent then
    local parent = plate:GetParent()
    if parent then return parent end
  end
  return WorldFrame or UIParent
end

local function CreateAuraContainer(plate)
  if not plate then return end
  BNP:RegisterPlate(plate)
  if plate.BNPAuraContainer then return end

  local size = GetIconSize()
  local width = size * MAX_VISIBLE_ICONS + ICON_SPACING * (MAX_VISIBLE_ICONS - 1)
  local container = CreateFrame("Frame", nil, GetAuraVisualParent(plate))
  container:SetWidth(width)
  container:SetHeight(size)
  container:SetFrameLevel(GetAuraFrameLevel(plate))

  AnchorAuraContainer(plate, container, false)

  container.icons = {}
  for i = 1, MAX_VISIBLE_ICONS do
    local icon = CreateAuraIcon(container, i)
    PositionAuraIcon(icon, container, i, 0, size)
    container.icons[i] = icon
  end

  container:Hide()
  plate.BNPAuraContainer = container
  ApplyAuraFrameLevel(plate, container)
  InstallAuraHideGuard(plate)
end

local function CreateCCContainer(plate)
  if not plate then return end
  BNP:RegisterPlate(plate)
  if plate.BNPCCContainer then return end

  local size = GetCCIconSize()
  local width = size * MAX_VISIBLE_ICONS + ICON_SPACING * (MAX_VISIBLE_ICONS - 1)
  local container = CreateFrame("Frame", nil, GetAuraVisualParent(plate))
  container:SetWidth(width)
  container:SetHeight(size)
  container:SetFrameLevel(GetAuraFrameLevel(plate))

  AnchorAuraContainer(plate, container, true)

  container.icons = {}
  for i = 1, MAX_VISIBLE_ICONS do
    local icon = CreateAuraIcon(container, i)
    PositionAuraIcon(icon, container, i, 0, size, true)
    container.icons[i] = icon
  end

  container:Hide()
  plate.BNPCCContainer = container
  ApplyAuraFrameLevel(plate, container)
end

local function GetPlateGUID(plate)
  if not plate or not plate.GetName then return nil end

  -- SuperWoW stores the unit GUID/token directly on the nameplate name slot.
  -- Use that exact token, just like Tank Mode and ShaguTweaks do. This avoids
  -- unreliable UnitExists() resolution and, importantly, avoids same-name
  -- fallback collisions between two mobs with identical names.
  local token = plate:GetName(1)
  if token and token ~= "" then return token end
  return nil
end

local function GetTargetGUID()
  local exists, guid = UnitExists("target")
  if exists and guid then return guid end
  return nil
end

local function ClearGUIDAuraState(guid)
  if not guid then return end
  BNP.guidAuras[guid] = nil
  if BNP.svStateByGUID then BNP.svStateByGUID[guid] = nil end
  if BNP.svExpiryByGUID then BNP.svExpiryByGUID[guid] = nil end
  if BNP.svRenderRevisionByGUID then BNP.svRenderRevisionByGUID[guid] = nil end
  if BNP.guidLiveCCs then BNP.guidLiveCCs[guid] = nil end
  if BNP.pendingAuras then BNP.pendingAuras[guid] = nil end
  if BNP.pvpAuraProtection then BNP.pvpAuraProtection[guid] = nil end
  if BNP.darkHarvest and BNP.darkHarvest.guid == guid then BNP.darkHarvest = nil end
  if BNP.guidNames then BNP.guidNames[guid] = nil end
end

local function CleanupDeadUnit(unit, guid, now)
  if not unit or not guid or not UnitIsDeadOrGhost then return false end
  if AuraCacheProtected and AuraCacheProtected(guid, now) then return false end
  if UnitIsDeadOrGhost(unit) then
    ClearGUIDAuraState(guid)
    return true
  end
  return false
end


-- Fallback for players/NPCs whose nameplate disappears before the periodic
-- dead-state check sees them. Vanilla combat chat reports "<name> dies." only,
-- so this fallback must NEVER clear multiple same-name GUIDs.
local function ClearAuraStateByName(name)
  if not name or name == "" then return end

  -- Combat death chat gives us only a name, never the exact GUID.
  -- Count ALL known GUIDs with this name, not only GUIDs that currently have
  -- tracked auras. Otherwise, if two same-name mobs exist but only one has our
  -- debuffs, the death of the other mob could wrongly clear the survivor.
  local matchGUID = nil
  local matches = 0
  local guid, knownName

  for guid, knownName in pairs(BNP.guidNames or {}) do
    if knownName == name then
      matches = matches + 1
      matchGUID = guid

      if matches > 1 then
        -- Ambiguous same-name death: never clear anything by name.
        -- Exact GUID-based target death cleanup remains authoritative.
        return
      end
    end
  end

  if matches == 1 and matchGUID then
    ClearGUIDAuraState(matchGUID)
  end
end


-- Boss / NPC evade-reset cleanup --------------------------------------------
-- On a real reset the server restores the NPC to full health and drops combat,
-- while BNP's local aura timers would otherwise keep running. Track only the
-- current hostile NPC and clear its exact GUID cache when that reset signature
-- is observed.
local resetWatch = {}
local resetElapsed = 0

local function CheckCurrentTargetReset(now)
  local exists, guid = UnitExists("target")
  if not exists or not guid then
    resetWatch.guid = nil
    resetWatch.wasDamaged = nil
    return
  end

  if UnitIsPlayer and UnitIsPlayer("target") then
    resetWatch.guid = guid
    resetWatch.wasDamaged = nil
    return
  end

  if resetWatch.guid ~= guid then
    resetWatch.guid = guid
    resetWatch.wasDamaged = nil
  end

  if not UnitHealth or not UnitHealthMax then return end
  local hp = tonumber(UnitHealth("target"))
  local maxhp = tonumber(UnitHealthMax("target"))
  if not hp or not maxhp or maxhp <= 0 then return end

  local pct = hp / maxhp
  if pct < 0.95 then
    resetWatch.wasDamaged = true
  end

  if not resetWatch.wasDamaged then return end
  if pct < 0.995 then return end

  -- Prefer the target's combat state when available. If the API is missing,
  -- require the player to be out of combat as a conservative fallback.
  local outOfCombat = false
  if UnitAffectingCombat then
    outOfCombat = not UnitAffectingCombat("target")
  elseif PlayerFrame and PlayerFrame.inCombat ~= nil then
    outOfCombat = not PlayerFrame.inCombat
  end

  if not outOfCombat then return end

  if BNP.guidAuras and BNP.guidAuras[guid] then
    ClearGUIDAuraState(guid)
    if RaidTrace then RaidTrace("RESET", guid, "-", nil) end
  end

  resetWatch.wasDamaged = nil
end

local resetFrame = CreateFrame("Frame")
resetFrame:SetScript("OnUpdate", function()
  resetElapsed = resetElapsed + arg1
  if resetElapsed < 0.10 then return end
  resetElapsed = 0
  CheckCurrentTargetReset(GetTime())
end)

local deathChatFrame = CreateFrame("Frame")
deathChatFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
deathChatFrame:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")
deathChatFrame:SetScript("OnEvent", function()
  local raw = arg1
  if not raw then return end
  local _, _, deadName = string.find(raw, "^(.+) dies%.$")
  if deadName then ClearAuraStateByName(deadName) end
end)

-- Only successful casts by the local player are allowed to create aura
-- entries. This prevents target scans from importing debuffs cast by other
-- players. SuperWoW supplies caster GUID, target GUID and spell ID.
local function GetPlayerGUID()
  local exists, guid = UnitExists("player")
  if exists and guid then return guid end
  return nil
end

local function DefHasSpellID(def, spellID)
  if not def or not spellID then return false end

  local i
  if def.spellIDs then
    for i = 1, table.getn(def.spellIDs) do
      if def.spellIDs[i] == spellID then return true end
    end
  end

  if def.durations and def.durations[spellID] then return true end
  return false
end

local function FindAuraDef(spellID)
  if not spellID or not SpellInfo then return nil, nil end
  local spellName, _, texture = SpellInfo(spellID)
  if not spellName and not texture then return nil, nil end

  -- Exact IDs are authoritative and must win over shared spell textures.
  local _, def
  for _, def in ipairs(AURA_DEFS) do
    if DefHasSpellID(def, spellID) then
      return def, texture, spellID
    end
  end

  for _, def in ipairs(AURA_DEFS) do
    if NameMatches(def, spellName) then
      return def, texture, spellID
    end
  end

  for _, def in ipairs(AURA_DEFS) do
    if texture and def.textureMatch and string.find(string.lower(texture), def.textureMatch) then
      return def, texture, spellID
    end
  end

  return nil, nil
end


-- Paladin Judgements --------------------------------------------------------
-- SuperWoW reports the button press as Judgement [20271], while the target
-- receives a different aura ID (e.g. Light 20344, Justice 20184, Crusader
-- 20302, Wisdom 20353). Therefore normal CAST-ID == AURA-ID confirmation
-- cannot work for Judgements.
local PALADIN_JUDGEMENT_CAST_ID = 20271

local function IsJudgementDef(def)
  if not def or not def.key then return false end
  return string.find(def.key, "^judgement_") and true or false
end

local function FindJudgementAuraOnUnit(unit)
  if playerClass ~= "PALADIN" or not unit then return nil end

  local i, texture, stacks, dtype, auraSpellID
  for i = 1, 64 do
    texture, stacks, dtype, auraSpellID = UnitDebuff(unit, i)
    if not texture then break end

    if auraSpellID then
      local auraName = nil
      if SpellInfo then auraName = SpellInfo(auraSpellID) end

      local _, def
      for _, def in ipairs(AURA_DEFS) do
        if IsJudgementDef(def) then
          local explicitMatch = false
          local j
          if def.spellIDs then
            for j = 1, table.getn(def.spellIDs) do
              if def.spellIDs[j] == auraSpellID then
                explicitMatch = true
                break
              end
            end
          end

          if explicitMatch or NameMatches(def, auraName) then
            return def, auraSpellID, texture
          end
        end
      end
    end
  end

  return nil
end


-- Turtle WoW Dark Harvest (spell 52552).
-- It is reported by SuperWoW as CHANNEL; arg5 is channel length in ms.
-- A 30% shorter tick interval means aura time advances at 1/0.70 speed.
local DARK_HARVEST_SPELL_ID = 52552
local DARK_HARVEST_SPEED = 1 / 0.70
local DARK_HARVEST_AURAS = {
  corruption=true, curse_of_agony=true, siphon_life=true,
  curse_of_doom=true, drain_life=true, drain_soul=true,
}
BNP.darkHarvest = nil

local function StartDarkHarvest(guid, durationMS)
  local now=GetTime()
  local duration=tonumber(durationMS) or 8000
  if duration > 100 then duration=duration/1000 end
  BNP.darkHarvest={guid=guid, lastUpdate=now, ends=now+duration}
end

local function UpdateDarkHarvest(now)
  local st=BNP.darkHarvest
  if not st then return end
  local untilTime=now
  if untilTime > st.ends then untilTime=st.ends end
  local delta=untilTime-st.lastUpdate
  if delta > 0 then
    local cache=BNP.guidAuras[st.guid]
    if cache then
      local bonus=delta*(DARK_HARVEST_SPEED-1)
      local key,aura
      for key,aura in pairs(cache) do
        if DARK_HARVEST_AURAS[key] and type(aura)=="table" and aura.expires and aura.expires > st.lastUpdate then
          aura.expires=aura.expires-bonus
        end
      end
    end
    st.lastUpdate=untilTime
  end
  if now >= st.ends then BNP.darkHarvest=nil end
end



-- Raid confirmation trace ----------------------------------------------------
-- Tiny always-on ring buffer for the last tracked own-aura transitions.
-- No chat output and no scanning; entries are only added at existing events.
BNP.raidTrace = BNP.raidTrace or {}
BNP.raidTraceMax = 30

local function RaidTrace(stage, guid, key, spellID)
  local t = BNP.raidTrace
  table.insert(t, {
    time = GetTime(),
    stage = stage,
    guid = guid,
    key = key,
    spellID = spellID,
  })
  while table.getn(t) > BNP.raidTraceMax do
    table.remove(t, 1)
  end
end

-- Cast confirmation ---------------------------------------------------------
-- UNIT_CASTEVENT "CAST" means the player finished the cast, but it does not
-- guarantee that the hostile aura actually landed. Resist/Miss/Immune must
-- therefore never create a visible timer.
--
-- We first remember the cast as "pending". It becomes a real aura only after
-- UnitDebuff confirms the matching aura on that exact SuperWoW GUID.
-- Never infer success from CAST alone: melee abilities can still miss/dodge,
-- and hostile targets may resist or be immune after the cast event.
BNP.pendingAuras = BNP.pendingAuras or {}
BNP.pendingAoEAuras = BNP.pendingAoEAuras or {}

-- Pending failures are matched by exact SuperWoW UNIT_CASTEVENT data.
-- Never use global combat-text "miss/resist" lines here: in a raid those can
-- belong to another spell and previously caused unrelated pending DoTs to die.

local function FailPendingAura(targetGUID, spellID)
  if not targetGUID or not spellID then return end
  local entries = BNP.pendingAuras[targetGUID]
  if not entries then return end

  local def = FindAuraDef(spellID)
  if def and entries[def.key] then
    entries[def.key] = nil
  end

  -- Generic Paladin Judgement failure.
  if playerClass == "PALADIN" and spellID == PALADIN_JUDGEMENT_CAST_ID then
    entries.__judgement = nil
  end
end

local PENDING_TIMEOUT = 4.0

-- Shagu-style authoritative own-cast tracking --------------------------------
-- Exact own SuperWoW CAST on an exact GUID creates normal direct single-target
-- debuffs immediately. The application remains provisional for a short window:
-- SuperWoW FAIL and localized combat-log miss/resist/immune messages can roll it
-- back, including restoring the old timer after a resisted refresh.
local STRICT_AURA_KEYS = {
  -- Shared / proc / secondary effects
  shadow_vulnerability=true, hunters_mark=true,

  -- Warlock CC
  fear=true, howl_of_terror=true, banish=true, death_coil=true,

  -- Hunter traps / CC / talent procs
  immolation_trap_effect=true, explosive_trap_effect=true, freezing_trap_effect=true,
  improved_scorpid_sting=true, improved_wing_clip=true, improved_concussive_shot=true,
  scatter_shot=true, wyvern_sting=true, entrapment=true, counterattack=true,
  intimidation=true, scare_beast=true,

  -- Mage CC / proc effects
  polymorph=true, frost_nova=true, counterspell=true, counterspell_silence=true,
  ignite=true, impact=true, frostbite=true, fire_vulnerability=true, winters_chill=true,

  -- Priest CC / proc effects
  psychic_scream=true, silence=true, blackout=true, touch_of_weakness=true,
  shackle_undead=true, mind_control=true,

  -- Paladin CC
  hammer_of_justice=true, repentance=true, turn_undead=true,

  -- Rogue CC / poison procs
  gouge=true, kidney_shot=true, cheap_shot=true, sap=true, blind=true,
  kick_silenced=true, crippling_poison=true, mind_numbing_poison=true,
  wound_poison=true, deadly_poison=true,

  -- Druid CC / secondary effects
  entangling_roots=true, bash=true, pounce=true, pounce_bleed=true,
  hibernate=true, feral_charge_effect=true,

  -- Warrior CC / talent procs
  improved_hamstring=true, intimidating_shout=true, disarm=true,
  charge_stun=true, intercept_stun=true, concussion_blow=true,
  revenge_stun=true, pummel=true, shield_bash=true, deep_wound=true,

  -- Shaman totem / proc effects
  earthbind=true, earthgrab=true, frostbrand_attack=true,
}

local function GetTrackingMode(def)
  if not def or not def.key then return "AURA" end
  if def.category == "CURSE" then return "AURA" end
  if def.aoe then return "AURA" end
  local cat = string.upper(tostring(def.category or ""))
  if cat == "CC" or cat == "ROOT" or cat == "STUN"
    or cat == "TRAP" or cat == "SILENCE" or cat == "PROC" then
    return "AURA"
  end
  if STRICT_AURA_KEYS[def.key] then return "AURA" end
  return "CAST"
end

local function IsCastPrimary(def)
  return GetTrackingMode(def) == "CAST"
end

local AURA_ATTEMPT_WINDOW = 5.0
BNP.auraCastAttempts = BNP.auraCastAttempts or {}

local function CopyAuraState(aura)
  if type(aura) ~= "table" then return nil end
  local copy = {}
  local k, v
  for k, v in pairs(aura) do copy[k] = v end
  return copy
end

local function BuildAffectedKeys(def)
  local keys = {}
  if not def or not def.key then return keys end

  keys[def.key] = true

  -- Any Warlock curse cast can change the target's complete curse state.
  -- Snapshot every tracked curse so a later resist/fail can restore exactly
  -- what was active before the attempt. This also supports Turtle mechanics
  -- where Curse of Agony may coexist with one regular curse.
  if def.category == "CURSE" then
    local _, oldDef
    for _, oldDef in ipairs(AURA_DEFS) do
      if oldDef.category == "CURSE" then
        keys[oldDef.key] = true
      end
    end
  end

  return keys
end

local function StartAuraCastAttempt(guid, def, spellID, affectedKeys)
  if not guid or not spellID then return nil end

  local keys = affectedKeys or BuildAffectedKeys(def)
  local cache = BNP.guidAuras[guid]
  local before = {}
  local key

  for key in pairs(keys) do
    local aura = cache and cache[key]
    before[key] = {
      exists = type(aura) == "table" and true or false,
      aura = CopyAuraState(aura),
    }
  end

  local spellName = nil
  if SpellInfo then spellName = SpellInfo(spellID) end
  if not spellName and def and def.localizedName then spellName = def.localizedName end
  if not spellName and def and def.names then spellName = def.names[1] end

  local attempt = {
    guid = guid,
    key = def and def.key or "__special",
    spellID = spellID,
    spellName = spellName,
    time = GetTime(),
    before = before,
    done = false,
  }

  table.insert(BNP.auraCastAttempts, attempt)
  while table.getn(BNP.auraCastAttempts) > 32 do
    table.remove(BNP.auraCastAttempts, 1)
  end

  return attempt
end

local function RollbackAuraCastAttempt(attempt, reason)
  if not attempt or attempt.done then return false end

  local guid = attempt.guid
  local cache = BNP.guidAuras[guid]
  if not cache then
    cache = {}
    BNP.guidAuras[guid] = cache
  end

  local key, state
  for key, state in pairs(attempt.before or {}) do
    if state.exists and state.aura then
      cache[key] = CopyAuraState(state.aura)
    else
      cache[key] = nil
    end
  end

  attempt.done = true
  RaidTrace("ROLLBACK", guid, attempt.key, attempt.spellID)
  return true
end

local function RollbackAuraAttemptBySpell(guid, spellID, reason)
  if not spellID then return false end
  local now = GetTime()
  local i

  for i = table.getn(BNP.auraCastAttempts), 1, -1 do
    local attempt = BNP.auraCastAttempts[i]
    if attempt and not attempt.done
      and attempt.spellID == spellID
      and (not guid or attempt.guid == guid)
      and now - (attempt.time or 0) <= AURA_ATTEMPT_WINDOW then
      return RollbackAuraCastAttempt(attempt, reason)
    end
  end

  return false
end

local function CleanupAuraCastAttempts(now)
  local i
  for i = table.getn(BNP.auraCastAttempts), 1, -1 do
    local attempt = BNP.auraCastAttempts[i]
    if not attempt or attempt.done or now - (attempt.time or 0) > AURA_ATTEMPT_WINDOW then
      table.remove(BNP.auraCastAttempts, i)
    end
  end
end

-- ShaguPlates does more than just seed debuffs from UNIT_CASTEVENT CAST:
-- libdebuff also watches the local player's failure combat messages and
-- reverts the last application on miss/resist/immune/evade/etc. BNP mirrors
-- that safety, but keeps the exact SuperWoW GUID and can restore the previous
-- timer when a refresh fails.
local failurePatterns = {}

local function EscapeLuaPattern(text)
  return string.gsub(text, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function CombatFormatToPattern(formatText)
  if not formatText or formatText == "" then return nil end

  local text = formatText
  text = string.gsub(text, "%%%%", "__BNP_PERCENT__")
  text = string.gsub(text, "%%%d+%$s", "__BNP_STRING__")
  text = string.gsub(text, "%%s", "__BNP_STRING__")
  text = string.gsub(text, "%%%d+%$d", "__BNP_NUMBER__")
  text = string.gsub(text, "%%d", "__BNP_NUMBER__")
  text = EscapeLuaPattern(text)
  text = string.gsub(text, "__BNP_STRING__", ".+")
  text = string.gsub(text, "__BNP_NUMBER__", "%%d+")
  text = string.gsub(text, "__BNP_PERCENT__", "%%%%")
  return "^" .. text .. "$"
end

local function AddFailurePattern(formatText)
  local pattern = CombatFormatToPattern(formatText)
  if pattern then table.insert(failurePatterns, pattern) end
end

AddFailurePattern(SPELLIMMUNESELFOTHER)
AddFailurePattern(IMMUNEDAMAGECLASSSELFOTHER)
AddFailurePattern(SPELLMISSSELFOTHER)
AddFailurePattern(SPELLRESISTSELFOTHER)
AddFailurePattern(SPELLEVADEDSELFOTHER)
AddFailurePattern(SPELLDODGEDSELFOTHER)
AddFailurePattern(SPELLDEFLECTEDSELFOTHER)
AddFailurePattern(SPELLREFLECTSELFOTHER)
AddFailurePattern(SPELLPARRIEDSELFOTHER)
AddFailurePattern(SPELLFAILCASTSELF)

local function IsLocalFailureMessage(raw)
  if not raw or raw == "" then return false end
  local i
  for i = 1, table.getn(failurePatterns) do
    if string.find(raw, failurePatterns[i]) then return true end
  end
  return false
end

local function RollbackAuraAttemptFromCombatMessage(raw)
  if not IsLocalFailureMessage(raw) then return false end

  local now = GetTime()
  local i
  for i = table.getn(BNP.auraCastAttempts), 1, -1 do
    local attempt = BNP.auraCastAttempts[i]
    if attempt and not attempt.done
      and now - (attempt.time or 0) <= AURA_ATTEMPT_WINDOW
      and attempt.spellName
      and string.find(raw, attempt.spellName, 1, true) then
      return RollbackAuraCastAttempt(attempt, "COMBAT_FAIL")
    end
  end

  return false
end

local auraFailureFrame = CreateFrame("Frame")
auraFailureFrame:RegisterEvent("CHAT_MSG_SPELL_FAILED_LOCALPLAYER")
auraFailureFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
auraFailureFrame:SetScript("OnEvent", function()
  RollbackAuraAttemptFromCombatMessage(arg1)
end)

local function HasPendingAuras()
  local guid, entries, key, pending
  for guid, entries in pairs(BNP.pendingAuras) do
    for key, pending in pairs(entries) do
      if type(pending) == "table" then
        return true
      end
    end
  end
  return false
end

local function GetUnitTokenForPlate(plate)
  if not plate or not plate.GetName then return nil end
  return plate:GetName(1)
end

local function FindMatchingAuraOnUnit(unit, def, castSpellID)
  if not unit or not def then return nil, nil, nil end

  -- SuperWoW can expose more than the stock 16/32 debuff slots. In a 40-player
  -- raid our own debuff may therefore sit beyond slot 32. Stopping at 32 made
  -- valid casts time out instead of entering guidAuras.
  local i = 1
  while i <= 64 do
    local texture, stacks, dtype, auraSpellID = UnitDebuff(unit, i)
    if not texture then break end

    if auraSpellID then
      if auraSpellID == castSpellID or DefHasSpellID(def, auraSpellID) then
        return auraSpellID, texture, tonumber(stacks) or 0
      end

      local auraName = SpellInfo and SpellInfo(auraSpellID) or nil
      if NameMatches(def, auraName) then
        return auraSpellID, texture, tonumber(stacks) or 0
      end
    end

    if texture and def.textureMatch and string.find(string.lower(texture), def.textureMatch) then
      return auraSpellID or castSpellID, texture, tonumber(stacks) or 0
    end

    i = i + 1
  end

  return nil, nil, nil
end

local function ReconcileLiveCurseCache(unit, guid)
  if playerClass ~= "WARLOCK" or not unit or not guid then return end

  local cache = BNP.guidAuras[guid]
  if not cache then return end

  -- Curse casts are already strict aura-confirmed. Once a new curse has really
  -- appeared, use that same live target aura state to decide which older curse
  -- timers are still valid. This avoids hard-coding whether CoA is exclusive:
  -- if the server keeps two curses, BNP keeps two; if one was replaced, BNP
  -- removes only the aura that is actually gone.
  local _, curseDef
  for _, curseDef in ipairs(AURA_DEFS) do
    if curseDef.category == "CURSE" and cache[curseDef.key] then
      local cachedAura = cache[curseDef.key]
      local liveSpellID = FindMatchingAuraOnUnit(
        unit,
        curseDef,
        cachedAura and cachedAura.spellID or nil
      )

      if not liveSpellID then
        RaidTrace("CURSE_REMOVE", guid, curseDef.key, cachedAura and cachedAura.spellID)
        cache[curseDef.key] = nil
      end
    end
  end
end

local function CommitPendingAura(guid, key, pending, unit)
  if not guid or not pending then return end

  local def = pending.def
  local cache = BNP.guidAuras[guid]
  if not cache then
    cache = {}
    BNP.guidAuras[guid] = cache
  end

  -- Do not guess curse exclusivity here. Warlock curses are strict aura-
  -- confirmed and are reconciled against the live target state after commit.
  -- This supports both normal Vanilla replacement and Turtle dual-curse rules.

  cache._nextOrder = (cache._nextOrder or 0) + 1
  local aura = cache[key] or {}
  aura.order = cache._nextOrder
  aura.duration = pending.duration
  aura.expires = GetTime() + pending.duration
  aura.spellID = pending.spellID
  aura.texture = pending.texture or def.texture
  aura.stacks = tonumber(pending.stacks) or 0
  aura.confirmedAt = GetTime()
  aura.missingScans = nil

  if pending.liveConfirmed then
    aura.castPrimary = nil
    aura.castPrimaryAt = nil
    aura.liveConfirmed = true
  elseif pending.castPrimary then
    aura.castPrimary = true
    aura.castPrimaryAt = GetTime()
    aura.liveConfirmed = nil
  end

  cache[key] = aura

  if def.category == "CURSE" and unit then
    ReconcileLiveCurseCache(unit, guid)
  end

  RaidTrace("CONFIRM", guid, key, aura.spellID)
end

local function ConfirmPendingForUnit(unit, guid, now)
  if not unit or not guid then return end
  local pendingForGUID = BNP.pendingAuras[guid]
  if not pendingForGUID then return end

  local key, pending
  for key, pending in pairs(pendingForGUID) do
    if type(pending) == "table" then
      if pending.judgementProbe then
        local def, auraSpellID, texture = FindJudgementAuraOnUnit(unit)

        if def and auraSpellID then
          local duration = def.duration
          if BNP.GetSpellbookDurationForDef then
            duration = BNP:GetSpellbookDurationForDef(def) or duration
          end

          local confirmed = {
            def = def,
            spellID = auraSpellID,
            texture = texture or def.texture,
            duration = duration,
            created = pending.created,
            liveConfirmed = true,
          }

          CommitPendingAura(guid, def.key, confirmed, unit)
          pendingForGUID[key] = nil
        elseif now - pending.created > PENDING_TIMEOUT then
          RaidTrace("TIMEOUT", guid, key, pending.spellID)
          -- No Judgement aura appeared: resist, miss, immune or failed cast.
          pendingForGUID[key] = nil
        end
      else
        local auraSpellID, auraTexture, auraStacks = FindMatchingAuraOnUnit(unit, pending.def, pending.spellID)
        if auraSpellID then
          local confirmed = {
            def = pending.def,
            spellID = auraSpellID,
            texture = auraTexture or pending.texture,
            duration = pending.duration,
            created = pending.created,
            stacks = auraStacks or 0,
            liveConfirmed = true,
          }
          CommitPendingAura(guid, key, confirmed, unit)
          pendingForGUID[key] = nil
        elseif now - pending.created > PENDING_TIMEOUT then
          RaidTrace("TIMEOUT", guid, key, pending.spellID)
          -- Effects not approved for the raid fallback remain strict.
          pendingForGUID[key] = nil
        end
      end
    end
  end
end

local function CleanupPending(now)
  local guid, entries, key, pending
  for guid, entries in pairs(BNP.pendingAuras) do
    local any = false
    for key, pending in pairs(entries) do
      if type(pending) == "table" then
        if now - pending.created > PENDING_TIMEOUT then
          entries[key] = nil
        else
          any = true
        end
      end
    end
    if not any then BNP.pendingAuras[guid] = nil end
  end
end


local AOE_PENDING_TIMEOUT = 1.5

local function QueueAoEAura(def, spellID, texture, duration)
  if not def or not spellID then return end
  BNP.pendingAoEAuras[def.key] = {
    def = def,
    spellID = spellID,
    texture = texture or def.texture,
    duration = duration,
    created = GetTime(),
  }
end

local function ConfirmAoEAurasOnUnit(unit, guid)
  if not unit or not guid then return end
  local key, pending
  for key, pending in pairs(BNP.pendingAoEAuras) do
    if type(pending) == "table" then
      local auraSpellID, auraTexture, auraStacks = FindMatchingAuraOnUnit(unit, pending.def, pending.spellID)
      if auraSpellID then
        CommitPendingAura(guid, pending.def.key, {
          def = pending.def,
          spellID = auraSpellID,
          texture = auraTexture or pending.texture,
          duration = pending.duration,
          created = pending.created,
          stacks = auraStacks or 0,
          liveConfirmed = true,
        }, unit)
      end
    end
  end
end

local function HasPendingAoEAuras()
  local key, pending
  for key, pending in pairs(BNP.pendingAoEAuras) do
    if type(pending) == "table" then return true end
  end
  return false
end

local function CleanupPendingAoE(now)
  local key, pending
  for key, pending in pairs(BNP.pendingAoEAuras) do
    if type(pending) == "table" and now - (pending.created or 0) > AOE_PENDING_TIMEOUT then
      BNP.pendingAoEAuras[key] = nil
    end
  end
end

local recentChannelAuras = {}

local function ChannelKey(guid, spellID)
  return tostring(guid or "-") .. ":" .. tostring(spellID or 0)
end

local castEvents = CreateFrame("Frame")
castEvents:RegisterEvent("UNIT_CASTEVENT")
castEvents:SetScript("OnEvent", function()
  local casterGUID = arg1
  local targetGUID = arg2
  local eventType = arg3
  local spellID = arg4
  local playerGUID = GetPlayerGUID()

  if not playerGUID or casterGUID ~= playerGUID then return end

  if eventType == "FAIL" then
    RaidTrace("FAIL", targetGUID, "-", spellID)
    FailPendingAura(targetGUID, spellID)
    RollbackAuraAttemptBySpell(targetGUID, spellID, "UNIT_FAIL")
    return
  end

  -- Dark Harvest has its own channel implementation and must not enter the
  -- generic aura pipeline below.
  if eventType == "CHANNEL" and spellID == DARK_HARVEST_SPELL_ID then
    StartDarkHarvest(targetGUID, arg5)
    return
  end

  if eventType ~= "CAST" and eventType ~= "CHANNEL" then return end

  -- Shadow audit only: this never changes the existing lookup or renderer.
  if BNP.AuditSpellDB then BNP:AuditSpellDB(spellID) end

  -- Paladin Judgement is a generic cast (20271). The actual debuff ID is only
  -- known after it lands on the target, so defer identification to UnitDebuff.
  if playerClass == "PALADIN" and spellID == PALADIN_JUDGEMENT_CAST_ID then
    if not targetGUID then return end

    if targetGUID then
      local judgementKeys = {}
      local _, judgementDef
      for _, judgementDef in ipairs(AURA_DEFS) do
        if IsJudgementDef(judgementDef) then judgementKeys[judgementDef.key] = true end
      end
      StartAuraCastAttempt(targetGUID, { key = "__judgement" }, spellID, judgementKeys)
    end

    local pendingForGUID = BNP.pendingAuras[targetGUID]
    if not pendingForGUID then
      pendingForGUID = {}
      BNP.pendingAuras[targetGUID] = pendingForGUID
    end

    pendingForGUID.__judgement = {
      judgementProbe = true,
      created = GetTime(),
    }
    return
  end

  -- Shadow Vulnerability uses one aura ID per talent rank. It is a shared
  -- raid debuff and has its own any-Warlock path below, so none of its ranks
  -- should enter the normal own-cast pending pipeline.
  local sid = tonumber(spellID)
  if playerClass == "WARLOCK" and (sid == 17794 or sid == 17797 or sid == 17798 or sid == 17799 or sid == 17800) then return end

  local def, texture = FindAuraDef(spellID)
  if not def then return end

  -- A few SuperWoW channel paths can omit arg2 briefly. A channel cannot move to
  -- a different target after it starts, so the real current target is a safe
  -- fallback here (unlike blindly doing this for every normal CAST event).
  if eventType == "CHANNEL" and not targetGUID then
    targetGUID = GetTargetGUID()
  end

  -- Channeled hostile effects are applied when SuperWoW emits CHANNEL, not when
  -- the channel later ends. Some clients may additionally emit CAST at the end;
  -- suppress that duplicate so the timer cannot restart after the channel. If a
  -- server exposes only CAST, the fallback remains available.
  if eventType == "CHANNEL" then
    if not def.channel then return end
    local channelMS = tonumber(arg5) or 0
    local hold = channelMS > 0 and (channelMS / 1000) or (def.duration or 1)
    recentChannelAuras[ChannelKey(targetGUID, spellID)] = GetTime() + hold + 0.75
  elseif def.channel then
    local untilTime = recentChannelAuras[ChannelKey(targetGUID, spellID)]
    if untilTime and GetTime() <= untilTime then return end
  end

  local duration = nil
  -- Resolve the exact rank that was cast. This preserves tooltip-derived talent
  -- or server modifications for that rank, while still falling back to the
  -- explicit rank table when the exact spellbook slot cannot be resolved.
  if BNP.GetSpellbookDurationForSpellID then
    duration = BNP:GetSpellbookDurationForSpellID(def, spellID)
  end
  duration = duration or (def.durations and def.durations[spellID])
  if not duration and BNP.GetSpellbookDurationForDef then
    duration = BNP:GetSpellbookDurationForDef(def)
  end
  duration = duration or def.duration

  if def.aoe then
    QueueAoEAura(def, spellID, texture, duration)
    return
  end

  if not targetGUID then return end

  StartAuraCastAttempt(targetGUID, def, spellID)

  local pendingForGUID = BNP.pendingAuras[targetGUID]
  if not pendingForGUID then
    pendingForGUID = {}
    BNP.pendingAuras[targetGUID] = pendingForGUID
  end

  pendingForGUID[def.key] = {
    def = def,
    spellID = spellID,
    texture = texture or def.texture,
    duration = duration,
    created = GetTime(),
  }

  RaidTrace("CAST", targetGUID, def.key, spellID)

  if IsCastPrimary(def) then
    local direct = {
      def = def,
      spellID = spellID,
      texture = texture or def.texture,
      duration = duration,
      created = GetTime(),
      stacks = 0,
      castPrimary = true,
    }
    CommitPendingAura(targetGUID, def.key, direct)
    local cache = BNP.guidAuras and BNP.guidAuras[targetGUID]
    if cache and cache[def.key] then
      cache[def.key].castPrimary = true
      cache[def.key].castPrimaryAt = GetTime()
      cache[def.key].liveConfirmed = nil
    end
    pendingForGUID[def.key] = nil
    RaidTrace("DIRECT", targetGUID, def.key, spellID)
    return
  end

  -- Fast path: if the cast target is still our current target, try to confirm
  -- immediately. The normal pending loop remains as the retry path.
  local currentTargetGUID = GetTargetGUID()
  if currentTargetGUID and currentTargetGUID == targetGUID then
    ConfirmPendingForUnit("target", targetGUID, GetTime())
  end
end)



-- Paladin Judgement melee refresh ------------------------------------------
-- Vanilla Judgement debuffs refresh when the judging Paladin lands a melee
-- strike on that target. The aura itself does not get re-cast, so UNIT_CASTEVENT
-- cannot update our timer. Refresh only an already-confirmed OWN Judgement.
local function RefreshOwnJudgementForGUID(guid)
  if playerClass ~= "PALADIN" or not guid then return end

  local cache = BNP.guidAuras[guid]
  if not cache then return end

  local _, def
  for _, def in ipairs(AURA_DEFS) do
    if IsJudgementDef(def) then
      local aura = cache[def.key]
      if type(aura) == "table" and aura.expires then
        local duration = aura.duration or def.duration or 10
        aura.duration = duration
        aura.expires = GetTime() + duration
        aura.confirmedAt = GetTime()
        aura.missingScans = nil
      end
    end
  end
end

-- SuperWoW gives us the target GUID of the player's current target. For normal
-- auto-attacks, the combat text event is sufficient to know a successful melee
-- hit occurred; matching the current target GUID keeps the refresh scoped to
-- the unit actually being attacked.
local judgementMeleeFrame = CreateFrame("Frame")
judgementMeleeFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
judgementMeleeFrame:SetScript("OnEvent", function()
  if playerClass ~= "PALADIN" then return end

  local guid = GetTargetGUID()
  if not guid then return end

  -- CHAT_MSG_COMBAT_SELF_HITS only fires for landed melee attacks (hit/crit).
  RefreshOwnJudgementForGUID(guid)
end)



-- Holy Strike also counts as a melee-style Judgement refresh on Turtle/Octo.
-- It is reported via CHAT_MSG_SPELL_SELF_DAMAGE rather than the normal melee
-- hit event and does not expose a useful spell ID in this client.
local holyStrikeRefreshFrame = CreateFrame("Frame")
holyStrikeRefreshFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
holyStrikeRefreshFrame:SetScript("OnEvent", function()
  if playerClass ~= "PALADIN" then return end

  local raw = arg1
  if not raw then return end

  -- Only successful Holy Strike hit messages refresh the timer.
  -- Miss/resist/immune lines do not match this pattern.
  if not string.find(raw, "^Your Holy Strike hits ") then return end

  local guid = GetTargetGUID()
  if not guid then return end

  -- Extra safety: when the target name is available, require it to be present
  -- in the combat-log line so a stale/current target cannot refresh another GUID.
  local targetName = UnitName("target")
  if targetName and targetName ~= "" and not string.find(raw, targetName, 1, true) then
    return
  end

  RefreshOwnJudgementForGUID(guid)
end)


-- Enemy Feign Death / Vanish protection.
local pvpDisappearFrame = CreateFrame("Frame")
pvpDisappearFrame:RegisterEvent("UNIT_CASTEVENT")
pvpDisappearFrame:SetScript("OnEvent", function()
  local casterGUID = arg1
  local eventType = arg3
  local spellID = arg4

  if not casterGUID or not spellID or not SpellInfo then return end
  if eventType ~= "CAST" and eventType ~= "START" then return end

  local spellName = SpellInfo(spellID)

  -- Abilities that can temporarily drop target/nameplate visibility without
  -- actually cleansing existing harmful effects.
  local TEMPORARY_DISAPPEAR = {
    ["Feign Death"] = true,
    ["Vanish"] = true,
    ["Shadowmeld"] = true,
  }

  if spellName and TEMPORARY_DISAPPEAR[spellName] then
    ProtectAuraCache(casterGUID, spellName)
  end
end)



-- Shared/global aura exceptions ---------------------------------------------
-- Most BNP debuffs are strictly "own casts only". A very small number of
-- effects are globally unique on a target and are useful even when applied by
-- another player. These are explicitly opted in via def.shared = true.
local LIVE_DEBUFF_SNAPSHOT = { entries = {}, count = 0, time = 0 }

-- Capture UnitDebuff once and reuse that exact snapshot for shared-aura sync
-- and removal sync in the same 0.10s scan. This avoids scanning the same
-- SuperWoW unit twice (or more) per plate while keeping behavior identical.
local function CaptureLiveDebuffSnapshot(unit, now)
  local snap = LIVE_DEBUFF_SNAPSHOT
  local entries = snap.entries
  local count = 0
  local i

  snap.time = now or GetTime()

  for i = 1, 64 do
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = UnitDebuff(unit, i)
    if not a1 then break end

    count = count + 1
    local entry = entries[count]
    if not entry then
      entry = {}
      entries[count] = entry
    end

    entry[1] = a1
    entry[2] = a2
    entry[3] = a3
    entry[4] = a4
    entry[5] = a5
    entry[6] = a6
    entry[7] = a7
    entry[8] = a8
    entry[9] = a9
    entry[10] = a10
  end

  snap.count = count
  return snap
end

local function ClassicAPIAuraDataAvailable()
  return type(C_UnitAuras) == "table" and type(C_UnitAuras.GetDebuffDataByIndex) == "function"
end

-- ClassicAPI exposes the real hostile-aura duration and absolute expiration.
-- Use it only for the isolated shared Shadow Vulnerability path; all normal own
-- debuffs keep their existing proven tracking pipeline unchanged.
local function FindClassicAPISharedAura(unit, def)
  if not ClassicAPIAuraDataAvailable() then return nil, nil, nil, nil, nil, false end

  local i
  for i = 1, 64 do
    local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, unit, i)
    if not ok then return nil, nil, nil, nil, nil, false end
    if not aura then break end

    local spellID = tonumber(aura.spellId or aura.spellID)
    local matches = false
    if def.sharedSpellIDs and spellID then
      local _, knownID
      for _, knownID in ipairs(def.sharedSpellIDs) do
        if spellID == knownID then
          matches = true
          break
        end
      end
    end
    if not matches and aura.name then matches = NameMatches(def, aura.name) end

    if matches then
      return spellID, aura.icon, tonumber(aura.duration), tonumber(aura.expirationTime),
        tonumber(aura.applications) or 0, true
    end
  end

  -- A successful empty ClassicAPI scan is authoritative for absence. The
  -- existing short missing grace protects against transient token updates.
  return nil, nil, nil, nil, nil, true
end

local function FindSharedAuraOnUnit(unit, def, snapshot)
  if not unit or not def then return nil, nil, nil, nil, nil, false end

  if def.key == "shadow_vulnerability" then
    local spellID, texture, duration, expires, stacks, authoritative =
      FindClassicAPISharedAura(unit, def)
    if authoritative then return spellID, texture, duration, expires, stacks, true end
  end

  local maxIndex = snapshot and snapshot.count or 64
  local now = snapshot and snapshot.time or GetTime()
  local i
  for i = 1, maxIndex do
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10

    if snapshot then
      local entry = snapshot.entries[i]
      if not entry then break end
      a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 =
        entry[1], entry[2], entry[3], entry[4], entry[5],
        entry[6], entry[7], entry[8], entry[9], entry[10]
    else
      a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = UnitDebuff(unit, i)
      if not a1 then break end
    end

    local texture = a1
    local auraSpellID = a4
    if not texture then break end

    local auraName = nil
    if auraSpellID and SpellInfo then
      auraName = SpellInfo(auraSpellID)
    end

    local sharedMatches = nil
    if def.sharedSpellIDs and auraSpellID then
      sharedMatches = false
      local _, sharedSpellID
      for _, sharedSpellID in ipairs(def.sharedSpellIDs) do
        if auraSpellID == sharedSpellID then
          sharedMatches = true
          break
        end
      end
    end

    -- Some different class talents use the same localized aura name. Shared
    -- effects may therefore opt into exact aura IDs instead of name matching.
    if sharedMatches == true or (sharedMatches == nil and AuraMatches(def, auraName, texture)) then
      -- SuperWoW/extended clients may append duration/expiration data.
      -- Probe plausible numeric return pairs without assuming one exact fork.
      local duration, expires
      local vals = { a5, a6, a7, a8, a9, a10 }
      local n
      for n = 1, table.getn(vals) - 1 do
        local d = vals[n]
        local e = vals[n + 1]
        if type(d) == "number" and type(e) == "number"
          and d > 0 and d <= 3600 and e > now then
          duration = d
          expires = e
          break
        end
      end

      return auraSpellID, texture, duration, expires, tonumber(a2) or 0, false
    end
  end

  return nil, nil, nil, nil, nil, false
end

local SV_SHARED_MISSING_GRACE = 0.45

local function SyncShadowVulnerabilityPresence(unit, guid, now, def, auraSpellID, texture, liveStacks, liveDuration, liveExpires, classicAPIAuthoritative)
  local cache = BNP.guidAuras[guid]
  local state = BNP.svStateByGUID[guid]

  -- ClassicAPI can keep an expired AuraData row around briefly before the
  -- next UNIT_AURA cleanup. A positive expirationTime in the past is proof
  -- that this row is stale; never turn it into a fresh estimated 10 seconds.
  -- A newer RAW_COMBATLOG application may temporarily outrun the API update,
  -- so preserve that independently proven future expiration when present.
  local previousExpires = state and tonumber(state.expires) or nil
  local explicitExpired = liveExpires and liveExpires > 0 and liveExpires <= now
  local provenFuture = state and state.provenExpires and state.provenExpires > now
  if explicitExpired and not provenFuture then
    BNP.svStateByGUID[guid] = nil
    BNP.svExpiryByGUID[guid] = nil
    if BNP.svRenderRevisionByGUID then BNP.svRenderRevisionByGUID[guid] = nil end
    if cache then cache[def.key] = nil end
    return
  end

  -- Some ClassicAPI builds replace expirationTime with 0/nil while retaining
  -- the expired AuraData row for another update or two. Once ClassicAPI has
  -- answered authoritatively, never manufacture a timer from that incomplete
  -- row. Keep only an already-known future expiry or a proven raw reapply.
  local classicRowWithoutFutureExpiry = classicAPIAuthoritative and
    (auraSpellID or texture) and not (liveExpires and liveExpires > now)
  local previousFuture = previousExpires and previousExpires > now
  if classicRowWithoutFutureExpiry and not provenFuture and not previousFuture then
    BNP.svStateByGUID[guid] = nil
    BNP.svExpiryByGUID[guid] = nil
    if BNP.svRenderRevisionByGUID then BNP.svRenderRevisionByGUID[guid] = nil end
    if cache then cache[def.key] = nil end
    return
  end

  if auraSpellID or texture then
    if not state then
      state = {
        present = true,
        lastSeen = now,
      }
      BNP.svStateByGUID[guid] = state
    end

    state.present = true
    state.lastSeen = now
    state.duration = (liveDuration and liveDuration > 0 and liveDuration) or state.duration or def.duration or 10

    if state.provenExpires and state.provenExpires <= now then state.provenExpires = nil end
    local apiExpires = liveExpires and liveExpires > now and liveExpires or nil
    local chosenExpires = apiExpires
    if state.provenExpires and (not chosenExpires or state.provenExpires > chosenExpires) then
      chosenExpires = state.provenExpires
    end
    if not chosenExpires and previousExpires and previousExpires > now then chosenExpires = previousExpires end
    if not chosenExpires then
      chosenExpires = now + state.duration
      state.estimated = true
    else
      state.estimated = nil
    end

    state.expires = chosenExpires
    state.apiExpires = apiExpires
    if previousExpires and chosenExpires > previousExpires + 0.05 then
      state.lastRefresh = now
      BNP.svRenderRevisionByGUID[guid] = (BNP.svRenderRevisionByGUID[guid] or 0) + 1
      state.renderRevision = BNP.svRenderRevisionByGUID[guid]
      RaidTrace("SV_CLASSICAPI_REFRESH", guid, def.key, auraSpellID or 17794)
    end

    state.spellID = auraSpellID or state.spellID or 17794
    state.texture = texture or state.texture or def.texture
    state.stacks = tonumber(liveStacks) or state.stacks or 0
    BNP.svExpiryByGUID[guid] = state.expires

    if not cache then
      cache = {}
      BNP.guidAuras[guid] = cache
    end
    local aura = cache[def.key]
    if not aura then
      cache._nextOrder = (cache._nextOrder or 0) + 1
      aura = { order = cache._nextOrder }
      cache[def.key] = aura
    end

    aura.sharedLive = true
    aura.spellID = state.spellID
    aura.texture = state.texture
    aura.stacks = state.stacks
    aura.duration = state.duration
    aura.expires = state.expires
    aura.confirmedAt = aura.confirmedAt or now
    aura.sharedLastSeen = now
    aura.sharedEstimated = state.estimated and true or nil
    return
  end

  -- One empty SuperWoW/UnitDebuff snapshot is not authoritative. Only remove
  -- the shared state after no token has positively seen it for a short grace.
  if state and now - (state.lastSeen or 0) >= SV_SHARED_MISSING_GRACE then
    BNP.svStateByGUID[guid] = nil
    BNP.svExpiryByGUID[guid] = nil
    if BNP.svRenderRevisionByGUID then BNP.svRenderRevisionByGUID[guid] = nil end
    if cache then cache[def.key] = nil end
  end
end

local function SyncSharedAuras(unit, guid, now, snapshot)
  if not unit or not guid then return end

  local _, def
  for _, def in ipairs(AURA_DEFS) do
    if def.shared then
      local auraSpellID, texture, liveDuration, liveExpires, liveStacks, classicAPIAuthoritative =
        FindSharedAuraOnUnit(unit, def, snapshot)

      -- Shadow Vulnerability is deliberately isolated from the generic shared
      -- aura timer path. Its GUID state is the only owner of its countdown.
      if def.key == "shadow_vulnerability" then
        SyncShadowVulnerabilityPresence(
          unit, guid, now, def, auraSpellID, texture, liveStacks, liveDuration,
          liveExpires, classicAPIAuthoritative
        )
      else
        local cache = BNP.guidAuras[guid]

        if auraSpellID or texture then
          if not cache then
            cache = {}
            BNP.guidAuras[guid] = cache
          end

          local aura = cache[def.key]
          -- Never overwrite an accurately timed own aura with the shared/live
          -- fallback. Shared entries exist only when we don't own the timer.
          if not aura or aura.sharedLive then
            if not aura then
              cache._nextOrder = (cache._nextOrder or 0) + 1
              aura = { order = cache._nextOrder }
            end

            aura.sharedLive = true
            aura.spellID = auraSpellID
            aura.texture = texture or def.texture
            aura.confirmedAt = now
            aura.sharedLastSeen = now

            local previousStacks = tonumber(aura.stacks) or 0
            local currentStacks = tonumber(liveStacks) or 0
            if currentStacks > previousStacks and aura.expires then
              aura.duration = def.duration or aura.duration or 10
              aura.expires = now + aura.duration
              aura.sharedEstimated = true
              RaidTrace("SHARED_STACK_REFRESH", guid, def.key, auraSpellID)
            end
            aura.stacks = currentStacks

            if liveExpires and liveExpires > now then
              aura.duration = liveDuration
              aura.expires = liveExpires
              aura.sharedEstimated = nil
            elseif not aura.expires then
              aura.duration = def.duration or 120
              aura.expires = now + aura.duration
              aura.sharedEstimated = true
            end

            cache[def.key] = aura
          end
        elseif cache and cache[def.key] and cache[def.key].sharedLive then
          local aura = cache[def.key]
          local lastSeen = aura.sharedLastSeen or aura.confirmedAt or 0
          if now - lastSeen >= 0.40 then cache[def.key] = nil end
        end
      end
    end
  end
end


-- Live aura removal ---------------------------------------------------------
-- Timers alone are not enough for CC/roots/traps: effects may be dispelled,
-- broken by damage, removed by trinkets, or otherwise end early.
--
-- We NEVER create auras from this scan. It may only remove already-confirmed
-- own auras from the GUID cache when their exact spell ID is no longer present.
local REMOVAL_SCAN_INTERVAL = 0.10
local REMOVAL_GRACE = 0.35
local NORMAL_REMOVAL_MISSING_SCANS = 4
-- Projected non-target nameplate tokens can briefly return an incomplete
-- UnitDebuff list when many plates overlap in raids. CC used to be deleted on
-- the first such miss, which made Banish/roots/stuns blink. Require a few
-- consecutive misses for non-target CC while keeping the real target strict.
local EXACT_NON_TARGET_MISSING_SCANS = 3

local function CacheHasTrackedAuras(cache)
  if not cache then return false end
  local key, aura
  for key, aura in pairs(cache) do
    if type(aura) == "table" and aura.spellID and aura.expires then
      return true
    end
  end
  return false
end

local CHANNEL_LIVE_REMOVAL = {
  drain_life=true, drain_soul=true,
  mind_flay=true, starshards=true, mind_control=true,
}

local EXACT_LIVE_REMOVAL = {
  -- Warlock
  fear=true, howl_of_terror=true, banish=true, death_coil=true,
  -- Hunter
  freezing_trap_effect=true, improved_wing_clip=true, improved_concussive_shot=true,
  scatter_shot=true, wyvern_sting=true, entrapment=true, counterattack=true,
  intimidation=true, scare_beast=true,
  -- Mage
  polymorph=true, frost_nova=true, counterspell_silence=true, impact=true, frostbite=true,
  -- Priest
  psychic_scream=true, silence=true, blackout=true, shackle_undead=true, mind_control=true,
  -- Paladin
  hammer_of_justice=true, repentance=true, turn_undead=true,
  -- Rogue
  gouge=true, kidney_shot=true, cheap_shot=true, sap=true, blind=true, kick_silenced=true,
  -- Druid
  entangling_roots=true, bash=true, pounce=true, hibernate=true, feral_charge_effect=true,
  -- Warrior
  improved_hamstring=true, intimidating_shout=true, disarm=true, charge_stun=true,
  intercept_stun=true, concussion_blow=true, revenge_stun=true, pummel=true, shield_bash=true,
  -- Shaman / custom roots
  earthgrab=true,
}

local function NeedsExactLiveRemoval(key)
  return EXACT_LIVE_REMOVAL[key] and true or false
end

local function IsCrowdControlDef(def)
  return def and EXACT_LIVE_REMOVAL[def.key] and true or false
end

local function GetEntryIconSize(entry, forceCC)
  if forceCC or (entry and IsCrowdControlDef(entry.def)) then
    return GetCCIconSize()
  end
  return GetIconSize()
end

local function ApplyIconDimensions(icon, size)
  if not icon or not size then return end
  if icon.BNPLayoutSize ~= size then
    icon:SetWidth(size)
    icon:SetHeight(size)
    icon.BNPLayoutSize = size
  end
end

local function LayoutActiveIcons(container, active, visibleCount, forceCC)
  if not container then return end
  local position = forceCC and GetCCPosition() or GetDebuffPosition()
  local sizes = {}
  local totalWidth = 0
  local maxSize = 0
  local i

  for i = 1, visibleCount do
    local size = GetEntryIconSize(active[i], forceCC)
    sizes[i] = size
    totalWidth = totalWidth + size
    if size > maxSize then maxSize = size end
  end
  if visibleCount > 1 then totalWidth = totalWidth + ICON_SPACING * (visibleCount - 1) end

  local maxConfigured = math.max(GetIconSize(), GetCCIconSize())
  local maxWidth = maxConfigured * MAX_VISIBLE_ICONS + ICON_SPACING * (MAX_VISIBLE_ICONS - 1)
  container:SetWidth(maxWidth)
  container:SetHeight(maxSize > 0 and maxSize or maxConfigured)

  local cursor
  if position == "left" then
    cursor = 0
    for i = 1, visibleCount do
      local icon = container.icons[i]
      local size = sizes[i]
      ApplyIconDimensions(icon, size)
      icon:ClearAllPoints()
      icon:SetPoint("RIGHT", container, "RIGHT", -cursor, 0)
      cursor = cursor + size + ICON_SPACING
    end
  elseif position == "right" then
    cursor = 0
    for i = 1, visibleCount do
      local icon = container.icons[i]
      local size = sizes[i]
      ApplyIconDimensions(icon, size)
      icon:ClearAllPoints()
      icon:SetPoint("LEFT", container, "LEFT", cursor, 0)
      cursor = cursor + size + ICON_SPACING
    end
  else
    cursor = (maxWidth - totalWidth) / 2
    for i = 1, visibleCount do
      local icon = container.icons[i]
      local size = sizes[i]
      ApplyIconDimensions(icon, size)
      icon:ClearAllPoints()
      icon:SetPoint("LEFT", container, "LEFT", cursor, 0)
      cursor = cursor + size + ICON_SPACING
    end
  end
end

local function ShouldDisplayAuraDef(def)
  if IsCrowdControlDef(def) then
    if BNP.AreCrowdControlEnabled and not BNP:AreCrowdControlEnabled() then return false end
    if UseDedicatedCCContainer() then return false end
    return true
  end
  return not BNP.AreDebuffsEnabled or BNP:AreDebuffsEnabled()
end


-- Separate CC display -------------------------------------------------------
-- This layer is intentionally independent from guidAuras. It may display live
-- CCs from other players, but it can never create, refresh, remove or alter an
-- own DoT/debuff timer.
local GLOBAL_CC_DEFS = {}
local GLOBAL_CC_BY_ID = {}
local GLOBAL_CC_NEGATIVE = {}
local seenGlobalCC = {}

local function BuildGlobalCCDefs()
  local _, defs, _, ccDef, _, sid
  for _, defs in pairs(CLASS_AURAS) do
    for _, ccDef in ipairs(defs or {}) do
      if IsCrowdControlDef(ccDef) and not seenGlobalCC[ccDef.key] then
        seenGlobalCC[ccDef.key] = true
        table.insert(GLOBAL_CC_DEFS, ccDef)
        if ccDef.spellIDs then
          for _, sid in ipairs(ccDef.spellIDs) do GLOBAL_CC_BY_ID[sid] = ccDef end
        end
        if ccDef.durations then
          for sid in pairs(ccDef.durations) do GLOBAL_CC_BY_ID[sid] = ccDef end
        end
      end
    end
  end
end
BuildGlobalCCDefs()

local function ResolveGlobalCCDef(spellID, texture)
  if spellID and GLOBAL_CC_BY_ID[spellID] then return GLOBAL_CC_BY_ID[spellID] end
  if spellID and GLOBAL_CC_NEGATIVE[spellID] then return nil end

  local auraName = spellID and SpellInfo and SpellInfo(spellID) or nil
  local _, ccDef
  for _, ccDef in ipairs(GLOBAL_CC_DEFS) do
    if NameMatches(ccDef, auraName)
      or (texture and ccDef.textureMatch and string.find(string.lower(texture), ccDef.textureMatch)) then
      if spellID then GLOBAL_CC_BY_ID[spellID] = ccDef end
      return ccDef
    end
  end

  if spellID then GLOBAL_CC_NEGATIVE[spellID] = true end
  return nil
end

local function WantsForeignCCs()
  return BNP.AreCrowdControlEnabled and BNP:AreCrowdControlEnabled()
    and BNP.ShowOtherPlayersCCs and BNP:ShowOtherPlayersCCs()
end

local function SyncForeignCCs(unit, guid, now)
  if not unit or not guid then return end
  if not WantsForeignCCs() then
    BNP.guidLiveCCs[guid] = nil
    return
  end

  local seen = {}
  local live = BNP.guidLiveCCs[guid]
  local i
  for i = 1, 64 do
    local texture, stacks, dtype, auraSpellID = UnitDebuff(unit, i)
    if not texture then break end

    local ccDef = ResolveGlobalCCDef(auraSpellID, texture)
    if ccDef then
      seen[ccDef.key] = true
      if not live then
        live = {}
        BNP.guidLiveCCs[guid] = live
      end

      local aura = live[ccDef.key]
      if not aura then
        aura = { firstSeen = now, order = now }
        live[ccDef.key] = aura
      end
      aura.def = ccDef
      aura.spellID = auraSpellID
      aura.texture = texture or ccDef.texture
      aura.stacks = tonumber(stacks) or 0
      aura.lastSeen = now
      aura.missingScans = nil
      -- Vanilla/SuperWoW does not reliably provide foreign application time.
      -- Use a conservative local estimate for text only; live aura presence is
      -- authoritative for appearance/removal.
      if not aura.expires and ccDef.duration then
        aura.expires = now + ccDef.duration
      end
    end
  end

  if live then
    local key, aura
    for key, aura in pairs(live) do
      if not seen[key] then
        aura.missingScans = (aura.missingScans or 0) + 1
        -- A single empty projected UnitDebuff scan is common with tightly
        -- stacked raid nameplates. Keep the last positive CC sighting through
        -- two misses so foreign Banish/CC does not visibly blink.
        if aura.missingScans >= 3 and now - (aura.lastSeen or 0) >= 0.40 then
          live[key] = nil
        end
      else
        aura.missingScans = nil
      end
    end
  end
end

local function HideCCRow(plate)
  local container = plate and plate.BNPCCContainer
  if not container then return end
  local i
  for i = 1, table.getn(container.icons or {}) do
    local icon = container.icons[i]
    icon.lastTimerText = nil
    icon.timer:SetText("")
    if icon.stack then icon.stack:SetText("") end
    icon:Hide()
  end
  container:Hide()
end

local function FormatCCTimer(remaining)
  if not remaining or remaining <= 0 then return "" end
  if remaining >= 3600 then
    return math.ceil(remaining / 3600) .. "h"
  elseif remaining >= 60 then
    return math.ceil(remaining / 60) .. "m"
  end
  return tostring(math.ceil(remaining))
end

local function UpdateCCRow(plate, guid, cache, now)
  if not UseDedicatedCCContainer()
    or (BNP.AreCrowdControlEnabled and not BNP:AreCrowdControlEnabled()) then
    HideCCRow(plate)
    return
  end

  if not plate.BNPCCContainer then CreateCCContainer(plate) end
  local container = plate.BNPCCContainer
  if not container then return end

  local active = container.activeAuras
  if not active then active = {}; container.activeAuras = active end
  local pool = container.activeAuraPool
  if not pool then
    pool = {}
    for i = 1, MAX_VISIBLE_ICONS do pool[i] = {} end
    container.activeAuraPool = pool
  end
  local oldCount = table.getn(active)
  for i = 1, oldCount do active[i] = nil end
  local count = 0
  local seenOwn = {}

  local _, ccDef
  for _, ccDef in ipairs(AURA_DEFS) do
    if IsCrowdControlDef(ccDef) then
      local aura = cache and cache[ccDef.key]
      local remaining = aura and aura.expires and (aura.expires - now) or nil
      local sharedLive = aura and aura.sharedLive
      if aura and (sharedLive or (remaining and remaining > 0)) then
        count = count + 1
        if count <= MAX_VISIBLE_ICONS then
          local entry = pool[count]
          active[count] = entry
          entry.def = ccDef
          entry.aura = aura
          entry.remaining = remaining
          seenOwn[ccDef.key] = true
        end
      end
    end
  end

  if WantsForeignCCs() then
    local live = guid and BNP.guidLiveCCs[guid]
    local key, aura
    for key, aura in pairs(live or {}) do
      if count >= MAX_VISIBLE_ICONS then break end
      if aura.def and not seenOwn[key] and now - (aura.lastSeen or 0) <= 0.60 then
        count = count + 1
        local entry = pool[count]
        active[count] = entry
        entry.def = aura.def
        entry.aura = aura
        entry.remaining = aura.expires and (aura.expires - now) or nil
      end
    end
  end

  table.sort(active, function(a, b)
    return (a.aura.order or a.aura.firstSeen or 0) < (b.aura.order or b.aura.firstSeen or 0)
  end)

  local visibleCount = table.getn(active)
  local iconSize = GetCCIconSize()
  local position = GetCCPosition()
  local layoutChanged = container.BNPLastVisibleCount ~= visibleCount
    or container.BNPLastCCIconSize ~= iconSize
    or container.BNPLastPosition ~= position
  if layoutChanged then
    container.BNPLastVisibleCount = visibleCount
    container.BNPLastCCIconSize = iconSize
    container.BNPLastPosition = position
    if visibleCount > 0 then LayoutActiveIcons(container, active, visibleCount, true) end
  end

  local i
  for i = 1, table.getn(container.icons) do
    local icon = container.icons[i]
    local entry = active[i]
    if entry then
      icon.texture:SetTexture(entry.aura.texture or entry.def.texture)
      local stackCount = tonumber(entry.aura.stacks) or 0
      if icon.stack then
        if stackCount > 1 then icon.stack:SetText(tostring(stackCount)) else icon.stack:SetText("") end
      end
      local timerText = FormatCCTimer(entry.remaining)
      if icon.lastTimerText ~= timerText then icon.timer:SetText(timerText); icon.lastTimerText = timerText end
      icon:Show()
    else
      icon.lastTimerText = nil
      icon.timer:SetText("")
      if icon.stack then icon.stack:SetText("") end
      icon:Hide()
    end
  end

  if visibleCount > 0 then container:Show() else container:Hide() end
end

local function SyncAuraRemoval(unit, guid, now, snapshot)
  if not unit or not guid then return end
  if AuraCacheProtected(guid, now) then return end
  local cache = BNP.guidAuras[guid]
  if not CacheHasTrackedAuras(cache) then return end

  local present = {}
  local i
  local maxIndex = snapshot and snapshot.count or 64
  for i = 1, maxIndex do
    local texture, stacks, dtype, auraSpellID
    if snapshot then
      local entry = snapshot.entries[i]
      if not entry then break end
      texture, stacks, dtype, auraSpellID = entry[1], entry[2], entry[3], entry[4]
    else
      texture, stacks, dtype, auraSpellID = UnitDebuff(unit, i)
      if not texture then break end
    end

    if auraSpellID then
      present[auraSpellID] = true

      local trackedKey, trackedAura
      for trackedKey, trackedAura in pairs(cache) do
        if type(trackedAura) == "table" and trackedAura.spellID == auraSpellID then
          trackedAura.stacks = tonumber(stacks) or 0
        end
      end
    end
  end

  -- Resolve current-target identity once per scan, not once per tracked aura.
  -- Knowing the target GUID for projected units also lets exact CC removal stay
  -- immediate on the real target but conservative on crowded non-target plates.
  local currentTargetGUID = GetTargetGUID()
  local playerRemoval = false
  if unit == "target" and UnitIsPlayer and UnitIsPlayer("target") then
    playerRemoval = currentTargetGUID and currentTargetGUID == guid
  end

  local key, aura
  for key, aura in pairs(cache) do
    if type(aura) == "table" and aura.spellID and aura.expires and key ~= "shadow_vulnerability" then
      -- Give the client a tiny grace period immediately after confirmation so
      -- transient aura-list updates cannot remove a freshly-landed effect.
      local age = now - (aura.confirmedAt or 0)
      local exactRemoval = NeedsExactLiveRemoval(key)

      -- Normal DoTs on player nameplates are only safe to live-remove from the
      -- CURRENT target. During target switches, non-target SuperWoW nameplate
      -- tokens can briefly expose an incomplete/empty UnitDebuff list. Treating
      -- that as a dispel caused valid DoTs to disappear from the GUID cache.
      --
      -- CC/root/trap effects still use live removal on every visible plate. The
      -- real target is immediate; projected non-targets require a few misses so
      -- one crowded-raid scan cannot make Banish/CC blink.
      -- Channeled debuffs should end when the channel is interrupted/cancelled,
      -- but only trust the real current-target UnitDebuff list for this. Busy
      -- non-target nameplate tokens remain intentionally non-authoritative.
      local channelRemoval = CHANNEL_LIVE_REMOVAL[key]
        and currentTargetGUID and currentTargetGUID == guid

      if age >= REMOVAL_GRACE then
        if present[aura.spellID] then
          -- Positive live sighting upgrades a CAST-seeded timer. Once upgraded,
          -- normal dispel/early-removal logic is safe again.
          aura.missingScans = nil
          aura.exactMissingScans = nil
          if aura.castPrimary then
            aura.castPrimary = nil
            aura.castPrimaryAt = nil
            aura.liveConfirmed = true
          end
        elseif channelRemoval then
          RaidTrace("CHANNEL_REMOVE", guid, key, aura.spellID)
          cache[key] = nil
        elseif exactRemoval then
          if currentTargetGUID and currentTargetGUID == guid then
            RaidTrace("REMOVE", guid, key, aura.spellID)
            -- The real target unit is authoritative, so CC can still disappear
            -- immediately when it is broken/dispelled.
            cache[key] = nil
          else
            -- Non-target SuperWoW tokens can return one empty/incomplete aura
            -- list while plates overlap. Do not turn that one bad sample into
            -- a visible Banish/CC blink.
            aura.exactMissingScans = (aura.exactMissingScans or 0) + 1
            if aura.exactMissingScans >= EXACT_NON_TARGET_MISSING_SCANS then
              RaidTrace("REMOVE", guid, key, aura.spellID)
              cache[key] = nil
            end
          end
        elseif playerRemoval then
          if aura.castPrimary then
            -- CAST-seeded auras may be omitted by crowded raid UnitDebuff lists.
            -- Do not use that same missing list to remove it early.
            aura.missingScans = nil
          else
            -- Normal positively-confirmed player DoTs/curses use conservative
            -- removal and still react to real dispels.
            aura.missingScans = (aura.missingScans or 0) + 1

            if aura.missingScans >= NORMAL_REMOVAL_MISSING_SCANS then
              RaidTrace("REMOVE", guid, key, aura.spellID)
              cache[key] = nil
            end
          end
        end
      end
    end
  end
end

local function FormatTimer(remaining)
  if not remaining or remaining <= 0 then return "" end

  -- Keep long durations compact on the small nameplate icons.
  -- Examples: 300s -> 5m, 61s -> 2m, 59s -> 59.
  if remaining >= 3600 then
    return math.ceil(remaining / 3600) .. "h"
  elseif remaining >= 60 then
    return math.ceil(remaining / 60) .. "m"
  end

  return tostring(math.ceil(remaining))
end

-- Nameplate GUID stability ---------------------------------------------------
-- Blizzard/SuperWoW can briefly recycle a visible plate while LOS/occlusion
-- changes (for example when a wall is between the player and nearby mobs).
-- During that tiny transition plate:GetName(1) may still expose the previous
-- unit GUID. Rendering that GUID's cache causes "ghost DoTs" on an unrelated
-- mob for a frame or two.
--
-- Require the same GUID on two consecutive renderer updates before using its
-- aura cache. This does not change aura tracking itself; it only gates display.
local AURA_GUID_TRANSIENT_HOLD = 0.75
local AURA_GUID_CONFIRM_UPDATES = 2
local AURA_GUID_SWITCH_CONFIRM_UPDATES = 8

local function PinExactTargetPlate(plate, now)
  if not plate or not C_NamePlate or
     type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
    return nil
  end

  local targetGUID = GetTargetGUID()
  if not targetGUID then return nil end

  local ok, targetPlate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
  if not ok or not targetPlate or targetPlate ~= plate then return nil end

  -- The real target is the one projected unit ClassicAPI can resolve exactly.
  -- Pinning it here prevents a crowded SuperWoW plate token from replacing the
  -- target GUID for a few renderer ticks. When the player switches away, this
  -- stable mapping remains useful for that now-non-target plate.
  plate.BNPAuraGUIDStable = targetGUID
  plate.BNPAuraGUIDCandidate = targetGUID
  plate.BNPAuraGUIDCandidateCount = AURA_GUID_SWITCH_CONFIRM_UPDATES
  plate.BNPAuraGUIDLastGoodAt = now
  plate.BNPAuraForceFreshIdentity = nil
  return targetGUID
end

local function StableNameStillMatches(plate, stableGUID)
  if not plate or not stableGUID or not plate.name or not plate.name.GetText then
    return true
  end
  local oldName = BNP.guidNames and BNP.guidNames[stableGUID]
  local visibleName = plate.name:GetText()
  if oldName and visibleName and oldName ~= "" and visibleName ~= "" then
    return oldName == visibleName
  end
  return true
end

local function GetStablePlateGUID(plate, now)
  if not plate then return nil end
  now = now or GetTime()

  -- Exact current-target frame identity always wins over projected token data.
  local exactTargetGUID = PinExactTargetPlate(plate, now)
  if exactTargetGUID then return exactTargetGUID end

  local guid = GetPlateGUID(plate)
  local stable = plate.BNPAuraGUIDStable

  -- Dense 40-player stacks can briefly lose the projected token. Keep the last
  -- confirmed identity long enough to bridge those gaps instead of hiding the
  -- whole icon row for one or two renderer ticks.
  if not guid then
    plate.BNPAuraGUIDCandidate = nil
    plate.BNPAuraGUIDCandidateCount = 0
    if stable and plate.BNPAuraGUIDLastGoodAt and
       now - plate.BNPAuraGUIDLastGoodAt <= AURA_GUID_TRANSIENT_HOLD and
       not plate.BNPAuraForceFreshIdentity then
      return stable
    end
    return nil
  end

  if stable and guid == stable then
    plate.BNPAuraGUIDCandidate = guid
    plate.BNPAuraGUIDCandidateCount = AURA_GUID_SWITCH_CONFIRM_UPDATES
    plate.BNPAuraGUIDLastGoodAt = now
    plate.BNPAuraForceFreshIdentity = nil
    return stable
  end

  if plate.BNPAuraGUIDCandidate ~= guid then
    plate.BNPAuraGUIDCandidate = guid
    plate.BNPAuraGUIDCandidateCount = 1

    -- If Blizzard really reused the frame for a differently named unit, switch
    -- quickly. Same-name raid mobs are exactly where transient GUID/token swaps
    -- happen, so keep the previous stable GUID until the new candidate persists.
    if stable and not plate.BNPAuraForceFreshIdentity and
       StableNameStillMatches(plate, stable) then
      return stable
    end
    return nil
  end

  plate.BNPAuraGUIDCandidateCount = (plate.BNPAuraGUIDCandidateCount or 1) + 1

  local required = AURA_GUID_SWITCH_CONFIRM_UPDATES
  if plate.BNPAuraForceFreshIdentity or
     (stable and not StableNameStillMatches(plate, stable)) then
    required = AURA_GUID_CONFIRM_UPDATES
  end

  if plate.BNPAuraGUIDCandidateCount < required then
    if stable and not plate.BNPAuraForceFreshIdentity and
       StableNameStillMatches(plate, stable) then
      return stable
    end
    return nil
  end

  plate.BNPAuraGUIDStable = guid
  plate.BNPAuraGUIDLastGoodAt = now
  plate.BNPAuraForceFreshIdentity = nil
  return guid
end

local function UpdatePlate(plate, now)
  if BNP.AreAnyAurasEnabled and not BNP:AreAnyAurasEnabled() then
    if plate and plate.BNPAuraContainer then
      local i
      for i = 1, MAX_VISIBLE_ICONS do
        local icon = plate.BNPAuraContainer.icons and plate.BNPAuraContainer.icons[i]
        if icon then icon:Hide() end
      end
      plate.BNPAuraContainer:Hide()
    end
    HideCCRow(plate)
    return
  end

  if not plate or not plate:IsShown() then
    HidePlateAuraFrames(plate)
    return
  end
  if not plate.BNPAuraContainer then CreateAuraContainer(plate) end

  local container = plate.BNPAuraContainer
  if not container then return end

  local guid = GetStablePlateGUID(plate, now)
  if guid and plate.name and plate.name.GetText then
    local visibleName = plate.name:GetText()
    if visibleName and visibleName ~= "" then BNP.guidNames[guid] = visibleName end
  end
  local cache = guid and BNP.guidAuras[guid] or nil
  now = now or GetTime()

  -- Reuse one small table per plate. Active auras are packed without gaps and
  -- sorted by the order in which they were first applied to this GUID.
  local active = container.activeAuras
  if not active then
    active = {}
    container.activeAuras = active
  end
  local activePool = container.activeAuraPool
  if not activePool then
    activePool = {}
    for i = 1, MAX_VISIBLE_ICONS do activePool[i] = {} end
    container.activeAuraPool = activePool
  end
  local previousCount = table.getn(active)
  for i = 1, previousCount do active[i] = nil end
  local activeCount = 0

  for _, def in ipairs(AURA_DEFS) do
    if ShouldDisplayAuraDef(def) then
      local aura = cache and cache[def.key]
      local remaining = aura and aura.expires and (aura.expires - now) or nil
      local sharedLive = aura and aura.sharedLive
      local svRenderRevision = nil

      if def.key == "shadow_vulnerability" and guid then
        local svState = BNP.svStateByGUID[guid]
        if svState and svState.present then
          -- Shadow Vulnerability rendering is owned entirely by svState.
          -- Do not require the mirrored generic cache entry to already exist:
          -- rebuild it from state if another cleanup path removed it.
          if not cache then
            cache = {}
            BNP.guidAuras[guid] = cache
          end
          aura = cache[def.key]
          if not aura then
            cache._nextOrder = (cache._nextOrder or 0) + 1
            aura = { order = cache._nextOrder }
            cache[def.key] = aura
          end

          aura.sharedLive = true
          aura.sharedEstimated = true
          aura.spellID = svState.spellID or aura.spellID or 17794
          aura.texture = svState.texture or aura.texture or def.texture
          aura.stacks = tonumber(svState.stacks) or aura.stacks or 0
          aura.duration = def.duration or 10
          aura.expires = svState.expires

          remaining = svState.expires and (svState.expires - now) or nil
          sharedLive = true
          svRenderRevision = BNP.svRenderRevisionByGUID[guid] or 0
        else
          remaining = nil
          sharedLive = false
          aura = nil
        end
      end

      if sharedLive or (remaining and remaining > 0) then
      if sharedLive and remaining and remaining <= 0 then
        remaining = nil
      end
        if activeCount < MAX_VISIBLE_ICONS then
          activeCount = activeCount + 1
          local entry = activePool[activeCount]
          active[activeCount] = entry
          entry.def = def
          entry.aura = aura
          entry.remaining = remaining
          entry.svRenderRevision = svRenderRevision
        end
      elseif cache and aura then
        cache[def.key] = nil
      end
    end
  end

  if activeCount > 1 then
    table.sort(active, function(a, b)
      return (a.aura.order or 0) < (b.aura.order or 0)
    end)
  end

  local visibleCount = activeCount
  local iconSize = GetIconSize()
  local ccIconSize = GetCCIconSize()
  local position = GetDebuffPosition()
  local layoutMask = 0
  local maskValue = 1
  for i = 1, visibleCount do
    if active[i] and IsCrowdControlDef(active[i].def) then
      layoutMask = layoutMask + maskValue
    end
    maskValue = maskValue * 2
  end

  local layoutChanged = container.BNPLastVisibleCount ~= visibleCount
    or container.BNPLastIconSize ~= iconSize
    or container.BNPLastCCIconSize ~= ccIconSize
    or container.BNPLastPosition ~= position
    or container.BNPLastLayoutMask ~= layoutMask
  if layoutChanged then
    container.BNPLastVisibleCount = visibleCount
    container.BNPLastIconSize = iconSize
    container.BNPLastCCIconSize = ccIconSize
    container.BNPLastPosition = position
    container.BNPLastLayoutMask = layoutMask
    if visibleCount > 0 then
      -- CCs may share the normal row for Left/Right (and optionally Top), so
      -- lay out each icon using its own configured size without touching tracking.
      LayoutActiveIcons(container, active, visibleCount, false)
    end
  end

  for i = 1, table.getn(container.icons) do
    local icon = container.icons[i]
    local entry = active[i]

    if entry then
      local texture = entry.aura.texture or entry.def.texture
      if icon.BNPLastTexture ~= texture then
        icon.texture:SetTexture(texture)
        icon.BNPLastTexture = texture
      end

      local stackCount = tonumber(entry.aura.stacks) or 0
      local stackText = stackCount > 1 and tostring(stackCount) or ""
      if icon.stack and icon.BNPLastStackText ~= stackText then
        icon.stack:SetText(stackText)
        icon.BNPLastStackText = stackText
      end

      local timerText = FormatTimer(entry.remaining)
      if entry.def and entry.def.key == "shadow_vulnerability" then
        local revision = entry.svRenderRevision or 0
        if icon.BNPSVRenderRevision ~= revision then
          -- A confirmed proc/refresh happened. Invalidate the text cache so the
          -- refreshed countdown is written by the normal renderer, never from
          -- inside a combat-log event callback.
          icon.lastTimerText = nil
          icon.BNPSVRenderRevision = revision
        end
        icon.BNPSVRenderedExpires = entry.aura and entry.aura.expires or nil
        icon.BNPSVRenderedRemaining = entry.remaining
      else
        icon.BNPSVRenderRevision = nil
        icon.BNPSVRenderedExpires = nil
        icon.BNPSVRenderedRemaining = nil
      end

      if icon.lastTimerText ~= timerText then
        icon.timer:SetText(timerText)
        icon.lastTimerText = timerText
      end

      icon:Show()
    else
      icon.lastTimerText = nil
      icon.BNPLastTexture = nil
      icon.BNPLastStackText = nil
      icon.timer:SetText("")
      if icon.stack then icon.stack:SetText("") end
      icon:Hide()
    end
  end

  if visibleCount > 0 then
    container:Show()
  else
    container:Hide()
  end

  UpdateCCRow(plate, guid, cache, now)
  ApplyAuraFrameLevel(plate, container)
  ApplyAuraFrameLevel(plate, plate.BNPCCContainer)
  ApplyTargetAuraPriority(plate, container)
  ApplyTargetAuraPriority(plate, plate.BNPCCContainer)
end


function BNP:RefreshAuraLayout(plate)
  if not plate then return end
  local auraSize = GetIconSize()
  local ccSize = GetCCIconSize()
  local maxSize = math.max(auraSize, ccSize)
  local width = maxSize * MAX_VISIBLE_ICONS + ICON_SPACING * (MAX_VISIBLE_ICONS - 1)
  local containers = { plate.BNPAuraContainer, plate.BNPCCContainer }
  local index, container
  for index, container in ipairs(containers) do
    if container then
      ApplyAuraFrameLevel(plate, container)
      local defaultSize = (index == 2) and ccSize or auraSize
      container:SetWidth(width)
      container:SetHeight(defaultSize)
      container.BNPLastVisibleCount = nil
      container.BNPLastIconSize = nil
      container.BNPLastCCIconSize = nil
      container.BNPLastPosition = nil
      container.BNPLastLayoutMask = nil
      local i
      for i = 1, table.getn(container.icons or {}) do
        ApplyIconDimensions(container.icons[i], defaultSize)
      end
    end
  end
end

function BNP:RefreshAllAuraLayouts()
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate then
      if plate.BNPAuraContainer then
        AnchorAuraContainer(plate, plate.BNPAuraContainer, false)
      end
      if plate.BNPCCContainer then
        AnchorAuraContainer(plate, plate.BNPCCContainer, true)
      end
    end
    self:RefreshAuraLayout(plate)
  end
end

ScanSpellbook()
table.insert(BNP.libnameplate.OnInit, CreateAuraContainer)
table.insert(BNP.libnameplate.OnInit, CreateCCContainer)
table.insert(BNP.libnameplate.OnShow, CreateAuraContainer)
table.insert(BNP.libnameplate.OnShow, CreateCCContainer)

-- Keep the proven central update loop and the existing icon implementation.
-- No CooldownFrame templates and no frames or tables are created here.
local renderer = CreateFrame("Frame")
local elapsedTotal = 0
local removalElapsed = 0
renderer:SetScript("OnUpdate", function()
  elapsedTotal = elapsedTotal + arg1
  removalElapsed = removalElapsed + arg1
  if elapsedTotal < UPDATE_INTERVAL then return end
  elapsedTotal = 0

  local now = GetTime()
  UpdateDarkHarvest(now)
  RefreshTargetPriorityIdentity()

  CleanupAuraCastAttempts(now)

  local hasPending = HasPendingAuras()
  local hasPendingAoE = HasPendingAoEAuras()
  local doRemovalScan = removalElapsed >= REMOVAL_SCAN_INTERVAL
  if doRemovalScan then removalElapsed = 0 end

  local targetGUID = nil
  if hasPending or hasPendingAoE or doRemovalScan then
    targetGUID = GetTargetGUID()
  end

  if hasPending and targetGUID then
    -- Current target is the most reliable confirmation source.
    ConfirmPendingForUnit("target", targetGUID, now)
  end

  if targetGUID then
    CleanupDeadUnit("target", targetGUID, now)
  end

  if doRemovalScan and targetGUID then
    local targetSnapshot = nil
    if HAS_SHARED_AURAS or CacheHasTrackedAuras(BNP.guidAuras[targetGUID]) then
      targetSnapshot = CaptureLiveDebuffSnapshot("target", now)
    end

    SyncSharedAuras("target", targetGUID, now, targetSnapshot)

    if BNP.guidAuras[targetGUID] then
      SyncAuraRemoval("target", targetGUID, now, targetSnapshot)
    end
  end

  -- The normal renderer always runs. Extra GUID/token/UnitDebuff work is only
  -- performed while pending casts exist or during the throttled removal scan.
  for plate in pairs(BNP.plates) do
    if plate:IsShown() and (hasPending or hasPendingAoE or doRemovalScan) then
      local guid = GetPlateGUID(plate)
      local token = GetUnitTokenForPlate(plate)

      if guid and token then
        -- Do NOT call UnitIsDeadOrGhost() on SuperWoW nameplate tokens.
        -- During target changes/recycling those tokens can briefly report an
        -- invalid dead state and wipe the entire GUID aura cache.
        local isCurrentTarget = targetGUID and targetGUID == guid

        -- The real "target" unit was already confirmed above and is more
        -- authoritative than its projected nameplate token. Avoid duplicate
        -- confirmation work for that same GUID.
        if hasPending and not isCurrentTarget then
          ConfirmPendingForUnit(token, guid, now)
        end

        if hasPendingAoE then
          ConfirmAoEAurasOnUnit(token, guid)
        end

        if doRemovalScan and not isCurrentTarget then
          -- Removal/shared scans are destructive and therefore must never use
          -- a raw projected GUID while the renderer still considers the plate
          -- identity unstable. This is the key raid-stack safeguard: one stale
          -- SuperWoW token can no longer remove auras from the wrong GUID.
          local stableGUID = plate.BNPAuraGUIDStable
          local identityTrusted = stableGUID and stableGUID == guid
          if identityTrusted then
            local snapshot = nil
            if HAS_SHARED_AURAS or CacheHasTrackedAuras(BNP.guidAuras[stableGUID]) then
              snapshot = CaptureLiveDebuffSnapshot(token, now)
            end

            SyncSharedAuras(token, stableGUID, now, snapshot)

            -- Non-target exact-removal also requires multiple misses below, so
            -- crowded raid aura lists cannot make Banish/CC blink.
            SyncAuraRemoval(token, stableGUID, now, snapshot)
          end
        end
      end
    end

    UpdatePlate(plate, now)
  end

  if hasPending then
    CleanupPending(now)
  end

  if hasPendingAoE then
    CleanupPendingAoE(now)
  end
end)


-- Foreign CC scanner ---------------------------------------------------------
-- Runs on its own frame so this optional feature can never interrupt the proven
-- own-debuff renderer/update loop.
local FOREIGN_CC_SCAN_INTERVAL = 0.15
local foreignCCElapsed = 0
local foreignCCScanner = CreateFrame("Frame")
foreignCCScanner:SetScript("OnUpdate", function()
  if not WantsForeignCCs() then return end
  foreignCCElapsed = foreignCCElapsed + arg1
  if foreignCCElapsed < FOREIGN_CC_SCAN_INTERVAL then return end
  foreignCCElapsed = 0

  local now = GetTime()
  local targetGUID = GetTargetGUID()
  if targetGUID then pcall(SyncForeignCCs, "target", targetGUID, now) end

  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate:IsShown() then
      local guid = GetPlateGUID(plate)
      if guid and guid ~= targetGUID then
        local token = GetUnitTokenForPlate(plate)
        if token then pcall(SyncForeignCCs, token, guid, now) end
      end
    end
  end
end)


-- Shadow Vulnerability [17794/17797/17798/17799/17800]: shared Warlock raid debuff -------------------
-- Improved Shadow Bolt's Shadow Vulnerability belongs to the TARGET, not to a
-- single BNP player. If any Warlock procs any Shadow Vulnerability rank, every Warlock running BNP
-- should display the same aura.
--
-- Tracking sources:
--   * SyncSharedAuras() is authoritative for appearance/removal and scans the
--     real target plus visible SuperWoW nameplate tokens every 0.10s.
--   * RAW_COMBATLOG is the primary refresh source for other Warlocks. SuperWoW
--     puts GUIDs into the raw combat text, so an actual Shadow Vulnerability
--     application can be tied to the exact target without guessing by name.
--   * UNIT_CASTEVENT for any SV rank remains as a harmless compatibility
--     fast-path for clients/servers that publish the proc itself as a cast event.
--   * Charge/stack increases are used as an additional live fallback.
--
-- No caster ownership is stored or required here.
local SHADOW_VULNERABILITY_IDS = {
  [17794] = true, -- Rank 1
  [17797] = true, -- Rank 2
  [17798] = true, -- Rank 3
  [17799] = true, -- Rank 4
  [17800] = true, -- Rank 5
}

local function IsShadowVulnerabilitySpellID(spellID)
  local sid = tonumber(spellID)
  if sid and SHADOW_VULNERABILITY_IDS[sid] then return true end

  -- Custom 1.12 servers may keep the visible aura on the classic ID while
  -- publishing a hidden proc/cast event on a custom spell ID.  Accept that
  -- event by its exact localized spell name as well.
  if sid and SpellInfo then
    local name = SpellInfo(sid)
    if name == "Shadow Vulnerability" or name == "Schattenverwundbarkeit" then
      return true
    end
  end
  return false
end

-- Small diagnostic state for the one thing vanilla does not expose directly:
-- the remaining duration of hostile debuffs.  This lets /bnp raidcheck show
-- whether a refresh produced any observable client-side signal (stack change,
-- UNIT_AURA, hidden UNIT_CASTEVENT, or changed UnitDebuff return values).
BNP.svProbe = BNP.svProbe or { events = {} }
BNP.svProbe.events = BNP.svProbe.events or {}
BNP.svProbe.raw = BNP.svProbe.raw or {}
local function SVProbeEvent(stage, guid, spellID, extra)
  local t = BNP.svProbe.events
  table.insert(t, {
    time = GetTime(), stage = stage, guid = guid, spellID = spellID, extra = extra,
  })
  while table.getn(t) > 18 do table.remove(t, 1) end
end

local function SnapshotSVUnit(unit, guid, reason)
  if not unit then return end
  local i
  for i = 1, 64 do
    local a1,a2,a3,a4,a5,a6,a7,a8,a9,a10 = UnitDebuff(unit, i)
    if not a1 then break end
    if IsShadowVulnerabilitySpellID(a4) then
      BNP.svProbe.last = {
        time = GetTime(), reason = reason, unit = unit, guid = guid, index = i,
        spellID = a4, stacks = a2, a3 = a3, a5 = a5, a6 = a6, a7 = a7,
        a8 = a8, a9 = a9, a10 = a10,
      }
      return
    end
  end
end

local function SVDef()
  local i
  for i = 1, table.getn(AURA_DEFS) do
    if AURA_DEFS[i] and AURA_DEFS[i].key == "shadow_vulnerability" then
      return AURA_DEFS[i]
    end
  end
end

local function FindSharedShadowVulnerabilityByGUID(guid, def)
  if not guid or not def then return nil, nil, nil, nil end

  local targetGUID = GetTargetGUID()
  if targetGUID and targetGUID == guid then
    local spellID, texture, duration, expires, stacks = FindSharedAuraOnUnit("target", def)
    if spellID or texture then return spellID, texture, duration, expires, stacks end
  end

  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate:IsShown() and GetPlateGUID(plate) == guid then
      local token = GetUnitTokenForPlate(plate)
      if token then
        local spellID, texture, duration, expires, stacks = FindSharedAuraOnUnit(token, def)
        if spellID or texture then return spellID, texture, duration, expires, stacks end
      end
    end
  end

  return nil, nil, nil, nil, nil
end

local function RefreshSharedShadowVulnerability(guid)
  if playerClass ~= "WARLOCK" or not guid then return false end
  local def = SVDef()
  if not def then return false end

  local now = GetTime()
  local liveSpellID, texture, liveDuration, liveExpires, liveStacks =
    FindSharedShadowVulnerabilityByGUID(guid, def)

  BNP.guidAuras[guid] = BNP.guidAuras[guid] or {}
  local cache = BNP.guidAuras[guid]
  local aura = cache[def.key]
  if not aura then
    cache._nextOrder = (cache._nextOrder or 0) + 1
    aura = { order = cache._nextOrder }
    cache[def.key] = aura
  end

  aura.sharedLive = true
  aura.sharedEstimated = nil
  aura.spellID = liveSpellID or aura.spellID or 17794
  aura.texture = texture or aura.texture or def.texture
  aura.confirmedAt = now
  aura.stacks = tonumber(liveStacks) or aura.stacks or 0
  if liveSpellID or texture then aura.sharedLastSeen = now end

  -- A real RAW_COMBATLOG re-application is proof of a fresh duration. Prefer
  -- ClassicAPI's absolute expiration when it has already updated; otherwise
  -- keep the proven local now+duration value until the API catches up.
  aura.duration = (liveDuration and liveDuration > 0 and liveDuration) or def.duration or 10
  local state = BNP.svStateByGUID[guid]
  if not state then
    state = {}
    BNP.svStateByGUID[guid] = state
  end
  state.present = true
  state.duration = aura.duration
  state.provenExpires = now + aura.duration
  state.rawRefreshAt = now
  local apiExpires = liveExpires and liveExpires > now and liveExpires or nil
  state.apiExpires = apiExpires
  if apiExpires and apiExpires > state.provenExpires then
    state.expires = apiExpires
  else
    state.expires = state.provenExpires
  end
  state.lastRefresh = now
  BNP.svRenderRevisionByGUID[guid] = (BNP.svRenderRevisionByGUID[guid] or 0) + 1
  state.renderRevision = BNP.svRenderRevisionByGUID[guid]
  if liveSpellID or texture then state.lastSeen = now end
  state.spellID = liveSpellID or state.spellID or aura.spellID or 17794
  state.texture = texture or state.texture or aura.texture or def.texture
  state.stacks = tonumber(liveStacks) or state.stacks or 0

  BNP.svExpiryByGUID[guid] = state.expires
  aura.spellID = state.spellID
  aura.texture = state.texture
  aura.stacks = state.stacks
  aura.expires = state.expires
  aura.sharedEstimated = nil

  RaidTrace("SV_SHARED_REFRESH", guid, def.key, aura.spellID or 17794)
  return true
end

-- SuperWoW's raw event contains the exact affected GUID. Unlike cast/channel
-- heuristics, an explicit "is afflicted by Shadow Vulnerability" line proves
-- that the proc really happened, including procs caused by another Warlock.
local svRawEvent = CreateFrame("Frame")
pcall(svRawEvent.RegisterEvent, svRawEvent, "RAW_COMBATLOG")
svRawEvent:SetScript("OnEvent", function()
  if playerClass ~= "WARLOCK" or event ~= "RAW_COMBATLOG" then return end
  local raw = tostring(arg2 or "")
  local lower = string.lower(raw)
  local hasName = string.find(lower, "shadow vulnerability", 1, true) or
    string.find(lower, "schattenverwundbarkeit", 1, true)
  if not hasName then return end
  if not string.find(lower, "is afflicted", 1, true) and
     not string.find(lower, "wird von", 1, true) then return end

  local _, _, guid = string.find(raw, "^(0x%x+)")
  if not guid then return end
  if RefreshSharedShadowVulnerability(guid) then
    SVProbeEvent("SV_RAW_REFRESH", guid, 17794, "proven application")
    RaidTrace("SV_RAW_REFRESH", guid, "shadow_vulnerability", 17794)
  end
end)

-- Shadow Vulnerability refresh: legacy compatibility fallback ---------------
--
-- The original v1.0.5 build was the most reliable version on this client.
-- It did not try to prove the hidden proc itself. Instead, every successful
-- Shadow Bolt CAST / Drain Soul CHANNEL opened a very short verification
-- window. If Shadow Vulnerability was live on that exact target GUID, the
-- local countdown was restarted at 10 seconds.
--
-- Keep that behavior only as a compatibility fallback when ClassicAPI aura
-- data is unavailable. ClassicAPI users must never refresh from a cast alone:
-- the report proved that this can reset the local clock without a real proc.
-- Unlike old v1.0.5, this listener accepts the trigger from ANY Warlock, not
-- only the local player, as long as UNIT_CASTEVENT supplies the target GUID.
local SHADOW_BOLT_IDS = {
  [686]=true, [695]=true, [705]=true, [1088]=true, [1106]=true,
  [7641]=true, [11659]=true, [11660]=true, [11661]=true, [25307]=true,
}

local DRAIN_SOUL_IDS = {
  [1120]=true, [8288]=true, [8289]=true, [11675]=true,
  [51687]=true, -- Octo/custom rank observed in UNIT_CASTEVENT
}

local function IsShadowBoltSpellID(spellID)
  spellID = tonumber(spellID)
  if spellID and SHADOW_BOLT_IDS[spellID] then return true end
  if not spellID or not SpellInfo then return false end
  local spellName = SpellInfo(spellID)
  return spellName == "Shadow Bolt" or spellName == "Schattenblitz"
end

local function IsDrainSoulSpellID(spellID)
  spellID = tonumber(spellID)
  if spellID and DRAIN_SOUL_IDS[spellID] then return true end
  if not spellID or not SpellInfo then return false end
  local spellName = SpellInfo(spellID)
  return spellName == "Drain Soul" or spellName == "Seelendieb"
end

local function ShadowVulnerabilityIsLive(guid)
  if not guid then return false end
  local def = SVDef()
  if not def then return false end
  local spellID, texture = FindSharedShadowVulnerabilityByGUID(guid, def)
  return IsShadowVulnerabilitySpellID(spellID) or texture ~= nil
end

-- One pending verification per target GUID so several Warlocks can cast at
-- different mobs during the same frame without overwriting each other.
local sv105Pending = {}
local sv105Elapsed = 0
local SV105_VERIFY_WINDOW = 0.80
local SV105_VERIFY_INTERVAL = 0.05

local function QueueSV105Refresh(guid, spellID, casterGUID, eventType)
  if not guid then return end
  sv105Pending[guid] = GetTime() + SV105_VERIFY_WINDOW
  SVProbeEvent("SV_105_ARM", guid, spellID, tostring(eventType or "?") .. ":" .. tostring(casterGUID or "?"))

  -- Mid-duration refreshes already have the aura visible. Handle them in the
  -- same event immediately so the icon number jumps back to 10 without waiting
  -- for the next scanner tick.
  if ShadowVulnerabilityIsLive(guid) then
    if RefreshSharedShadowVulnerability(guid) then
      sv105Pending[guid] = nil
      SVProbeEvent("SV_105_REFRESH", guid, spellID, "immediate")
      RaidTrace("SV_105_REFRESH", guid, "shadow_vulnerability", spellID)
    end
  end
end

local sv105Event = CreateFrame("Frame")
sv105Event:RegisterEvent("UNIT_CASTEVENT")
sv105Event:SetScript("OnEvent", function()
  if playerClass ~= "WARLOCK" then return end
  if ClassicAPIAuraDataAvailable() then return end

  local casterGUID = arg1
  local targetGUID = arg2
  local eventType = arg3
  local spellID = tonumber(arg4)

  if eventType ~= "CAST" and eventType ~= "CHANNEL" then return end
  if not IsShadowBoltSpellID(spellID) and not IsDrainSoulSpellID(spellID) then return end

  -- Old v1.0.5 used only the local player's exact target GUID. For the shared
  -- version we trust arg2 for any Warlock. Only our own cast may fall back to
  -- the current target when this old SuperWoW build omits arg2.
  if not targetGUID then
    local playerGUID = GetPlayerGUID()
    if playerGUID and casterGUID == playerGUID then targetGUID = GetTargetGUID() end
  end
  if not targetGUID then return end

  QueueSV105Refresh(targetGUID, spellID, casterGUID, eventType)
end)

local sv105RefreshFrame = CreateFrame("Frame")
sv105RefreshFrame:SetScript("OnUpdate", function()
  if playerClass ~= "WARLOCK" or not next(sv105Pending) then return end
  if ClassicAPIAuraDataAvailable() then
    sv105Pending = {}
    return
  end

  sv105Elapsed = sv105Elapsed + arg1
  if sv105Elapsed < SV105_VERIFY_INTERVAL then return end
  sv105Elapsed = 0

  local now = GetTime()
  local guid, untilTime
  for guid, untilTime in pairs(sv105Pending) do
    if now > untilTime then
      sv105Pending[guid] = nil
    elseif ShadowVulnerabilityIsLive(guid) then
      if RefreshSharedShadowVulnerability(guid) then
        sv105Pending[guid] = nil
        SVProbeEvent("SV_105_REFRESH", guid, 17794, "verified")
        RaidTrace("SV_105_REFRESH", guid, "shadow_vulnerability", 17794)
      end
    end
  end
end)

function BNP:RefreshDebuffVisibility()
  if not self:AreCrowdControlEnabled() or not self:ShowOtherPlayersCCs() then
    BNP.guidLiveCCs = {}
  end
  self:RefreshAllAuraLayouts()

  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate.BNPAuraContainer then
      if self:AreAnyAurasEnabled() then
        UpdatePlate(plate)
      else
        local i
        for i = 1, MAX_VISIBLE_ICONS do
          local icon = plate.BNPAuraContainer.icons and plate.BNPAuraContainer.icons[i]
          if icon then icon:Hide() end
        end
        plate.BNPAuraContainer:Hide()
        HideCCRow(plate)
      end
    end
  end
end
