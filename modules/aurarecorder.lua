BNP = BNP or {}

-- Missing Spell / Aura Recorder --------------------------------------------
--
-- This diagnostic is deliberately dormant until the user presses New
-- Recording. While active it records only the selected target, player casts,
-- SuperWoW combat events and a throttled snapshot of the selected target's
-- negative auras. Closing or stopping the recorder unregisters every event and
-- removes its OnUpdate handler.

local recorder = BNP.auraRecorder or {}
BNP.auraRecorder = recorder

recorder.lines = recorder.lines or {}
recorder.registered = recorder.registered or {}
recorder.pendingSnapshots = recorder.pendingSnapshots or {}
recorder.active = false
recorder.dirty = false
recorder.limitHit = false
recorder.charCount = recorder.charCount or 0

local CAPTURE_CHAR_LIMIT = 48000
local REPORT_CHAR_LIMIT = 62000
local CAPTURE_LINE_LIMIT = 700
local REPORT_LINE_LIMIT = 900
local AURA_SCAN_INTERVAL = 0.15
local EDIT_REFRESH_INTERVAL = 0.25

local EVENT_NAMES = {
  "UNIT_CASTEVENT",
  "RAW_COMBATLOG",
  "SUPERWOW_COMBAT_LOG_EVENT",
  "UNIT_AURA",
  "PLAYER_TARGET_CHANGED",
  "UNIT_SPELLCAST_SENT",
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_DELAYED",
  "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_FAILED_QUIET",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_UPDATE",
  "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_RETICLE_TARGET",
  "UNIT_SPELLCAST_RETICLE_CLEAR",
  "CHAT_MSG_COMBAT_SELF_HITS",
  "CHAT_MSG_SPELL_SELF_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE",
  "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
  "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
  "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
  "CHAT_MSG_SPELL_BREAK_AURA",
  "CHAT_MSG_SPELL_AURA_GONE_OTHER",
  "CHAT_MSG_SPELL_AURA_GONE_SELF",
}

local SELF_COMBAT_EVENTS = {
  CHAT_MSG_COMBAT_SELF_HITS = true,
  CHAT_MSG_SPELL_SELF_DAMAGE = true,
}

local CLASSICAPI_SPELLCAST_EVENTS = {
  UNIT_SPELLCAST_SENT = true,
  UNIT_SPELLCAST_START = true,
  UNIT_SPELLCAST_STOP = true,
  UNIT_SPELLCAST_DELAYED = true,
  UNIT_SPELLCAST_SUCCEEDED = true,
  UNIT_SPELLCAST_INTERRUPTED = true,
  UNIT_SPELLCAST_FAILED = true,
  UNIT_SPELLCAST_FAILED_QUIET = true,
  UNIT_SPELLCAST_CHANNEL_START = true,
  UNIT_SPELLCAST_CHANNEL_UPDATE = true,
  UNIT_SPELLCAST_CHANNEL_STOP = true,
  UNIT_SPELLCAST_RETICLE_TARGET = true,
  UNIT_SPELLCAST_RETICLE_CLEAR = true,
}

local SHADOW_VULNERABILITY_IDS = {
  [17794] = true,
  [17797] = true,
  [17798] = true,
  [17799] = true,
  [17800] = true,
}

local SHADOW_BOLT_IDS = {
  [686] = true, [695] = true, [705] = true, [1088] = true,
  [1106] = true, [7641] = true, [11659] = true, [11660] = true,
  [11661] = true, [25307] = true,
}

local function CleanValue(value, maxLength)
  if value == nil then return "nil" end
  local text = tostring(value)
  text = string.gsub(text, "\r", "\\r")
  text = string.gsub(text, "\n", "\\n")
  text = string.gsub(text, "\t", "\\t")
  maxLength = maxLength or 260
  if string.len(text) > maxLength then
    text = string.sub(text, 1, maxLength) .. "..."
  end
  return text
end

local function GetUnitGUID(unit)
  if not unit then return nil end
  local ok, exists, guid = pcall(UnitExists, unit)
  if ok and exists and guid then return guid end
  if UnitGUID then
    local guidOK, classicGUID = pcall(UnitGUID, unit)
    if guidOK and classicGUID then return classicGUID end
  end
  return nil
end

local function SpellLabel(spellID)
  if not spellID then return "nil/?" end
  if SpellInfo then
    local ok, name, rank = pcall(SpellInfo, spellID)
    if ok and name then
      local label = tostring(spellID) .. "/" .. CleanValue(name, 100)
      if rank and rank ~= "" then label = label .. " " .. CleanValue(rank, 60) end
      return label
    end
  end
  if GetSpellInfo then
    local ok, name, rank = pcall(GetSpellInfo, spellID)
    if ok and name then
      local label = tostring(spellID) .. "/" .. CleanValue(name, 100)
      if rank and rank ~= "" then label = label .. " " .. CleanValue(rank, 60) end
      return label
    end
  end
  return tostring(spellID) .. "/?"
end

local function RelativeTime()
  if not recorder.startedAt then return "+0.000" end
  return string.format("+%.3f", GetTime() - recorder.startedAt)
end

local function ClassicAPIVersionLabel()
  if CLASSIC_API_VERSION == nil then return "not detected" end
  local numeric = tonumber(CLASSIC_API_VERSION)
  if not numeric then return CleanValue(CLASSIC_API_VERSION) end
  local major = math.floor(numeric / 10000)
  local minor = math.floor((numeric - (major * 10000)) / 100)
  local patch = numeric - (major * 10000) - (minor * 100)
  return tostring(numeric) .. " (" .. tostring(major) .. "." .. tostring(minor) .. "." .. tostring(patch) .. ")"
end

local function AppendLine(text, important)
  text = CleanValue(text, 1400)
  local charLimit = important and REPORT_CHAR_LIMIT or CAPTURE_CHAR_LIMIT
  local lineLimit = important and REPORT_LINE_LIMIT or CAPTURE_LINE_LIMIT
  local nextChars = (recorder.charCount or 0) + string.len(text) + 1

  if nextChars > charLimit or table.getn(recorder.lines) >= lineLimit then
    if not recorder.limitHit then
      local marker = "[CAPTURE LIMIT REACHED - recording stopped before the report became too large]"
      table.insert(recorder.lines, marker)
      recorder.charCount = (recorder.charCount or 0) + string.len(marker) + 1
      recorder.limitHit = true
      recorder.stopRequested = true
      recorder.dirty = true
    end
    return false
  end

  table.insert(recorder.lines, text)
  recorder.charCount = nextChars
  recorder.dirty = true
  return true
end

local function AppendTimed(kind, text)
  return AppendLine("[" .. RelativeTime() .. "] " .. tostring(kind) .. " | " .. tostring(text or ""), false)
end

local function ShallowFields(data)
  if type(data) ~= "table" then return CleanValue(data) end
  local fields = {}
  local key, value
  for key, value in pairs(data) do
    local valueType = type(value)
    if valueType ~= "table" and valueType ~= "function" and valueType ~= "userdata" then
      table.insert(fields, CleanValue(key, 80) .. "=" .. CleanValue(value, 220))
    end
  end
  table.sort(fields)
  if table.getn(fields) == 0 then return "(no scalar fields)" end
  return table.concat(fields, " | ")
end

local function IsRelatedText(raw)
  if not raw or raw == "" then return false end
  raw = tostring(raw)

  if recorder.traceGUID and string.find(raw, tostring(recorder.traceGUID), 1, true) then return true end
  if recorder.playerGUID and string.find(raw, tostring(recorder.playerGUID), 1, true) then return true end
  if recorder.traceName and recorder.traceName ~= "" and string.find(raw, recorder.traceName, 1, true) then return true end
  if recorder.playerName and recorder.playerName ~= "" and string.find(raw, recorder.playerName, 1, true) then return true end
  return false
end

local function CurrentSnapshotUnit()
  local targetGUID = GetUnitGUID("target")
  if recorder.traceGUID and targetGUID == recorder.traceGUID then return "target" end
  if recorder.traceGUID and UnitTokenFromGUID then
    local ok, token = pcall(UnitTokenFromGUID, recorder.traceGUID)
    if ok and token then return token end
  end
  if recorder.traceGUID then return recorder.traceGUID end
  if UnitName("target") then return "target" end
  return nil
end

local function QueueSnapshot(delay, reason, force)
  local pending = recorder.pendingSnapshots
  if table.getn(pending) >= 18 then return end
  table.insert(pending, {
    at = GetTime() + (delay or 0),
    reason = reason or "event",
    force = force and true or false,
  })
end

local function HasClassicAuraAPI()
  return type(C_UnitAuras) == "table" and type(C_UnitAuras.GetDebuffDataByIndex) == "function"
end

local function IsShadowVulnerability(spellID, spellName)
  local numeric = tonumber(spellID)
  if SHADOW_VULNERABILITY_IDS[numeric] then return true end
  local name = string.lower(tostring(spellName or ""))
  return name == "shadow vulnerability" or name == "schattenverwundbarkeit"
end

local function IsShadowBolt(spellID, spellName)
  local numeric = tonumber(spellID)
  if SHADOW_BOLT_IDS[numeric] then return true end
  local name = spellName
  if (not name or name == "") and numeric and SpellInfo then
    local ok, resolved = pcall(SpellInfo, numeric)
    if ok then name = resolved end
  end
  name = string.lower(tostring(name or ""))
  return name == "shadow bolt" or name == "schattenblitz"
end

local function ShouldCaptureClassicAura(aura)
  if type(aura) ~= "table" then return true end
  local spellID = tonumber(aura.spellId or aura.spellID)
  if IsShadowVulnerability(spellID, aura.name) then return true end

  if aura.sourceGUID and recorder.playerGUID then return aura.sourceGUID == recorder.playerGUID end
  if aura.sourceUnit then return aura.sourceUnit == "player" end
  -- ClassicAPI may omit source data for foreign auras. Unknown ownership is not
  -- enough to include a normal aura; Shadow Vulnerability was allowed above.
  return false
end

local function SnapshotClassicAPIAuras(unit, reason, force)
  if not HasClassicAuraAPI() then return end

  local signatureParts = {}
  local auraLines = {}
  local count = 0
  local shadowOnly = force and string.find(tostring(reason or ""), "Shadow", 1, true)
  local i
  for i = 1, 64 do
    local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, unit, i)
    if not ok then
      if force then
        AppendTimed(
          "CLASSICAPI_AURA_SNAPSHOT",
          "reason=" .. CleanValue(reason) .. " | unit=" .. CleanValue(unit) ..
          " | error=" .. CleanValue(aura)
        )
      end
      return
    end
    if not aura then break end

    if ShouldCaptureClassicAura(aura) and (not shadowOnly or IsShadowVulnerability(aura.spellId or aura.spellID, aura.name)) then
      count = count + 1
      local fields = ShallowFields(aura)
      table.insert(signatureParts, fields)

      local remaining = "unknown"
      local expiration = tonumber(aura.expirationTime)
      if expiration and expiration > 0 then
        remaining = string.format("%.3f", expiration - GetTime())
      end
      table.insert(
        auraLines,
        "  CLASSIC_AURA " .. tostring(i) ..
        " | remaining=" .. remaining ..
        " | " .. fields
      )
    end
  end

  local signature = table.concat(signatureParts, "||")
  local snapshotKey = (shadowOnly and "classic-shadow:" or "classic:") .. tostring(recorder.traceGUID or unit)
  local previous = recorder.lastAuraSignatures and recorder.lastAuraSignatures[snapshotKey]
  local changed = previous ~= signature

  recorder.lastAuraSignatures = recorder.lastAuraSignatures or {}
  recorder.lastAuraSignatures[snapshotKey] = signature
  if recorder.baselineOnly then return end
  if not changed and not force then return end

  AppendTimed(
    "CLASSICAPI_AURA_SNAPSHOT",
    "reason=" .. CleanValue(reason) ..
    " | unit=" .. CleanValue(unit) ..
    " | guid=" .. CleanValue(recorder.traceGUID) ..
    " | count=" .. tostring(count) ..
    " | changed=" .. (changed and "1" or "0")
  )
  if count == 0 then
    AppendLine("  CLASSIC_AURA none", false)
  else
    for i = 1, table.getn(auraLines) do AppendLine(auraLines[i], false) end
  end
end

local function SnapshotAuras(reason, force)
  local unit = CurrentSnapshotUnit()
  if not unit then
    if force then AppendTimed("AURA_SNAPSHOT", "reason=" .. CleanValue(reason) .. " | no target unit") end
    return
  end

  -- ClassicAPI exposes a richer AuraData table including spellId, duration,
  -- expirationTime and (where observed) sourceUnit/sourceGUID. Keep this
  -- snapshot independent from legacy UnitDebuff so a duration-only refresh is
  -- visible even when the vanilla aura slots themselves do not change.
  SnapshotClassicAPIAuras(unit, reason, force)
  if HasClassicAuraAPI() then return end

  local signatureParts = {}
  local auraLines = {}
  local count = 0
  local i
  for i = 1, 64 do
    local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = pcall(UnitDebuff, unit, i)
    if not ok then
      if force then
        AppendTimed("AURA_SNAPSHOT", "reason=" .. CleanValue(reason) .. " | UnitDebuff error=" .. CleanValue(a1))
      end
      return
    end
    if not a1 then break end

    count = count + 1
    local spellName = "?"
    local spellRank = nil
    if a4 and SpellInfo then
      local spellOK, name, rank = pcall(SpellInfo, a4)
      if spellOK and name then spellName = name end
      if spellOK then spellRank = rank end
    end

    table.insert(signatureParts,
      CleanValue(a1) .. ":" .. CleanValue(a2) .. ":" .. CleanValue(a3) .. ":" ..
      CleanValue(a4) .. ":" .. CleanValue(a5) .. ":" .. CleanValue(a6) .. ":" ..
      CleanValue(a7) .. ":" .. CleanValue(a8) .. ":" .. CleanValue(a9) .. ":" .. CleanValue(a10)
    )

    table.insert(auraLines,
      "  AURA " .. tostring(i) ..
      " | id=" .. CleanValue(a4) ..
      " | name=" .. CleanValue(spellName, 120) ..
      " | rank=" .. CleanValue(spellRank, 80) ..
      " | stacks=" .. CleanValue(a2) ..
      " | type=" .. CleanValue(a3) ..
      " | texture=" .. CleanValue(a1, 180) ..
      " | r5=" .. CleanValue(a5) ..
      " | r6=" .. CleanValue(a6) ..
      " | r7=" .. CleanValue(a7) ..
      " | r8=" .. CleanValue(a8) ..
      " | r9=" .. CleanValue(a9) ..
      " | r10=" .. CleanValue(a10)
    )
  end

  local signature = table.concat(signatureParts, "||")
  local snapshotKey = tostring(recorder.traceGUID or unit)
  local previous = recorder.lastAuraSignatures and recorder.lastAuraSignatures[snapshotKey]
  local changed = previous ~= signature

  recorder.lastAuraSignatures = recorder.lastAuraSignatures or {}
  recorder.lastAuraSignatures[snapshotKey] = signature

  if recorder.baselineOnly then return end

  if not changed and not force then return end

  AppendTimed(
    "AURA_SNAPSHOT",
    "reason=" .. CleanValue(reason) ..
    " | unit=" .. CleanValue(unit) ..
    " | guid=" .. CleanValue(recorder.traceGUID) ..
    " | count=" .. tostring(count) ..
    " | changed=" .. (changed and "1" or "0")
  )

  if count == 0 then
    AppendLine("  AURA none", false)
  else
    for i = 1, table.getn(auraLines) do AppendLine(auraLines[i], false) end
  end
end

local function UpdateTarget(reason)
  local exists, guid = UnitExists("target")
  local name = UnitName("target")
  if exists and guid then
    local changed = guid ~= recorder.traceGUID
    recorder.traceGUID = guid
    recorder.traceName = name or "?"
    if changed then
      AppendTimed(
        "TARGET",
        "reason=" .. CleanValue(reason) .. " | name=" .. CleanValue(recorder.traceName) .. " | guid=" .. CleanValue(guid)
      )
      QueueSnapshot(0.03, "target changed", false)
    end
  elseif not recorder.traceGUID then
    AppendTimed("TARGET", "reason=" .. CleanValue(reason) .. " | no target / no SuperWoW GUID")
  else
    AppendTimed("TARGET", "reason=" .. CleanValue(reason) .. " | target cleared; keeping guid=" .. CleanValue(recorder.traceGUID))
  end
end

local function IsRelevantCast(casterGUID, targetGUID)
  if recorder.playerGUID and casterGUID == recorder.playerGUID then return true end
  return false
end

local function HandleCastEvent()
  local casterGUID = arg1
  local targetGUID = arg2
  local eventType = arg3
  local spellID = arg4
  local duration = arg5
  if not IsRelevantCast(casterGUID, targetGUID) then return end

  AppendTimed(
    "UNIT_CASTEVENT",
    "type=" .. CleanValue(eventType) ..
    " | spell=" .. SpellLabel(spellID) ..
    " | caster=" .. CleanValue(casterGUID) ..
    " | target=" .. CleanValue(targetGUID) ..
    " | castDuration=" .. CleanValue(duration)
  )

  if IsShadowBolt(spellID) then
    QueueSnapshot(0.20, "200ms after Shadow Bolt UNIT_CASTEVENT", true)
  end
end

local function HandleRawCombatLog()
  local originalEvent = arg1
  local raw = arg2
  if not IsRelatedText(raw) then return end
  local lowerRaw = string.lower(tostring(raw or ""))
  local ownSignal = false
  if recorder.playerGUID and string.find(lowerRaw, string.lower(tostring(recorder.playerGUID)), 1, true) then ownSignal = true end
  if recorder.playerName and string.find(lowerRaw, string.lower(tostring(recorder.playerName)), 1, true) then ownSignal = true end
  local sharedSignal = string.find(lowerRaw, "shadow vulnerability", 1, true) or
    string.find(lowerRaw, "schattenverwundbarkeit", 1, true) or
    string.find(lowerRaw, "17794", 1, true) or string.find(lowerRaw, "17797", 1, true) or
    string.find(lowerRaw, "17798", 1, true) or string.find(lowerRaw, "17799", 1, true) or
    string.find(lowerRaw, "17800", 1, true)
  if not ownSignal and not sharedSignal then return end
  AppendTimed("RAW_COMBATLOG", "event=" .. CleanValue(originalEvent) .. " | raw=" .. CleanValue(raw, 1100))

  if sharedSignal then
    QueueSnapshot(0.04, "after Shadow Vulnerability RAW_COMBATLOG", true)
    QueueSnapshot(0.30, "300ms after Shadow Vulnerability RAW_COMBATLOG", true)
  end
end

local function HandleStructuredCombatLog()
  local timestamp = arg1
  local eventType = arg2
  local sourceGUID = arg3
  local sourceName = arg4
  local sourceFlags = arg5
  local destGUID = arg6
  local destName = arg7
  local destFlags = arg8
  local spellID = arg9
  local spellName = arg10
  local spellSchool = arg11

  local relevant = recorder.playerGUID and sourceGUID == recorder.playerGUID
  if recorder.traceGUID and destGUID == recorder.traceGUID and IsShadowVulnerability(spellID, spellName) then relevant = true end
  if not relevant then return end

  AppendTimed(
    "SUPERWOW_COMBAT_LOG_EVENT",
    "timestamp=" .. CleanValue(timestamp) ..
    " | event=" .. CleanValue(eventType) ..
    " | source=" .. CleanValue(sourceGUID) .. "/" .. CleanValue(sourceName, 100) .. "/" .. CleanValue(sourceFlags) ..
    " | dest=" .. CleanValue(destGUID) .. "/" .. CleanValue(destName, 100) .. "/" .. CleanValue(destFlags) ..
    " | spell=" .. CleanValue(spellID) .. "/" .. CleanValue(spellName, 120) ..
    " | school=" .. CleanValue(spellSchool) ..
    " | p12=" .. CleanValue(arg12) .. " | p13=" .. CleanValue(arg13) ..
    " | p14=" .. CleanValue(arg14) .. " | p15=" .. CleanValue(arg15) ..
    " | p16=" .. CleanValue(arg16) .. " | p17=" .. CleanValue(arg17) ..
    " | p18=" .. CleanValue(arg18) .. " | p19=" .. CleanValue(arg19) ..
    " | p20=" .. CleanValue(arg20)
  )

  if IsShadowVulnerability(spellID, spellName) then
    QueueSnapshot(0.03, "after structured Shadow Vulnerability", true)
    QueueSnapshot(0.25, "250ms after structured Shadow Vulnerability", true)
  end
end

local function HandleUnitAura()
  local unit = arg1
  if unit ~= "target" then return end
  local guid = GetUnitGUID(unit)
  AppendTimed("UNIT_AURA", "unit=" .. CleanValue(unit) .. " | guid=" .. CleanValue(guid))
  QueueSnapshot(0.02, "after UNIT_AURA", false)
end

local function HandleClassicAPISpellcast(eventName)
  local unit = arg1
  local targetName = nil
  local castGUID, spellID, spellName, rank

  if eventName == "UNIT_SPELLCAST_SENT" then
    targetName = arg2
    castGUID = arg3
    spellID = arg4
    spellName = arg5
    rank = arg6
  else
    castGUID = arg2
    spellID = arg3
    spellName = arg4
    rank = arg5
  end

  local unitGUID = GetUnitGUID(unit)
  local relevant = unit == "player"
  if recorder.traceGUID and (unitGUID == recorder.traceGUID or unit == recorder.traceGUID) then relevant = true end
  if targetName and recorder.traceName and targetName == recorder.traceName then relevant = true end
  if not relevant then return end

  AppendTimed(
    "CLASSICAPI_" .. tostring(eventName),
    "unit=" .. CleanValue(unit) ..
    " | unitGUID=" .. CleanValue(unitGUID) ..
    " | castGUID=" .. CleanValue(castGUID) ..
    " | spell=" .. CleanValue(spellID) .. "/" .. CleanValue(spellName, 120) ..
    " | rank=" .. CleanValue(rank, 80) ..
    " | targetName=" .. CleanValue(targetName, 120)
  )

  -- UNIT_CASTEVENT supplies the single post-cast control snapshot. Keeping the
  -- modern spellcast events as text avoids three duplicate aura dumps per cast.
end

local function HandleCombatText(eventName)
  local raw = arg1
  if not SELF_COMBAT_EVENTS[eventName] then
    if not IsRelatedText(raw) then return end
    local lower = string.lower(tostring(raw or ""))
    local ownSignal = string.find(lower, "your ", 1, true)
    if recorder.playerName and string.find(lower, string.lower(tostring(recorder.playerName)), 1, true) then ownSignal = true end
    local sharedSignal = string.find(lower, "shadow vulnerability", 1, true) or
      string.find(lower, "schattenverwundbarkeit", 1, true)
    if not ownSignal and not sharedSignal then return end
  end
  AppendTimed(
    eventName,
    "a1=" .. CleanValue(raw, 1050) ..
    " | a2=" .. CleanValue(arg2, 160) ..
    " | a3=" .. CleanValue(arg3, 160) ..
    " | a4=" .. CleanValue(arg4, 160)
  )
end

local eventFrame = recorder.eventFrame or CreateFrame("Frame", "BNPAuraRecorderEventFrame")
recorder.eventFrame = eventFrame
eventFrame:SetScript("OnEvent", function()
  if not recorder.active then return end
  local eventName = event

  if eventName == "UNIT_CASTEVENT" then
    HandleCastEvent()
  elseif eventName == "RAW_COMBATLOG" then
    HandleRawCombatLog()
  elseif eventName == "SUPERWOW_COMBAT_LOG_EVENT" then
    HandleStructuredCombatLog()
  elseif eventName == "UNIT_AURA" then
    HandleUnitAura()
  elseif eventName == "PLAYER_TARGET_CHANGED" then
    UpdateTarget("PLAYER_TARGET_CHANGED")
  elseif CLASSICAPI_SPELLCAST_EVENTS[eventName] then
    HandleClassicAPISpellcast(eventName)
  else
    HandleCombatText(eventName)
  end
end)

local function SafeRegister(eventName)
  if type(C_EventUtils) == "table" and type(C_EventUtils.IsEventValid) == "function" then
    local validOK, valid = pcall(C_EventUtils.IsEventValid, eventName)
    if validOK and not valid then return false end
  end
  local ok = pcall(eventFrame.RegisterEvent, eventFrame, eventName)
  if ok then recorder.registered[eventName] = true end
  return ok
end

local function UnregisterRecorderEvents()
  pcall(eventFrame.UnregisterAllEvents, eventFrame)
  recorder.registered = {}
end

local function StatusText()
  local target = tostring(recorder.traceName or "no target")
  local guid = tostring(recorder.traceGUID or "no GUID")
  local lineCount = table.getn(recorder.lines)
  if recorder.copyNotice then return recorder.copyNotice end
  if recorder.active then
    return "RECORDING  |  Target: " .. target .. "  |  " .. guid .. "  |  " .. tostring(lineCount) .. " lines"
  end
  if recorder.limitHit then
    return "STOPPED (size limit)  |  " .. tostring(lineCount) .. " lines  |  Copy the report"
  end
  return "STOPPED  |  Target: " .. target .. "  |  " .. tostring(lineCount) .. " lines  |  Copy the report"
end

local function RefreshRecorderText(force)
  if not recorder.frame or not recorder.editBox then return end
  if not force and not recorder.dirty then return end

  local report = table.concat(recorder.lines, "\n")
  recorder.editBox:SetText(report)

  local visualLines = 0
  local i
  for i = 1, table.getn(recorder.lines) do
    local length = string.len(recorder.lines[i] or "")
    visualLines = visualLines + math.max(1, math.ceil(length / 96))
  end
  recorder.editBox:SetHeight(math.max(330, (visualLines * 13) + 24))
  if recorder.scrollFrame and recorder.scrollFrame.UpdateScrollChildRect then
    recorder.scrollFrame:UpdateScrollChildRect()
  end

  if recorder.status then
    recorder.status:SetText(StatusText())
    if recorder.copyNotice then
      recorder.status:SetTextColor(0.2, 1, 0.35)
    elseif recorder.active then
      recorder.status:SetTextColor(0.2, 1, 0.35)
    elseif recorder.limitHit then
      recorder.status:SetTextColor(1, 0.35, 0.2)
    else
      recorder.status:SetTextColor(1, 0.82, 0)
    end
  end

  if recorder.stopButton then
    if recorder.active then recorder.stopButton:Enable() else recorder.stopButton:Disable() end
  end
  recorder.dirty = false
end

local function DumpScalarTable(label, data, important)
  if type(data) ~= "table" then
    AppendLine(label .. " | " .. CleanValue(data), important)
    return
  end
  AppendLine(label .. " | " .. ShallowFields(data), important)
end

local function DumpInternalDiagnostics()
  AppendLine("", true)
  AppendLine("=== INTERNAL BNP DIAGNOSTICS ===", true)
  AppendLine("Target | name=" .. CleanValue(recorder.traceName) .. " | guid=" .. CleanValue(recorder.traceGUID), true)

  local guid = recorder.traceGUID
  local cache = guid and BNP.guidAuras and BNP.guidAuras[guid]
  AppendLine("--- GUID AURA CACHE ---", true)
  if not cache then
    AppendLine("CACHE | empty", true)
  else
    local cacheKey, aura
    local cacheCount = 0
    for cacheKey, aura in pairs(cache) do
      if type(aura) == "table" then
        cacheCount = cacheCount + 1
        AppendLine("CACHE | key=" .. CleanValue(cacheKey) .. " | " .. ShallowFields(aura), true)
      end
    end
    if cacheCount == 0 then AppendLine("CACHE | no aura tables | " .. ShallowFields(cache), true) end
  end

  AppendLine("--- SHADOW VULNERABILITY STATE ---", true)
  local svState = guid and BNP.svStateByGUID and BNP.svStateByGUID[guid]
  if svState then DumpScalarTable("SV_STATE", svState, true) else AppendLine("SV_STATE | none", true) end

  local rendered = false
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate:IsShown() and plate.GetName and plate:GetName(1) == guid then
      local container = plate.BNPAuraContainer
      if container and container.icons then
        local iconIndex
        for iconIndex = 1, table.getn(container.icons) do
          local icon = container.icons[iconIndex]
          if icon and icon.BNPSVRenderedExpires then
            AppendLine(
              "SV_RENDER | icon=" .. tostring(iconIndex) ..
              " | timerText=" .. CleanValue(icon.timer and icon.timer:GetText()) ..
              " | renderedExpires=" .. CleanValue(icon.BNPSVRenderedExpires) ..
              " | revision=" .. CleanValue(icon.BNPSVRenderRevision),
              true
            )
            rendered = true
          end
        end
      end
    end
  end
  if not rendered then AppendLine("SV_RENDER | no visible SV icon", true) end

  AppendLine("--- PENDING AURAS ---", true)
  local pending = guid and BNP.pendingAuras and BNP.pendingAuras[guid]
  if not pending then
    AppendLine("PENDING | none", true)
  else
    local pendingKey, pendingAura
    for pendingKey, pendingAura in pairs(pending) do
      AppendLine("PENDING | key=" .. CleanValue(pendingKey) .. " | " .. ShallowFields(pendingAura), true)
    end
  end

  AppendLine("--- LAST TRACKED AURA TRANSITIONS ---", true)
  local trace = BNP.raidTrace or {}
  local start = math.max(1, table.getn(trace) - 29)
  local i
  if table.getn(trace) == 0 then AppendLine("RAID_TRACE | none", true) end
  for i = start, table.getn(trace) do
    local traceEntry = trace[i]
    AppendLine("RAID_TRACE " .. tostring(i) .. " | " .. ShallowFields(traceEntry), true)
  end

  AppendLine("--- UNKNOWN SPELL / AURA COLLECTOR ---", true)
  local unknown = BNP.unknownBeta
  if not unknown or table.getn(unknown.order or {}) == 0 then
    AppendLine("UNKNOWN | no indexed entries", true)
  else
    for i = 1, table.getn(unknown.order) do
      local unknownKey = unknown.order[i]
      local unknownEntry = unknown.entries and unknown.entries[unknownKey]
      if unknownEntry then
        AppendLine("UNKNOWN | key=" .. CleanValue(unknownKey) .. " | " .. ShallowFields(unknownEntry), true)
      end
    end
  end
  if unknown and unknown.combat then
    local effectKey, effect
    for effectKey, effect in pairs(unknown.combat) do
      AppendLine("UNKNOWN_EFFECT | key=" .. CleanValue(effectKey, 220) .. " | " .. ShallowFields(effect), true)
    end
  end

  AppendLine("--- DIRECT PLAYER CAST EVENTS ---", true)
  local directCount = 0
  local directKey, directEntry
  for directKey, directEntry in pairs(BNP.unknownDirectEvents or {}) do
    directCount = directCount + 1
    AppendLine("DIRECT | key=" .. CleanValue(directKey) .. " | " .. ShallowFields(directEntry), true)
  end
  if directCount == 0 then AppendLine("DIRECT | none", true) end

  AppendLine("--- SPELLDB SHADOW AUDIT ---", true)
  local spellDB = BNP.SpellDBShadow
  if not spellDB then
    AppendLine("SPELLDB | unavailable", true)
  else
    DumpScalarTable("SPELLDB_STATS", spellDB.stats, true)
    local recent = spellDB.recent or {}
    for i = 1, table.getn(recent) do
      AppendLine("SPELLDB_RECENT " .. tostring(i) .. " | " .. ShallowFields(recent[i]), true)
    end
  end

  AppendLine("--- SHADOW VULNERABILITY PROBE ---", true)
  local probe = BNP.svProbe
  if not probe then
    AppendLine("SV_PROBE | unavailable", true)
  else
    if probe.last then DumpScalarTable("SV_PROBE_LAST", probe.last, true) else AppendLine("SV_PROBE_LAST | none", true) end
    local probeEvents = probe.events or {}
    for i = 1, table.getn(probeEvents) do
      AppendLine("SV_PROBE_EVENT " .. tostring(i) .. " | " .. ShallowFields(probeEvents[i]), true)
    end
    local rawEvents = probe.raw or {}
    for i = 1, table.getn(rawEvents) do
      AppendLine("SV_PROBE_RAW " .. tostring(i) .. " | " .. ShallowFields(rawEvents[i]), true)
    end
  end
end

local updateFrame = recorder.updateFrame or CreateFrame("Frame", "BNPAuraRecorderUpdateFrame")
recorder.updateFrame = updateFrame

local function RecorderOnUpdate()
  recorder.scanElapsed = (recorder.scanElapsed or 0) + arg1
  recorder.editElapsed = (recorder.editElapsed or 0) + arg1

  if recorder.scanElapsed >= AURA_SCAN_INTERVAL then
    recorder.scanElapsed = 0
    SnapshotAuras("poll change", false)

    local now = GetTime()
    local i = 1
    while i <= table.getn(recorder.pendingSnapshots) do
      local pending = recorder.pendingSnapshots[i]
      if pending and now >= (pending.at or 0) then
        table.remove(recorder.pendingSnapshots, i)
        SnapshotAuras(pending.reason, pending.force)
      else
        i = i + 1
      end
    end
  end

  if recorder.editElapsed >= EDIT_REFRESH_INTERVAL then
    recorder.editElapsed = 0
    RefreshRecorderText(false)
  end

  if recorder.stopRequested then
    BNP:StopAuraRecorder("capture limit")
  end
end

function BNP:StartAuraRecorder()
  -- New Recording is also a clean restart when a capture is already running.
  if recorder.active then
    recorder.active = false
    UnregisterRecorderEvents()
    updateFrame:SetScript("OnUpdate", nil)
  end

  UnregisterRecorderEvents()
  recorder.lines = {}
  recorder.charCount = 0
  recorder.limitHit = false
  recorder.stopRequested = false
  recorder.copyNotice = nil
  recorder.pendingSnapshots = {}
  recorder.lastAuraSignatures = {}
  recorder.startedAt = GetTime()
  recorder.stoppedAt = nil
  recorder.scanElapsed = 0
  recorder.editElapsed = 0
  recorder.playerGUID = GetUnitGUID("player")
  recorder.playerName = UnitName("player") or "?"
  recorder.traceGUID = nil
  recorder.traceName = nil
  recorder.active = true

  local registeredCount = 0
  local i
  for i = 1, table.getn(EVENT_NAMES) do
    if SafeRegister(EVENT_NAMES[i]) then registeredCount = registeredCount + 1 end
  end
  local classicSpellcastCount = 0
  local classicEventName
  for classicEventName in pairs(CLASSICAPI_SPELLCAST_EVENTS) do
    if recorder.registered[classicEventName] then classicSpellcastCount = classicSpellcastCount + 1 end
  end

  AppendLine("BNP_MISSING_SPELL_AURA_REPORT v1", true)
  AppendLine("Addon | version=" .. CleanValue(BNP.version), true)
  AppendLine(
    "SuperWoW | string=" .. CleanValue(SUPERWOW_STRING) ..
    " | version=" .. CleanValue(SUPERWOW_VERSION) ..
    " | CombatLogAdd=" .. (CombatLogAdd and "yes" or "no") ..
    " | SpellInfo=" .. (SpellInfo and "yes" or "no"),
    true
  )
  AppendLine(
    "ClassicAPI | version=" .. ClassicAPIVersionLabel() ..
    " | C_UnitAuras=" .. (HasClassicAuraAPI() and "yes" or "no") ..
    " | UnitGUID=" .. (UnitGUID and "yes" or "no") ..
    " | UnitTokenFromGUID=" .. (UnitTokenFromGUID and "yes" or "no") ..
    " | CopyToClipboard=" .. (CopyToClipboard and "yes" or "no") ..
    " | spellcastEvents=" .. tostring(classicSpellcastCount),
    true
  )
  if GetBuildInfo then
    local version, build, buildDate, interfaceVersion = GetBuildInfo()
    AppendLine(
      "Client | version=" .. CleanValue(version) .. " | build=" .. CleanValue(build) ..
      " | date=" .. CleanValue(buildDate) .. " | interface=" .. CleanValue(interfaceVersion) ..
      " | locale=" .. CleanValue(GetLocale and GetLocale()),
      true
    )
  end
  local _, class = UnitClass("player")
  AppendLine(
    "Player | name=" .. CleanValue(recorder.playerName) .. " | class=" .. CleanValue(class) ..
    " | guid=" .. CleanValue(recorder.playerGUID),
    true
  )
  AppendLine(
    "Sources | registered=" .. tostring(registeredCount) .. "/" .. tostring(table.getn(EVENT_NAMES)) ..
    " | RAW_COMBATLOG=" .. (recorder.registered.RAW_COMBATLOG and "yes" or "no") ..
    " | STRUCTURED=" .. (recorder.registered.SUPERWOW_COMBAT_LOG_EVENT and "yes" or "no") ..
    " | CLASSICAPI_AURAS=" .. (HasClassicAuraAPI() and "yes" or "no"),
    true
  )
  AppendLine("Aura filter | own auras + Shadow Vulnerability from any Warlock", true)
  AppendLine("Test | apply aura, refresh while active, then let it expire or remove it", true)
  AppendLine("=== LIVE RECORDING ===", true)

  UpdateTarget("recording started")
  -- Establish a silent baseline. Existing foreign auras must not appear just
  -- because the user pressed Start Recording; only later changes are logged.
  recorder.baselineOnly = true
  SnapshotAuras("baseline", false)
  recorder.baselineOnly = false

  updateFrame:SetScript("OnUpdate", RecorderOnUpdate)
  recorder.dirty = true
  RefreshRecorderText(true)
end

function BNP:StopAuraRecorder(reason)
  if not recorder.active then
    RefreshRecorderText(true)
    return
  end

  recorder.stopRequested = false
  SnapshotAuras("final before stop", true)
  recorder.active = false
  recorder.stoppedAt = GetTime()
  UnregisterRecorderEvents()
  updateFrame:SetScript("OnUpdate", nil)
  DumpInternalDiagnostics()
  AppendLine("=== END REPORT | reason=" .. CleanValue(reason or "user") .. " | elapsed=" ..
    string.format("%.3f", recorder.stoppedAt - (recorder.startedAt or recorder.stoppedAt)) .. "s ===", true)
  recorder.dirty = true
  RefreshRecorderText(true)
end

function BNP:ClearAuraRecorder()
  if recorder.active then self:StopAuraRecorder("cleared") end
  recorder.lines = {}
  recorder.charCount = 0
  recorder.limitHit = false
  recorder.stopRequested = false
  recorder.copyNotice = nil
  recorder.pendingSnapshots = {}
  recorder.lastAuraSignatures = {}
  recorder.traceGUID = nil
  recorder.traceName = nil
  recorder.dirty = true
  RefreshRecorderText(true)
end

function BNP:SelectAllAuraRecorderText()
  if not recorder.editBox then return end
  RefreshRecorderText(true)
  recorder.editBox:SetFocus()
  recorder.editBox:HighlightText()
end

function BNP:CopyAuraRecorderText()
  RefreshRecorderText(true)
  local report = table.concat(recorder.lines, "\n")

  if CopyToClipboard then
    local ok = pcall(CopyToClipboard, report)
    if ok then
      recorder.copyNotice = "COPIED TO CLIPBOARD  |  Paste the report with Ctrl+V"
      recorder.dirty = true
      RefreshRecorderText(true)
      return true
    end
  end

  -- Older ClassicAPI builds and plain 1.12 clients have no direct clipboard
  -- function. Keep the normal edit-box path as a complete fallback.
  self:SelectAllAuraRecorderText()
  recorder.copyNotice = "TEXT SELECTED  |  Press Ctrl+C, then paste the report"
  recorder.dirty = true
  RefreshRecorderText(true)
  recorder.editBox:SetFocus()
  recorder.editBox:HighlightText()
  return false
end

function BNP:CreateAuraRecorderWindow()
  if recorder.frame then return recorder.frame end

  local frame = CreateFrame("Frame", "BNPAuraRecorderFrame", UIParent)
  frame:SetWidth(760)
  frame:SetHeight(560)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  frame:SetScript("OnHide", function()
    if recorder.active then BNP:StopAuraRecorder("window closed") end
  end)
  frame:Hide()
  recorder.frame = frame

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("Missing Spell / Aura Recorder")

  local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  instructions:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -46)
  instructions:SetWidth(706)
  instructions:SetJustifyH("LEFT")
  if CopyToClipboard then
    instructions:SetText("1. Select the affected unit.  2. Start Recording.  3. Apply the aura, refresh it while active, then let it expire or remove it.  4. Stop.  5. Copy Report and paste it.")
  else
    instructions:SetText("1. Select the affected unit.  2. Start Recording.  3. Apply the aura, refresh it while active, then let it expire or remove it.  4. Stop.  5. Select All, press Ctrl+C and paste it.")
  end

  local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  status:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -86)
  status:SetWidth(706)
  status:SetJustifyH("LEFT")
  recorder.status = status

  local startButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  startButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -112)
  startButton:SetWidth(126)
  startButton:SetHeight(24)
  startButton:SetText("Start Recording")
  startButton:SetScript("OnClick", function() BNP:StartAuraRecorder() end)
  recorder.startButton = startButton

  local stopButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  stopButton:SetPoint("LEFT", startButton, "RIGHT", 8, 0)
  stopButton:SetWidth(82)
  stopButton:SetHeight(24)
  stopButton:SetText("Stop")
  stopButton:SetScript("OnClick", function() BNP:StopAuraRecorder("user") end)
  recorder.stopButton = stopButton

  local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  clearButton:SetPoint("LEFT", stopButton, "RIGHT", 8, 0)
  clearButton:SetWidth(82)
  clearButton:SetHeight(24)
  clearButton:SetText("Clear")
  clearButton:SetScript("OnClick", function() BNP:ClearAuraRecorder() end)

  local selectButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  selectButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
  selectButton:SetWidth(108)
  selectButton:SetHeight(24)
  selectButton:SetText(CopyToClipboard and "Copy Report" or "Select All")
  selectButton:SetScript("OnClick", function() BNP:CopyAuraRecorderText() end)

  local copyHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  copyHint:SetPoint("LEFT", selectButton, "RIGHT", 10, 0)
  copyHint:SetText(CopyToClipboard and "then paste" or "then Ctrl+C")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

  local textBG = CreateFrame("Frame", nil, frame)
  textBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -146)
  textBG:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 48)
  textBG:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  textBG:SetBackdropColor(0.015, 0.015, 0.015, 0.95)
  textBG:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

  local scroll = CreateFrame("ScrollFrame", "BNPAuraRecorderScrollFrame", textBG, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", textBG, "TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", textBG, "BOTTOMRIGHT", -28, 8)
  recorder.scrollFrame = scroll

  local edit = CreateFrame("EditBox", "BNPAuraRecorderEditBox", scroll)
  edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  edit:SetWidth(676)
  edit:SetHeight(330)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetTextColor(0.92, 0.92, 0.92)
  edit:SetMaxLetters(65000)
  edit:EnableMouse(true)
  edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  edit:SetScript("OnTextChanged", function()
    if recorder.scrollFrame and recorder.scrollFrame.UpdateScrollChildRect then
      recorder.scrollFrame:UpdateScrollChildRect()
    end
  end)
  scroll:SetScrollChild(edit)
  recorder.editBox = edit

  local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 26, 24)
  footer:SetWidth(706)
  footer:SetJustifyH("LEFT")
  footer:SetText("The recorder changes no tracking settings. It is completely inactive after Stop or Close.")

  RefreshRecorderText(true)
  return frame
end

function BNP:OpenAuraRecorder()
  local function OpenFullRecorder()
    local frame = BNP:CreateAuraRecorderWindow()
    frame:Show()
    RefreshRecorderText(true)
  end

  local ok = pcall(OpenFullRecorder)
  if not ok and self.OpenEmergencyAuraRecorder then
    self:OpenEmergencyAuraRecorder()
  end
end
