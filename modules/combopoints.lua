BNP = BNP or {}

local _, playerClass = UnitClass("player")
local COMBO_CLASS = (playerClass == "ROGUE" or playerClass == "DRUID")

local MAX_POINTS = 5
local POINT_GAP = 1
local POINT_SIZE = 16
local CUSTOM_POINT_TEXTURE = "Interface\\AddOns\\BlizzNameplatesPlus\\media\\combo_point_orb.tga"

-- Combo points can remain on the previous unit after changing target on this
-- server. Track the owning GUID ourselves instead of tying the display to the
-- currently selected target.
local comboOwnerGUID = nil
local comboOwnerCount = 0
local comboOwnerSynthetic = false

-- Some 1.12 clients do not immediately expose the first point on a newly
-- selected target through GetComboPoints(). Remember the generator CAST, but
-- do NOT move ownership from CAST alone: melee generators can miss/dodge/parry.
-- Ownership is moved immediately when PLAYER_COMBO_POINTS confirms that a
-- combo-point change actually happened. This is event-driven and adds no scan.
local pendingGenerator = nil
local GENERATOR_CONFIRM_WINDOW = 0.75

local function Enabled()
  return COMBO_CLASS and BNP.AreComboPointsEnabled and BNP:AreComboPointsEnabled()
end

local function GetUnitGUID(unit)
  local exists, guid = UnitExists(unit)
  if exists and guid then return guid end
  return nil
end

local function GetTargetGUID()
  return GetUnitGUID("target")
end

local function GetPlayerGUID()
  return GetUnitGUID("player")
end

local function GetComboCount()
  if not GetComboPoints then return 0 end
  local count = tonumber(GetComboPoints()) or 0
  if count < 0 then count = 0 end
  if count > MAX_POINTS then count = MAX_POINTS end
  return count
end

local ROGUE_GENERATOR_IDS = {
  -- Sinister Strike
  [1752]=1,[1757]=1,[1758]=1,[1759]=1,[1760]=1,[8621]=1,[11293]=1,[11294]=1,
  -- Backstab
  [53]=1,[2589]=1,[2590]=1,[2591]=1,[8721]=1,[11279]=1,[11280]=1,[11281]=1,
  -- Gouge
  [1776]=1,[1777]=1,[8629]=1,[11285]=1,[11286]=1,
  -- Ambush
  [8676]=1,[8724]=1,[8725]=1,[11267]=1,[11268]=1,[11269]=1,
  -- Garrote
  [703]=1,[8631]=1,[8632]=1,[8633]=1,[11289]=1,[11290]=1,
  -- Cheap Shot / Hemorrhage / Ghostly Strike / Premeditation
  [1833]=1,[16511]=1,[17347]=1,[17348]=1,[14278]=1,[14183]=2,
}

local DRUID_GENERATOR_IDS = {
  -- Claw
  [1082]=1,[3029]=1,[5201]=1,[9849]=1,[9850]=1,
  -- Rake
  [1822]=1,[1823]=1,[1824]=1,[9904]=1,
  -- Shred
  [5221]=1,[6800]=1,[8992]=1,[9829]=1,[9830]=1,
  -- Ravage
  [6785]=1,[6787]=1,[9866]=1,[9867]=1,
  -- Pounce
  [9005]=1,[9823]=1,[9827]=1,
  -- Mangle (Cat), for clients/servers that expose TBC/custom IDs
  [33876]=1,[33982]=1,[33983]=1,
}

local ROGUE_GENERATOR_NAMES = {
  ["sinister strike"]=1,["finsterer stoß"]=1,
  ["backstab"]=1,["meucheln"]=1,
  ["gouge"]=1,["solarplexus"]=1,
  ["ambush"]=1,["hinterhalt"]=1,
  ["garrote"]=1,["erdrosseln"]=1,
  ["cheap shot"]=1,["fieser trick"]=1,
  ["hemorrhage"]=1,["blutsturz"]=1,
  ["ghostly strike"]=1,["geisterhafter stoß"]=1,
  ["premeditation"]=2,
}

local DRUID_GENERATOR_NAMES = {
  ["claw"]=1,["klaue"]=1,
  ["rake"]=1,["krallenhieb"]=1,
  ["shred"]=1,["schreddern"]=1,
  ["ravage"]=1,["verheeren"]=1,
  ["pounce"]=1,["anspringen"]=1,
  ["mangle"]=1,["mangle (cat)"]=1,["zerfleischen"]=1,["zerfleischen (katze)"]=1,
}

local function ResolveSpellName(spellID)
  if not spellID or not SpellInfo then return nil end
  local ok, name = pcall(SpellInfo, spellID)
  if ok and name then return string.lower(tostring(name)) end
  return nil
end

local function GetGeneratorGain(spellID)
  local id = tonumber(spellID)
  if playerClass == "ROGUE" then
    if id and ROGUE_GENERATOR_IDS[id] then return ROGUE_GENERATOR_IDS[id] end
    local name = ResolveSpellName(id)
    if name then return ROGUE_GENERATOR_NAMES[name] end
  elseif playerClass == "DRUID" then
    if id and DRUID_GENERATOR_IDS[id] then return DRUID_GENERATOR_IDS[id] end
    local name = ResolveSpellName(id)
    if name then return DRUID_GENERATOR_NAMES[name] end
  end
  return nil
end

local function BeginPendingGenerator(targetGUID, spellID, gain)
  if not targetGUID or not gain then return end
  pendingGenerator = {
    guid = targetGUID,
    spellID = tonumber(spellID),
    gain = tonumber(gain) or 1,
    started = GetTime and GetTime() or 0,
  }
end

local function CancelPendingGenerator(targetGUID, spellID)
  if not pendingGenerator then return end
  if targetGUID and pendingGenerator.guid ~= targetGUID then return end
  if spellID and pendingGenerator.spellID and tonumber(spellID) ~= pendingGenerator.spellID then return end
  pendingGenerator = nil
end

local function ApplyPendingGenerator()
  if not pendingGenerator then return false end

  local now = GetTime and GetTime() or 0
  local started = pendingGenerator.started or now

  -- PLAYER_COMBO_POINTS should arrive essentially immediately after a real
  -- point gain. Ignore stale CAST candidates so a missed attack can never be
  -- applied later by an unrelated combo-point event.
  if now - started > GENERATOR_CONFIRM_WINDOW then
    pendingGenerator = nil
    return false
  end

  local guid = pendingGenerator.guid
  local gain = pendingGenerator.gain or 1
  local targetGUID = GetTargetGUID()
  local apiCount = 0

  -- Only trust GetComboPoints for the pending unit while it is the current
  -- target. If the broken 1.12 client still reports zero, PLAYER_COMBO_POINTS
  -- itself is the confirmation and we use the inferred generator gain.
  if targetGUID and targetGUID == guid then
    apiCount = GetComboCount()
  end

  if apiCount > 0 then
    comboOwnerGUID = guid
    comboOwnerCount = apiCount
    comboOwnerSynthetic = false
  else
    if comboOwnerGUID == guid then
      comboOwnerCount = math.min(MAX_POINTS, (comboOwnerCount or 0) + gain)
    else
      -- First confirmed generator on a different target: old owner's points
      -- are gone and ownership switches immediately to this GUID.
      comboOwnerGUID = guid
      comboOwnerCount = math.min(MAX_POINTS, gain)
    end
    comboOwnerSynthetic = true
  end

  pendingGenerator = nil
  return true
end

-- Read authoritative API state when available. A zero on some *other* current
-- target must never delete the stored points from the previous owner.
local function SyncComboOwnerFromAPI(allowZeroOnOwner)
  local targetGUID = GetTargetGUID()
  if not targetGUID then return end

  local count = GetComboCount()
  if count > 0 then
    comboOwnerGUID = targetGUID
    comboOwnerCount = count
    comboOwnerSynthetic = false
    pendingGenerator = nil
    return
  end

  if allowZeroOnOwner and comboOwnerGUID == targetGUID and not pendingGenerator then
    comboOwnerGUID = nil
    comboOwnerCount = 0
    comboOwnerSynthetic = false
  end
end

local function GetSourcePoint()
  if getglobal then return getglobal("TargetFrameComboPoint1") end
  return nil
end

local function GetComboYOffset()
  if BNP.GetComboPointsYOffset then return BNP:GetComboPointsYOffset() end
  return 0
end

local function AnchorComboHolder(plate, holder)
  if not plate or not holder or not plate.name then return end
  holder:ClearAllPoints()
  holder:SetPoint("BOTTOM", plate.name, "TOP", 0, 2 + GetComboYOffset())
end

local function ApplyTargetFrameScale(holder)
  if not holder then return end
  local source = GetSourcePoint()
  local parent = holder:GetParent()
  local sourceScale = 1.0
  local parentScale = 1.0

  if source and source.GetEffectiveScale then
    sourceScale = tonumber(source:GetEffectiveScale()) or 1.0
  elseif UIParent and UIParent.GetEffectiveScale then
    sourceScale = tonumber(UIParent:GetEffectiveScale()) or 1.0
  elseif UIParent and UIParent.GetScale then
    sourceScale = tonumber(UIParent:GetScale()) or 1.0
  end

  if parent and parent.GetEffectiveScale then
    parentScale = tonumber(parent:GetEffectiveScale()) or 1.0
  end

  if sourceScale <= 0 then sourceScale = 1.0 end
  if parentScale <= 0 then parentScale = 1.0 end
  holder:SetScale(sourceScale / parentScale)
end

local function CreateCustomPoint(parent)
  local point = CreateFrame("Frame", nil, parent)
  point:SetWidth(POINT_SIZE)
  point:SetHeight(POINT_SIZE)

  local tex = point:CreateTexture(nil, "ARTWORK")
  tex:SetTexture(CUSTOM_POINT_TEXTURE)
  tex:SetAllPoints(point)
  tex:SetTexCoord(0, 1, 0, 1)
  tex:SetBlendMode("BLEND")
  point.texture = tex

  point:Hide()
  return point
end

local function EnsurePoints(plate)
  if plate.BNPComboPoints then
    AnchorComboHolder(plate, plate.BNPComboPoints)
    ApplyTargetFrameScale(plate.BNPComboPoints)
    return plate.BNPComboPoints
  end

  if not plate or not plate.name then return nil end

  local parent = plate.BNPScaleWrapper or plate
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetWidth(MAX_POINTS * POINT_SIZE + (MAX_POINTS - 1) * POINT_GAP)
  holder:SetHeight(POINT_SIZE)
  AnchorComboHolder(plate, holder)
  holder:SetFrameLevel((plate:GetFrameLevel() or 1) + 12)
  holder.points = {}
  holder:Hide()

  local i
  for i = 1, MAX_POINTS do
    local point = CreateCustomPoint(holder)
    if i == 1 then
      point:SetPoint("LEFT", holder, "LEFT", 0, 0)
    else
      point:SetPoint("LEFT", holder.points[i - 1], "RIGHT", POINT_GAP, 0)
    end
    holder.points[i] = point
  end

  ApplyTargetFrameScale(holder)
  plate.BNPComboPoints = holder
  return holder
end

local function HidePoints(plate)
  local holder = plate and plate.BNPComboPoints
  if not holder then return end
  local i
  for i = 1, MAX_POINTS do holder.points[i]:Hide() end
  holder:Hide()
end

local function UpdatePlate(plate)
  if not plate or not plate:IsShown() then return end

  if not Enabled() then HidePoints(plate) return end

  local plateGUID = plate.GetName and plate:GetName(1) or nil
  if not plateGUID or not comboOwnerGUID or plateGUID ~= comboOwnerGUID then
    HidePoints(plate)
    return
  end

  if comboOwnerCount <= 0 then
    HidePoints(plate)
    return
  end

  local holder = EnsurePoints(plate)
  if not holder then return end
  ApplyTargetFrameScale(holder)

  local i
  for i = 1, MAX_POINTS do
    if i <= comboOwnerCount then holder.points[i]:Show() else holder.points[i]:Hide() end
  end
  holder:Show()
end

function BNP:RefreshComboPoints()
  for plate in pairs(BNP.plates or {}) do
    if plate:IsShown() then UpdatePlate(plate) else HidePoints(plate) end
  end
  if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
end

table.insert(BNP.libnameplate.OnInit, function(plate)
  if COMBO_CLASS then EnsurePoints(plate) HidePoints(plate) end
end)

table.insert(BNP.libnameplate.OnShow, function(plate)
  if COMBO_CLASS then
    -- Positive API counts may be adopted when a plate appears, but a zero on a
    -- newly selected target must not clear the previous owner's points.
    SyncComboOwnerFromAPI(false)
    HidePoints(plate)
    UpdatePlate(plate)
  end
end)

table.insert(BNP.libnameplate.OnUpdate, function(plate)
  if COMBO_CLASS then UpdatePlate(plate) end
end)

if COMBO_CLASS then
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("PLAYER_COMBO_POINTS")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("UNIT_CASTEVENT")

  events:SetScript("OnEvent", function()
    if event == "UNIT_CASTEVENT" then
      local casterGUID = arg1
      local targetGUID = arg2
      local eventType = arg3
      local spellID = arg4
      local playerGUID = GetPlayerGUID()
      if not playerGUID or casterGUID ~= playerGUID then return end

      local gain = GetGeneratorGain(spellID)
      if not gain then return end

      if eventType == "CAST" then
        BeginPendingGenerator(targetGUID or GetTargetGUID(), spellID, gain)
      elseif eventType == "FAIL" then
        CancelPendingGenerator(targetGUID, spellID)
      end
      return
    end

    if event == "PLAYER_TARGET_CHANGED" then
      -- This is intentionally positive-only. Changing target by itself must
      -- never clear the combo points stored on the previous GUID.
      SyncComboOwnerFromAPI(false)
      BNP:RefreshComboPoints()
      return
    end

    if event == "PLAYER_COMBO_POINTS" then
      -- This is the success confirmation. Switch ownership immediately here,
      -- never on UNIT_CASTEVENT CAST alone. If the Blizzard frame/API still
      -- returns zero, the pending generator provides the synthetic first point.
      if pendingGenerator then
        if not ApplyPendingGenerator() then
          SyncComboOwnerFromAPI(true)
        end
      else
        SyncComboOwnerFromAPI(true)
      end
      BNP:RefreshComboPoints()
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      pendingGenerator = nil
      SyncComboOwnerFromAPI(false)
      BNP:RefreshComboPoints()
    end
  end)
end
