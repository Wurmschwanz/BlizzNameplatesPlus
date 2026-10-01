BNP = BNP or {}

-- Personal Nameplate -------------------------------------------------------
-- A lightweight player resource display that visually follows BNP's classic
-- nameplate styling. It is screen-space UI (not a projected world nameplate),
-- so it stays stable beneath the player and does not interfere with Blizzard's
-- nameplate discovery/click handling.

local FRAME_WIDTH = 128
local FRAME_HEIGHT = 45
local HEALTH_WIDTH = 104
local HEALTH_HEIGHT = 9
local POWER_WIDTH = 104
local POWER_HEIGHT = 5
local PERSONAL_DEBUFF_MAX_DURATION = 60
local PERSONAL_DEBUFF_MAX_ICONS = 6
local PERSONAL_DEBUFF_SPACING = 1
-- Match BNP health text anchoring: healthbar CENTER +3px. The personal frame
-- is wider than the healthbar because of the level medallion, so centering
-- debuffs on the whole frame makes the row look shifted to the right.
local PERSONAL_HEALTH_TEXT_X = 3
local PERSONAL_HEALTH_TEXT_Y = 1
local PERSONAL_POWER_TEXT_Y = 1
local PERSONAL_CONTENT_CENTER_X = (5 + HEALTH_WIDTH / 2 + PERSONAL_HEALTH_TEXT_X) - (FRAME_WIDTH / 2)
local STATUS_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local BORDER_TEXTURE = "Interface\\AddOns\\BlizzNameplatesPlus\\media\\classic_nameplate_border"
local FONT = "Fonts\\FRIZQT__.TTF"

local classFallback = {
  WARRIOR = { 0.78, 0.61, 0.43 },
  MAGE = { 0.41, 0.80, 0.94 },
  ROGUE = { 1.00, 0.96, 0.41 },
  DRUID = { 1.00, 0.49, 0.04 },
  HUNTER = { 0.67, 0.83, 0.45 },
  SHAMAN = { 0.00, 0.44, 0.87 },
  PRIEST = { 1.00, 1.00, 1.00 },
  WARLOCK = { 0.58, 0.51, 0.79 },
  PALADIN = { 0.96, 0.55, 0.73 },
}

local powerColors = {
  [0] = { 0.00, 0.45, 1.00 }, -- Mana
  [1] = { 1.00, 0.12, 0.12 }, -- Rage
  [2] = { 1.00, 0.50, 0.25 }, -- Focus (custom clients/classes)
  [3] = { 1.00, 0.85, 0.10 }, -- Energy
  [4] = { 0.00, 0.70, 1.00 }, -- Happiness / fallback legacy resource
}

local personalFrame
local inCombat = false
local updateElapsed = 0
local debuffScanElapsed = 0

local function FormatValue(value)
  value = tonumber(value) or 0
  if value < 0 then value = 0 end
  if value >= 1000000 then
    local shown = math.floor((value / 1000000) * 10 + 0.5) / 10
    return tostring(shown) .. "m"
  elseif value >= 10000 then
    return tostring(math.floor(value / 1000 + 0.5)) .. "k"
  end
  return tostring(math.floor(value + 0.5))
end

local function CreateSolidTexture(parent, layer)
  local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
  texture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
  return texture
end

local function SetThinBorderColor(frame, r, g, b, a)
  if not frame then return end
  local edges = frame.BNPEdges
  if not edges then return end
  local i
  for i = 1, table.getn(edges) do
    edges[i]:SetVertexColor(r, g, b, a or 1)
  end
end

local function CreateThinBorder(parent)
  local edges = {}
  local top = CreateSolidTexture(parent, "OVERLAY")
  top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  top:SetHeight(1)
  table.insert(edges, top)

  local bottom = CreateSolidTexture(parent, "OVERLAY")
  bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(1)
  table.insert(edges, bottom)

  local left = CreateSolidTexture(parent, "OVERLAY")
  left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
  left:SetWidth(1)
  table.insert(edges, left)

  local right = CreateSolidTexture(parent, "OVERLAY")
  right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(1)
  table.insert(edges, right)

  parent.BNPEdges = edges
end

local function CreatePersonalFrame()
  if personalFrame then return personalFrame end

  local frame = CreateFrame("Frame", "BNPPersonalNameplate", UIParent)
  frame:SetWidth(FRAME_WIDTH)
  frame:SetHeight(FRAME_HEIGHT)
  frame:SetFrameStrata("MEDIUM")
  frame:SetFrameLevel(8)
  frame:EnableMouse(false)
  frame:Hide()

  -- Main health bar, sized to sit inside BNP's classic nameplate border art.
  local health = CreateFrame("StatusBar", nil, frame)
  health:SetWidth(HEALTH_WIDTH)
  health:SetHeight(HEALTH_HEIGHT)
  health:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -19)
  health:SetStatusBarTexture(STATUS_TEXTURE)
  health:SetMinMaxValues(0, 1)
  health:SetValue(1)
  frame.healthbar = health

  local healthBG = CreateSolidTexture(health, "BACKGROUND")
  healthBG:SetAllPoints(health)
  healthBG:SetVertexColor(0, 0, 0, 1)
  frame.healthBG = healthBG

  -- Put border art on a tiny higher-level overlay frame. Child StatusBars can
  -- otherwise render above parent textures on old clients and eat the rim.
  local overlay = CreateFrame("Frame", nil, frame)
  overlay:SetAllPoints(frame)
  overlay:SetFrameLevel(frame:GetFrameLevel() + 4)
  overlay:EnableMouse(false)
  frame.overlay = overlay

  local border = overlay:CreateTexture(nil, "ARTWORK")
  border:SetTexture(BORDER_TEXTURE)
  border:SetWidth(128)
  border:SetHeight(32)
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.border = border

  local healthText = health:CreateFontString(nil, "OVERLAY")
  healthText:SetFont(FONT, 8, "OUTLINE")
  healthText:SetPoint("CENTER", health, "CENTER", PERSONAL_HEALTH_TEXT_X, PERSONAL_HEALTH_TEXT_Y)
  healthText:SetTextColor(1, 1, 1)
  frame.healthText = healthText

  -- BNP's classic border contains the small round level medallion at the right.
  local levelText = overlay:CreateFontString(nil, "OVERLAY")
  levelText:SetFont(FONT, 8, "OUTLINE")
  levelText:SetPoint("CENTER", frame, "TOPLEFT", 115, -24)
  levelText:SetTextColor(1, 0.82, 0)
  frame.levelText = levelText

  -- Slim power bar below the health nameplate. The 1px rim uses the same
  -- gold/dark language as BNP's border while keeping the resource bar compact.
  local powerHolder = CreateFrame("Frame", nil, frame)
  powerHolder:SetWidth(108)
  powerHolder:SetHeight(9)
  powerHolder:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -34)
  CreateThinBorder(powerHolder)
  frame.powerHolder = powerHolder

  local powerBG = CreateSolidTexture(powerHolder, "BACKGROUND")
  powerBG:SetPoint("TOPLEFT", powerHolder, "TOPLEFT", 1, -1)
  powerBG:SetPoint("BOTTOMRIGHT", powerHolder, "BOTTOMRIGHT", -1, 1)
  powerBG:SetVertexColor(0, 0, 0, 0.78)
  frame.powerBG = powerBG

  local power = CreateFrame("StatusBar", nil, powerHolder)
  power:SetWidth(POWER_WIDTH)
  power:SetHeight(POWER_HEIGHT)
  power:SetPoint("CENTER", powerHolder, "CENTER", 0, 0)
  power:SetStatusBarTexture(STATUS_TEXTURE)
  power:SetMinMaxValues(0, 1)
  power:SetValue(1)
  frame.powerbar = power

  local powerText = power:CreateFontString(nil, "OVERLAY")
  powerText:SetFont(FONT, 7, "OUTLINE")
  powerText:SetPoint("CENTER", power, "CENTER", 0, PERSONAL_POWER_TEXT_Y)
  powerText:SetTextColor(1, 1, 1)
  frame.powerText = powerText

  -- Short player debuffs sit centered above the personal plate. They use the
  -- same compact icon + countdown language as BNP's normal aura row.
  local debuffHolder = CreateFrame("Frame", nil, frame)
  debuffHolder:SetWidth(FRAME_WIDTH)
  debuffHolder:SetHeight(22)
  debuffHolder:SetPoint("BOTTOM", frame, "TOP", PERSONAL_CONTENT_CENTER_X, 1)
  debuffHolder:SetFrameLevel(frame:GetFrameLevel() + 6)
  debuffHolder:EnableMouse(false)
  debuffHolder.icons = {}
  frame.debuffHolder = debuffHolder

  local i
  for i = 1, PERSONAL_DEBUFF_MAX_ICONS do
    local icon = CreateFrame("Frame", nil, debuffHolder)
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetFrameLevel(debuffHolder:GetFrameLevel())
    icon:EnableMouse(false)

    local iconBG = CreateSolidTexture(icon, "BACKGROUND")
    iconBG:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    iconBG:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    iconBG:SetVertexColor(0, 0, 0, 0.95)

    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(icon)
    icon.texture = texture

    local timer = icon:CreateFontString(nil, "OVERLAY")
    timer:SetFont(FONT, 8, "OUTLINE")
    timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
    timer:SetTextColor(1, 1, 1)
    icon.timer = timer

    local stack = icon:CreateFontString(nil, "OVERLAY")
    stack:SetFont(FONT, 7, "OUTLINE")
    stack:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    stack:SetTextColor(1, 1, 1)
    stack:SetText("")
    icon.stack = stack

    icon:Hide()
    debuffHolder.icons[i] = icon
  end
  debuffHolder:Hide()

  personalFrame = frame
  BNP.personalNameplateFrame = frame
  return frame
end

local function GetPlayerHealthColor()
  if BNP.IsPersonalNameplateClassColorEnabled and BNP:IsPersonalNameplateClassColorEnabled() then
    local _, class = UnitClass("player")
    if RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class] then
      local c = RAID_CLASS_COLORS[class]
      return c.r, c.g, c.b
    end
    local c = class and classFallback[class]
    if c then return c[1], c[2], c[3] end
  end
  return 0.10, 0.95, 0.10
end

local function UpdateStyle(frame)
  if not frame then return end

  local dark = BNP.IsDarkNameplateBorderEnabled and BNP:IsDarkNameplateBorderEnabled()
  local hidden = BNP.IsNameplateBorderHidden and BNP:IsNameplateBorderHidden()
  local blackBG = BNP.IsBlackHealthbarBackgroundEnabled and BNP:IsBlackHealthbarBackgroundEnabled()

  if hidden then
    frame.border:Hide()
  else
    frame.border:Show()
    if dark then
      frame.border:SetVertexColor(0.38, 0.38, 0.38, 1)
    else
      frame.border:SetVertexColor(1, 1, 1, 1)
    end
  end

  local edge = dark and 0.32 or 0.78
  local edgeG = dark and 0.32 or 0.60
  local edgeB = dark and 0.32 or 0.08
  SetThinBorderColor(frame.powerHolder, edge, edgeG, edgeB, hidden and 0 or 1)

  if blackBG then
    frame.healthBG:SetVertexColor(0, 0, 0, 1)
  else
    frame.healthBG:SetVertexColor(0, 0, 0, 1)
  end

  if hidden then frame.levelText:Hide() else frame.levelText:Show() end

  local hr, hg, hb = GetPlayerHealthColor()
  frame.healthbar:SetStatusBarColor(hr, hg, hb)
end

local function UpdatePosition(frame)
  if not frame then return end
  local scale = BNP.GetPersonalNameplateScale and BNP:GetPersonalNameplateScale() or 1.0
  local y = BNP.GetPersonalNameplateYOffset and BNP:GetPersonalNameplateYOffset() or -90

  frame:SetScale(scale)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, y)

  if frame.debuffHolder then
    local debuffY = BNP.GetPersonalNameplateDebuffYOffset and BNP:GetPersonalNameplateDebuffYOffset() or 0
    frame.debuffHolder:ClearAllPoints()
    frame.debuffHolder:SetPoint("BOTTOM", frame, "TOP", PERSONAL_CONTENT_CENTER_X, 1 + debuffY)
  end
end

local function GetPersonalDebuffIconSize()
  local size = BNP.GetIconSize and tonumber(BNP:GetIconSize()) or 18
  if not size then size = 18 end
  if size < 12 then size = 12 end
  if size > 20 then size = 20 end
  return size
end

local function FormatDebuffTimer(remaining)
  remaining = tonumber(remaining)
  if not remaining or remaining <= 0 then return "" end
  if remaining >= 10 then return tostring(math.ceil(remaining)) end
  return string.format("%.1f", remaining)
end

local function ReadPlayerDebuff(index)
  if type(C_UnitAuras) == "table" and type(C_UnitAuras.GetDebuffDataByIndex) == "function" then
    local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, "player", index)
    if not ok or not aura then return nil end
    return aura.icon, aura.applications or aura.count or 0, aura.duration, aura.expirationTime, aura.name, aura.spellId or aura.spellID
  end

  if type(C_UnitAuras) == "table" and type(C_UnitAuras.UnitDebuff) == "function" then
    local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellID = C_UnitAuras.UnitDebuff("player", index)
    if not name then return nil end
    return icon, count or 0, duration, expirationTime, name, spellID
  end

  -- Legacy UnitDebuff on pure 1.12 usually has no reliable duration. Read it
  -- only when duration/expiration are supplied by the custom client; otherwise
  -- skip it rather than accidentally showing multi-minute effects.
  if UnitDebuff then
    local texture, count, dispelType, spellID, duration, expirationTime = UnitDebuff("player", index)
    if not texture then return nil end
    return texture, count or 0, duration, expirationTime, nil, spellID
  end
  return nil
end

local function HidePersonalDebuffs(frame)
  if not frame or not frame.debuffHolder then return end
  local i
  for i = 1, table.getn(frame.debuffHolder.icons or {}) do
    local icon = frame.debuffHolder.icons[i]
    icon.timer:SetText("")
    icon.stack:SetText("")
    icon:Hide()
  end
  frame.debuffHolder:Hide()
end

local function UpdatePersonalDebuffs(frame, forceScan)
  if not frame or not frame.debuffHolder then return end
  if not (BNP.IsPersonalNameplateDebuffsEnabled and BNP:IsPersonalNameplateDebuffsEnabled()) then
    frame.BNPPersonalDebuffEntries = nil
    HidePersonalDebuffs(frame)
    return
  end

  local now = GetTime()
  local entries = frame.BNPPersonalDebuffEntries
  if forceScan or not entries then
    entries = {}
    local index
    for index = 1, 64 do
      local texture, count, duration, expirationTime, name, spellID = ReadPlayerDebuff(index)
      if not texture then break end

      duration = tonumber(duration) or 0
      expirationTime = tonumber(expirationTime) or 0
      if duration > 0 and duration <= PERSONAL_DEBUFF_MAX_DURATION and expirationTime > now then
        table.insert(entries, {
          texture = texture,
          count = tonumber(count) or 0,
          duration = duration,
          expirationTime = expirationTime,
          name = name,
          spellID = spellID,
        })
        if table.getn(entries) >= PERSONAL_DEBUFF_MAX_ICONS then break end
      end
    end
    frame.BNPPersonalDebuffEntries = entries
  end

  local visible = 0
  local i
  for i = 1, table.getn(entries) do
    if entries[i].expirationTime and entries[i].expirationTime > now then
      visible = visible + 1
    end
  end

  if visible < 1 then
    HidePersonalDebuffs(frame)
    return
  end

  local size = GetPersonalDebuffIconSize()
  local totalWidth = visible * size + (visible - 1) * PERSONAL_DEBUFF_SPACING
  local startX = -totalWidth / 2
  local displayIndex = 0
  for i = 1, table.getn(entries) do
    local entry = entries[i]
    if entry.expirationTime and entry.expirationTime > now then
      displayIndex = displayIndex + 1
      local icon = frame.debuffHolder.icons[displayIndex]
      if icon then
        if icon.BNPLastSize ~= size then
          icon:SetWidth(size)
          icon:SetHeight(size)
          icon.timer:SetFont(FONT, math.max(7, math.floor(size * 0.44 + 0.5)), "OUTLINE")
          icon.stack:SetFont(FONT, math.max(6, math.floor(size * 0.38 + 0.5)), "OUTLINE")
          icon.BNPLastSize = size
        end
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", frame.debuffHolder, "CENTER", startX + (displayIndex - 1) * (size + PERSONAL_DEBUFF_SPACING), 0)
        if icon.BNPLastTexture ~= entry.texture then
          icon.texture:SetTexture(entry.texture)
          icon.BNPLastTexture = entry.texture
        end
        icon.timer:SetText(FormatDebuffTimer(entry.expirationTime - now))
        icon.stack:SetText(entry.count > 1 and tostring(entry.count) or "")
        icon:Show()
      end
    end
  end

  for i = displayIndex + 1, table.getn(frame.debuffHolder.icons) do
    local icon = frame.debuffHolder.icons[i]
    icon.timer:SetText("")
    icon.stack:SetText("")
    icon:Hide()
  end
  frame.debuffHolder:Show()
end

local function UpdateValues(frame)
  if not frame then return end

  local health = tonumber(UnitHealth("player")) or 0
  local maxHealth = tonumber(UnitHealthMax("player")) or 0
  if maxHealth < 1 then maxHealth = 1 end
  if health < 0 then health = 0 end
  if health > maxHealth then health = maxHealth end
  frame.healthbar:SetMinMaxValues(0, maxHealth)
  frame.healthbar:SetValue(health)

  -- Personal Health Text mirrors BNP's regular nameplate display modes, but
  -- remains independently configurable so the player HUD does not have to
  -- match enemy nameplates.
  local healthMode = BNP.GetPersonalNameplateHealthTextMode and BNP:GetPersonalNameplateHealthTextMode() or "both"
  local healthDisplay = nil
  if healthMode == "percent" then
    local pct = math.floor((health / maxHealth) * 100 + 0.5)
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    healthDisplay = tostring(pct) .. "%"
  elseif healthMode == "hp" then
    healthDisplay = FormatValue(health)
  elseif healthMode == "both" then
    local pct = math.floor((health / maxHealth) * 100 + 0.5)
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    healthDisplay = FormatValue(health) .. " | " .. tostring(pct) .. "%"
  end

  if healthDisplay then
    frame.healthText:SetText(healthDisplay)
    frame.healthText:Show()
  else
    frame.healthText:SetText("")
    frame.healthText:Hide()
  end

  local power = tonumber(UnitMana("player")) or 0
  local maxPower = tonumber(UnitManaMax("player")) or 0
  if maxPower < 1 then maxPower = 1 end
  if power < 0 then power = 0 end
  if power > maxPower then power = maxPower end
  frame.powerbar:SetMinMaxValues(0, maxPower)
  frame.powerbar:SetValue(power)
  frame.powerText:SetText(FormatValue(power) .. " / " .. FormatValue(maxPower))

  local powerType = 0
  if UnitManaType then powerType = tonumber(UnitManaType("player")) or 0 end
  local c = powerColors[powerType] or powerColors[0]
  frame.powerbar:SetStatusBarColor(c[1], c[2], c[3])

  local level = UnitLevel and UnitLevel("player") or nil
  if level and level > 0 then frame.levelText:SetText(tostring(level)) else frame.levelText:SetText("") end
end

local function OptionsPreviewActive()
  return BNP.optionsFrame and BNP.optionsFrame.IsShown and BNP.optionsFrame:IsShown()
end

local function ShouldShow()
  if not (BNP.IsPersonalNameplateEnabled and BNP:IsPersonalNameplateEnabled()) then
    return false
  end

  if not (BNP.IsPersonalNameplateCombatOnly and BNP:IsPersonalNameplateCombatOnly()) then
    return true
  end

  -- Keep it visible while the options window is open so Scale/Y Offset can be
  -- adjusted outside combat without needing a training dummy.
  return inCombat or OptionsPreviewActive()
end

local events = CreateFrame("Frame")
local updater = CreateFrame("Frame")
local runtimeEnabled = false
local RuntimeOnUpdate

local runtimeEvents = {
  "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "UNIT_HEALTH",
  "UNIT_MANA",
  "UNIT_AURA",
  "PLAYER_LEVEL_UP",
}

local function SetRuntimeEnabled(enabled)
  enabled = enabled and true or false
  if enabled == runtimeEnabled then return end
  runtimeEnabled = enabled

  local i
  if enabled then
    for i = 1, table.getn(runtimeEvents) do
      events:RegisterEvent(runtimeEvents[i])
    end
    updater:SetScript("OnUpdate", RuntimeOnUpdate)
  else
    for i = 1, table.getn(runtimeEvents) do
      events:UnregisterEvent(runtimeEvents[i])
    end
    updater:SetScript("OnUpdate", nil)
    updateElapsed = 0
    debuffScanElapsed = 0
    if personalFrame then personalFrame:Hide() end
  end
end

local function Refresh()
  local enabled = BNP.IsPersonalNameplateEnabled and BNP:IsPersonalNameplateEnabled()
  if not enabled then
    SetRuntimeEnabled(false)
    if personalFrame then personalFrame:Hide() end
    return
  end

  SetRuntimeEnabled(true)

  local frame = CreatePersonalFrame()
  UpdatePosition(frame)
  UpdateStyle(frame)
  UpdateValues(frame)

  if ShouldShow() then
    frame:Show()
    UpdatePersonalDebuffs(frame, true)
  else
    frame:Hide()
  end
end

function BNP:RefreshPersonalNameplate()
  Refresh()
end

function BNP:RefreshPersonalNameplateStyle()
  if not (BNP.IsPersonalNameplateEnabled and BNP:IsPersonalNameplateEnabled()) then return end
  if not personalFrame then return end
  UpdateStyle(personalFrame)
  UpdateValues(personalFrame)
  if personalFrame:IsShown() then UpdatePersonalDebuffs(personalFrame, true) end
end

events:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    events:UnregisterEvent("VARIABLES_LOADED")
    Refresh()
    return
  end

  if not runtimeEnabled then return end

  if event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
    Refresh()
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    inCombat = false
    Refresh()
    return
  elseif event == "PLAYER_ENTERING_WORLD" then
    if UnitAffectingCombat then
      inCombat = UnitAffectingCombat("player") and true or false
    else
      inCombat = false
    end
    Refresh()
    return
  end

  if (event == "UNIT_HEALTH" or event == "UNIT_MANA" or event == "UNIT_AURA") and arg1 and arg1 ~= "player" then
    return
  end

  if personalFrame then
    UpdateValues(personalFrame)
    UpdateStyle(personalFrame)
    if event == "UNIT_AURA" and personalFrame:IsShown() then UpdatePersonalDebuffs(personalFrame, true) end
  end
end)

RuntimeOnUpdate = function()
  updateElapsed = updateElapsed + arg1
  if updateElapsed < 0.10 then return end
  updateElapsed = 0

  if not personalFrame then return end

  -- Cheap 10 Hz fallback for custom 1.12 clients that do not emit every modern
  -- player-resource event consistently. This script is attached only while the
  -- Personal Nameplate feature itself is enabled.
  local shouldShow = ShouldShow()
  if shouldShow then
    if not personalFrame:IsShown() then
      personalFrame:Show()
      debuffScanElapsed = 0.50
    end
    UpdateValues(personalFrame)

    debuffScanElapsed = debuffScanElapsed + 0.10
    local forceScan = false
    if debuffScanElapsed >= 0.50 then
      debuffScanElapsed = 0
      forceScan = true
    end
    UpdatePersonalDebuffs(personalFrame, forceScan)
  elseif personalFrame:IsShown() then
    personalFrame:Hide()
  end
end

-- Bootstrap once SavedVariables are available. If the feature is disabled,
-- this event removes itself and no Personal Nameplate runtime events or
-- OnUpdate polling stay active in the background.
events:RegisterEvent("VARIABLES_LOADED")
