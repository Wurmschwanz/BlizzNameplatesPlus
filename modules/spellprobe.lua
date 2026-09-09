BNP = BNP or {}

local wanted = {
  corruption = { "Corruption", "Verderbnis" },
  agony = { "Curse of Agony", "Fluch der Pein" },
  siphon = { "Siphon Life", "Lebensentzug" },
  shadow_word_pain = { "Shadow Word: Pain", "Schattenwort: Schmerz" },
}

local function isWanted(name, list)
  if not name then return false end
  local lower = string.lower(name)
  local i
  for i = 1, table.getn(list) do
    if lower == string.lower(list[i]) then return true end
  end
  return false
end

local function normalizeNumber(value)
  if not value then return nil end
  value = string.gsub(value, ",", ".")
  return tonumber(value)
end

-- WoW 1.12 uses Lua 5.0. Use string.find captures instead of string.match.
local function durationFromLine(text)
  if not text then return nil end
  local lower = string.lower(text)
  local _, _, num

  -- German: 14,95 Sek. / 14.95 Sekunden
  _, _, num = string.find(lower, "([0-9]+[%,%.]?[0-9]*)%s*sek")
  if num then return normalizeNumber(num) end

  -- English: 14.95 sec / seconds
  _, _, num = string.find(lower, "([0-9]+[%,%.]?[0-9]*)%s*sec")
  if num then return normalizeNumber(num) end

  -- Generic short form: "over 14.95 s" / "14,95 s"
  _, _, num = string.find(lower, "over%s+([0-9]+[%,%.]?[0-9]*)%s+s")
  if num then return normalizeNumber(num) end

  return nil
end

local function getTooltip()
  local tooltip = getglobal("BNPSpellProbeTooltip")
  if tooltip then return tooltip end

  tooltip = CreateFrame("GameTooltip", "BNPSpellProbeTooltip", UIParent, "GameTooltipTemplate")
  tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
  return tooltip
end

local function scanSpell(slot)
  local tooltip = getTooltip()
  tooltip:ClearLines()
  tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
  tooltip:SetSpell(slot, BOOKTYPE_SPELL)

  local lines = {}
  local bestDuration = nil
  local i
  for i = 1, tooltip:NumLines() do
    local fs = getglobal("BNPSpellProbeTooltipTextLeft" .. i)
    local text = fs and fs:GetText()
    if text and text ~= "" then
      table.insert(lines, text)
      local parsed = durationFromLine(text)
      if parsed and parsed > 0 then
        bestDuration = parsed
      end
    end
  end

  return bestDuration, lines
end

local function findSpell(wantedNames)
  local slot = 1
  local found = nil
  while true do
    local name, rank = GetSpellName(slot, BOOKTYPE_SPELL)
    if not name then break end
    if isWanted(name, wantedNames) then
      found = { slot = slot, name = name, rank = rank }
      -- keep scanning so the highest learned rank wins
    end
    slot = slot + 1
  end
  return found
end

local function findSpellByID(def, spellID)
  if not def or not spellID or not SpellInfo then return nil end

  local wantedName, wantedRank = SpellInfo(spellID)
  if not wantedName then return nil end

  local slot = 1
  local name, rank
  while true do
    name, rank = GetSpellName(slot, BOOKTYPE_SPELL)
    if not name then break end

    if isWanted(name, def.names or { wantedName }) then
      -- SuperWoW SpellInfo exposes the localized rank when available. Matching
      -- both name and rank lets us scan the exact spellbook rank that was cast
      -- instead of always inheriting the highest learned rank's tooltip.
      if wantedRank and wantedRank ~= "" and rank == wantedRank then
        return { slot = slot, name = name, rank = rank }
      end
    end

    slot = slot + 1
  end

  return nil
end


BNP.spellbookDurations = BNP.spellbookDurations or {}
BNP.spellbookDurationsByID = BNP.spellbookDurationsByID or {}

function BNP:RefreshSpellbookDurations()
  -- Exact-rank tooltip values can change after talent/spellbook updates.
  BNP.spellbookDurationsByID = {}
  local id
  for id, names in pairs(wanted) do
    local spell = findSpell(names)
    if spell then
      local ok, duration = pcall(scanSpell, spell.slot)
      if ok and duration and duration > 0 then
        BNP.spellbookDurations[id] = duration
        BNP.spellbookDurations[string.lower(spell.name)] = duration
      end
    end
  end
end

function BNP:GetSpellbookDurationForSpellID(def, spellID)
  if not def or not spellID then return nil end
  BNP.spellbookDurationsByID = BNP.spellbookDurationsByID or {}

  if BNP.spellbookDurationsByID[spellID] then
    return BNP.spellbookDurationsByID[spellID]
  end

  local spell = findSpellByID(def, spellID)
  if spell then
    local ok, duration = pcall(scanSpell, spell.slot)
    if ok and duration and duration > 0 then
      BNP.spellbookDurationsByID[spellID] = duration
      return duration
    end
  end

  return nil
end

function BNP:GetSpellbookDurationForDef(def)
  if not def then return nil end
  BNP.spellbookDurations = BNP.spellbookDurations or {}

  if def.key and BNP.spellbookDurations[def.key] then
    return BNP.spellbookDurations[def.key]
  end

  if def.names then
    local i
    for i = 1, table.getn(def.names) do
      local key = string.lower(def.names[i])
      if BNP.spellbookDurations[key] then
        return BNP.spellbookDurations[key]
      end
    end

    -- Generic on-demand scan: works for every class, not only the original
    -- Warlock/Priest probe list.
    local spell = findSpell(def.names)
    if spell then
      local ok, duration = pcall(scanSpell, spell.slot)
      if ok and duration and duration > 0 then
        if def.key then BNP.spellbookDurations[def.key] = duration end
        BNP.spellbookDurations[string.lower(spell.name)] = duration
        return duration
      end
    end
  end

  return nil
end

function BNP:SpellbookProbe(key)
  self:RefreshSpellbookDurations()
  local keys = {}
  if key and key ~= "" and wanted[key] then
    table.insert(keys, key)
  else
    table.insert(keys, "corruption")
    table.insert(keys, "agony")
    table.insert(keys, "siphon")
    table.insert(keys, "shadow_word_pain")
  end

  self:Print("=== Spellbook Tooltip Probe ===")
  local k
  for k = 1, table.getn(keys) do
    local id = keys[k]
    local spell = findSpell(wanted[id])
    if not spell then
      self:Print(id .. ": not found in spellbook")
    else
      local ok, duration, lines = pcall(scanSpell, spell.slot)
      if not ok then
        self:Print(spell.name .. ": tooltip scan ERROR: " .. tostring(duration))
      else
        self:Print(spell.name .. " " .. tostring(spell.rank or "") .. " | Slot " .. spell.slot .. " | Duration: " .. tostring(duration or "NOT DETECTED"))
        local i
        for i = 1, table.getn(lines) do
          self:Print("  " .. i .. ": " .. lines[i])
        end
      end
    end
  end
end
