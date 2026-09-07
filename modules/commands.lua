-- Elite dragon render probe ---------------------------------------------------
-- Kept directly in commands.lua on purpose so /bnp dragontest cannot depend
-- on a separate module loading successfully. This is render-only: it does not
-- alter level text, classification state, nameplate discovery, or saved data.
local function BNP_FindTargetPlateForDragonTest()
  if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok and plate then return plate end
  end

  local exists, guid = UnitExists("target")
  if not exists or not guid then return nil end
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate:IsShown() and plate.GetName then
      local ok, token = pcall(plate.GetName, plate, 1)
      if ok and token == guid then return plate end
    end
  end
  return nil
end

local function BNP_ToggleDirectDragonRenderTest()
  if not UnitExists("target") then
    BNP:Print("Target a visible unit first.")
    return
  end

  local plate = BNP_FindTargetPlateForDragonTest()
  if not plate then
    BNP:Print("Target nameplate not found. Keep the target nameplate visible and try again.")
    return
  end

  local healthbar = plate.healthbar
  if not healthbar and plate.GetChildren then
    healthbar = plate:GetChildren()
    plate.healthbar = healthbar
  end
  if not healthbar then
    BNP:Print("Target healthbar not found.")
    return
  end

  if not plate.BNPDirectDragonTestFrame then
    -- Put the dragon directly on the healthbar BACKGROUND layer.
    -- This keeps the exact size/position/scaling, but lets the bar, border
    -- and level text draw in front of it at all times.
    local t = healthbar:CreateTexture(nil, "BACKGROUND")
    t:SetWidth(37)
    t:SetHeight(28)
    t:SetPoint("CENTER", healthbar, "RIGHT", 20, -1)
    t:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
    t:SetTexCoord(0.58, 1.00, 0.00, 0.78125)

    t:Hide()
    plate.BNPDirectDragonTestFrame = t
  end

  local f = plate.BNPDirectDragonTestFrame
  if f:IsShown() then
    f:Hide()
    BNP:Print("Dragon test OFF.")
  else
    f:Show()
    local classification = UnitClassification and UnitClassification("target") or "?"
    BNP:Print("Dragon test ON. Classification: " .. tostring(classification) .. ".")
  end
end


-- Automatic Elite / World Boss dragon ---------------------------------------
-- Keep this in commands.lua deliberately: /bnp dragontest and /bnp eliteinfo
-- prove that this file and this exact plate/render path work on the 1.12 client.
-- The automatic path reuses the SAME frame created by dragontest.
local BNP_EliteAutoNextScan = 0
local BNP_EliteAutoState = {
  ticks = 0,
  visible = 0,
  elite = 0,
  shown = 0,
  lastClass = "nil",
  lastError = "none",
}

local function BNP_GetOrCreateAutoDragon(plate)
  if not plate then return nil end

  -- Reuse the exact proven dragontest frame if it already exists.
  if plate.BNPDirectDragonTestFrame then
    return plate.BNPDirectDragonTestFrame
  end

  local healthbar = plate.healthbar
  if not healthbar and plate.GetChildren then
    healthbar = plate:GetChildren()
    plate.healthbar = healthbar
  end
  if not healthbar then return nil end

  -- Same render path as /bnp dragontest: a BACKGROUND texture directly
  -- on the healthbar, so the dragon always stays behind bar/level elements.
  local t = healthbar:CreateTexture(nil, "BACKGROUND")
  t:SetWidth(37)
  t:SetHeight(28)
  t:SetPoint("CENTER", healthbar, "RIGHT", 20, -1)
  t:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
  t:SetTexCoord(0.58, 1.00, 0.00, 0.78125)

  t:Hide()
  plate.BNPDirectDragonTestFrame = t
  return t
end

local function BNP_UpdateEliteDragonPlate(plate, unit)
  if not plate or not plate:IsShown() then
    if plate and plate.BNPDirectDragonTestFrame then
      plate.BNPDirectDragonTestFrame:Hide()
    end
    return
  end

  local token = unit
  if not token and plate.GetName then
    token = plate:GetName(1)
  end

  local classification = nil
  if token and UnitClassification then
    classification = UnitClassification(token)
  end

  local dragon = BNP_GetOrCreateAutoDragon(plate)
  if not dragon then return end

  if classification == "elite" or classification == "worldboss" then
    dragon:Show()
  else
    dragon:Hide()
  end
end

local function BNP_RunEliteAutoScan()
  local visible = 0
  local elite = 0
  local shown = 0
  local lastClass = "nil"

  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate:IsShown() then
      visible = visible + 1

      local classification = nil
      local token = nil
      if plate.GetName then
        token = plate:GetName(1)
      end
      if token and UnitClassification then
        classification = UnitClassification(token)
      end
      lastClass = tostring(classification or "nil")

      local dragon = BNP_GetOrCreateAutoDragon(plate)
      if dragon then
        if classification == "elite" or classification == "worldboss" then
          elite = elite + 1
          dragon:Show()
          shown = shown + 1
        else
          dragon:Hide()
        end
      end
    elseif plate and plate.BNPDirectDragonTestFrame then
      plate.BNPDirectDragonTestFrame:Hide()
    end
  end

  BNP_EliteAutoState.visible = visible
  BNP_EliteAutoState.elite = elite
  BNP_EliteAutoState.shown = shown
  BNP_EliteAutoState.lastClass = lastClass
end

-- Instant path ---------------------------------------------------------------
-- 1) BNP's own OnShow fires immediately when an already-known Blizzard plate
--    is shown/reused.
if BNP.libnameplate and BNP.libnameplate.OnShow then
  table.insert(BNP.libnameplate.OnShow, function(plate)
    BNP_UpdateEliteDragonPlate(plate)
  end)
end

-- 2) ClassicAPI's nameplate event can resolve the unit token directly on the
--    frame it belongs to. This is the fastest path for newly appearing plates.
local BNP_EliteInstantEvents = CreateFrame("Frame", nil, UIParent)
local addedOK = pcall(BNP_EliteInstantEvents.RegisterEvent, BNP_EliteInstantEvents, "NAME_PLATE_UNIT_ADDED")
local removedOK = pcall(BNP_EliteInstantEvents.RegisterEvent, BNP_EliteInstantEvents, "NAME_PLATE_UNIT_REMOVED")

if addedOK or removedOK then
  BNP_EliteInstantEvents:SetScript("OnEvent", function()
    local unit = arg1
    if not unit then return end

    if event == "NAME_PLATE_UNIT_ADDED" then
      if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and plate then
          BNP_UpdateEliteDragonPlate(plate, unit)
        end
      end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      -- The fallback pass clears hidden/recycled frames. If ClassicAPI still
      -- exposes the frame at removal time, hide it immediately as well.
      if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and plate and plate.BNPDirectDragonTestFrame then
          plate.BNPDirectDragonTestFrame:Hide()
        end
      end
    end
  end)
end

-- Apply immediately to any plates that were already visible when this module
-- loaded. Afterwards the 0.50s scan is only a safety net.
pcall(BNP_RunEliteAutoScan)

local BNP_EliteAutoFrame = CreateFrame("Frame", nil, UIParent)
BNP_EliteAutoFrame:SetScript("OnUpdate", function()
  local now = GetTime()
  if now < BNP_EliteAutoNextScan then return end
  BNP_EliteAutoNextScan = now + 0.50
  BNP_EliteAutoState.ticks = BNP_EliteAutoState.ticks + 1

  local ok, err = pcall(BNP_RunEliteAutoScan)
  if not ok then
    BNP_EliteAutoState.lastError = tostring(err or "unknown")
  else
    BNP_EliteAutoState.lastError = "none"
  end
end)
BNP_EliteAutoFrame:Show()


local function BNP_PrintEliteInfo()
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffBNP ELITEINFO|r")

  local targetExists, targetGUID = UnitExists("target")
  local targetName = UnitName("target") or "?"
  local targetClass = UnitClassification and UnitClassification("target") or "?"
  local targetLevel = UnitLevel and UnitLevel("target") or "?"

  DEFAULT_CHAT_FRAME:AddMessage(
    "TARGET | "..tostring(targetName)..
    " | level "..tostring(targetLevel)..
    " | class "..tostring(targetClass)..
    " | guid "..tostring(targetGUID or "nil")
  )

  if not targetExists then
    DEFAULT_CHAT_FRAME:AddMessage("No target. Target a visible Elite and run /bnp eliteinfo again.")
    return
  end

  local apiTargetPlate = nil
  if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
    local ok, frame = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if ok then apiTargetPlate = frame end
  end
  DEFAULT_CHAT_FRAME:AddMessage("C_NamePlate(target) | "..tostring(apiTargetPlate and "FOUND" or "nil"))

  local matchedPlate = nil
  local visible = 0
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate:IsShown() then
      visible = visible + 1
      local rawToken = nil
      if plate.GetName then
        local ok, value = pcall(plate.GetName, plate, 1)
        if ok then rawToken = value end
      end

      local directMatch = apiTargetPlate and plate == apiTargetPlate
      local guidMatch = targetGUID and rawToken == targetGUID
      if directMatch or guidMatch then
        matchedPlate = plate
        local rawExists, rawGUID = false, nil
        if rawToken then rawExists, rawGUID = UnitExists(rawToken) end
        local rawClass = "nil"
        if rawToken and UnitClassification then
          local ok, value = pcall(UnitClassification, rawToken)
          if ok then rawClass = value end
        end
        DEFAULT_CHAT_FRAME:AddMessage(
          "BNP MATCH | direct "..tostring(directMatch and 1 or 0)..
          " | guid "..tostring(guidMatch and 1 or 0)..
          " | token "..tostring(rawToken or "nil")
        )
        DEFAULT_CHAT_FRAME:AddMessage(
          "BNP TOKEN | exists "..tostring(rawExists and 1 or 0)..
          " | guid "..tostring(rawGUID or "nil")..
          " | class "..tostring(rawClass or "nil")
        )
        break
      end
    end
  end
  DEFAULT_CHAT_FRAME:AddMessage("BNP visible plates | "..tostring(visible).." | target match "..tostring(matchedPlate and "YES" or "NO"))

  local existing = 0
  local guidMatchUnit = nil
  local frameMatchUnit = nil
  local i
  for i = 1, 40 do
    local unit = "nameplate"..tostring(i)
    local exists, guid = UnitExists(unit)
    if exists then
      existing = existing + 1
      local class = UnitClassification and UnitClassification(unit) or "?"
      local frame = nil
      if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
        local ok, value = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok then frame = value end
      end

      if targetGUID and guid == targetGUID then
        guidMatchUnit = unit
        DEFAULT_CHAT_FRAME:AddMessage(
          "TOKEN GUID MATCH | "..unit..
          " | class "..tostring(class)..
          " | frame "..tostring(frame and "FOUND" or "nil")
        )
      end

      if apiTargetPlate and frame == apiTargetPlate then
        frameMatchUnit = unit
        DEFAULT_CHAT_FRAME:AddMessage(
          "TOKEN FRAME MATCH | "..unit..
          " | guid "..tostring(guid or "nil")..
          " | class "..tostring(class)
        )
      end
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage(
    "nameplateN | existing "..tostring(existing)..
    " | guidMatch "..tostring(guidMatchUnit or "NONE")..
    " | frameMatch "..tostring(frameMatchUnit or "NONE")
  )
end

SLASH_BLIZZNAMEPLATESPLUS1 = "/bnp"
SlashCmdList["BLIZZNAMEPLATESPLUS"] = function(msg)
  msg = string.lower(msg or "")

  if msg == "" or msg == "config" or msg == "options" then
    if BNP.ToggleOptions then BNP:ToggleOptions() end
  elseif msg == "spellprobe" or msg == "spellbook" then
    if BNP.SpellbookProbe then BNP:SpellbookProbe() else BNP:Print("Spellbook probe is not loaded.") end
  elseif msg == "spellprobe corruption" then
    if BNP.SpellbookProbe then BNP:SpellbookProbe("corruption") end
  elseif msg == "spellprobe agony" then
    if BNP.SpellbookProbe then BNP:SpellbookProbe("agony") end
  elseif msg == "spellprobe siphon" then
    if BNP.SpellbookProbe then BNP:SpellbookProbe("siphon") end
  elseif msg == "unknown" or msg == "learn" then
    if BNP.PrintUnknownBeta then BNP:PrintUnknownBeta(false) else BNP:Print("Unknown collector is not loaded.") end
  elseif msg == "unknown verbose" or msg == "learn verbose" then
    if BNP.PrintUnknownBeta then BNP:PrintUnknownBeta(true) else BNP:Print("Unknown collector is not loaded.") end
  elseif msg == "unknown reset" or msg == "learn reset" then
    if BNP.ResetUnknownBeta then BNP:ResetUnknownBeta() end
    BNP.unknownDirectEvents = {}
  elseif msg == "auras" or msg == "targetauras" then
    if BNP.PrintTargetAuraProbe then
      BNP:PrintTargetAuraProbe()
    else
      BNP:Print("Target aura probe is not loaded.")
    end
  elseif msg == "raidcheck" then
    local exists, guid = UnitExists("target")
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffBNP RAIDCHECK|r")
    if not exists or not guid then
      DEFAULT_CHAT_FRAME:AddMessage("No target / no target GUID.")
      return
    end
    DEFAULT_CHAT_FRAME:AddMessage("Target: "..tostring(UnitName("target") or "?").." | GUID: "..tostring(guid))
    local cache=BNP.guidAuras and BNP.guidAuras[guid]
    local n=0
    if cache then
      local key,aura
      for key,aura in pairs(cache) do
        if type(aura)=="table" and aura.spellID then
          n=n+1
          local mode = aura.castPrimary and "CAST" or (aura.liveConfirmed and "LIVE" or "?")
        DEFAULT_CHAT_FRAME:AddMessage(
          "CACHE | "..tostring(key).." | ID "..tostring(aura.spellID).." | "..mode..
          " | stacks "..tostring(aura.stacks or 0)..
          " | left "..(aura.expires and string.format("%.1f", aura.expires-GetTime()) or "?")
        )
        end
      end
    end
    if n==0 then DEFAULT_CHAT_FRAME:AddMessage("CACHE: EMPTY") end
    local svState = BNP.svStateByGUID and BNP.svStateByGUID[guid]
    if svState then
      DEFAULT_CHAT_FRAME:AddMessage(
        "SV STATE | present "..tostring(svState.present and 1 or 0)..
        " | ID "..tostring(svState.spellID or "?")..
        " | left "..(svState.expires and string.format("%.1f", svState.expires-GetTime()) or "?")..
        " | refreshed "..(svState.lastRefresh and string.format("%.1fs ago", GetTime()-svState.lastRefresh) or "?")
      )
    else
      DEFAULT_CHAT_FRAME:AddMessage("SV STATE: none")
    end

    -- Renderer-side SV diagnostics: tells us what the actual visible icon has
    -- consumed from the GUID state, not just what the cache contains.
    local rendered = false
    local plate
    for plate in pairs(BNP.plates or {}) do
      if plate and plate:IsShown() and plate.GetName and plate:GetName(1) == guid then
        local c = plate.BNPAuraContainer
        if c and c.icons then
          local ri
          for ri = 1, table.getn(c.icons) do
            local icon = c.icons[ri]
            if icon and icon.BNPSVRenderedExpires then
              DEFAULT_CHAT_FRAME:AddMessage(
                "SV RENDER | icon "..tostring(ri)..
                " | text "..tostring(icon.timer and icon.timer:GetText() or "?")..
                " | left "..string.format("%.1f", (icon.BNPSVRenderedExpires or GetTime())-GetTime())..
                " | rev "..tostring(icon.BNPSVRenderRevision or 0)
              )
              rendered = true
              break
            end
          end
        end
      end
    end
    if not rendered then DEFAULT_CHAT_FRAME:AddMessage("SV RENDER: no visible SV icon") end

    local pending = BNP.pendingAuras and BNP.pendingAuras[guid]
    if pending then
      DEFAULT_CHAT_FRAME:AddMessage("-- PENDING FOR TARGET --")
      local pk,pv
      for pk,pv in pairs(pending) do
        if type(pv)=="table" then
          DEFAULT_CHAT_FRAME:AddMessage(
            "PENDING | "..tostring(pk)..
            " | ID "..tostring(pv.spellID or "?")..
            " | age "..string.format("%.1fs", GetTime()-(pv.created or GetTime()))
          )
        end
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage("PENDING: none")
    end

    DEFAULT_CHAT_FRAME:AddMessage("-- LAST TRACKED CAST EVENTS --")
    local trace=BNP.raidTrace or {}
    local start=math.max(1,table.getn(trace)-14)
    local ti
    for ti=start,table.getn(trace) do
      local e=trace[ti]
      DEFAULT_CHAT_FRAME:AddMessage(
        tostring(e.stage)..
        " | "..tostring(e.key or "-")..
        " | ID "..tostring(e.spellID or "?")..
        " | GUID "..tostring(e.guid or "nil")..
        " | "..string.format("%.1fs ago",GetTime()-(e.time or GetTime()))
      )
    end

    DEFAULT_CHAT_FRAME:AddMessage("-- LIVE TARGET AURAS (up to 64) --")
    local i
    for i=1,64 do
      local tex,stacks,dtype,id=UnitDebuff("target",i)
      if not tex then break end
      local name=(id and SpellInfo and SpellInfo(id)) or "?"
      DEFAULT_CHAT_FRAME:AddMessage("LIVE "..tostring(i).." | ID "..tostring(id or "?").." | "..tostring(name).." | stacks "..tostring(stacks or 0))
    end

    local svp = BNP.svProbe
    if svp then
      DEFAULT_CHAT_FRAME:AddMessage("-- SV PROBE --")
      local last = svp.last
      if last then
        DEFAULT_CHAT_FRAME:AddMessage(
          "SV LIVE | "..tostring(last.reason or "?").." | unit "..tostring(last.unit or "?")..
          " | idx "..tostring(last.index or "?").." | ID "..tostring(last.spellID or "?")..
          " | stacks "..tostring(last.stacks or 0)
        )
        DEFAULT_CHAT_FRAME:AddMessage(
          "RET a3="..tostring(last.a3).." a5="..tostring(last.a5).." a6="..tostring(last.a6)..
          " a7="..tostring(last.a7).." a8="..tostring(last.a8).." a9="..tostring(last.a9).." a10="..tostring(last.a10)
        )
      else
        DEFAULT_CHAT_FRAME:AddMessage("SV LIVE: no captured snapshot")
      end
      local ev = svp.events or {}
      local es = math.max(1, table.getn(ev)-9)
      local ei
      for ei=es,table.getn(ev) do
        local e=ev[ei]
        DEFAULT_CHAT_FRAME:AddMessage(
          tostring(e.stage).." | ID "..tostring(e.spellID or "?").." | GUID "..tostring(e.guid or "nil")..
          " | "..tostring(e.extra or "-").." | "..string.format("%.1fs ago",GetTime()-(e.time or GetTime()))
        )
      end

      DEFAULT_CHAT_FRAME:AddMessage("-- SV RAW WINDOW --")
      local raw = svp.raw or {}
      if table.getn(raw) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("RAW: no matching lines captured")
      else
        local rs = math.max(1, table.getn(raw)-13)
        local ri
        for ri=rs,table.getn(raw) do
          local r=raw[ri]
          DEFAULT_CHAT_FRAME:AddMessage(
            "RAW "..string.format("%.1fs",GetTime()-(r.time or GetTime()))..
            " | "..tostring(r.event or "?").." | "..tostring(r.raw or "")
          )
        end
      end
    end
  elseif msg == "direct" then
    if BNP.PrintUnknownDirectEvents then
      BNP:PrintUnknownDirectEvents()
    else
      BNP:Print("Direct event collector is not loaded.")
    end
  elseif msg == "spelldb" or msg == "audit" then
    if BNP.PrintSpellDBAudit then BNP:PrintSpellDBAudit() else BNP:Print("SpellDB audit is not loaded.") end
  elseif msg == "spelldb reset" or msg == "audit reset" then
    if BNP.ResetSpellDBAudit then BNP:ResetSpellDBAudit() end
  elseif msg == "guid" or msg == "guiddebug" or msg == "diag" then
    if BNP.PrintGUIDDiagnostic then BNP:PrintGUIDDiagnostic() else BNP:Print("GUID diagnostics are not loaded.") end
  elseif msg == "dragontest" then
    BNP_ToggleDirectDragonRenderTest()
  elseif msg == "eliteinfo" then
    BNP_PrintEliteInfo()
  elseif msg == "eliteauto" then
    BNP:Print("Elite auto | ticks " .. tostring(BNP_EliteAutoState.ticks) .. " | visible " .. tostring(BNP_EliteAutoState.visible) .. " | elite " .. tostring(BNP_EliteAutoState.elite) .. " | shown " .. tostring(BNP_EliteAutoState.shown) .. " | lastClass " .. tostring(BNP_EliteAutoState.lastClass) .. " | error " .. tostring(BNP_EliteAutoState.lastError))
  elseif msg == "status" then
    local visible = 0
    local plate
    for plate in pairs(BNP.plates) do
      if plate:IsShown() then visible = visible + 1 end
    end
    BNP:Print("registered: " .. BNP.detected .. ", visible: " .. visible .. ", test spell: " .. tostring(BNP.corruptionName or "not found"))
  elseif msg == "cache" then
    local name = UnitName("target")
    if not name then
      BNP:Print("No target selected.")
      return
    end
    local remaining = BNP.FindCachedCorruption and BNP.FindCachedCorruption(name)
    BNP:Print("Cache for " .. name .. ": " .. tostring(remaining or "no Corruption found"))
  elseif msg == "castbars on" then
    if BNP.SetCastbarsEnabled then BNP:SetCastbarsEnabled(true) end
  elseif msg == "castbars off" then
    if BNP.SetCastbarsEnabled then BNP:SetCastbarsEnabled(false) end
  elseif msg == "scale" then
    BNP:Print("Current nameplate scale: " .. tostring(BNP:GetNameplateScale()))
  elseif msg == "scale reset" then
    if BNP.ResetNameplateScale then BNP:ResetNameplateScale() end
  elseif string.find(msg, "^scale%s+") then
    local _, _, value = string.find(msg, "^scale%s+([0-9%.]+)")
    if BNP.SetNameplateScale then BNP:SetNameplateScale(value) end
  elseif msg == "classcolors on" then
    BNP_DB = BNP_DB or {}
    BNP_DB.classColors = true
    BNP:Print("Class colors enabled.")
  elseif msg == "classcolors off" then
    BNP_DB = BNP_DB or {}
    BNP_DB.classColors = false
    BNP:Print("Class colors disabled.")
  elseif msg == "debug on" then
    BNP:SetDebug(true)
  elseif msg == "debug off" then
    BNP:SetDebug(false)
  elseif msg == "debug" then
    BNP:SetDebug(not BNP.debugEnabled)
  else
    BNP:Print("Commands: /bnp unknown, /bnp direct, /bnp spellprobe, /bnp spelldb, /bnp guid, /bnp dragontest, /bnp eliteinfo, /bnp eliteauto, /bnp status, /bnp castbars on/off, /bnp scale <0.5-1.5>, /bnp scale reset, /bnp classcolors on/off, /bnp debug on, /bnp debug off")
  end
end
