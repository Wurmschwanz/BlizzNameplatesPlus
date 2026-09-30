BNP = BNP or {}

local _, optionsPlayerClass = UnitClass("player")
local comboOptionsClass = (optionsPlayerClass == "ROGUE" or optionsPlayerClass == "DRUID")

local function Round(value, step)
  return math.floor((value / step) + 0.5) * step
end

local function RoundSignedInteger(value)
  value = tonumber(value) or 0
  if value >= 0 then return math.floor(value + 0.5) end
  return math.ceil(value - 0.5)
end

local sliderCount = 0
local function CreateSlider(parent, label, minValue, maxValue, step, y, x, width)
  sliderCount = sliderCount + 1
  local slider = CreateFrame("Slider", "BNPOptionsSlider" .. sliderCount, parent, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 28, y)
  slider:SetWidth(width or 220)
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

local function SetColorSwatchColor(button, r, g, b)
  if not button then return end
  if button.BNPColorTexture then
    button.BNPColorTexture:SetVertexColor(r or 1, g or 1, b or 1, 1)
  elseif button.SetBackdropColor then
    button:SetBackdropColor(r or 1, g or 1, b or 1, 1)
  end
end

local function PrepareBNPColorPicker()
  if not ColorPickerFrame then return end

  -- BNP's options window lives on DIALOG. Put the Blizzard color picker on a
  -- higher strata, but do NOT force a high frame level on the parent itself.
  -- Raising only the parent frame level can leave Blizzard's native Okay /
  -- Cancel buttons underneath its mouse layer on old 1.12 clients.
  if ColorPickerFrame.SetFrameStrata then
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  end
  if ColorPickerFrame.SetMovable then
    ColorPickerFrame:SetMovable(true)
  end
  if ColorPickerFrame.SetClampedToScreen then
    ColorPickerFrame:SetClampedToScreen(true)
  end
  if ColorPickerFrame.EnableMouse then
    ColorPickerFrame:EnableMouse(true)
  end
  -- Never let the picker become a modal keyboard owner. On some 1.12
  -- clients the Blizzard color picker can otherwise swallow movement keys
  -- and action-bar binds while it is visible. Mouse interaction remains
  -- enabled so the wheel, buttons and background dragging still work.
  if ColorPickerFrame.EnableKeyboard then
    ColorPickerFrame:EnableKeyboard(false)
  end

  -- Remove the old separate drag header if this code is loaded over a build
  -- that already created it during the same UI session.
  if BNPColorPickerDragHandle then
    BNPColorPickerDragHandle:Hide()
    BNPColorPickerDragHandle:EnableMouse(false)
  end

  -- Do NOT make the ColorPickerFrame itself draggable with the left mouse
  -- button. On the old client the color wheel/value slider are handled by the
  -- ColorSelect frame itself, so a parent OnMouseDown steals the drag from the
  -- color selector. Instead create transparent drag zones only over genuinely
  -- unused background areas. This keeps the picker easy to move while the
  -- color point and brightness slider remain fully interactive.
  if not ColorPickerFrame.BNPDragInstalled then
    ColorPickerFrame.BNPDragInstalled = true

    local function CreatePickerDragZone(name)
      local zone = CreateFrame("Frame", name, ColorPickerFrame)
      zone:EnableMouse(true)
      if zone.SetFrameLevel and ColorPickerFrame.GetFrameLevel then
        zone:SetFrameLevel(ColorPickerFrame:GetFrameLevel() + 5)
      end
      zone:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" and ColorPickerFrame.StartMoving then
          ColorPickerFrame:StartMoving()
        end
      end)
      zone:SetScript("OnMouseUp", function()
        if ColorPickerFrame.StopMovingOrSizing then
          ColorPickerFrame:StopMovingOrSizing()
        end
      end)
      return zone
    end

    -- Top/title area: full width, safely above the actual color controls.
    local top = CreatePickerDragZone("BNPColorPickerDragTop")
    top:SetPoint("TOPLEFT", ColorPickerFrame, "TOPLEFT", 6, -4)
    top:SetPoint("TOPRIGHT", ColorPickerFrame, "TOPRIGHT", -6, -4)
    top:SetHeight(28)

    -- Right-side empty panel around the preview swatch. This gives a second,
    -- large place to grab the window without covering the wheel or slider.
    local side = CreatePickerDragZone("BNPColorPickerDragSide")
    side:SetPoint("TOPRIGHT", ColorPickerFrame, "TOPRIGHT", -6, -34)
    side:SetWidth(58)
    side:SetHeight(92)

    ColorPickerFrame.BNPDragTop = top
    ColorPickerFrame.BNPDragSide = side
  end

  -- Keep the three action buttons compact and separated so they stay fully
  -- clickable on the old client. The default Blizzard button widths are a bit
  -- too large once BNP adds Reset, which caused overlap in practice.
  if ColorPickerOkayButton then
    ColorPickerOkayButton:ClearAllPoints()
    ColorPickerOkayButton:SetWidth(62)
    ColorPickerOkayButton:SetHeight(18)
    ColorPickerOkayButton:SetPoint("BOTTOMLEFT", ColorPickerFrame, "BOTTOMLEFT", 10, 12)
  end
  if ColorPickerCancelButton then
    ColorPickerCancelButton:ClearAllPoints()
    ColorPickerCancelButton:SetWidth(62)
    ColorPickerCancelButton:SetHeight(18)
    ColorPickerCancelButton:SetPoint("BOTTOMRIGHT", ColorPickerFrame, "BOTTOMRIGHT", -10, 12)
  end

  -- Reset lives directly on the picker and gets its own centered slot between
  -- Okay and Cancel, so no button overlaps another one.
  if not BNPColorPickerResetButton then
    local reset = CreateFrame("Button", "BNPColorPickerResetButton", ColorPickerFrame, "UIPanelButtonTemplate")
    reset:SetText("Reset")
    reset:SetScript("OnClick", function()
      local r = ColorPickerFrame.BNPResetR
      local g = ColorPickerFrame.BNPResetG
      local b = ColorPickerFrame.BNPResetB
      local setter = ColorPickerFrame.BNPActiveColorSetter
      local swatch = ColorPickerFrame.BNPActiveColorSwatch
      if r == nil or g == nil or b == nil or not setter then return end

      ColorPickerFrame:SetColorRGB(r, g, b)
      setter(r, g, b)
      if swatch and swatch.RefreshColor then swatch:RefreshColor() end
    end)
    reset:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText("Reset Color", 1, 0.82, 0)
      GameTooltip:AddLine(ColorPickerFrame.BNPResetTooltip or "Restores BNP's default color for this Invert Tank state.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  BNPColorPickerResetButton:ClearAllPoints()
  BNPColorPickerResetButton:SetWidth(46)
  BNPColorPickerResetButton:SetHeight(18)
  BNPColorPickerResetButton:SetPoint("BOTTOM", ColorPickerFrame, "BOTTOM", 0, 12)
end

local function CreateColorSwatch(parent, label, y, x, getColor, setColor, defaultR, defaultG, defaultB, tooltipLine, resetTooltip)
  local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 22, y - 2)
  text:SetText(label)

  -- Use explicit textures instead of a backdrop here. This is more reliable on
  -- old 1.12 clients and guarantees that the user actually sees a color box.
  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetWidth(24)
  swatch:SetHeight(24)
  swatch:SetPoint("LEFT", text, "RIGHT", 8, 0)

  local border = swatch:CreateTexture(nil, "BACKGROUND")
  border:SetAllPoints(swatch)
  border:SetTexture(0.10, 0.10, 0.10, 1)

  local color = swatch:CreateTexture(nil, "ARTWORK")
  color:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
  color:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)
  color:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
  swatch.BNPColorTexture = color

  local shine = swatch:CreateTexture(nil, "OVERLAY")
  shine:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
  shine:SetWidth(18)
  shine:SetHeight(1)
  shine:SetTexture(0.85, 0.85, 0.85, 0.9)

  function swatch:RefreshColor()
    local r, g, b = getColor()
    SetColorSwatchColor(self, r, g, b)
  end

  swatch:SetScript("OnClick", function()
    local r, g, b = getColor()
    local oldR, oldG, oldB = r, g, b

    PrepareBNPColorPicker()
    ColorPickerFrame:Hide()
    ColorPickerFrame.BNPResetR = defaultR
    ColorPickerFrame.BNPResetG = defaultG
    ColorPickerFrame.BNPResetB = defaultB
    ColorPickerFrame.BNPActiveColorSetter = setColor
    ColorPickerFrame.BNPActiveColorSwatch = swatch
    ColorPickerFrame.BNPResetTooltip = resetTooltip
    ColorPickerFrame.func = nil
    ColorPickerFrame.opacityFunc = nil
    ColorPickerFrame.cancelFunc = nil
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame:SetColorRGB(r, g, b)

    ColorPickerFrame.func = function()
      local nr, ng, nb = ColorPickerFrame:GetColorRGB()
      setColor(nr, ng, nb)
      swatch:RefreshColor()
    end

    ColorPickerFrame.cancelFunc = function()
      setColor(oldR, oldG, oldB)
      swatch:RefreshColor()
    end

    ColorPickerFrame:Show()
    -- Blizzard's OnShow may restore keyboard input on old clients, so force
    -- it off after the frame is actually visible as well.
    if ColorPickerFrame.EnableKeyboard then ColorPickerFrame:EnableKeyboard(false) end
    if ColorPickerFrame.Raise then ColorPickerFrame:Raise() end
  end)

  swatch:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(label, 1, 0.82, 0)
    GameTooltip:AddLine(tooltipLine or "Click the color box to choose the color used while Invert Tank Colors is enabled.", 1, 1, 1, true)
    GameTooltip:AddLine("The color picker opens above this menu and can be dragged from any free background area.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
  swatch.BNPLabel = text
  swatch:RefreshColor()
  return swatch, text
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

local function BuildOtherDebuffsOptions(frame, otherPage, createSection)

createSection(otherPage, "Other Class Debuffs", -4)

local otherDebuffsEnabled = CreateCheck(otherPage, "Enable Other Class Debuffs", -28, function()
  BNP_DB.otherDebuffs = this:GetChecked() and true or false
  if BNP.RefreshOtherDebuffs then BNP:RefreshOtherDebuffs() end
  if frame.RefreshOtherDebuffPage then frame:RefreshOtherDebuffPage() end
end, 22)
otherDebuffsEnabled:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  GameTooltip:SetText("Other Class Debuffs", 1, 0.82, 0)
  GameTooltip:AddLine("Shows selected non-CC debuffs applied by other players/classes. The feature is off by default and never changes BNP's own-cast tracking.", 1, 1, 1, true)
  GameTooltip:Show()
end)
otherDebuffsEnabled:SetScript("OnLeave", function() GameTooltip:Hide() end)
frame.otherDebuffsEnabledCheck = otherDebuffsEnabled

local otherNote = otherPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
otherNote:SetPoint("TOPLEFT", otherPage, "TOPLEFT", 28, -58)
otherNote:SetWidth(390)
otherNote:SetJustifyH("LEFT")
otherNote:SetText("Select which non-CC foreign debuffs BNP should display. Crowd Control stays in BNP's dedicated CC system.")

local OTHER_TAB_W = 80
local OTHER_TAB_H = 20
local OTHER_TAB_GAP = 3
local OTHER_TAB_X = 5
local OTHER_TAB_Y = -90
frame.otherDebuffClassTabs = {}
frame.otherSelectedClass = "warrior"

local classOrder = BNP.OtherDebuffClassOrder or { "warrior", "rogue", "hunter", "mage", "warlock", "priest", "druid", "shaman", "paladin" }
local classLabels = BNP.OtherDebuffClassLabels or {}
local classColors = BNP.OtherDebuffClassColors or {}

local i
for i = 1, table.getn(classOrder) do
  local classKey = classOrder[i]
  local tab = CreateFrame("Button", nil, otherPage)
  tab:SetWidth(OTHER_TAB_W)
  tab:SetHeight(OTHER_TAB_H)
  tab:EnableMouse(true)
  if i <= 5 then
    tab:SetPoint("TOPLEFT", otherPage, "TOPLEFT", OTHER_TAB_X + (i - 1) * (OTHER_TAB_W + OTHER_TAB_GAP), OTHER_TAB_Y)
  else
    tab:SetPoint("TOPLEFT", otherPage, "TOPLEFT", OTHER_TAB_X + (i - 6) * (OTHER_TAB_W + OTHER_TAB_GAP), OTHER_TAB_Y - OTHER_TAB_H - 3)
  end

  local color = classColors[classKey] or { 0.6, 0.6, 0.6 }
  local bg = tab:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(tab)
  bg:SetTexture(color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 0.85)
  tab.BNPBG = bg

  local text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  text:SetPoint("CENTER", tab, "CENTER", 0, 0)
  text:SetText(classLabels[classKey] or classKey)
  text:SetTextColor(color[1], color[2], color[3])
  tab.BNPText = text
  tab.BNPClassKey = classKey

  tab:SetScript("OnClick", function()
    frame.otherSelectedClass = this.BNPClassKey
    if frame.RefreshOtherDebuffPage then frame:RefreshOtherDebuffPage() end
  end)
  tab:SetScript("OnEnter", function()
    local c = classColors[this.BNPClassKey] or { 0.6, 0.6, 0.6 }
    if this.BNPBG then this.BNPBG:SetTexture(c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 1) end
  end)
  tab:SetScript("OnLeave", function()
    local c = classColors[this.BNPClassKey] or { 0.6, 0.6, 0.6 }
    local selected = frame.otherSelectedClass == this.BNPClassKey
    if this.BNPBG then
      if selected then this.BNPBG:SetTexture(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1)
      else this.BNPBG:SetTexture(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 0.85) end
    end
  end)

  frame.otherDebuffClassTabs[classKey] = tab
end

local selectedClassLabel = otherPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
selectedClassLabel:SetPoint("TOPLEFT", otherPage, "TOPLEFT", 14, -147)
selectedClassLabel:SetText("Warrior")
frame.otherSelectedClassLabel = selectedClassLabel

local enableClassButton = CreateFrame("Button", nil, otherPage, "UIPanelButtonTemplate")
enableClassButton:SetWidth(92)
enableClassButton:SetHeight(22)
enableClassButton:SetPoint("TOPRIGHT", otherPage, "TOPRIGHT", -112, -140)
enableClassButton:SetText("Enable All")
enableClassButton:SetScript("OnClick", function()
  BNP:SetAllOtherDebuffsEnabled(true)
  if BNP.RefreshOtherDebuffs then BNP:RefreshOtherDebuffs() end
  if frame.RefreshOtherDebuffPage then frame:RefreshOtherDebuffPage() end
end)

local disableClassButton = CreateFrame("Button", nil, otherPage, "UIPanelButtonTemplate")
disableClassButton:SetWidth(92)
disableClassButton:SetHeight(22)
disableClassButton:SetPoint("TOPRIGHT", otherPage, "TOPRIGHT", -14, -140)
disableClassButton:SetText("Disable All")
disableClassButton:SetScript("OnClick", function()
  BNP:SetAllOtherDebuffsEnabled(false)
  if BNP.RefreshOtherDebuffs then BNP:RefreshOtherDebuffs() end
  if frame.RefreshOtherDebuffPage then frame:RefreshOtherDebuffPage() end
end)

frame.otherEnableClassButton = enableClassButton
frame.otherDisableClassButton = disableClassButton
frame.otherDebuffRows = {}

for i = 1, 12 do
  local row = CreateFrame("Frame", nil, otherPage)
  row:SetWidth(405)
  row:SetHeight(28)
  row:SetPoint("TOPLEFT", otherPage, "TOPLEFT", 14, -174 - ((i - 1) * 29))

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("LEFT", row, "LEFT", 2, 0)
  icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  row.BNPIcon = icon

  local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  check:SetWidth(24)
  check:SetHeight(24)
  check:SetPoint("LEFT", icon, "RIGHT", 5, 0)
  row.BNPCheck = check

  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", check, "RIGHT", 3, 0)
  label:SetWidth(300)
  label:SetJustifyH("LEFT")
  row.BNPLabel = label

  check:SetScript("OnClick", function()
    if not this.BNPDebuffKey then return end
    BNP:SetOtherDebuffSelected(this.BNPDebuffKey, this:GetChecked() and true or false)
    if BNP.RefreshOtherDebuffs then BNP:RefreshOtherDebuffs() end
  end)
  check:SetScript("OnEnter", function()
    local def = this.BNPDebuffDef
    if not def then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(def.label or def.key, 1, 0.82, 0)
    if def.description then GameTooltip:AddLine(def.description, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  check:SetScript("OnLeave", function() GameTooltip:Hide() end)

  frame.otherDebuffRows[i] = row
end

local emptyClassNote = otherPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
emptyClassNote:SetPoint("TOPLEFT", otherPage, "TOPLEFT", 20, -184)
emptyClassNote:SetWidth(380)
emptyClassNote:SetJustifyH("LEFT")
emptyClassNote:SetText("No shared Shaman debuffs are defined in the imported Cursive class list.")
emptyClassNote:Hide()
frame.otherEmptyClassNote = emptyClassNote

function frame:RefreshOtherDebuffPage()
  if self.otherDebuffsEnabledCheck then
    self.otherDebuffsEnabledCheck:SetChecked(BNP.AreOtherDebuffsEnabled and BNP:AreOtherDebuffsEnabled() or false)
  end

  local selected = self.otherSelectedClass or "warrior"
  local defs = BNP.OtherDebuffDefs and BNP.OtherDebuffDefs[selected] or nil
  local selectedColor = classColors[selected] or { 1, 0.82, 0 }
  if self.otherSelectedClassLabel then
    self.otherSelectedClassLabel:SetText(classLabels[selected] or selected)
    self.otherSelectedClassLabel:SetTextColor(selectedColor[1], selectedColor[2], selectedColor[3])
  end

  local classKey, tab
  for classKey, tab in pairs(self.otherDebuffClassTabs or {}) do
    local c = classColors[classKey] or { 0.6, 0.6, 0.6 }
    if tab.BNPBG then
      if classKey == selected then tab.BNPBG:SetTexture(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1)
      else tab.BNPBG:SetTexture(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 0.85) end
    end
  end

  local count = defs and table.getn(defs) or 0
  if self.otherEmptyClassNote then
    if count == 0 then self.otherEmptyClassNote:Show() else self.otherEmptyClassNote:Hide() end
  end

  local rowIndex
  for rowIndex = 1, table.getn(self.otherDebuffRows or {}) do
    local row = self.otherDebuffRows[rowIndex]
    local def = defs and defs[rowIndex] or nil
    if def then
      row.BNPDef = def
      row.BNPCheck.BNPDebuffKey = def.key
      row.BNPCheck.BNPDebuffDef = def
      row.BNPCheck:SetChecked(BNP.IsOtherDebuffSelected and BNP:IsOtherDebuffSelected(def.key) or false)
      row.BNPIcon:SetTexture(BNP.GetOtherDebuffTexture and BNP:GetOtherDebuffTexture(def) or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.BNPLabel:SetText(def.label or def.key)
      row.BNPLabel:SetTextColor(selectedColor[1], selectedColor[2], selectedColor[3])
      row:Show()
    else
      row.BNPDef = nil
      row.BNPCheck.BNPDebuffKey = nil
      row.BNPCheck.BNPDebuffDef = nil
      row:Hide()
    end
  end
end

end

function BNP:CreateOptions()
  if self.optionsFrame then return end

  local frame = CreateFrame("Frame", "BNPOptionsFrame", UIParent)
  frame:SetWidth(470)
  frame:SetHeight(710)
  -- Keep the top edge in roughly the same place and add the extra room
  -- downward. The Icons page uses the height for Totems, Raid Marks and
  -- Quest Indicators without crowding or clipping.
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
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
    page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
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

  -- Compact tab navigation. The Icons page groups visual indicators that sit
  -- on nameplates but do not belong to the debuff/CC state machine.
  frame.pages = {
    nameplates = CreatePage(),
    auras = CreatePage(),
    totems = CreatePage(),
    castbar = CreatePage(),
    target = CreatePage(),
    other = CreatePage(),
    tools = CreatePage(),
  }
  frame.tabs = {}

  local tabDefs = {
    { key = "nameplates", label = "Nameplates", width = 72 },
    { key = "auras", label = "Auras", width = 50 },
    { key = "totems", label = "Icons", width = 52 },
    { key = "castbar", label = "Castbar", width = 58 },
    { key = "target", label = "Target", width = 54 },
    { key = "other", label = "Other Debuffs", width = 84 },
    { key = "tools", label = "Tools", width = 46 },
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
    if key == "other" and self.RefreshOtherDebuffPage then
      self:RefreshOtherDebuffPage()
    end
  end

  local tabX = 15
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

  -- GENERAL ---------------------------------------------------------------
  CreateSection(nameplatesPage, "General", -4)

  local scale = CreateSlider(nameplatesPage, "Nameplate Scale", 0.70, 1.50, 0.05, -28, 28, 150)
  scale:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = Round(this:GetValue(), 0.05)
    BNP_DB.nameplateScale = value
    getglobal(this:GetName() .. "Text"):SetText("Nameplate Scale: " .. string.format("%.2f", value))
    if BNP.ApplyNameplateScaleAll then BNP:ApplyNameplateScaleAll() end
  end)
  frame.scaleSlider = scale

  local yOffset = CreateSlider(nameplatesPage, "Nameplate Y Offset", 0, 50, 1, -28, 220, 150)
  yOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.nameplateYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Nameplate Y Offset: +" .. value)
    if BNP.ApplyNameplateYOffsetAll then BNP:ApplyNameplateYOffsetAll() end
  end)
  frame.yOffsetSlider = yOffset

  local nonTargetAlpha = CreateSlider(nameplatesPage, "Non-Target Alpha", 30, 100, 5, -64, 28, 150)
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

  local classColors = CreateCheck(nameplatesPage, "Class Colors", -60, function()
    BNP_DB.classColors = this:GetChecked() and true or false
    if BNP.RefreshClassColors then BNP:RefreshClassColors() end
  end, 214)
  frame.classColorsCheck = classColors

  local darkNameplateBorder = CreateCheck(nameplatesPage, "Dark Border", -88, function()
    BNP_DB.darkNameplateBorder = this:GetChecked() and true or false
    if BNP.RefreshNameplateBorderStyle then BNP:RefreshNameplateBorderStyle() end
  end, 22)
  darkNameplateBorder:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Dark Nameplate Border", 1, 0.82, 0)
    GameTooltip:AddLine("Darkens only the classic Blizzard nameplate border using the ShaguTweaks Darkened UI color.", 1, 1, 1, true)
    GameTooltip:AddLine("When disabled, the original gold border is restored, including with ShaguTweaks. Other elements remain unchanged.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  darkNameplateBorder:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.darkNameplateBorderCheck = darkNameplateBorder

  local hideNameplateBorder = CreateCheck(nameplatesPage, "Hide Border", -88, function()
    BNP_DB.hideNameplateBorder = this:GetChecked() and true or false
    if BNP.RefreshNameplateBorderStyle then BNP:RefreshNameplateBorderStyle() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end, 214)
  hideNameplateBorder:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Hide Nameplate Border", 1, 0.82, 0)
    GameTooltip:AddLine("Hides only the native Blizzard nameplate border. BNP keeps the border reference internally so it can be restored safely.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  hideNameplateBorder:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.hideNameplateBorderCheck = hideNameplateBorder

  -- TANK MODE -------------------------------------------------------------
  CreateSection(nameplatesPage, "Tank Mode", -118)

  local tank = CreateCheck(nameplatesPage, "Tank Mode", -142, function()
    BNP_DB.tankMode = this:GetChecked() and true or false
    if BNP.UpdateTankMode then BNP:UpdateTankMode() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end, 22)
  tank:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Tank Mode", 1, 0.82, 0)
    GameTooltip:AddLine("Normal mode is fixed: Green when the unit targets you, Red when it targets someone else.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  tank:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.tankCheck = tank

  local invertTankColors = CreateCheck(nameplatesPage, "Invert Tank Colors", -142, function()
    BNP_DB.invertTankColors = this:GetChecked() and true or false
    if BNP.UpdateTankMode then BNP:UpdateTankMode() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end, 214)
  invertTankColors:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Invert Tank Colors", 1, 0.82, 0)
    GameTooltip:AddLine("Uses the two custom colors below instead of the normal fixed Green/Red Tank Mode colors.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  invertTankColors:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.invertTankColorsCheck = invertTankColors

  local invertAggroColor = CreateColorSwatch(nameplatesPage, "Aggro Color", -170, 22,
    function() return BNP:GetInvertTankAggroColor() end,
    function(r, g, b) BNP:SetInvertTankAggroColor(r, g, b) end,
    1.00, 0.00, 0.00)
  frame.invertAggroColorSwatch = invertAggroColor

  local invertNoAggroColor = CreateColorSwatch(nameplatesPage, "No Aggro Color", -170, 214,
    function() return BNP:GetInvertTankNoAggroColor() end,
    function(r, g, b) BNP:SetInvertTankNoAggroColor(r, g, b) end,
    0.00, 1.00, 0.00)
  frame.invertNoAggroColorSwatch = invertNoAggroColor

  -- NAMES & LEVEL ---------------------------------------------------------
  CreateSection(nameplatesPage, "Names & Level", -202)

  local hidePlayerNames = CreateCheck(nameplatesPage, "Hide Player Names", -226, function()
    BNP_DB.hidePlayerNames = this:GetChecked() and true or false
    if BNP.RefreshNameVisibility then BNP:RefreshNameVisibility() end
  end, 22)
  frame.hidePlayerNamesCheck = hidePlayerNames

  local hideNPCNames = CreateCheck(nameplatesPage, "Hide NPC Names", -226, function()
    BNP_DB.hideNPCNames = this:GetChecked() and true or false
    if BNP.RefreshNameVisibility then BNP:RefreshNameVisibility() end
  end, 214)
  frame.hideNPCNamesCheck = hideNPCNames

  local hideNameplateLevel = CreateCheck(nameplatesPage, "Hide Level", -250, function()
    BNP_DB.hideNameplateLevel = this:GetChecked() and true or false
    if BNP.RefreshNameplateLevelVisibility then BNP:RefreshNameplateLevelVisibility() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end, 22)
  hideNameplateLevel:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Hide Nameplate Level", 1, 0.82, 0)
    GameTooltip:AddLine("Hides the numeric Blizzard level text without removing BNP's internal reference to it. Boss/level icons are left untouched.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  hideNameplateLevel:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.hideNameplateLevelCheck = hideNameplateLevel

  local customNameColor = CreateCheck(nameplatesPage, "Custom Name Color", -250, function()
    BNP_DB.customNameColor = this:GetChecked() and true or false
    if BNP.RefreshNameAppearance then BNP:RefreshNameAppearance() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end, 214)
  customNameColor:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Custom Name Color", 1, 0.82, 0)
    GameTooltip:AddLine("Keeps nameplate names in one fixed color instead of allowing the client to recolor them, for example to red during combat.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  customNameColor:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.customNameColorCheck = customNameColor

  local nameColorSwatch, nameColorLabel = CreateColorSwatch(nameplatesPage, "Name Color", -276, 214,
    function() return BNP:GetNameColor() end,
    function(r, g, b) BNP:SetNameColor(r, g, b) end,
    1.00, 1.00, 1.00,
    "Choose the fixed color used for nameplate names while Custom Name Color is enabled.",
    "Restores the custom name color to white.")
  nameColorSwatch:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Name Color", 1, 0.82, 0)
    GameTooltip:AddLine("Choose the fixed color used for nameplate names while Custom Name Color is enabled.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  nameColorSwatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.nameColorSwatch = nameColorSwatch

  -- Name text controls are independent from Nameplate Scale. The size setting
  -- only touches the Blizzard name FontString; the Y offset only moves it.
  local nameFontSize = CreateSlider(nameplatesPage, "Name Font Size", 8, 24, 1, -306, 28, 150)
  nameFontSize:SetScript("OnValueChanged", function()
    if not BNP_DB or frame.BNPSyncingNameControls then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.nameFontSize = value
    getglobal(this:GetName() .. "Text"):SetText("Name Font Size: " .. value)
    if BNP.RefreshNameAppearance then BNP:RefreshNameAppearance() end
  end)
  frame.nameFontSizeSlider = nameFontSize

  local nameFontYOffset = CreateSlider(nameplatesPage, "Name Y Offset", -50, 50, 1, -306, 220, 150)
  nameFontYOffset:SetScript("OnValueChanged", function()
    if not BNP_DB or frame.BNPSyncingNameControls then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.nameFontYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Name Y Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.ApplyNameFontYOffsetAll then BNP:ApplyNameFontYOffsetAll() end
  end)
  frame.nameFontYOffsetSlider = nameFontYOffset

  -- HEALTH BAR & TEXT -----------------------------------------------------
  CreateSection(nameplatesPage, "Health Bar & Text", -336)

  local healthTextLabel = nameplatesPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  healthTextLabel:SetPoint("TOPLEFT", nameplatesPage, "TOPLEFT", 28, -358)
  healthTextLabel:SetText("Display")

  local healthTextDropdown = CreateFrame("Frame", "BNPHealthTextDropdown", nameplatesPage, "UIDropDownMenuTemplate")
  healthTextDropdown:SetPoint("TOPLEFT", nameplatesPage, "TOPLEFT", 10, -370)
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

  local healthOutlineLabel = nameplatesPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  healthOutlineLabel:SetPoint("TOPLEFT", nameplatesPage, "TOPLEFT", 220, -358)
  healthOutlineLabel:SetText("Outline")

  local healthOutlineDropdown = CreateFrame("Frame", "BNPHealthOutlineDropdown", nameplatesPage, "UIDropDownMenuTemplate")
  healthOutlineDropdown:SetPoint("TOPLEFT", nameplatesPage, "TOPLEFT", 200, -370)
  UIDropDownMenu_SetWidth(150, healthOutlineDropdown)

  local healthOutlineLabels = {
    none = "None",
    outline = "Outline",
    thick = "Thick Outline",
  }

  local function SetHealthTextOutline(value)
    if not healthOutlineLabels[value] then value = "outline" end
    BNP_DB.healthTextOutline = value
    UIDropDownMenu_SetSelectedValue(healthOutlineDropdown, value)
    UIDropDownMenu_SetText(healthOutlineLabels[value], healthOutlineDropdown)
    if BNP.RefreshHealthPercent then BNP:RefreshHealthPercent() end
  end

  UIDropDownMenu_Initialize(healthOutlineDropdown, function()
    local values = { "none", "outline", "thick" }
    local n
    for n = 1, table.getn(values) do
      local value = values[n]
      local info = {}
      info.text = healthOutlineLabels[value]
      info.value = value
      info.func = function() SetHealthTextOutline(this.value) end
      info.checked = (BNP:GetHealthTextOutline() == value)
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.healthTextOutlineDropdown = healthOutlineDropdown
  frame.SetHealthTextOutline = SetHealthTextOutline

  local healthFontSize = CreateSlider(nameplatesPage, "Health Font Size", 8, 20, 1, -416, 28, 150)
  healthFontSize:SetScript("OnValueChanged", function()
    if not BNP_DB or frame.BNPSyncingHealthTextControls then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.healthTextFontSize = value
    getglobal(this:GetName() .. "Text"):SetText("Health Font Size: " .. value)
    if BNP.RefreshHealthPercent then BNP:RefreshHealthPercent() end
  end)
  frame.healthTextFontSizeSlider = healthFontSize

  local blackHealthbarBackground = CreateCheck(nameplatesPage, "Black Health Background", -412, function()
    BNP_DB.blackHealthbarBackground = this:GetChecked() and true or false
    if BNP.RefreshHealthbarBackground then BNP:RefreshHealthbarBackground() end
  end, 214)
  blackHealthbarBackground:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Black Healthbar Background", 1, 0.82, 0)
    GameTooltip:AddLine("Shows missing health on the nameplate against a solid black background instead of the transparent world view.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  blackHealthbarBackground:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.blackHealthbarBackgroundCheck = blackHealthbarBackground

  -- COMBO POINTS (Rogue / Druid only) ------------------------------------
  if comboOptionsClass then
    CreateSection(nameplatesPage, "Combo Points", -442)

    local comboPoints = CreateCheck(nameplatesPage, "Combo Points", -466, function()
      BNP_DB.comboPoints = this:GetChecked() and true or false
      if BNP.RefreshComboPoints then BNP:RefreshComboPoints() end
      if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
      if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
      if frame.UpdateDependentControls then frame:UpdateDependentControls() end
    end, 22)
    frame.comboPointsCheck = comboPoints

    local darkComboPointBorder = CreateCheck(nameplatesPage, "Dark CP Border", -466, function()
      BNP_DB.darkComboPointBorder = this:GetChecked() and true or false
      if BNP.RefreshComboPointBorderStyle then BNP:RefreshComboPointBorderStyle() end
      if BNP.RefreshComboPoints then BNP:RefreshComboPoints() end
    end, 150)
    darkComboPointBorder:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText("Dark Combo Point Border", 1, 0.82, 0)
      GameTooltip:AddLine("Replaces the gold Combo Point rim with a dark border.", 1, 1, 1, true)
      GameTooltip:AddLine("This setting is independent from Dark Nameplate Border and ShaguTweaks.", 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    darkComboPointBorder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.darkComboPointBorderCheck = darkComboPointBorder

    local comboYOffset = CreateSlider(nameplatesPage, "Combo Point Y Offset", -50, 50, 1, -466, 278, 105)
    comboYOffset:SetScript("OnValueChanged", function()
      if not BNP_DB then return end
      local value = RoundSignedInteger(this:GetValue())
      BNP_DB.comboPointsYOffset = value
      getglobal(this:GetName() .. "Text"):SetText("Combo Point Y Offset: " .. (value > 0 and "+" or "") .. value)
      if BNP.RefreshComboPoints then BNP:RefreshComboPoints() end
    end)
    frame.comboPointsYOffsetSlider = comboYOffset
  end

  -- AURAS TAB --------------------------------------------------------------
  local aurasPage = frame.pages.auras
  CreateSection(aurasPage, "Debuffs", -4)

  local icon = CreateSlider(aurasPage, "Aura Icon Size", 12, 32, 1, -78, 28, 150)
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

  local auraFontSize = CreateSlider(aurasPage, "Aura Font Size", 6, 18, 1, -124, 28, 150)
  auraFontSize:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.auraFontSize = value
    getglobal(this:GetName() .. "Text"):SetText("Aura Font Size: " .. value)
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
  end)
  frame.auraFontSizeSlider = auraFontSize

  frame.cooldownSpiralCheck = CreateCheck(aurasPage, "Cooldown Spiral", -126, function()
    BNP_DB.cooldownSpiral = this:GetChecked() and true or false
    if BNP.RefreshAuraCooldownSpirals then BNP:RefreshAuraCooldownSpirals() end
  end, 208)

  local debuffYOffset = CreateSlider(aurasPage, "Debuff Y Offset", -50, 50, 1, -78, 220, 150)
  debuffYOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.debuffYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Debuff Y Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.debuffYOffsetSlider = debuffYOffset

  local ccIcon = CreateSlider(aurasPage, "CC Icon Size", 12, 32, 1, -230, 28, 150)
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

  local ccYOffset = CreateSlider(aurasPage, "CC Y Offset", -50, 50, 1, -230, 220, 150)
  ccYOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.ccYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("CC Y Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.ccYOffsetSlider = ccYOffset

  local debuffs = CreateCheck(aurasPage, "Enable Debuffs", -30, function()
    BNP_DB.debuffs = this:GetChecked() and true or false
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.debuffsCheck = debuffs

  local debuffPositionDropdown = CreateFrame("Frame", "BNPDebuffPositionDropdown", aurasPage, "UIDropDownMenuTemplate")
  debuffPositionDropdown:SetPoint("TOPLEFT", aurasPage, "TOPLEFT", 188, -24)
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

  CreateSection(aurasPage, "Crowd Control", -156)

  local crowdControl = CreateCheck(aurasPage, "Enable Crowd Control", -182, function()
    BNP_DB.crowdControl = this:GetChecked() and true or false
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.crowdControlCheck = crowdControl

  local ccPositionDropdown = CreateFrame("Frame", "BNPCCPositionDropdown", aurasPage, "UIDropDownMenuTemplate")
  ccPositionDropdown:SetPoint("TOPLEFT", aurasPage, "TOPLEFT", 188, -176)
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

  local separateCCRow = CreateCheck(aurasPage, "Display CCs in Separate Row", -264, function()
    BNP_DB.separateCCRow = this:GetChecked() and true or false
    if BNP.RefreshAllAuraLayouts then BNP:RefreshAllAuraLayouts() end
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end, 42)
  frame.separateCCRowCheck = separateCCRow

  local showOtherCCs = CreateCheck(aurasPage, "Show CCs from Other Players", -290, function()
    BNP_DB.showOtherCCs = this:GetChecked() and true or false
    if BNP.RefreshDebuffVisibility then BNP:RefreshDebuffVisibility() end
  end, 42)
  frame.showOtherCCsCheck = showOtherCCs

  CreateSection(aurasPage, "Immunities / Important Buffs", -328)

  local pvpImmunities = CreateCheck(aurasPage, "Enable PvP Immunities", -354, function()
    BNP_DB.pvpImmunities = this:GetChecked() and true or false
    if BNP.RefreshImmunityVisibility then BNP:RefreshImmunityVisibility() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end, 22)
  frame.pvpImmunitiesCheck = pvpImmunities

  local immunityPositionDropdown = CreateFrame("Frame", "BNPImmunityPositionDropdown", aurasPage, "UIDropDownMenuTemplate")
  immunityPositionDropdown:SetPoint("TOPLEFT", aurasPage, "TOPLEFT", 188, -348)
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

  local immunityIcon = CreateSlider(aurasPage, "Immunity Icon Size", 12, 32, 1, -402, 28, 150)
  immunityIcon:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.immunityIconSize = value
    getglobal(this:GetName() .. "Text"):SetText("Immunity Icon Size: " .. value)
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.immunityIconSlider = immunityIcon

  local immunityYOffset = CreateSlider(aurasPage, "Immunity Y Offset", -50, 50, 1, -402, 220, 150)
  immunityYOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.immunityYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Immunity Y Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshAllImmunityLayouts then BNP:RefreshAllImmunityLayouts() end
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.immunityYOffsetSlider = immunityYOffset

  -- ICONS TAB --------------------------------------------------------------
  local totemsPage = frame.pages.totems

  -- Totem indicators
  CreateSection(totemsPage, "Totem Indicators", -4)

  local totemIndicators = CreateCheck(totemsPage, "Enable Totem Icons", -36, function()
    BNP_DB.totemIndicators = this:GetChecked() and true or false
    if BNP.RefreshTotemIndicators then BNP:RefreshTotemIndicators() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  frame.totemIndicatorsCheck = totemIndicators

  local totemIcon = CreateSlider(totemsPage, "Totem Icon Size", 16, 36, 1, -82)
  totemIcon:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.totemIconSize = value
    getglobal(this:GetName() .. "Text"):SetText("Totem Icon Size: " .. value)
    if BNP.RefreshTotemIndicators then BNP:RefreshTotemIndicators() end
  end)
  frame.totemIconSlider = totemIcon

  local totemNote = totemsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  totemNote:SetPoint("TOPLEFT", totemsPage, "TOPLEFT", 28, -132)
  totemNote:SetWidth(350)
  totemNote:SetJustifyH("LEFT")
  totemNote:SetText("Replaces visible shaman totem nameplates with compact icons.")

  -- Raid marks
  CreateSection(totemsPage, "Raid Marks", -176)

  local raidMarkPositionLabel = totemsPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  raidMarkPositionLabel:SetPoint("TOPLEFT", totemsPage, "TOPLEFT", 28, -202)
  raidMarkPositionLabel:SetText("Raid Mark Position")
  frame.raidMarkPositionLabel = raidMarkPositionLabel

  local raidMarkPositionDropdown = CreateFrame("Frame", "BNPRaidMarkPositionDropdown", totemsPage, "UIDropDownMenuTemplate")
  raidMarkPositionDropdown:SetPoint("TOPLEFT", totemsPage, "TOPLEFT", 10, -214)
  UIDropDownMenu_SetWidth(150, raidMarkPositionDropdown)

  local raidMarkPositionLabels = {
    top = "Top",
    left = "Left",
    right = "Right",
  }

  local function SetRaidMarkPosition(position)
    if not raidMarkPositionLabels[position] then position = "top" end
    BNP_DB.raidMarkPosition = position
    UIDropDownMenu_SetSelectedValue(raidMarkPositionDropdown, position)
    UIDropDownMenu_SetText(raidMarkPositionLabels[position], raidMarkPositionDropdown)
    if BNP.RefreshRaidMarkPositions then BNP:RefreshRaidMarkPositions() end
  end

  UIDropDownMenu_Initialize(raidMarkPositionDropdown, function()
    local positions = { "top", "left", "right" }
    local n
    for n = 1, table.getn(positions) do
      local position = positions[n]
      local info = {}
      info.text = raidMarkPositionLabels[position]
      info.value = position
      info.func = function() SetRaidMarkPosition(this.value) end
      info.checked = (BNP:GetRaidMarkPosition() == position)
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.raidMarkPositionDropdown = raidMarkPositionDropdown
  frame.SetRaidMarkPosition = SetRaidMarkPosition

  local raidMarkXOffset = CreateSlider(totemsPage, "Raid Mark X Offset: 0", -50, 50, 1, -270, 28, 150)
  raidMarkXOffset:SetScript("OnValueChanged", function()
    if not BNP_DB or frame.BNPSyncingRaidMarkControls then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.raidMarkXOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Raid Mark X Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshRaidMarkPositions then BNP:RefreshRaidMarkPositions() end
  end)
  frame.raidMarkXOffsetSlider = raidMarkXOffset

  local raidMarkYOffset = CreateSlider(totemsPage, "Raid Mark Y Offset: 0", -50, 50, 1, -270, 220, 150)
  raidMarkYOffset:SetScript("OnValueChanged", function()
    if not BNP_DB or frame.BNPSyncingRaidMarkControls then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.raidMarkYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Raid Mark Y Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshRaidMarkPositions then BNP:RefreshRaidMarkPositions() end
  end)
  frame.raidMarkYOffsetSlider = raidMarkYOffset

  -- Quest indicators
  CreateSection(totemsPage, "Quest Indicators", -334)

  local questPlateIndicators = CreateCheck(totemsPage, "Enable Quest Icons", -368, function()
    BNP_DB.questPlateIndicators = this:GetChecked() and true or false
    if BNP.SetQuestPlateRuntimeEnabled then
      BNP:SetQuestPlateRuntimeEnabled(BNP_DB.questPlateIndicators, true)
    else
      if BNP_DB.questPlateIndicators and BNP.RequestQuestPlateObjectiveUpdate then
        BNP:RequestQuestPlateObjectiveUpdate()
      end
      if BNP.RefreshQuestPlateIndicators then BNP:RefreshQuestPlateIndicators() end
    end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  frame.questPlateIndicatorsCheck = questPlateIndicators

  local questIconSize = CreateSlider(totemsPage, "Quest Icon Size", 6, 64, 1, -416, 28, 150)
  questIconSize:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.questPlateIconSize = value
    getglobal(this:GetName() .. "Text"):SetText("Quest Icon Size: " .. value)
    if BNP.RefreshQuestPlateIndicators then BNP:RefreshQuestPlateIndicators() end
  end)
  frame.questPlateIconSizeSlider = questIconSize

  local questXOffset = CreateSlider(totemsPage, "Quest Icon X Offset", -100, 100, 1, -482, 28, 150)
  questXOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.questPlateXOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Quest Icon X Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshQuestPlateIndicators then BNP:RefreshQuestPlateIndicators() end
  end)
  frame.questPlateXOffsetSlider = questXOffset

  local questYOffset = CreateSlider(totemsPage, "Quest Icon Y Offset", -100, 100, 1, -482, 220, 150)
  questYOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.questPlateYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Quest Icon Y Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshQuestPlateIndicators then BNP:RefreshQuestPlateIndicators() end
  end)
  frame.questPlateYOffsetSlider = questYOffset

  local questNote = totemsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  questNote:SetPoint("TOPLEFT", totemsPage, "TOPLEFT", 28, -526)
  questNote:SetWidth(350)
  questNote:SetJustifyH("LEFT")
  questNote:SetText("Shows remaining kill/item quest objectives beside matching mob nameplates.")
  frame.questPlateNote = questNote

  local questStatus = totemsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  questStatus:SetPoint("TOPLEFT", totemsPage, "TOPLEFT", 28, -560)
  questStatus:SetWidth(350)
  questStatus:SetJustifyH("LEFT")
  frame.questPlateStatus = questStatus


  -- CASTBAR TAB ------------------------------------------------------------
  local castbarPage = frame.pages.castbar
  CreateSection(castbarPage, "Castbar", -4)

  local castbars = CreateCheck(castbarPage, "Castbars", -42, function()
    local enabled = this:GetChecked() and true or false
    if BNP.SetCastbarsEnabled then BNP:SetCastbarsEnabled(enabled) else BNP_DB.castbars = enabled end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  frame.castbarsCheck = castbars

  local castbarTest = CreateCheck(castbarPage, "Test Castbars", -42, function()
    if BNP.SetCastbarTestMode then BNP:SetCastbarTestMode(this:GetChecked() and true or false) end
  end, 128)
  castbarTest:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Test Castbars", 1, 0.82, 0)
    GameTooltip:AddLine("Shows a looping simulated castbar on every visible nameplate.", 1, 1, 1, true)
    GameTooltip:AddLine("Use it to adjust style, height, font size and offsets live. The test mode is not saved.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  castbarTest:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.castbarTestCheck = castbarTest

  local castbarIcon = CreateCheck(castbarPage, "Spell Icon", -42, function()
    BNP_DB = BNP_DB or {}
    BNP_DB.castbarIcon = this:GetChecked() and true or false
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end, 250)
  frame.castbarIconCheck = castbarIcon

  local castbarStyleLabel = castbarPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  castbarStyleLabel:SetPoint("TOPLEFT", castbarPage, "TOPLEFT", 28, -82)
  castbarStyleLabel:SetText("Castbar Style")

  local castbarStyleDropdown = CreateFrame("Frame", "BNPCastbarStyleDropdown", castbarPage, "UIDropDownMenuTemplate")
  castbarStyleDropdown:SetPoint("TOPLEFT", castbarPage, "TOPLEFT", 10, -94)
  UIDropDownMenu_SetWidth(150, castbarStyleDropdown)

  local castbarStyleLabels = {
    modern = "Modern",
    classic = "Classic",
  }

  local castbarHeight
  local function UpdateCastbarHeightRange(style)
    if not castbarHeight then return end
    BNP_DB = BNP_DB or {}
    local minValue = style == "classic" and 8 or 4
    castbarHeight:SetMinMaxValues(minValue, 20)
    getglobal(castbarHeight:GetName() .. "Low"):SetText(tostring(minValue))

    local value = tonumber(BNP_DB.castbarHeight) or BNP:GetCastbarHeight()
    value = math.floor(value + 0.5)
    if value < minValue then
      value = minValue
      BNP_DB.castbarHeight = value
    elseif value > 20 then
      value = 20
      BNP_DB.castbarHeight = value
    end
    castbarHeight:SetValue(value)
    getglobal(castbarHeight:GetName() .. "Text"):SetText("Castbar Height: " .. value)
  end

  local function SetCastbarStyle(style)
    if not castbarStyleLabels[style] then style = "modern" end
    BNP_DB.castbarStyle = style
    UIDropDownMenu_SetSelectedValue(castbarStyleDropdown, style)
    UIDropDownMenu_SetText(castbarStyleLabels[style], castbarStyleDropdown)
    UpdateCastbarHeightRange(style)
    if BNP.RefreshCastbarStyle then BNP:RefreshCastbarStyle() elseif BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end

  UIDropDownMenu_Initialize(castbarStyleDropdown, function()
    local styles = { "modern", "classic" }
    local n
    for n = 1, table.getn(styles) do
      local style = styles[n]
      local info = {}
      info.text = castbarStyleLabels[style]
      info.value = style
      info.func = function() SetCastbarStyle(this.value) end
      info.checked = (BNP:GetCastbarStyle() == style)
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.castbarStyleLabel = castbarStyleLabel
  frame.castbarStyleDropdown = castbarStyleDropdown
  frame.SetCastbarStyle = SetCastbarStyle

  castbarHeight = CreateSlider(castbarPage, "Castbar Height", 4, 20, 1, -94, 220, 150)
  castbarHeight:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.castbarHeight = value
    getglobal(this:GetName() .. "Text"):SetText("Castbar Height: " .. value)
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() elseif BNP.RefreshCastbarHeights then BNP:RefreshCastbarHeights() end
  end)
  UpdateCastbarHeightRange(BNP:GetCastbarStyle())
  frame.castbarHeightSlider = castbarHeight
  frame.UpdateCastbarHeightRange = UpdateCastbarHeightRange

  local castbarFontSize = CreateSlider(castbarPage, "Castbar Font Size", 6, 18, 1, -166, 28, 150)
  castbarFontSize:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.castbarFontSize = value
    getglobal(this:GetName() .. "Text"):SetText("Castbar Font Size: " .. value)
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.castbarFontSizeSlider = castbarFontSize

  local castbarXOffset = CreateSlider(castbarPage, "Castbar X Offset", -50, 50, 1, -238, 28, 150)
  castbarXOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.castbarXOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Castbar X Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.castbarXOffsetSlider = castbarXOffset

  local castbarYOffset = CreateSlider(castbarPage, "Castbar Y Offset", -50, 50, 1, -238, 220, 150)
  castbarYOffset:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = RoundSignedInteger(this:GetValue())
    BNP_DB.castbarYOffset = value
    getglobal(this:GetName() .. "Text"):SetText("Castbar Y Offset: " .. (value > 0 and "+" or "") .. value)
    if BNP.RefreshCastbarLayout then BNP:RefreshCastbarLayout() end
  end)
  frame.castbarYOffsetSlider = castbarYOffset

  -- TARGET TAB -------------------------------------------------------------
  local targetPage = frame.pages.target

  -- Target highlight: glow and arrows share one color, but keep independent
  -- enable switches and sizing controls.
  CreateSection(targetPage, "Target Highlight", -4)

  local targetFocus = CreateCheck(targetPage, "Target Glow", -38, function()
    BNP_DB.targetFocus = this:GetChecked() and true or false
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  frame.targetFocusCheck = targetFocus

  local targetArrows = CreateCheck(targetPage, "Target Arrows", -38, function()
    BNP_DB.targetArrows = this:GetChecked() and true or false
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  targetArrows:ClearAllPoints()
  targetArrows:SetPoint("TOPLEFT", targetPage, "TOPLEFT", 204, -38)
  frame.targetArrowsCheck = targetArrows

  -- One shared free RGB color for glow and arrows.
  local targetColorSwatch, targetColorLabel = CreateColorSwatch(targetPage, "Glow / Arrow Color", -86, 28,
    function() return BNP:GetTargetColor() end,
    function(r, g, b) BNP:SetTargetColor(r, g, b) end,
    1.00, 1.00, 1.00,
    "Choose the shared color used by Target Glow and Target Arrows.",
    "Restores the default BNP glow / arrow color.")
  frame.targetColorSwatch = targetColorSwatch
  frame.targetColorLabel = targetColorLabel

  local glowSize = CreateSlider(targetPage, "Target Glow Size", 0, 20, 1, -150)
  glowSize:SetWidth(145)
  glowSize:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.targetGlowSize = value
    getglobal(this:GetName() .. "Text"):SetText("Target Glow Size: +" .. value .. " px")
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
  end)
  frame.targetGlowSizeSlider = glowSize

  local glowOpacity = CreateSlider(targetPage, "Target Glow Opacity", 20, 100, 5, -208)
  glowOpacity:SetWidth(145)
  glowOpacity:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.targetGlowOpacity = value / 100
    getglobal(this:GetName() .. "Text"):SetText("Target Glow Opacity: " .. value .. "%")
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
  end)
  frame.targetGlowOpacitySlider = glowOpacity

  local arrowStyleLabel = targetPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  arrowStyleLabel:SetPoint("TOPLEFT", targetPage, "TOPLEFT", 210, -88)
  arrowStyleLabel:SetText("Arrow Style")
  frame.arrowStyleLabel = arrowStyleLabel

  local arrowStyleDropdown = CreateFrame("Frame", "BNPTargetArrowStyleDropdown", targetPage, "UIDropDownMenuTemplate")
  arrowStyleDropdown:SetPoint("TOPLEFT", targetPage, "TOPLEFT", 192, -100)
  UIDropDownMenu_SetWidth(140, arrowStyleDropdown)

  local arrowStyleLabels = {
    chevron = "Chevron",
    triangle = "Triangle",
    slim_triangle = "Slim Triangle",
    double_chevron = "Double Chevron",
    diamond_tip = "Diamond Tip",
  }

  local function SetTargetArrowStyle(style)
    if not arrowStyleLabels[style] then style = "chevron" end
    BNP_DB.targetArrowStyle = style
    UIDropDownMenu_SetSelectedValue(arrowStyleDropdown, style)
    UIDropDownMenu_SetText(arrowStyleLabels[style], arrowStyleDropdown)
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
  end

  UIDropDownMenu_Initialize(arrowStyleDropdown, function()
    local styles = { "chevron", "triangle", "slim_triangle", "double_chevron", "diamond_tip" }
    local n
    for n = 1, table.getn(styles) do
      local style = styles[n]
      local info = {}
      info.text = arrowStyleLabels[style]
      info.value = style
      info.func = function() SetTargetArrowStyle(this.value) end
      info.checked = ((BNP_DB and BNP_DB.targetArrowStyle) or "chevron") == style
      UIDropDownMenu_AddButton(info)
    end
  end)
  frame.arrowStyleDropdown = arrowStyleDropdown
  frame.SetTargetArrowStyle = SetTargetArrowStyle

  local arrowSize = CreateSlider(targetPage, "Target Arrow Size", 10, 24, 1, -166)
  arrowSize:ClearAllPoints()
  arrowSize:SetPoint("TOPLEFT", targetPage, "TOPLEFT", 210, -166)
  arrowSize:SetWidth(145)
  arrowSize:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = math.floor(this:GetValue() + 0.5)
    BNP_DB.targetArrowSize = value
    getglobal(this:GetName() .. "Text"):SetText("Target Arrow Size: " .. value)
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
  end)
  frame.targetArrowSizeSlider = arrowSize

  local thickArrows = CreateCheck(targetPage, "Thick Arrows", -220, function()
    BNP_DB.targetArrowThick = this:GetChecked() and true or false
    if BNP.RefreshTargetFocus then BNP:RefreshTargetFocus() end
  end)
  thickArrows:ClearAllPoints()
  thickArrows:SetPoint("TOPLEFT", targetPage, "TOPLEFT", 204, -220)
  frame.targetArrowThickCheck = thickArrows

  local targetOnlyNameplates = CreateCheck(targetPage, "Only Show Target", -250, function()
    BNP_DB.targetOnlyNameplates = this:GetChecked() and true or false
    if BNP.RefreshTargetOnlyNameplates then BNP:RefreshTargetOnlyNameplates() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  targetOnlyNameplates:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Only Show Target", 1, 0.82, 0)
    GameTooltip:AddLine("While a target is selected, hides every other nameplate by making it fully transparent.", 1, 1, 1, true)
    GameTooltip:AddLine("With no target selected, all nameplates stay visible so you can still select one. Disabling this option immediately restores normal visibility.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  targetOnlyNameplates:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.targetOnlyNameplatesCheck = targetOnlyNameplates

  -- Target border
  CreateSection(targetPage, "Target Border", -280)

  local targetBorderColor = CreateCheck(targetPage, "Target Border Color", -314, function()
    BNP_DB.targetBorderColorEnabled = this:GetChecked() and true or false
    if BNP.RefreshTargetBorderColor then BNP:RefreshTargetBorderColor() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  frame.targetBorderColorCheck = targetBorderColor

  -- Keep the compact color box on the same row, slightly lower than the label
  -- so it visually aligns with the checkbox text.
  local targetBorderColorSwatch = CreateColorSwatch(targetPage, "", -320, 166,
    function() return BNP:GetTargetBorderColor() end,
    function(r, g, b) BNP:SetTargetBorderColor(r, g, b) end,
    1.00, 0.20, 0.20,
    "Choose the color of the native nameplate border while this unit is your target.",
    "Restores the default BNP target border color.")
  targetBorderColorSwatch:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Target Border Color", 1, 0.82, 0)
    GameTooltip:AddLine("Click the color box to choose the border color used on your current target.", 1, 1, 1, true)
    GameTooltip:AddLine("Target Glow and Target Arrows use the separate Glow / Arrow Color above.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  targetBorderColorSwatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.targetBorderColorSwatch = targetBorderColorSwatch

  local targetBorderBold = CreateCheck(targetPage, "Bold Target Border", -346, function()
    BNP_DB.targetBorderBold = this:GetChecked() and true or false
    if BNP.RefreshTargetBorderColor then BNP:RefreshTargetBorderColor() end
  end)
  targetBorderBold:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Bold Target Border", 1, 0.82, 0)
    GameTooltip:AddLine("Uses a thicker version of the same target border. No second frame is added.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  targetBorderBold:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.targetBorderBoldCheck = targetBorderBold

  -- Target scale
  CreateSection(targetPage, "Target Scale", -398)

  local targetScaleEnabled = CreateCheck(targetPage, "Enable Target Scale", -432, function()
    BNP_DB.targetScaleEnabled = this:GetChecked() and true or false
    if BNP.RefreshTargetScale then BNP:RefreshTargetScale() end
    if frame.UpdateDependentControls then frame:UpdateDependentControls() end
  end)
  frame.targetScaleEnabledCheck = targetScaleEnabled

  local targetScale = CreateSlider(targetPage, "Target Scale: 1.20x", 1.00, 1.50, 0.05, -478, 28, 220)
  targetScale:SetScript("OnValueChanged", function()
    if not BNP_DB then return end
    local value = Round(this:GetValue(), 0.05)
    if value < 1.00 then value = 1.00 end
    if value > 1.50 then value = 1.50 end
    BNP_DB.targetScale = value
    getglobal(this:GetName() .. "Text"):SetText(string.format("Target Scale: %.2fx", value))
    if BNP.RefreshTargetScale then BNP:RefreshTargetScale() end
  end)
  frame.targetScaleSlider = targetScale

  -- OTHER DEBUFFS TAB ------------------------------------------------------
  BuildOtherDebuffsOptions(frame, frame.pages.other, CreateSection)

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
    local castbarsEnabled = BNP:AreCastbarsEnabled()
    SetCheckEnabled(self.castbarTestCheck, castbarsEnabled)
    SetCheckEnabled(self.castbarIconCheck, castbarsEnabled)

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
    if self.debuffYOffsetSlider then
      self.debuffYOffsetSlider:SetAlpha(debuffsEnabled and 1.0 or 0.45)
      if self.debuffYOffsetSlider.EnableMouse then self.debuffYOffsetSlider:EnableMouse(debuffsEnabled) end
    end
    if self.ccYOffsetSlider then
      self.ccYOffsetSlider:SetAlpha(ccEnabled and 1.0 or 0.45)
      if self.ccYOffsetSlider.EnableMouse then self.ccYOffsetSlider:EnableMouse(ccEnabled) end
    end

    local comboEnabled = BNP.AreComboPointsEnabled and BNP:AreComboPointsEnabled() or false
    if self.comboPointsYOffsetSlider then
      self.comboPointsYOffsetSlider:SetAlpha(comboEnabled and 1.0 or 0.45)
      if self.comboPointsYOffsetSlider.EnableMouse then self.comboPointsYOffsetSlider:EnableMouse(comboEnabled) end
    end
    SetCheckEnabled(self.darkComboPointBorderCheck, comboEnabled)
    SetCheckEnabled(self.darkNameplateBorderCheck, not (BNP.IsNameplateBorderHidden and BNP:IsNameplateBorderHidden()))

    local invertTankEnabled = BNP:IsTankModeEnabled() and BNP:AreTankModeColorsInverted()
    local function SetTankSwatchEnabled(swatch, enabled)
      if not swatch then return end
      swatch:SetAlpha(enabled and 1.0 or 0.45)
      if swatch.EnableMouse then swatch:EnableMouse(enabled) end
      if swatch.BNPLabel then
        swatch.BNPLabel:SetTextColor(enabled and 1 or 0.5, enabled and 0.82 or 0.5, enabled and 0 or 0.5)
      end
    end
    SetTankSwatchEnabled(self.invertAggroColorSwatch, invertTankEnabled)
    SetTankSwatchEnabled(self.invertNoAggroColorSwatch, invertTankEnabled)

    local nameColorEnabled = BNP.IsCustomNameColorEnabled and BNP:IsCustomNameColorEnabled() or false
    if self.nameColorSwatch then
      self.nameColorSwatch:SetAlpha(nameColorEnabled and 1.0 or 0.45)
      if self.nameColorSwatch.EnableMouse then self.nameColorSwatch:EnableMouse(nameColorEnabled) end
      if self.nameColorSwatch.BNPLabel then
        self.nameColorSwatch.BNPLabel:SetTextColor(nameColorEnabled and 1 or 0.5, nameColorEnabled and 0.82 or 0.5, nameColorEnabled and 0 or 0.5)
      end
    end

    local immunitiesEnabled = BNP.ArePvPImmunitiesEnabled and BNP:ArePvPImmunitiesEnabled() or false
    if self.immunityIconSlider then
      self.immunityIconSlider:SetAlpha(immunitiesEnabled and 1.0 or 0.45)
      if self.immunityIconSlider.EnableMouse then self.immunityIconSlider:EnableMouse(immunitiesEnabled) end
    end
    if self.immunityYOffsetSlider then
      self.immunityYOffsetSlider:SetAlpha(immunitiesEnabled and 1.0 or 0.45)
      if self.immunityYOffsetSlider.EnableMouse then self.immunityYOffsetSlider:EnableMouse(immunitiesEnabled) end
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

    local questEnabled = BNP.AreQuestPlateIndicatorsEnabled and BNP:AreQuestPlateIndicatorsEnabled() or false
    local questSliders = { self.questPlateIconSizeSlider, self.questPlateXOffsetSlider, self.questPlateYOffsetSlider }
    local questIndex
    for questIndex = 1, table.getn(questSliders) do
      local slider = questSliders[questIndex]
      if slider then
        slider:SetAlpha(questEnabled and 1.0 or 0.45)
        if slider.EnableMouse then slider:EnableMouse(questEnabled) end
      end
    end
    if self.questPlateStatus then
      local dependency = BNP.GetQuestPlateDependencyName and BNP:GetQuestPlateDependencyName() or nil
      if dependency then
        self.questPlateStatus:SetText("Database: " .. dependency .. " detected")
        self.questPlateStatus:SetTextColor(0.35, 1.0, 0.45)
      else
        self.questPlateStatus:SetText("Database: Questie-Octo / pfQuest not detected")
        self.questPlateStatus:SetTextColor(1.0, 0.35, 0.25)
      end
    end

    local glowEnabled = BNP:IsTargetFocusEnabled()
    local arrowsEnabled = BNP.AreTargetArrowsEnabled and BNP:AreTargetArrowsEnabled() or false
    local targetColorEnabled = glowEnabled or arrowsEnabled
    if self.targetColorLabel then
      self.targetColorLabel:SetTextColor(targetColorEnabled and 1 or 0.5, targetColorEnabled and 0.82 or 0.5, targetColorEnabled and 0 or 0.5)
    end
    if self.targetColorSwatch then
      self.targetColorSwatch:SetAlpha(targetColorEnabled and 1.0 or 0.45)
      if self.targetColorSwatch.EnableMouse then self.targetColorSwatch:EnableMouse(targetColorEnabled) end
    end
    local targetBorderEnabled = BNP.IsTargetBorderColorEnabled and BNP:IsTargetBorderColorEnabled() or false
    SetCheckEnabled(self.targetBorderBoldCheck, targetBorderEnabled)
    if self.targetBorderColorSwatch then
      self.targetBorderColorSwatch:SetAlpha(targetBorderEnabled and 1.0 or 0.45)
      if self.targetBorderColorSwatch.EnableMouse then self.targetBorderColorSwatch:EnableMouse(targetBorderEnabled) end
    end
    if self.targetGlowSizeSlider then
      self.targetGlowSizeSlider:SetAlpha(glowEnabled and 1.0 or 0.45)
      if self.targetGlowSizeSlider.EnableMouse then self.targetGlowSizeSlider:EnableMouse(glowEnabled) end
    end
    if self.targetGlowOpacitySlider then
      self.targetGlowOpacitySlider:SetAlpha(glowEnabled and 1.0 or 0.45)
      if self.targetGlowOpacitySlider.EnableMouse then self.targetGlowOpacitySlider:EnableMouse(glowEnabled) end
    end
    if self.arrowStyleLabel then
      self.arrowStyleLabel:SetTextColor(arrowsEnabled and 1 or 0.5, arrowsEnabled and 0.82 or 0.5, arrowsEnabled and 0 or 0.5)
    end
    if self.arrowStyleDropdown then
      self.arrowStyleDropdown:SetAlpha(arrowsEnabled and 1.0 or 0.45)
      if arrowsEnabled then
        if UIDropDownMenu_EnableDropDown then UIDropDownMenu_EnableDropDown(self.arrowStyleDropdown) end
      else
        if UIDropDownMenu_DisableDropDown then UIDropDownMenu_DisableDropDown(self.arrowStyleDropdown) end
      end
    end
    if self.targetArrowSizeSlider then
      self.targetArrowSizeSlider:SetAlpha(arrowsEnabled and 1.0 or 0.45)
      if self.targetArrowSizeSlider.EnableMouse then self.targetArrowSizeSlider:EnableMouse(arrowsEnabled) end
    end
    SetCheckEnabled(self.targetArrowThickCheck, arrowsEnabled)

    local targetOnlyEnabled = BNP.IsTargetOnlyNameplatesEnabled and BNP:IsTargetOnlyNameplatesEnabled() or false
    if self.nonTargetAlphaSlider then
      self.nonTargetAlphaSlider:SetAlpha(targetOnlyEnabled and 0.45 or 1.0)
      if self.nonTargetAlphaSlider.EnableMouse then self.nonTargetAlphaSlider:EnableMouse(not targetOnlyEnabled) end
    end

    local targetScaleEnabled = BNP.IsTargetScaleEnabled and BNP:IsTargetScaleEnabled() or false
    if self.targetScaleSlider then
      self.targetScaleSlider:SetAlpha(targetScaleEnabled and 1.0 or 0.45)
      if self.targetScaleSlider.EnableMouse then self.targetScaleSlider:EnableMouse(targetScaleEnabled) end
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
  if frame.nameFontSizeSlider or frame.nameFontYOffsetSlider then
    frame.BNPSyncingNameControls = true
    if frame.nameFontSizeSlider then
      local value = self:GetNameFontSize()
      frame.nameFontSizeSlider:SetValue(value)
      getglobal(frame.nameFontSizeSlider:GetName() .. "Text"):SetText("Name Font Size: " .. value)
    end
    if frame.nameFontYOffsetSlider then
      local value = self:GetNameFontYOffset()
      frame.nameFontYOffsetSlider:SetValue(value)
      getglobal(frame.nameFontYOffsetSlider:GetName() .. "Text"):SetText("Name Y Offset: " .. (value > 0 and "+" or "") .. value)
    end
    frame.BNPSyncingNameControls = nil
  end
  if frame.comboPointsYOffsetSlider then
    local value = self:GetComboPointsYOffset()
    frame.comboPointsYOffsetSlider:SetValue(value)
    getglobal(frame.comboPointsYOffsetSlider:GetName() .. "Text"):SetText("Combo Point Y Offset: " .. (value > 0 and "+" or "") .. value)
  end
  if frame.debuffYOffsetSlider then
    local value = self:GetDebuffYOffset()
    frame.debuffYOffsetSlider:SetValue(value)
    getglobal(frame.debuffYOffsetSlider:GetName() .. "Text"):SetText("Debuff Y Offset: " .. (value > 0 and "+" or "") .. value)
  end
  if frame.ccYOffsetSlider then
    local value = self:GetCCYOffset()
    frame.ccYOffsetSlider:SetValue(value)
    getglobal(frame.ccYOffsetSlider:GetName() .. "Text"):SetText("CC Y Offset: " .. (value > 0 and "+" or "") .. value)
  end
  if frame.immunityYOffsetSlider then
    local value = self:GetImmunityYOffset()
    frame.immunityYOffsetSlider:SetValue(value)
    getglobal(frame.immunityYOffsetSlider:GetName() .. "Text"):SetText("Immunity Y Offset: " .. (value > 0 and "+" or "") .. value)
  end
  if frame.nonTargetAlphaSlider then
    local alphaPercent = math.floor((self:GetNonTargetAlpha() * 100) + 0.5)
    frame.nonTargetAlphaSlider:SetValue(alphaPercent)
    getglobal(frame.nonTargetAlphaSlider:GetName() .. "Text"):SetText("Non-Target Alpha: " .. alphaPercent .. "%")
  end
  frame.iconSlider:SetValue(self:GetIconSize())
  if frame.auraFontSizeSlider then
    local auraFontSize = self:GetAuraFontSize()
    frame.auraFontSizeSlider:SetValue(auraFontSize)
    getglobal(frame.auraFontSizeSlider:GetName() .. "Text"):SetText("Aura Font Size: " .. auraFontSize)
  end
  if frame.cooldownSpiralCheck then frame.cooldownSpiralCheck:SetChecked(self:IsAuraCooldownSpiralEnabled()) end
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
  local castbarStyle = self:GetCastbarStyle()
  if frame.UpdateCastbarHeightRange then frame.UpdateCastbarHeightRange(castbarStyle) end
  frame.castbarHeightSlider:SetValue(self:GetCastbarHeight())
  if frame.castbarIconCheck then frame.castbarIconCheck:SetChecked(self:IsCastbarIconEnabled()) end
  if frame.castbarStyleDropdown then
    local labels = { modern = "Modern", classic = "Classic" }
    UIDropDownMenu_SetSelectedValue(frame.castbarStyleDropdown, castbarStyle)
    UIDropDownMenu_SetText(labels[castbarStyle] or "Modern", frame.castbarStyleDropdown)
  end
  if frame.castbarFontSizeSlider then
    local size = self:GetCastbarFontSize()
    frame.castbarFontSizeSlider:SetValue(size)
    getglobal(frame.castbarFontSizeSlider:GetName() .. "Text"):SetText("Castbar Font Size: " .. size)
  end
  if frame.castbarXOffsetSlider then
    local offset = self:GetCastbarXOffset()
    frame.castbarXOffsetSlider:SetValue(offset)
    getglobal(frame.castbarXOffsetSlider:GetName() .. "Text"):SetText("Castbar X Offset: " .. (offset > 0 and "+" or "") .. offset)
  end
  if frame.castbarYOffsetSlider then
    local offset = self:GetCastbarYOffset()
    frame.castbarYOffsetSlider:SetValue(offset)
    getglobal(frame.castbarYOffsetSlider:GetName() .. "Text"):SetText("Castbar Y Offset: " .. (offset > 0 and "+" or "") .. offset)
  end
  frame.classColorsCheck:SetChecked(self:AreClassColorsEnabled())
  if frame.darkNameplateBorderCheck then
    frame.darkNameplateBorderCheck:SetChecked(self:IsDarkNameplateBorderEnabled())
  end
  if frame.hideNameplateBorderCheck then
    frame.hideNameplateBorderCheck:SetChecked(self:IsNameplateBorderHidden())
  end
  if frame.hideNameplateLevelCheck then
    frame.hideNameplateLevelCheck:SetChecked(self:IsNameplateLevelHidden())
  end
  if frame.blackHealthbarBackgroundCheck then
    frame.blackHealthbarBackgroundCheck:SetChecked(self:IsBlackHealthbarBackgroundEnabled())
  end
  if frame.hidePlayerNamesCheck then frame.hidePlayerNamesCheck:SetChecked(self:HidePlayerNamesEnabled()) end
  if frame.hideNPCNamesCheck then frame.hideNPCNamesCheck:SetChecked(self:HideNPCNamesEnabled()) end
  if frame.customNameColorCheck then frame.customNameColorCheck:SetChecked(self:IsCustomNameColorEnabled()) end
  if frame.nameColorSwatch and frame.nameColorSwatch.RefreshColor then frame.nameColorSwatch:RefreshColor() end
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
  if frame.otherDebuffsEnabledCheck then frame.otherDebuffsEnabledCheck:SetChecked(self:AreOtherDebuffsEnabled()) end
  if frame.RefreshOtherDebuffPage then frame:RefreshOtherDebuffPage() end
  if frame.pvpImmunitiesCheck then frame.pvpImmunitiesCheck:SetChecked(self:ArePvPImmunitiesEnabled()) end
  if frame.immunityPositionDropdown then
    local position = self:GetImmunityPosition()
    local labels = { top = "Top", left = "Left", right = "Right" }
    UIDropDownMenu_SetSelectedValue(frame.immunityPositionDropdown, position)
    UIDropDownMenu_SetText(labels[position] or "Top", frame.immunityPositionDropdown)
  end
  if frame.totemIndicatorsCheck then frame.totemIndicatorsCheck:SetChecked(self:AreTotemIndicatorsEnabled()) end
  if frame.questPlateIndicatorsCheck then
    frame.questPlateIndicatorsCheck:SetChecked(self.AreQuestPlateIndicatorsEnabled and self:AreQuestPlateIndicatorsEnabled() or false)
  end
  if frame.questPlateIconSizeSlider then
    local size = self.GetQuestPlateIconSize and self:GetQuestPlateIconSize() or 16
    frame.questPlateIconSizeSlider:SetValue(size)
    getglobal(frame.questPlateIconSizeSlider:GetName() .. "Text"):SetText("Quest Icon Size: " .. size)
  end
  if frame.questPlateXOffsetSlider then
    local value = self.GetQuestPlateXOffset and self:GetQuestPlateXOffset() or 10
    frame.questPlateXOffsetSlider:SetValue(value)
    getglobal(frame.questPlateXOffsetSlider:GetName() .. "Text"):SetText("Quest Icon X Offset: " .. (value > 0 and "+" or "") .. value)
  end
  if frame.questPlateYOffsetSlider then
    local value = self.GetQuestPlateYOffset and self:GetQuestPlateYOffset() or -7
    frame.questPlateYOffsetSlider:SetValue(value)
    getglobal(frame.questPlateYOffsetSlider:GetName() .. "Text"):SetText("Quest Icon Y Offset: " .. (value > 0 and "+" or "") .. value)
  end
  frame.castbarsCheck:SetChecked(self:AreCastbarsEnabled())
  if frame.castbarTestCheck then
    frame.castbarTestCheck:SetChecked(self.IsCastbarTestMode and self:IsCastbarTestMode() or false)
  end
  frame.tankCheck:SetChecked(self:IsTankModeEnabled())
  if frame.invertTankColorsCheck then frame.invertTankColorsCheck:SetChecked(self:AreTankModeColorsInverted()) end
  if frame.invertAggroColorSwatch and frame.invertAggroColorSwatch.RefreshColor then frame.invertAggroColorSwatch:RefreshColor() end
  if frame.invertNoAggroColorSwatch and frame.invertNoAggroColorSwatch.RefreshColor then frame.invertNoAggroColorSwatch:RefreshColor() end
  if frame.comboPointsCheck and comboOptionsClass then
    frame.comboPointsCheck:SetChecked(self:AreComboPointsEnabled())
  end
  if frame.darkComboPointBorderCheck and comboOptionsClass then
    frame.darkComboPointBorderCheck:SetChecked(self:IsDarkComboPointBorderEnabled())
  end
  if frame.healthTextDropdown then
    local mode = self:GetHealthTextMode()
    UIDropDownMenu_SetSelectedValue(frame.healthTextDropdown, mode)
    local labels = { off = "Off", percent = "Percent", hp = "HP", both = "HP + Percent" }
    UIDropDownMenu_SetText(labels[mode] or "Off", frame.healthTextDropdown)
  end
  if frame.healthTextFontSizeSlider then
    frame.BNPSyncingHealthTextControls = true
    local size = self:GetHealthTextFontSize()
    frame.healthTextFontSizeSlider:SetValue(size)
    getglobal(frame.healthTextFontSizeSlider:GetName() .. "Text"):SetText("Health Font Size: " .. size)
    frame.BNPSyncingHealthTextControls = nil
  end
  if frame.healthTextOutlineDropdown then
    local outline = self:GetHealthTextOutline()
    local labels = { none = "None", outline = "Outline", thick = "Thick Outline" }
    UIDropDownMenu_SetSelectedValue(frame.healthTextOutlineDropdown, outline)
    UIDropDownMenu_SetText(labels[outline] or "Outline", frame.healthTextOutlineDropdown)
  end
  frame.targetFocusCheck:SetChecked(self:IsTargetFocusEnabled())
  if frame.targetOnlyNameplatesCheck then
    frame.targetOnlyNameplatesCheck:SetChecked(self.IsTargetOnlyNameplatesEnabled and self:IsTargetOnlyNameplatesEnabled() or false)
  end
  if frame.targetBorderColorCheck then
    frame.targetBorderColorCheck:SetChecked(self.IsTargetBorderColorEnabled and self:IsTargetBorderColorEnabled() or false)
  end
  if frame.targetBorderBoldCheck then
    frame.targetBorderBoldCheck:SetChecked(self.IsTargetBorderBoldEnabled and self:IsTargetBorderBoldEnabled() or false)
  end
  if frame.targetBorderColorSwatch and frame.targetBorderColorSwatch.RefreshColor then
    frame.targetBorderColorSwatch:RefreshColor()
  end
  if frame.targetScaleEnabledCheck then
    frame.targetScaleEnabledCheck:SetChecked(self.IsTargetScaleEnabled and self:IsTargetScaleEnabled() or false)
  end
  if frame.targetScaleSlider then
    local targetScale = self.GetTargetScale and self:GetTargetScale() or 1.20
    frame.targetScaleSlider:SetValue(targetScale)
    getglobal(frame.targetScaleSlider:GetName() .. "Text"):SetText(string.format("Target Scale: %.2fx", targetScale))
  end
  if frame.raidMarkPositionDropdown then
    local position = self.GetRaidMarkPosition and self:GetRaidMarkPosition() or "top"
    local labels = { top = "Top", left = "Left", right = "Right" }
    UIDropDownMenu_SetSelectedValue(frame.raidMarkPositionDropdown, position)
    UIDropDownMenu_SetText(labels[position] or "Top", frame.raidMarkPositionDropdown)
  end
  if frame.raidMarkXOffsetSlider or frame.raidMarkYOffsetSlider then
    frame.BNPSyncingRaidMarkControls = true
    if frame.raidMarkXOffsetSlider then
      local value = self.GetRaidMarkXOffset and self:GetRaidMarkXOffset() or 0
      frame.raidMarkXOffsetSlider:SetValue(value)
      getglobal(frame.raidMarkXOffsetSlider:GetName() .. "Text"):SetText("Raid Mark X Offset: " .. (value > 0 and "+" or "") .. value)
    end
    if frame.raidMarkYOffsetSlider then
      local value = self.GetRaidMarkYOffset and self:GetRaidMarkYOffset() or 0
      frame.raidMarkYOffsetSlider:SetValue(value)
      getglobal(frame.raidMarkYOffsetSlider:GetName() .. "Text"):SetText("Raid Mark Y Offset: " .. (value > 0 and "+" or "") .. value)
    end
    frame.BNPSyncingRaidMarkControls = nil
  end
  if frame.targetArrowsCheck then
    frame.targetArrowsCheck:SetChecked(self.AreTargetArrowsEnabled and self:AreTargetArrowsEnabled() or false)
  end
  if frame.targetColorSwatch and frame.targetColorSwatch.RefreshColor then
    frame.targetColorSwatch:RefreshColor()
  end
  if frame.arrowStyleDropdown then
    local style = self:GetTargetArrowStyle()
    local labels = {
      chevron = "Chevron",
      triangle = "Triangle",
      slim_triangle = "Slim Triangle",
      double_chevron = "Double Chevron",
      diamond_tip = "Diamond Tip",
    }
    UIDropDownMenu_SetSelectedValue(frame.arrowStyleDropdown, style)
    UIDropDownMenu_SetText(labels[style] or "Chevron", frame.arrowStyleDropdown)
  end
  if frame.targetArrowSizeSlider then
    local arrowSize = self:GetTargetArrowSize()
    frame.targetArrowSizeSlider:SetValue(arrowSize)
    getglobal(frame.targetArrowSizeSlider:GetName() .. "Text"):SetText("Target Arrow Size: " .. arrowSize)
  end
  if frame.targetArrowThickCheck then
    frame.targetArrowThickCheck:SetChecked(self.AreTargetArrowsThick and self:AreTargetArrowsThick() or false)
  end

  if frame.targetGlowSizeSlider then
    local glowSize = self:GetTargetGlowSize()
    frame.targetGlowSizeSlider:SetValue(glowSize)
    getglobal(frame.targetGlowSizeSlider:GetName() .. "Text"):SetText("Target Glow Size: +" .. glowSize .. " px")
  end
  if frame.targetGlowOpacitySlider then
    local opacityPercent = math.floor((self:GetTargetGlowOpacity() * 100) + 0.5)
    frame.targetGlowOpacitySlider:SetValue(opacityPercent)
    getglobal(frame.targetGlowOpacitySlider:GetName() .. "Text"):SetText("Target Glow Opacity: " .. opacityPercent .. "%")
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
