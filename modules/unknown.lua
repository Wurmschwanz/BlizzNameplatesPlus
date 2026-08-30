BNP = BNP or {}
BNP.unknownDirectEvents = BNP.unknownDirectEvents or {}

-- Beta spell collector -------------------------------------------------------
-- Purpose: help testers report missing Turtle/custom spell IDs without
-- editing Lua files. It records unknown own cast IDs and unknown debuff IDs
-- that newly appear shortly after one of the player's casts.
--
-- It is intentionally diagnostic only: it never changes tracking/rendering.

BNP.unknownBeta = BNP.unknownBeta or {
  entries = {},
  order = {},
  recentCasts = {},
  seenByGUID = {},
  activeUntil = 0,
}

local _, playerClass = UnitClass("player")

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

local function GetPlayerGUID()
  local exists, guid = UnitExists("player")
  if exists and guid then return guid end
  return nil
end

local function GetUnitGUID(unit)
  local exists, guid = UnitExists(unit)
  if exists and guid then return guid end
  return nil
end

local function IsExplicitKnownID(spellID)
  if not spellID then return false end

  -- Dark Harvest is handled by dedicated Warlock logic.
  if spellID == 52552 then return true end

  local i, j, def
  for i = 1, table.getn(AURA_DEFS) do
    def = AURA_DEFS[i]

    if def.spellIDs then
      for j = 1, table.getn(def.spellIDs) do
        if def.spellIDs[j] == spellID then return true end
      end
    end

    if def.durations and def.durations[spellID] then
      return true
    end
  end

  return false
end

local function SpellName(spellID)
  if not spellID or not SpellInfo then return "?" end
  local name = SpellInfo(spellID)
  return name or "?"
end

local function AddEntry(kind, spellID, spellName, guid, trigger, confidence)
  if not spellID then return end

  local key = tostring(kind) .. ":" .. tostring(spellID)
  local data = BNP.unknownBeta
  local old = data.entries[key]

  if old then
    old.count = (old.count or 1) + 1
    old.lastSeen = GetTime()
    if confidence == "TARGET" then old.confidence = confidence end
    if trigger and not old.trigger then old.trigger = trigger end
    return
  end

  local entry = {
    kind = kind,
    spellID = spellID,
    name = spellName or SpellName(spellID),
    class = playerClass or "?",
    guid = guid,
    trigger = trigger,
    confidence = confidence or "?",
    count = 1,
    firstSeen = GetTime(),
    lastSeen = GetTime(),
  }

  data.entries[key] = entry
  table.insert(data.order, key)
end

local function RememberCast(spellID, targetGUID, eventType)
  local data = BNP.unknownBeta
  local now = GetTime()
  data.activeUntil = now + 8.0
  local cast = {
    time = now,
    spellID = spellID,
    name = SpellName(spellID),
    targetGUID = targetGUID,
    eventType = eventType,
  }

  table.insert(data.recentCasts, cast)
  while table.getn(data.recentCasts) > 20 do
    table.remove(data.recentCasts, 1)
  end

  -- Unknown own CAST/CHANNEL IDs are useful too. Some trap/proc systems expose
  -- the effect as a separate cast event before the aura is seen.
  if spellID and not IsExplicitKnownID(spellID) then
    AddEntry("CAST", spellID, cast.name, targetGUID, nil, "OWN")
  end
end

local function FindRecentTrigger(guid, now)
  local casts = BNP.unknownBeta.recentCasts
  local i
  for i = table.getn(casts), 1, -1 do
    local cast = casts[i]
    local age = now - cast.time

    if age > 6 then
      break
    end

    if cast.targetGUID and guid and cast.targetGUID == guid then
      return cast, "TARGET"
    end

    -- Short global fallback catches effects such as traps where the placement
    -- cast may not carry the eventual victim GUID.
    if age <= 1.5 then
      return cast, "RECENT"
    end
  end

  return nil, nil
end

local function ScanUnit(unit, guid, now)
  if not unit or not guid then return end

  local seen = BNP.unknownBeta.seenByGUID[guid]
  if not seen then
    seen = {}
    BNP.unknownBeta.seenByGUID[guid] = seen
  end

  local current = {}
  local i
  for i = 1, 32 do
    local texture, stacks, dtype, auraSpellID = UnitDebuff(unit, i)
    if not texture then break end

    if auraSpellID then
      current[auraSpellID] = true

      if not seen[auraSpellID] and not IsExplicitKnownID(auraSpellID) then
        local trigger, confidence = FindRecentTrigger(guid, now)
        if trigger then
          AddEntry(
            "AURA",
            auraSpellID,
            SpellName(auraSpellID),
            guid,
            tostring(trigger.name) .. " [" .. tostring(trigger.spellID) .. "]",
            confidence
          )
        end
      end
    end
  end

  -- Keep only currently present aura IDs so a later re-application can be
  -- detected again without growing this table forever.
  BNP.unknownBeta.seenByGUID[guid] = current
end


-- Indirect Effect Audit: traps/procs may never expose a UnitDebuff ID.
BNP.unknownBeta.combat = BNP.unknownBeta.combat or {}
local EFFECT_WINDOW = 8.0


local function IsUsefulEffectLine(raw)
  if not raw or raw == "" then return false end
  local lower = string.lower(raw)

  -- Ignore obvious player-action/noise lines.
  if string.find(lower, "you cast ", 1, true) then return false end
  if string.find(lower, "auto shot", 1, true) then return false end
  if string.find(lower, "login", 1, true) then return false end

  -- Keep lines that actually describe a harmful aura/effect or its periodic damage.
  if string.find(lower, "afflicted by", 1, true) then return true end
  if string.find(lower, "is afflicted", 1, true) then return true end
  if string.find(lower, "is affected by", 1, true) then return true end
  if string.find(lower, "suffers", 1, true) then return true end
  if string.find(lower, "periodic", 1, true) then return true end

  return false
end

local function AddCombatEffect(raw)
  if not IsUsefulEffectLine(raw) then return end
  local now=GetTime()
  local casts=BNP.unknownBeta.recentCasts
  local trigger=nil
  local i
  for i=table.getn(casts),1,-1 do
    local c=casts[i]
    if now-c.time > EFFECT_WINDOW then break end
    if c.spellID ~= 75 then trigger=c break end
  end
  if not trigger then return end
  if string.find(string.lower(raw),"auto shot",1,true) then return end

  local key=tostring(trigger.spellID)..":"..raw
  local old=BNP.unknownBeta.combat[key]
  if old then old.count=old.count+1 return end
  BNP.unknownBeta.combat[key]={
    raw=raw, triggerID=trigger.spellID, triggerName=trigger.name, count=1
  }
end

local combatFrame=CreateFrame("Frame")
local combatEvents={
  "CHAT_MSG_COMBAT_SELF_HITS",
  "CHAT_MSG_SPELL_SELF_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
}
local cei
for cei=1,table.getn(combatEvents) do combatFrame:RegisterEvent(combatEvents[cei]) end
combatFrame:SetScript("OnEvent",function() AddCombatEffect(arg1) end)

local castFrame = CreateFrame("Frame")
castFrame:RegisterEvent("UNIT_CASTEVENT")
castFrame:SetScript("OnEvent", function()
  local playerGUID = GetPlayerGUID()
  if not playerGUID or arg1 ~= playerGUID then return end

  local eventType = arg3
  if eventType ~= "CAST" and eventType ~= "CHANNEL" then return end

  RememberCast(arg4, arg2, eventType)
end)

local scanner = CreateFrame("Frame")
local elapsed = 0
scanner:SetScript("OnUpdate", function()
  elapsed = elapsed + arg1
  if elapsed < 0.35 then return end
  elapsed = 0

  local now = GetTime()
  if not BNP.unknownBeta.activeUntil or now > BNP.unknownBeta.activeUntil then
    return
  end

  local targetGUID = GetUnitGUID("target")
  if targetGUID then
    ScanUnit("target", targetGUID, now)
  end

  local plate
  for plate in pairs(BNP.plates) do
    if plate:IsShown() and plate.GetName then
      local token = plate:GetName(1)
      if token then
        local guid = GetUnitGUID(token)
        if guid then
          ScanUnit(token, guid, now)
        end
      end
    end
  end
end)

function BNP:PrintUnknownBeta(verbose)
  local data = self.unknownBeta
  self:Print("=== BNP Beta: Unknown Auras (" .. tostring(playerClass or "?") .. ") ===")

  local auraCount = 0
  local i
  for i = 1, table.getn(data.order) do
    local entry = data.entries[data.order[i]]
    if entry and entry.kind == "AURA" then
      auraCount = auraCount + 1
      local line =
        tostring(auraCount) ..
        " | AURA | ID " .. tostring(entry.spellID) ..
        " | " .. tostring(entry.name) ..
        " | x" .. tostring(entry.count or 1)

      if entry.confidence then
        line = line .. " | " .. tostring(entry.confidence)
      end

      self:Print(line)

      if entry.trigger then
        self:Print("    Trigger: " .. tostring(entry.trigger))
      end
    end
  end

  local combatCount = 0
  local ck
  for ck in pairs(data.combat or {}) do combatCount = combatCount + 1 end

  if combatCount > 0 then
    self:Print("--- Indirect Effects ---")
    local key, e
    for key, e in pairs(data.combat) do
      self:Print("EFFECT | Trigger " .. tostring(e.triggerName) .. " [" .. tostring(e.triggerID) .. "] | x" .. tostring(e.count))
      self:Print("    " .. tostring(e.raw))
    end
  end

  if auraCount == 0 and combatCount == 0 then
    self:Print("No unknown negative auras/effects found since login.")
  end

  if verbose then
    self:Print("--- Verbose: unknown player cast IDs ---")
    local castCount = 0
    for i = 1, table.getn(data.order) do
      local entry = data.entries[data.order[i]]
      if entry and entry.kind == "CAST" then
        castCount = castCount + 1
        self:Print(
          tostring(castCount) ..
          " | CAST | ID " .. tostring(entry.spellID) ..
          " | " .. tostring(entry.name) ..
          " | x" .. tostring(entry.count or 1)
        )
      end
    end
    if castCount == 0 then
      self:Print("No unknown cast IDs.")
    end
  else
    self:Print("Open Missing Spell / Aura in the settings to copy a complete report.")
  end
end

function BNP:ResetUnknownBeta()
  self.unknownBeta.entries = {}
  self.unknownBeta.order = {}
  self.unknownBeta.recentCasts = {}
  self.unknownBeta.seenByGUID = {}
  self.unknownBeta.combat = {}
  self.unknownBeta.activeUntil = 0
  self:Print("Unknown spell/effect list cleared.")
end



-- Target Aura Probe ----------------------------------------------------------
-- Diagnostic helper for proc/talent auras that the normal unknown collector
-- may miss because they were already present in its seen-state.
function BNP:PrintTargetAuraProbe()
  local exists, guid = UnitExists("target")
  if not exists or not guid then
    self:Print("Target Aura Probe: no target selected.")
    return
  end

  self:Print("=== BNP Target Negative Auras ===")
  self:Print("Target: " .. tostring(UnitName("target") or "?") .. " | GUID " .. tostring(guid))

  local count = 0
  local i
  for i = 1, 32 do
    local texture, stacks, dtype, auraSpellID = UnitDebuff("target", i)
    if not texture then break end

    count = count + 1
    local name = auraSpellID and SpellName(auraSpellID) or "?"
    self:Print(
      tostring(count) ..
      " | ID " .. tostring(auraSpellID or "?") ..
      " | " .. tostring(name) ..
      " | stacks " .. tostring(stacks or 0) ..
      " | type " .. tostring(dtype or "?")
    )
  end

  if count == 0 then
    self:Print("No negative target auras found.")
  end
end

-- Direct player spell collector --------------------------------------------
-- Captures successful player spell events that do not create a persistent
-- aura and therefore never appear in the normal unknown-aura collector.

local function GetLocalPlayerGUID()
  local exists, guid = UnitExists("player")
  if exists and guid then return guid end
  return nil
end

local function RememberDirectEvent(eventType, spellID, targetGUID, extra)
  if not spellID then return end

  local name = nil
  if SpellInfo then name = SpellInfo(spellID) end
  name = name or ("Spell " .. tostring(spellID))

  local key = tostring(eventType) .. ":" .. tostring(spellID)
  local entry = BNP.unknownDirectEvents[key]

  if not entry then
    entry = {
      eventType = eventType,
      spellID = spellID,
      name = name,
      targetGUID = targetGUID,
      count = 0,
      extra = extra,
      last = GetTime(),
    }
    BNP.unknownDirectEvents[key] = entry
  end

  entry.count = (entry.count or 0) + 1
  entry.targetGUID = targetGUID or entry.targetGUID
  entry.extra = extra or entry.extra
  entry.last = GetTime()
end

local directFrame = CreateFrame("Frame")
directFrame:RegisterEvent("UNIT_CASTEVENT")
directFrame:SetScript("OnEvent", function()
  local casterGUID = arg1
  local targetGUID = arg2
  local eventType = arg3
  local spellID = arg4
  local playerGUID = GetLocalPlayerGUID()

  if not playerGUID or casterGUID ~= playerGUID then return end
  if not spellID then return end

  if eventType == "START" or eventType == "CAST" or eventType == "CHANNEL" then
    RememberDirectEvent(eventType, spellID, targetGUID, arg5)
  end
end)

function BNP:PrintUnknownDirectEvents()
  local list = {}
  local key, entry

  for key, entry in pairs(self.unknownDirectEvents or {}) do
    table.insert(list, entry)
  end

  table.sort(list, function(a, b)
    return (a.last or 0) > (b.last or 0)
  end)

  if table.getn(list) == 0 then
    self:Print("--- Direct Player Events: none captured ---")
    return
  end

  self:Print("--- Direct Player Events ---")

  local i, e
  for i = 1, table.getn(list) do
    e = list[i]
    self:Print(
      tostring(i) .. " | " ..
      tostring(e.eventType) .. " | ID " ..
      tostring(e.spellID) .. " | " ..
      tostring(e.name) .. " | x" ..
      tostring(e.count or 1)
    )
  end
end
