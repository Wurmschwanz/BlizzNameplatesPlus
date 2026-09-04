BNP = BNP or {}

local _, optionsPlayerClass = UnitClass("player")
local comboOptionsClass = (optionsPlayerClass == "ROGUE" or optionsPlayerClass == "DRUID")

local function Round(value, step)
  return math.floor((value / step) + 0.5) * step
end

local sliderCount = 0
local function CreateSlider(parent, label, minValue, maxValue, step, y)
  sliderCount = sliderCount + 1
  local slider = CreateFrame("Slider", "BNPOptionsSlider" .. sliderCount, parent, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 28, y)
  slider:SetWidth(220)
  slider:SetHeight(16)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  getglobal(slider:GetName() .. "Low"):SetText(tostring(minValue))
  getglobal(slider:GetName() .. "High"):SetText(tostring(maxValue))
  getglobal(slider:GetName() .. "Text"):SetText(label)
  return slider
end

local function CreateCheck(parent, label, y, onclick, x)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 22, y)
  check:SetWidth(24)
  check:SetHeight(24)

  local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("LEFT", check, "RIGHT", 4, 0)
  text:SetText(label)
  check.BNPLabel = text

  check:SetScript("OnClick", onclick)
  return check
end

-- 1.12-safe emergency recorder ------------------------------------------------
--
-- Keep a compact recorder directly in this already proven options file.  The
-- full diagnostic module replaces BNP.OpenAuraRecorder later when it loads.
-- If an old/private 1.12 client refuses that larger module, this fallback still
-- provides the window and the ClassicAPI aura data we actually need.

local emergency = BNP.emergencyAuraRecorder or {}
BNP.emergencyAuraRecorder = emergency
emergency.lines = emergency.lines or {}
emergency.active = false

local function EmergencyValue(value, limit)
  if value == nil then return "nil" end
  local text = tostring(value)
  text = string.gsub(text, "\r", "\\r")
  text = string.gsub(text, "\n", "\\n")
  text = string.gsub(text, "\t", "\\t")
  limit = limit or 240
  if string.len(text) > limit then text = string.sub(text, 1, limit) .. "..." end
  return text
end

local function EmergencyAppend(text)
  text = EmergencyValue(text, 1300)
  if string.len(table.concat(emergency.lines, "\n")) + string.len(text) > 60000 then
    if not emergency.limitHit then
      table.insert(emergency.lines, "[REPORT LIMIT REACHED - recording stopped]")
      emergency.limitHit = true
      emergency.active = false
    end
    return
  end
  table.insert(emergency.lines, text)
  emergency.dirty = true
end

local function EmergencyFields(data)
  if type(data) ~= "table" then return EmergencyValue(data) end
  local fields = {}
  local key, value
  for key, value in pairs(data) do
    local kind = type(value)
    if kind ~= "table" and kind ~= "function" and kind ~= "userdata" then
      table.insert(fields, EmergencyValue(key, 80) .. "=" .. EmergencyValue(value, 180))
    end
  end
  table.sort(fields)
  return table.concat(fields, " | ")
end

local function EmergencyGUID(unit)
  local exists, guid = UnitExists(unit)
  if exists and guid then return guid end
  if UnitGUID then
    local ok, value = pcall(UnitGUID, unit)
    if ok then return value end
  end
  return nil
end

local function EmergencyWantedAura(aura)
  if type(aura) ~= "table" then return true end
  local spellID = tonumber(aura.spellId or aura.spellID)
  local name = string.lower(tostring(aura.name or ""))
  if spellID == 17794 or spellID == 17797 or spellID == 17798 or spellID == 17799 or spellID == 17800 then return true end
  if name == "shadow vulnerability" or name == "schattenverwundbarkeit" then return true end

  local playerGUID = EmergencyGUID("player")
  if aura.sourceGUID and playerGUID then return aura.sourceGUID == playerGUID end
  if aura.sourceUnit then return aura.sourceUnit == "player" end
  return false
end

local function EmergencyIsShadowBolt(spellID, spellName)
  local numeric = tonumber(spellID)
  if numeric == 686 or numeric == 695 or numeric == 705 or numeric == 1088 or
     numeric == 1106 or numeric == 7641 or numeric == 11659 or numeric == 11660 or
     numeric == 11661 or numeric == 25307 then return true end
  local name = string.lower(tostring(spellName or ""))
  return name == "shadow bolt" or name == "schattenblitz"
end

local function EmergencyRefresh()
  if not emergency.edit then return end
  emergency.edit:SetText(table.concat(emergency.lines, "\n"))
  emergency.edit:SetHeight(math.max(300, table.getn(emergency.lines) * 16 + 30))
  if emergency.status then
    if emergency.active then
      emergency.status:SetText("RECORDING | Target: " .. EmergencyValue(UnitName("target") or "none", 100))
      emergency.status:SetTextColor(0.2, 1, 0.35)
    else
      emergency.status:SetText("STOPPED | " .. tostring(table.getn(emergency.lines)) .. " lines")
      emergency.status:SetTextColor(1, 0.82, 0)
    end
  end
  emergency.dirty = false
end

local function EmergencySnapshot(reason, force)
  if not UnitExists("target") then
    if force then EmergencyAppend("AURA_SNAPSHOT | reason=" .. reason .. " | no target") end
    return
  end

  local auraLines = {}
  local signatureParts = {}
  local count = 0
  local classic = type(C_UnitAuras) == "table" and type(C_UnitAuras.GetDebuffDataByIndex) == "function"
  local i

  if classic then
    for i = 1, 64 do
      local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, "target", i)
      if not ok then
        EmergencyAppend("CLASSICAPI_ERROR | " .. EmergencyValue(aura, 800))
        break
      end
      if not aura then break end
      if EmergencyWantedAura(aura) then
        count = count + 1
        local fields = EmergencyFields(aura)
        table.insert(signatureParts, fields)
        table.insert(auraLines, "  CLASSIC_AURA " .. tostring(i) .. " | " .. fields)
      end
    end
  else
    for i = 1, 64 do
      local ok, texture, stacks, dispelType, spellID, r5, r6, r7, r8, r9, r10 = pcall(UnitDebuff, "target", i)
      if not ok or not texture then break end
      count = count + 1
      local fields = "spellId=" .. EmergencyValue(spellID) ..
        " | stacks=" .. EmergencyValue(stacks) ..
        " | type=" .. EmergencyValue(dispelType) ..
        " | texture=" .. EmergencyValue(texture, 160) ..
        " | r5=" .. EmergencyValue(r5) .. " | r6=" .. EmergencyValue(r6) ..
        " | r7=" .. EmergencyValue(r7) .. " | r8=" .. EmergencyValue(r8) ..
        " | r9=" .. EmergencyValue(r9) .. " | r10=" .. EmergencyValue(r10)
      table.insert(signatureParts, fields)
      table.insert(auraLines, "  LEGACY_AURA " .. tostring(i) .. " | " .. fields)
    end
  end

  local signature = table.concat(signatureParts, "||")
  if emergency.baselineOnly then
    emergency.lastSignature = signature
    return
  end
  if not force and signature == emergency.lastSignature then return end
  emergency.lastSignature = signature
  EmergencyAppend(
    "[+" .. string.format("%.3f", GetTime() - (emergency.startedAt or GetTime())) .. "] AURA_SNAPSHOT" ..
    " | reason=" .. EmergencyValue(reason) ..
    " | guid=" .. EmergencyValue(EmergencyGUID("target")) ..
    " | source=" .. (classic and "ClassicAPI" or "UnitDebuff") ..
    " | count=" .. tostring(count)
  )
  if count == 0 then
    EmergencyAppend("  AURA none")
  else
    for i = 1, table.getn(auraLines) do EmergencyAppend(auraLines[i]) end
  end
end

local function EmergencyUnregister()
  if emergency.eventFrame then pcall(emergency.eventFrame.UnregisterAllEvents, emergency.eventFrame) end
end

local function EmergencyStop(reason)
  if not emergency.active then EmergencyRefresh() return end
  EmergencySnapshot("final", true)
  emergency.active = false
  EmergencyUnregister()
  if emergency.frame then emergency.frame:SetScript("OnUpdate", nil) end
  EmergencyAppend("=== END | reason=" .. EmergencyValue(reason or "user") .. " ===")
  EmergencyRefresh()
end

local function EmergencyStart()
  EmergencyUnregister()
  emergency.lines = {}
  emergency.limitHit = false
  emergency.lastSignature = nil
  emergency.startedAt = GetTime()
  emergency.elapsed = 0
  emergency.active = true
  if emergency.frame and emergency.onUpdate then emergency.frame:SetScript("OnUpdate", emergency.onUpdate) end
  EmergencyAppend("BNP_CLASSICAPI_AURA_REPORT v2")
  EmergencyAppend(
    "ClassicAPI | version=" .. EmergencyValue(CLASSIC_API_VERSION or "not detected") ..
    " | C_UnitAuras=" .. ((type(C_UnitAuras) == "table" and type(C_UnitAuras.GetDebuffDataByIndex) == "function") and "yes" or "no") ..
    " | CopyToClipboard=" .. (CopyToClipboard and "yes" or "no")
  )
  EmergencyAppend("Aura filter | own auras + Shadow Vulnerability from any Warlock")
  EmergencyAppend("Target | name=" .. EmergencyValue(UnitName("target")) .. " | guid=" .. EmergencyValue(EmergencyGUID("target")))
  EmergencyAppend("Test | proc aura, refresh it while active, then let it expire")
  EmergencyAppend("=== LIVE RECORDING ===")

  local events = {
    "UNIT_CASTEVENT", "UNIT_AURA", "PLAYER_TARGET_CHANGED",
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
  }
  local i
  for i = 1, table.getn(events) do pcall(emergency.eventFrame.RegisterEvent, emergency.eventFrame, events[i]) end
  -- Learn the target's existing auras without printing them. Only changes
  -- occurring after Start Recording belong in the diagnostic report.
  emergency.baselineOnly = true
  EmergencySnapshot("baseline", false)
  emergency.baselineOnly = false
  EmergencyRefresh()
end

local function EmergencyCreateWindow()
  if emergency.frame then return emergency.frame end

  local frame = CreateFrame("Frame", "BNPEmergencyAuraRecorderFrame", UIParent)
  frame:SetWidth(720)
  frame:SetHeight(520)
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
  frame:SetScript("OnHide", function() EmergencyStop("window closed") end)
  emergency.frame = frame

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("Missing Spell / Aura Recorder")

  local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  status:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -50)
  status:SetWidth(660)
  status:SetJustifyH("LEFT")
  emergency.status = status

  local start = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  start:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -76)
  start:SetWidth(126)
  start:SetHeight(24)
  start:SetText("Start Recording")
  start:SetScript("OnClick", EmergencyStart)

  local stop = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  stop:SetPoint("LEFT", start, "RIGHT", 8, 0)
  stop:SetWidth(82)
  stop:SetHeight(24)
  stop:SetText("Stop")
  stop:SetScript("OnClick", function() EmergencyStop("user") end)

  local copy = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  copy:SetPoint("LEFT", stop, "RIGHT", 8, 0)
  copy:SetWidth(110)
  copy:SetHeight(24)
  copy:SetText(CopyToClipboard and "Copy Report" or "Select All")
  copy:SetScript("OnClick", function()
    EmergencyRefresh()
    local report = table.concat(emergency.lines, "\n")
    if CopyToClipboard and pcall(CopyToClipboard, report) then
      emergency.status:SetText("COPIED | Paste with Ctrl+V")
      emergency.status:SetTextColor(0.2, 1, 0.35)
    else
      emergency.edit:SetFocus()
      emergency.edit:HighlightText()
      emergency.status:SetText("SELECTED | Press Ctrl+C")
    end
  end)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

  local scroll = CreateFrame("ScrollFrame", "BNPEmergencyAuraRecorderScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -112)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -48, 30)

  local edit = CreateFrame("EditBox", "BNPEmergencyAuraRecorderEdit", scroll)
  edit:SetWidth(640)
  edit:SetHeight(300)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetMaxLetters(65000)
  edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  scroll:SetScrollChild(edit)
  emergency.edit = edit

  emergency.eventFrame = CreateFrame("Frame", "BNPEmergencyAuraRecorderEvents")
  emergency.eventFrame:SetScript("OnEvent", function()
    if not emergency.active then return end
    if event == "UNIT_AURA" and arg1 ~= "target" then return end
    if event == "UNIT_CASTEVENT" and arg1 ~= EmergencyGUID("player") then return end
    EmergencyAppend(
      "[+" .. string.format("%.3f", GetTime() - emergency.startedAt) .. "] EVENT | " .. EmergencyValue(event) ..
      " | a1=" .. EmergencyValue(arg1) .. " | a2=" .. EmergencyValue(arg2) ..
      " | a3=" .. EmergencyValue(arg3) .. " | a4=" .. EmergencyValue(arg4) ..
      " | a5=" .. EmergencyValue(arg5) .. " | a6=" .. EmergencyValue(arg6)
    )
    emergency.forceSnapshot = event == "PLAYER_TARGET_CHANGED" or
      (event == "UNIT_CASTEVENT" and EmergencyIsShadowBolt(arg4)) or
      (event == "UNIT_SPELLCAST_SENT" and EmergencyIsShadowBolt(arg4, arg5)) or
      (event ~= "UNIT_SPELLCAST_SENT" and string.find(tostring(event or ""), "UNIT_SPELLCAST_", 1, true) and EmergencyIsShadowBolt(arg3, arg4))
  end)

  emergency.onUpdate = function()
    if not emergency.active then return end
    emergency.elapsed = (emergency.elapsed or 0) + arg1
    if emergency.elapsed >= 0.12 then
      emergency.elapsed = 0
      EmergencySnapshot(emergency.forceSnapshot and "event" or "poll", emergency.forceSnapshot)
      emergency.forceSnapshot = false
      if emergency.dirty then EmergencyRefresh() end
    end
  end

  return frame
end

-- This remains available even if the full recorder loads, so that module can
-- fall back when a private client rejects one of the larger window calls.
function BNP:OpenEmergencyAuraRecorder()
  local frame = EmergencyCreateWindow()
  frame:Show()
  EmergencyRefresh()
end

function BNP:StartEmergencyAuraRecorder()
  EmergencyStart()
end

-- This is intentionally defined before the large optional recorder module.
-- A successful module load overwrites it; otherwise the button still works.
function BNP:OpenAuraRecorder()
  self:OpenEmergencyAuraRecorder()
end

function BNP:CreateOptions()
  if self.optionsFrame then return end

  local frame = CreateFrame("Frame", "BNPOptionsFrame", UIParent)
  frame:SetWidth(430)
  frame:SetHeight(500)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
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
  frame:Hide()

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("Blizz Nameplates+")

  local version = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  version:SetPoint("TOP", title, "BOTTOM", 0, -4)
  version:SetText("Version " .. tostring(BNP.version or "?"))
  frame.versionText = version

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

  local function CreatePage()
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -104)
    page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 22)
    page:Hide()
    return page
  end

  local function CreateSection(parent, label, y)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    text:SetText(label)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(1, 1, 1, 0.16)
    line:SetPoint("LEFT", text, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    line:SetHeight(1)

    return text
  end

  local function SetCheckEnabled(check, enabled)
    if not check then return end
    if enabled then
      if check.Enable then check:Enable() end
      check:SetAlpha(1.0)
      if check.BNPLabel then check.BNPLabel:SetTextColor(1, 0.82, 0) end
    else
      if check.Disable then check:Disable() end
      check:SetAlpha(0.45)
      if check.BNPLabel then check.BNPLabel:SetTextColor(0.5, 0.5, 0.5) end
    end
  end

  -- Compact tab navigation. Totems stays separate from aura tracking so PvP
  -- nameplate indicators never touch the debuff/CC state machine.
  frame.pages = {
    nameplates = CreatePage(),
    auras = CreatePage(),
    totems = CreatePage(),
    castbar = CreatePage(),
    target = CreatePage(),
    tools = CreatePage(),
  }
  frame.tabs = {}

  local tabDefs = {
    { key = "nameplates", label = "Nameplates", width = 76 },
    { key = "auras", label = "Auras", width = 52 },
    { key = "totems", label = "Totems", width = 58 },
    { key = "castbar", label = "Castbar", width = 60 },
    { key = "target", label = "Target", width = 56 },
    { key = "tools", label = "Tools", width = 50 },
  }

  function frame:ShowTab(key)
    local pageKey, page
    for pageKey, page in pairs(self.pages) do
      if pageKey == key then page:Show() else page:Hide() end
    end

    local i
    for i = 1, table.getn(tabDefs) do
      local def = tabDefs[i]
      local button = self.tabs[def.key]
      if button then
        if def.key == key then
          if button.Disable then button:Disable() end
          button:SetAlpha(1.0)
        else
          if button.Enable then button:Enable() end
          button:SetAlpha(0.80)
        end
      end
    end
    self.selectedTab = key
  end

  local tabX = 28
  local i
  for i = 1, table.getn(tabDefs) do
    local def = tabDefs[i]
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetWidth(def.width)
    button:SetHeight(24)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", tabX, -68)
    button:SetText(def.label)
    button.BNPTabKey = def.key
    button:SetScript("OnClick", function()
      frame:ShowTab(this.BNPTabKey)
    end)
    frame.tabs[def.key] = button
    tabX = tabX + def.width + 4
  end

  -- NAMEPLATES TAB ---------------------------------------------------------
  local nameplatesPage = frame.pages.nameplates
  CreateSection(nameplatesPage, "Nameplates", -4)

  local scale = CreateSlider(nameplatesPage, "Nameplate Scale", 0.70, 1.50, 0.05, -38)
  scale:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = Round(this:GetValue(), 0.05)
    BNP_DB.nameplateScale = value
    getglobal(this:GetName() .. "Text"):SetText("Nameplate Scale: " .. string.format("%.2f", value))
    if BNP.ApplyNameplateScaleAll then BNP:ApplyNameplateScaleAll() end
  end)
  frame.scaleSlider = scale

  local yOffset = CreateSlider(nameplatesPage, "Nameplate Y Offset", 0, 50, 1, -86)
  yOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.nameplateYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Nameplate Y Offset: +" .. value)
    if BNP.ApplyNameplateYOffsetAll then BNP:ApplyNameplateYOffsetAll() end
  end)
  frame.yOffsetSlider = yOffset

  local nonTargetAlpha = CreateSlider(nameplatesPage, "Non-Target Alpha", 30, 100, 5, -134)
  nonTargetAlpha:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local percent = math.floor((this:GetValue() / 5) + 0.5) * 5
    if percent < 30 then percent = 30 end
    if percent > 100 then percent = 100 end
    BNP_DB.nonTargetAlpha = percent / 100
    getglobal(this:GetName() .. "Text"):SetText("Non-Target Alpha: " .. percent .. "%")
    if BNP.RefreshNonTargetAlpha then BNP:RefreshNonTargetAlpha() end
  end)
  frame.nonTargetAlphaSlider = nonTargetAlpha

  local classColors = CreateCheck(nameplatesPage, "Class Colors", -180, function()
    BNP_DB.classColors = this:GetChecked() and true or false
    if BNP_DB.classColors then
      local plate
      for plate in pairs(BNP.plates or {}) do
        plate.BNPClassColorApplied = nil
        plate.BNPClassR = nil
        plate.BNPClassG = nil
        plate.BNPClassB = nil
      end
    end
  end)
  frame.classColorsCheck = classColors

  local hidePlayerNames = CreateCheck(nameplatesPage, "Hide Player Names", -180, function()
    BNP_DB.hidePlayerNames = this:GetChecked() and true or false
    if BNP.RefreshNameVisibility then BNP:RefreshNameVisibility() end
  end, 190)
  frame.hidePlayerNamesCheck = hidePlayerNames

  local tank = CreateCheck(nameplatesPage, "Tank Mode", -208, function()
    BNP_DB.tankMode = this:GetChecked() and true or false
    if BNP.UpdateTankMode then BNP:UpdateTankMode() end
  end)
  tank:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Tank Mode", 1, 0.82, 0)
    GameTooltip:AddLine("Green: the unit is targeting you.", 1, 1, 1)
    GameTooltip:AddLine("Red: the unit is targeting someone else.", 1, 1, 1)
    GameTooltip:Show()
  end)
  tank:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.tankCheck = tank

  local hideNPCNames = CreateCheck(nameplatesPage, "Hide NPC/Mob Names", -208, function()
    BNP_DB.hideNPCNames = this:GetChecked() and true or false
    if BNP.RefreshNameVisibility then BNP:RefreshNameVisibility() end
  end, 190)
  frame.hideNPCNamesCheck = hideNPCNames

  local healthTextLabel = nameplatesPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  healthTextLabel:SetPoint("TOPLEFT", nameplatesPage, "TOPLEFT", 28, -276)
  healthTextLabel:SetText("Health Text")

  local healthTextDropdown = CreateFrame("Frame", "BNPHealthTextDropdown", nameplatesPage, "UIDropDownMenuTemplate")
  healthTextDropdown:SetPoint("TOPLEFT", nameplatesPage, "TOPLEFT", 10, -288)
  UIDropDownMenu_SetWidth(150, healthTextDropdown)

  local healthModeLabels = {
    off = "Off",
    percent = "Percent",
    hp = "HP",
    both = "HP + Percent",
  }

  local function SetHealthTextMode(mode)
    if not healthModeLabels[mode] then mode = "off" end
    BNP_DB.healthText = mode
    BNP_DB.healthPercent = (mode == "percent" or mode == "both")
    UIDropDownMenu_SetSelectedValue(healthTextDropdown, mode)
    UIDropDownMenu_SetText(healthModeLabels[mode], healthTextDropdown)
    if BNP.RefreshHealthPercent then BNP:RefreshHealthPercent() end
  end

  UIDropDownMenu_Initialize(healthTextDropdown, function()
    local modes = { "off", "percent", "hp", "both" }
    local n
    for n = 1, table.getn(modes) do
      local mode = modes[n]
      local info = {}
      info.text = healthModeLabels[mode]
      info.value = mode
      info.func = function() SetHealthTextMode(this.value) end
      info.checked = (BNP:GetHealthTextMode() == mode)
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.healthTextDropdown = healthTextDropdown
  frame.SetHealthTextMode = SetHealthTextMode

  if comboOptionsClass then
    local comboPoints = CreateCheck(nameplatesPage, "Combo Points", -236, function()
      BNP_DB.comboPoints = this:GetChecked() and true or false
      if BNP.RefreshComboPoints then BNP:RefreshComboPoints() end
      if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
      if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    end, 22)
    frame.comboPointsCheck = comboPoints
  end

  -- AURAS TAB --------------------------------------------------------------
  local aurasPage = frame.pages.auras
  CreateSection(aurasPage, "Auras & Crowd Control", -4)

  local icon = CreateSlider(aurasPage, "Aura Icon Size", 12, 32, 1, -38)
  icon:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.iconSize = value
    getglobal(this:GetName() .. "Text"):SetText("Aura Icon Size: " .. value)
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.iconSlider = icon

  local ccIcon = CreateSlider(aurasPage, "CC Icon Size", 12, 32, 1, -86)
  ccIcon:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.ccIconSize = value
    getglobal(this:GetName() .. "Text"):SetText("CC Icon Size: " .. value)
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.ccIconSlider = ccIcon

  local debuffs = CreateCheck(aurasPage, "Debuffs", -134, function()
    BNP_DB.debuffs = this:GetChecked() and true or false
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.debuffsCheck = debuffs

  local debuffPositionDropdown = CreateFrame("Frame", "BNPDebuffPositionDropdown", aurasPage, "UIDropDownMenuTemplate")
  debuffPositionDropdown:SetPoint("TOPLEFT", aurasPage, "TOPLEFT", 188, -128)
  UIDropDownMenu_SetWidth(112, debuffPositionDropdown)

  local debuffPositionLabels = {
    top = "Top Mid",
    top_left = "Top Left",
    top_right = "Top Right",
    left = "Left",
    right = "Right",
    bottom_mid = "Bottom Mid",
    bottom_left = "Bottom Left",
    bottom_right = "Bottom Right",
  }

  local function SetDebuffPosition(position)
    if not debuffPositionLabels[position] then position = "top" end
    BNP_DB.debuffPosition = position
    UIDropDownMenu_SetSelectedValue(debuffPositionDropdown, position)
    UIDropDownMenu_SetText(debuffPositionLabels[position], debuffPositionDropdown)
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshTotemIndicators then BNP:RefreshTotemIndicators() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end

  UIDropDownMenu_Initialize(debuffPositionDropdown, function()
    local positions = { "top", "top_left", "top_right", "left", "right", "bottom_mid", "bottom_left", "bottom_right" }
    local n
    for n = 1, table.getn(positions) do
      local position = positions[n]
      local info = {}
      info.text = debuffPositionLabels[position]
      info.value = position
      info.func = function() SetDebuffPosition(this.value) end
      info.checked = (BNP:GetDebuffPosition() == position)
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.debuffPositionDropdown = debuffPositionDropdown
  frame.SetDebuffPosition = SetDebuffPosition

  local debuffPositionLabel = aurasPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  debuffPositionLabel:SetPoint("BOTTOMLEFT", debuffPositionDropdown, "TOPLEFT", 18, 5)
  debuffPositionLabel:SetText("Debuff Position")
  frame.debuffPositionLabel = debuffPositionLabel

  local crowdControl = CreateCheck(aurasPage, "Crowd Control", -190, function()
    BNP_DB.crowdControl = this:GetChecked() and true or false
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.crowdControlCheck = crowdControl

  local ccPositionDropdown = CreateFrame("Frame", "BNPCCPositionDropdown", aurasPage, "UIDropDownMenuTemplate")
  ccPositionDropdown:SetPoint("TOPLEFT", aurasPage, "TOPLEFT", 188, -184)
  UIDropDownMenu_SetWidth(92, ccPositionDropdown)

  local ccPositionLabels = {
    top = "Top",
    left = "Left",
    right = "Right",
  }

  local function SetCCPosition(position)
    if not ccPositionLabels[position] then position = "top" end
    BNP_DB.ccPosition = position
    UIDropDownMenu_SetSelectedValue(ccPositionDropdown, position)
    UIDropDownMenu_SetText(ccPositionLabels[position], ccPositionDropdown)
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end

  UIDropDownMenu_Initialize(ccPositionDropdown, function()
    local positions = { "top", "left", "right" }
    local n
    for n = 1, table.getn(positions) do
      local position = positions[n]
      local info = {}
      info.text = ccPositionLabels[position]
      info.value = position
      info.func = function() SetCCPosition(this.value) end
      info.checked = (BNP:GetCCPosition() == position)
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.ccPositionDropdown = ccPositionDropdown
  frame.SetCCPosition = SetCCPosition

  local ccPositionLabel = aurasPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ccPositionLabel:SetPoint("BOTTOMLEFT", ccPositionDropdown, "TOPLEFT", 18, 5)
  ccPositionLabel:SetText("CC Position")
  frame.ccPositionLabel = ccPositionLabel

  local separateCCRow = CreateCheck(aurasPage, "Display CCs in Separate Row", -222, function()
    BNP_DB.separateCCRow = this:GetChecked() and true or false
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end, 42)
  frame.separateCCRowCheck = separateCCRow

  local showOtherCCs = CreateCheck(aurasPage, "Show CCs from Other Players", -250, function()
    BNP_DB.showOtherCCs = this:GetChecked() and true or false
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
  end, 42)
  frame.showOtherCCsCheck = showOtherCCs

  local pvpImmunities = CreateCheck(aurasPage, "PvP Immunities", -302, function()
    BNP_DB.pvpImmunities = this:GetChecked() and true or false
    if BNP.RefreshImmunityVisibility then BNP:RefreshImmunityVisibility() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end, 42)
  frame.pvpImmunitiesCheck = pvpImmunities

  local immunityPositionDropdown = CreateFrame("Frame", "BNPImmunityPositionDropdown", aurasPage, "UIDropDownMenuTemplate")
  immunityPositionDropdown:SetPoint("TOPLEFT", aurasPage, "TOPLEFT", 188, -296)
  UIDropDownMenu_SetWidth(92, immunityPositionDropdown)

  local immunityPositionLabels = {
    top = "Top",
    left = "Left",
    right = "Right",
  }

  local function SetImmunityPosition(position)
    if not immunityPositionLabels[position] then position = "top" end
    BNP_DB.immunityPosition = position
    UIDropDownMenu_SetSelectedValue(immunityPositionDropdown, position)
    UIDropDownMenu_SetText(immunityPositionLabels[position], immunityPositionDropdown)
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end

  UIDropDownMenu_Initialize(immunityPositionDropdown, function()
    local positions = { "top", "left", "right" }
    local n
    for n = 1, table.getn(positions) do
      local position = positions[n]
      local info = {}
      info.text = immunityPositionLabels[position]
      info.value = position
      info.func = function() SetImmunityPosition(this.value) end
      info.checked = (BNP:GetImmunityPosition() == position)
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.immunityPositionDropdown = immunityPositionDropdown
  frame.SetImmunityPosition = SetImmunityPosition

  local immunityPositionLabel = aurasPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  immunityPositionLabel:SetPoint("BOTTOMLEFT", immunityPositionDropdown, "TOPLEFT", 18, 5)
  immunityPositionLabel:SetText("Immunity Position")
  frame.immunityPositionLabel = immunityPositionLabel

  local immunityIcon = CreateSlider(aurasPage, "Immunity Icon Size", 12, 32, 1, -350)
  immunityIcon:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.immunityIconSize = value
    getglobal(this:GetName() .. "Text"):SetText("Immunity Icon Size: " .. value)
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.immunityIconSlider = immunityIcon

  -- TOTEMS TAB -------------------------------------------------------------
  local totemsPage = frame.pages.totems
  CreateSection(totemsPage, "Totem Indicators", -4)

  local totemIndicators = CreateCheck(totemsPage, "Enable Totem Icons", -42, function()
    BNP_DB.totemIndicators = this:GetChecked() and true or false
    if BNP.RefreshTotemIndicators then BNP:RefreshTotemIndicators() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  frame.totemIndicatorsCheck = totemIndicators

  local totemIcon = CreateSlider(totemsPage, "Totem Icon Size", 16, 36, 1, -92)
  totemIcon:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.totemIconSize = value
    getglobal(this:GetName() .. "Text"):SetText("Totem Icon Size: " .. value)
    if BNP.RefreshTotemIndicators then BNP:RefreshTotemIndicators() end
  end)
  frame.totemIconSlider = totemIcon

  local totemNote = totemsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  totemNote:SetPoint("TOPLEFT", totemsPage, "TOPLEFT", 28, -150)
  totemNote:SetWidth(340)
  totemNote:SetJustifyH("LEFT")
  totemNote:SetText("Replaces all visible shaman totem nameplates with compact icons. There are no individual totem filters.")


  -- CASTBAR TAB ------------------------------------------------------------
  local castbarPage = frame.pages.castbar
  CreateSection(castbarPage, "Castbar", -4)

  local castbars = CreateCheck(castbarPage, "Castbars", -42, function()
    local enabled = this:GetChecked() and true or false
    if BNP.SetCastbarsEnabled then BNP:SetCastbarsEnabled(enabled) else BNP_DB.castbars = enabled end
  end)
  frame.castbarsCheck = castbars

  local castbarTest = CreateCheck(castbarPage, "Test Castbars", -42, function()
    if BNP.SetCastbarTestMode then BNP:SetCastbarTestMode(this:GetChecked() and true or false) end
  end, 164)
  castbarTest:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Test Castbars", 1, 0.82, 0)
    GameTooltip:AddLine("Shows a looping simulated castbar on every visible nameplate.", 1, 1, 1, true)
    GameTooltip:AddLine("Use it to adjust height and spacing live. The test mode is not saved.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  castbarTest:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.castbarTestCheck = castbarTest

  local castbarHeight = CreateSlider(castbarPage, "Castbar Height", 4, 14, 1, -94)
  castbarHeight:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.castbarHeight = value
    getglobal(this:GetName() .. "Text"):SetText("Castbar Height: " .. value)
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() elseif BNP.RefreshCastbarHeights then BNP:RefreshCastbarHeights() end
  end)
  frame.castbarHeightSlider = castbarHeight

  local castbarSpacing = CreateSlider(castbarPage, "Castbar Spacing", 0, 10, 1, -148)
  castbarSpacing:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.castbarSpacing = value
    getglobal(this:GetName() .. "Text"):SetText("Castbar Spacing: " .. value .. " px")
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.castbarSpacingSlider = castbarSpacing

  -- TARGET TAB -------------------------------------------------------------
  local targetPage = frame.pages.target
  CreateSection(targetPage, "Target", -4)

  local targetFocus = CreateCheck(targetPage, "Target Glow", -42, function()
    BNP_DB.targetFocus = this:GetChecked() and true or false
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  frame.targetFocusCheck = targetFocus

  local glowColorLabel = targetPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  glowColorLabel:SetPoint("TOPLEFT", targetPage, "TOPLEFT", 28, -88)
  glowColorLabel:SetText("Glow Color")
  frame.glowColorLabel = glowColorLabel

  local glowColorDropdown = CreateFrame("Frame", "BNPTargetGlowColorDropdown", targetPage, "UIDropDownMenuTemplate")
  glowColorDropdown:SetPoint("TOPLEFT", targetPage, "TOPLEFT", 10, -100)
  UIDropDownMenu_SetWidth(150, glowColorDropdown)

  local glowColorLabels = {
    white = "White",
    gold = "Gold",
    blue = "Blue",
    green = "Green",
    red = "Red",
    purple = "Purple",
  }

  local function SetTargetGlowColor(color)
    if not glowColorLabels[color] then color = "white" end
    BNP_DB.targetGlowColor = color
    UIDropDownMenu_SetSelectedValue(glowColorDropdown, color)
    UIDropDownMenu_SetText(glowColorLabels[color], glowColorDropdown)
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
  end

  UIDropDownMenu_Initialize(glowColorDropdown, function()
    local colors = { "white", "gold", "blue", "green", "red", "purple" }
    local n
    for n = 1, table.getn(colors) do
      local color = colors[n]
      local info = {}
      info.text = glowColorLabels[color]
      info.value = color
      info.func = function() SetTargetGlowColor(this.value) end
      info.checked = ((BNP_DB and BNP_DB.targetGlowColor) or "white") == color
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.glowColorDropdown = glowColorDropdown
  frame.SetTargetGlowColor = SetTargetGlowColor

  -- TOOLS TAB --------------------------------------------------------------
  local toolsPage = frame.pages.tools
  CreateSection(toolsPage, "Tools", -4)

  local auraRecorder = CreateFrame("Button", nil, toolsPage, "UIPanelButtonTemplate")
  auraRecorder:SetPoint("TOPLEFT", toolsPage, "TOPLEFT", 28, -48)
  auraRecorder:SetWidth(254)
  auraRecorder:SetHeight(24)
  auraRecorder:SetText("Missing Spell / Aura...")
  auraRecorder:SetScript("OnClick", function() BNP:OpenAuraRecorder() end)
  auraRecorder:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Missing Spell / Aura Recorder", 1, 0.82, 0)
    GameTooltip:AddLine("Records target aura IDs, SuperWoW events and refresh signals in one copyable report.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  auraRecorder:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.auraRecorderButton = auraRecorder

  local note = toolsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", toolsPage, "TOPLEFT", 28, -88)
  note:SetWidth(330)
  note:SetJustifyH("LEFT")
  note:SetText("Diagnostic tools for testing missing spells and aura refresh behavior.")

  function frame:UpdateDependentControls()
    local ccEnabled = BNP:AreCrowdControlEnabled()
    local debuffsEnabled = BNP:AreDebuffsEnabled()
    local debuffPosition = BNP.GetDebuffPosition and BNP:GetDebuffPosition() or "top"
    local ccPosition = BNP.GetCCPosition and BNP:GetCCPosition() or debuffPosition
    local separateRowAvailable = ccEnabled and debuffsEnabled and (debuffPosition == "top" or debuffPosition == "top_left" or debuffPosition == "top_right") and ccPosition == "top"

    SetCheckEnabled(self.separateCCRowCheck, separateRowAvailable)
    if self.separateCCRowCheck then
      self.separateCCRowCheck:SetChecked(separateRowAvailable and BNP:IsSeparateCCRowEnabled() or false)
    end
    SetCheckEnabled(self.showOtherCCsCheck, ccEnabled)

    local immunitiesEnabled = BNP.ArePvPImmunitiesEnabled and BNP:ArePvPImmunitiesEnabled() or false
    if self.immunityIconSlider then
      self.immunityIconSlider:SetAlpha(immunitiesEnabled and 1.0 or 0.45)
      if self.immunityIconSlider.EnableMouse then self.immunityIconSlider:EnableMouse(immunitiesEnabled) end
    end
    if self.immunityPositionLabel then
      self.immunityPositionLabel:SetTextColor(immunitiesEnabled and 1 or 0.5, immunitiesEnabled and 1 or 0.5, immunitiesEnabled and 1 or 0.5)
    end
    if self.immunityPositionDropdown then
      self.immunityPositionDropdown:SetAlpha(immunitiesEnabled and 1.0 or 0.45)
      if immunitiesEnabled then
        if UIDropDownMenu_EnableDropDown then UIDropDownMenu_EnableDropDown(self.immunityPositionDropdown) end
      else
        if UIDropDownMenu_DisableDropDown then UIDropDownMenu_DisableDropDown(self.immunityPositionDropdown) end
      end
    end

    local totemsEnabled = BNP.AreTotemIndicatorsEnabled and BNP:AreTotemIndicatorsEnabled() or false
    if self.totemIconSlider then
      self.totemIconSlider:SetAlpha(totemsEnabled and 1.0 or 0.45)
      if self.totemIconSlider.EnableMouse then self.totemIconSlider:EnableMouse(totemsEnabled) end
    end

    local glowEnabled = BNP:IsTargetFocusEnabled()
    if self.glowColorLabel then
      self.glowColorLabel:SetTextColor(glowEnabled and 1 or 0.5, glowEnabled and 0.82 or 0.5, glowEnabled and 0 or 0.5)
    end
    if self.glowColorDropdown then
      self.glowColorDropdown:SetAlpha(glowEnabled and 1.0 or 0.45)
      if glowEnabled then
        if UIDropDownMenu_EnableDropDown then UIDropDownMenu_EnableDropDown(self.glowColorDropdown) end
      else
        if UIDropDownMenu_DisableDropDown then UIDropDownMenu_DisableDropDown(self.glowColorDropdown) end
      end
    end
  end

  frame:ShowTab("nameplates")
  self.optionsFrame = frame
end

function BNP:SyncOptions()
  self:CreateOptions()
  local frame = self.optionsFrame
  frame.scaleSlider:SetValue(self:GetNameplateScale())
  if frame.yOffsetSlider then
    local yOffset = self:GetNameplateYOffset()
    frame.yOffsetSlider:SetValue(yOffset)
    getglobal(frame.yOffsetSlider:GetName() .. "Text"):SetText("Nameplate Y Offset: +" .. yOffset)
  end
  if frame.nonTargetAlphaSlider then
    local alphaPercent = math.floor((self:GetNonTargetAlpha() * 100) + 0.5)
    frame.nonTargetAlphaSlider:SetValue(alphaPercent)
    getglobal(frame.nonTargetAlphaSlider:GetName() .. "Text"):SetText("Non-Target Alpha: " .. alphaPercent .. "%")
  end
  frame.iconSlider:SetValue(self:GetIconSize())
  if frame.ccIconSlider then
    local ccSize = self:GetCCIconSize()
    frame.ccIconSlider:SetValue(ccSize)
    getglobal(frame.ccIconSlider:GetName() .. "Text"):SetText("CC Icon Size: " .. ccSize)
  end
  if frame.immunityIconSlider then
    local immunitySize = self:GetImmunityIconSize()
    frame.immunityIconSlider:SetValue(immunitySize)
    getglobal(frame.immunityIconSlider:GetName() .. "Text"):SetText("Immunity Icon Size: " .. immunitySize)
  end
  if frame.totemIconSlider then
    local totemSize = self:GetTotemIconSize()
    frame.totemIconSlider:SetValue(totemSize)
    getglobal(frame.totemIconSlider:GetName() .. "Text"):SetText("Totem Icon Size: " .. totemSize)
  end
  frame.castbarHeightSlider:SetValue(self:GetCastbarHeight())
  if frame.castbarSpacingSlider then
    local spacing = self:GetCastbarSpacing()
    frame.castbarSpacingSlider:SetValue(spacing)
    getglobal(frame.castbarSpacingSlider:GetName() .. "Text"):SetText("Castbar Spacing: " .. spacing .. " px")
  end
  frame.classColorsCheck:SetChecked(self:AreClassColorsEnabled())
  if frame.hidePlayerNamesCheck then frame.hidePlayerNamesCheck:SetChecked(self:HidePlayerNamesEnabled()) end
  if frame.hideNPCNamesCheck then frame.hideNPCNamesCheck:SetChecked(self:HideNPCNamesEnabled()) end
  if frame.debuffsCheck then frame.debuffsCheck:SetChecked(self:AreDebuffsEnabled()) end
  if frame.debuffPositionDropdown then
    local position = self:GetDebuffPosition()
    local labels = { top = "Top Mid", top_left = "Top Left", top_right = "Top Right", left = "Left", right = "Right", bottom_mid = "Bottom Mid", bottom_left = "Bottom Left", bottom_right = "Bottom Right" }
    UIDropDownMenu_SetSelectedValue(frame.debuffPositionDropdown, position)
    UIDropDownMenu_SetText(labels[position] or "Top Mid", frame.debuffPositionDropdown)
  end
  if frame.ccPositionDropdown then
    local position = self:GetCCPosition()
    local labels = { top = "Top", left = "Left", right = "Right" }
    UIDropDownMenu_SetSelectedValue(frame.ccPositionDropdown, position)
    UIDropDownMenu_SetText(labels[position] or "Top", frame.ccPositionDropdown)
  end
  if frame.crowdControlCheck then frame.crowdControlCheck:SetChecked(self:AreCrowdControlEnabled()) end
  if frame.separateCCRowCheck then frame.separateCCRowCheck:SetChecked(self:IsSeparateCCRowEnabled()) end
  if frame.showOtherCCsCheck then frame.showOtherCCsCheck:SetChecked(self:ShowOtherPlayersCCs()) end
  if frame.pvpImmunitiesCheck then frame.pvpImmunitiesCheck:SetChecked(self:ArePvPImmunitiesEnabled()) end
  if frame.immunityPositionDropdown then
    local position = self:GetImmunityPosition()
    local labels = { top = "Top", left = "Left", right = "Right" }
    UIDropDownMenu_SetSelectedValue(frame.immunityPositionDropdown, position)
    UIDropDownMenu_SetText(labels[position] or "Top", frame.immunityPositionDropdown)
  end
  if frame.totemIndicatorsCheck then frame.totemIndicatorsCheck:SetChecked(self:AreTotemIndicatorsEnabled()) end
  frame.castbarsCheck:SetChecked(self:AreCastbarsEnabled())
  if frame.castbarTestCheck then
    frame.castbarTestCheck:SetChecked(self.IsCastbarTestMode and self:IsCastbarTestMode() or false)
  end
  frame.tankCheck:SetChecked(self:IsTankModeEnabled())
  if frame.comboPointsCheck and comboOptionsClass then
    frame.comboPointsCheck:SetChecked(self:AreComboPointsEnabled())
  end
  if frame.healthTextDropdown then
    local mode = self:GetHealthTextMode()
    UIDropDownMenu_SetSelectedValue(frame.healthTextDropdown, mode)
    local labels = { off = "Off", percent = "Percent", hp = "HP", both = "HP + Percent" }
    UIDropDownMenu_SetText(labels[mode] or "Off", frame.healthTextDropdown)
  end
  frame.targetFocusCheck:SetChecked(self:IsTargetFocusEnabled())

  if frame.glowColorDropdown then
    local _, _, _, color = self:GetTargetGlowColor()
    local labels = {
      white = "White",
      gold = "Gold",
      blue = "Blue",
      green = "Green",
      red = "Red",
      purple = "Purple",
    }
    UIDropDownMenu_SetSelectedValue(frame.glowColorDropdown, color or "white")
    UIDropDownMenu_SetText(labels[color] or "White", frame.glowColorDropdown)
  end

  if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  frame.versionText:SetText("Version " .. tostring(self.version or "?"))
end

function BNP:ToggleOptions()
  self:SyncOptions()
  if self.optionsFrame:IsShown() then
    self.optionsFrame:Hide()
  else
    self.optionsFrame:Show()
  end
end

function BNP:CreateMinimapButton()
  if self.minimapButton then return end

  BNP_DB = BNP_DB or {}
  if BNP_DB.minimapAngle == nil then BNP_DB.minimapAngle = 225 end

  local button = CreateFrame("Button", "BNPMinimapButton", Minimap)
  button:SetWidth(31)
  button:SetHeight(31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  button:RegisterForClicks("LeftButtonUp")
  button:RegisterForDrag("LeftButton")
  button:EnableMouse(true)
  button:SetMovable(true)

  -- Classic round minimap-button background.
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetWidth(22)
  bg:SetHeight(22)
  bg:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.bg = bg

  -- Addon identity: simple BN+ lettering instead of a spell/item icon.
  -- Rendered directly by the client, so no external texture file is needed.
  local iconBG = button:CreateTexture(nil, "ARTWORK")
  iconBG:SetTexture(0.03, 0.03, 0.03, 1)
  iconBG:SetWidth(20)
  iconBG:SetHeight(20)
  iconBG:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.iconBG = iconBG

  local label = button:CreateFontString(nil, "OVERLAY")
  label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  label:SetText("BN+")
  label:SetTextColor(0.20, 0.60, 1.00)
  button.label = label

  -- Standard Blizzard circular minimap border.
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(54)
  border:SetHeight(54)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button.border = border

  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  highlight:SetBlendMode("ADD")
  highlight:SetAllPoints(button)
  button.highlight = highlight

  local function UpdatePosition()
    local angle = tonumber(BNP_DB.minimapAngle) or 225
    local radius = 78
    local rad = math.rad(angle)

    button:ClearAllPoints()
    button:SetPoint(
      "CENTER",
      Minimap,
      "CENTER",
      math.cos(rad) * radius,
      math.sin(rad) * radius
    )
  end

  local function UpdateAngleFromCursor()
    local mx, my = Minimap:GetCenter()
    local scale = 1
    if UIParent.GetEffectiveScale then
      scale = UIParent:GetEffectiveScale() or 1
    elseif UIParent.GetScale then
      scale = UIParent:GetScale() or 1
    end
    local cx, cy = GetCursorPosition()
    cx = cx / scale
    cy = cy / scale

    local dx = cx - mx
    local dy = cy - my

    local angle
    if math.atan2 then
      angle = math.deg(math.atan2(dy, dx))
    else
      if dx == 0 then
        angle = dy >= 0 and 90 or -90
      else
        angle = math.deg(math.atan(dy / dx))
        if dx < 0 then angle = angle + 180 end
      end
    end
    BNP_DB.minimapAngle = angle
    UpdatePosition()
  end

  button:SetScript("OnDragStart", function()
    this:SetScript("OnUpdate", UpdateAngleFromCursor)
  end)

  button:SetScript("OnDragStop", function()
    this:SetScript("OnUpdate", nil)
    UpdateAngleFromCursor()
  end)

  button:SetScript("OnClick", function()
    BNP:ToggleOptions()
  end)

  button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("Blizz Nameplates+")
    GameTooltip:AddLine("Left-click: Open settings", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move minimap button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  UpdatePosition()
  self.minimapButton = button
end
