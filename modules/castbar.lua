BNP = BNP or {}

local casts = {}
local BAR_HEIGHT = 6

-- Runtime-only visual preview. This is intentionally not saved in BNP_DB so
-- a /reload always returns to normal cast detection.
local castbarTestMode = false
local testCastStart = 0
local TEST_CAST_DURATION = 4
local TEST_CAST_TEXTURE = "Interface\\Icons\\Spell_Fire_Fireball02"

local testCast = {
  name = "Test Cast",
  texture = TEST_CAST_TEXTURE,
  startTime = 0,
  endTime = 0,
  duration = TEST_CAST_DURATION,
  channel = false,
}

local function ResetTestCast(now)
  now = now or GetTime()
  testCastStart = now
  testCast.startTime = now
  testCast.endTime = now + TEST_CAST_DURATION
  testCast.duration = TEST_CAST_DURATION
end

local function GetTestCast(now)
  if testCastStart == 0 or now >= testCast.endTime then
    ResetTestCast(now)
  end
  return testCast
end

local function GetCastbarHeight()
  if BNP.GetCastbarHeight then return BNP:GetCastbarHeight() end
  return BAR_HEIGHT
end
local BAR_GAP = 4

local function GetCastbarSpacing()
  if BNP.GetCastbarSpacing then return BNP:GetCastbarSpacing() end
  return BAR_GAP
end

local BOTTOM_AURA_EDGE_GAP = 4
local BOTTOM_AURA_ROW_SPACING = 2

local function FrameShown(frame)
  return frame and frame.IsShown and frame:IsShown() and true or false
end

local function IsBottomDebuffPosition(position)
  return position == "bottom_mid" or position == "bottom_left" or position == "bottom_right"
end

local function GetBottomAuraClearance(plate)
  if not plate then return 0 end

  local debuffPosition = BNP.GetDebuffPosition and BNP:GetDebuffPosition() or "top"
  local debuffsEnabled = not BNP.AreDebuffsEnabled or BNP:AreDebuffsEnabled()
  local auraSize = BNP.GetIconSize and BNP:GetIconSize() or 18

  if debuffsEnabled and IsBottomDebuffPosition(debuffPosition) and FrameShown(plate.BNPAuraContainer) then
    return BOTTOM_AURA_EDGE_GAP + auraSize
  end
  return 0
end

local function ApplyCastbarLayout(plate, bar)
  if not plate or not plate.healthbar or not bar then return end
  local gap = GetCastbarSpacing() + GetBottomAuraClearance(plate)

  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", plate.healthbar, "BOTTOMLEFT", 15, -gap)
  bar:SetPoint("TOPRIGHT", plate.healthbar, "BOTTOMRIGHT", 14, -gap)

  if bar.icon then
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("TOPLEFT", plate.healthbar, "BOTTOMLEFT", 0, -gap)
  end
  bar.BNPBottomAuraClearance = GetBottomAuraClearance(plate)
end

local function Enabled()
  if BNP.AreCastbarsEnabled then return BNP:AreCastbarsEnabled() end
  return not BNP_DB or BNP_DB.castbars ~= false
end

local function GetPlateGUID(plate)
  if not plate or not plate.GetName then return nil end

  local token = plate:GetName(1)
  if not token then return nil end

  local exists, guid = UnitExists(token)
  if exists and guid then return guid end

  -- On SuperWoW the plate token itself can already be the GUID.
  return token
end

local function SpellData(spellID)
  if SpellInfo and spellID then
    local name, _, texture = SpellInfo(spellID)
    return name or "Casting", texture
  end
  return "Casting", nil
end

local function CreateCastbar(plate)
  if plate.BNPCastbar then return plate.BNPCastbar end
  if not plate.healthbar then return nil end

  local parent = plate.BNPScaleWrapper or plate
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetHeight(GetCastbarHeight())
  -- Center the castbar under the complete Blizzard nameplate.
  -- Extend beneath the level badge instead of stopping at the healthbar edge.
  -- Compact row: icon + castbar together span the complete plate width.
  -- The icon begins at the healthbar's left edge; the bar continues directly
  -- beside it and ends beneath the level badge.
  local gap = GetCastbarSpacing() + GetBottomAuraClearance(plate)
  bar:SetPoint("TOPLEFT", plate.healthbar, "BOTTOMLEFT", 15, -gap)
  bar:SetPoint("TOPRIGHT", plate.healthbar, "BOTTOMRIGHT", 14, -gap)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(1.0, 0.8, 0.0)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:SetFrameLevel((plate.healthbar:GetFrameLevel() or 1) + 1)
  bar:Hide()

  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bg:SetVertexColor(0.10, 0.10, 0.00, 0.85)
  bg:SetAllPoints(bar)

  local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  text:SetTextColor(1, 1, 1)
  bar.text = text

  -- Spell icon to the left of the castbar.
  local icon = CreateFrame("Frame", nil, parent)
  icon:SetWidth(14)
  icon:SetHeight(14)
  icon:SetPoint("TOPLEFT", plate.healthbar, "BOTTOMLEFT", 0, -gap)
  icon:SetFrameLevel(bar:GetFrameLevel() + 1)

  local texture = icon:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(icon)
  icon.texture = texture

  local border = icon:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  border:SetPoint("CENTER", icon, "CENTER", 0, 0)
  border:SetWidth(23)
  border:SetHeight(23)
  icon.border = border

  icon:Hide()
  bar.icon = icon

  plate.BNPCastbar = bar
  return bar
end

local function Hide(plate)
  if plate and plate.BNPCastbar then
    plate.BNPCastbar:Hide()
    if plate.BNPCastbar.icon then
      plate.BNPCastbar.icon:Hide()
    end
  end
end

-- Exact SuperWoW event path used by ShaguTweaks' superwow module:
-- START / CAST / CHANNEL create cast state; FAIL removes it.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_CASTEVENT")
eventFrame:SetScript("OnEvent", function()
  local guid = arg1
  local eventType = arg3
  local spellID = arg4
  local timerMS = tonumber(arg5) or 0

  if not guid then return end

  if eventType == "START" or eventType == "CAST" or eventType == "CHANNEL" then
    if timerMS <= 0 then
      -- Instant casts do not need a visible castbar.
      casts[guid] = nil
      return
    end

    local name, texture = SpellData(spellID)
    local now = GetTime()
    local duration = timerMS / 1000

    casts[guid] = {
      name = name,
      texture = texture,
      startTime = now,
      endTime = now + duration,
      duration = duration,
      channel = eventType == "CHANNEL",
    }
  elseif eventType == "FAIL" then
    casts[guid] = nil
  end
end)

local activeCastPlates = {}

local function MarkCastPlateActive(plate)
  if not plate then return end
  activeCastPlates[plate] = true
end

local function MarkCastPlateInactive(plate)
  if not plate then return end
  activeCastPlates[plate] = nil
  Hide(plate)
end

-- Lightweight discovery pass. This does NOT animate bars; it only checks
-- visible plates for active cast state at 20 Hz.
local discovery = CreateFrame("Frame")
local discoveryElapsed = 0
discovery:SetScript("OnUpdate", function()
  discoveryElapsed = discoveryElapsed + arg1
  if discoveryElapsed < 0.05 then return end
  discoveryElapsed = 0

  if not Enabled() and not castbarTestMode then
    local plate
    for plate in pairs(activeCastPlates) do
      MarkCastPlateInactive(plate)
    end
    return
  end

  local now = GetTime()
  local plate
  for plate in pairs(BNP.plates) do
    if plate:IsShown() then
      if castbarTestMode then
        -- Preview every visible nameplate. No GUID/cast lookup is needed.
        MarkCastPlateActive(plate)
      else
        local guid = GetPlateGUID(plate)
        local cast = guid and casts[guid]

        if cast and now < cast.endTime then
          MarkCastPlateActive(plate)
        elseif activeCastPlates[plate] then
          MarkCastPlateInactive(plate)
        end
      end
    elseif activeCastPlates[plate] then
      MarkCastPlateInactive(plate)
    end
  end
end)

-- Frame-perfect animation remains unchanged visually, but only active
-- castbars are updated every rendered frame.
local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function()
  if not Enabled() and not castbarTestMode then return end

  local now = GetTime()
  local plate
  for plate in pairs(activeCastPlates) do
    if not plate:IsShown() then
      MarkCastPlateInactive(plate)
    else
      local guid
      local cast

      if castbarTestMode then
        cast = GetTestCast(now)
      else
        guid = GetPlateGUID(plate)
        cast = guid and casts[guid]
      end

      if not cast or now >= cast.endTime then
        if (not castbarTestMode) and guid and cast and now >= cast.endTime then
          casts[guid] = nil
        end
        MarkCastPlateInactive(plate)
      else
        local bar = CreateCastbar(plate)
        if bar then
          local bottomClearance = GetBottomAuraClearance(plate)
          if bar.BNPBottomAuraClearance ~= bottomClearance then
            ApplyCastbarLayout(plate, bar)
          end

          local current = now - cast.startTime
          if current < 0 then current = 0 end
          if current > cast.duration then current = cast.duration end

          bar:SetMinMaxValues(0, cast.duration)

          if cast.channel then
            bar:SetValue(cast.duration - current)
          else
            bar:SetValue(current)
          end

          bar.text:SetText(cast.name)
          bar:SetAlpha(1)

          if bar.icon then
            if cast.texture then
              bar.icon.texture:SetTexture(cast.texture)
              bar.icon:SetAlpha(1)
              bar.icon:Show()
            else
              bar.icon:Hide()
            end
          end

          bar:Show()
        end
      end
    end
  end
end)


function BNP:IsCastbarTestMode()
  return castbarTestMode and true or false
end

function BNP:SetCastbarTestMode(enabled)
  castbarTestMode = enabled and true or false

  if castbarTestMode then
    ResetTestCast(GetTime())
  else
    -- Remove every preview immediately. Real casts are rediscovered on the
    -- next lightweight discovery pass without touching their stored state.
    local plate
    for plate in pairs(activeCastPlates) do
      MarkCastPlateInactive(plate)
    end
  end

  if self.optionsFrame and self.optionsFrame.castbarTestCheck then
    self.optionsFrame.castbarTestCheck:SetChecked(castbarTestMode)
  end
end


function BNP:RefreshCastbarLayout()
  local plate
  local height = GetCastbarHeight()

  for plate in pairs(BNP.plates or {}) do
    if plate and plate.BNPCastbar then
      plate.BNPCastbar:SetHeight(height)
      ApplyCastbarLayout(plate, plate.BNPCastbar)
    end
  end
end

function BNP:RefreshCastbarHeights()
  self:RefreshCastbarLayout()
end

function BNP:SetCastbarsEnabled(enabled)
  BNP_DB = BNP_DB or {}
  BNP_DB.castbars = enabled and true or false

  if not enabled then
    local plate
    for plate in pairs(BNP.plates) do Hide(plate) end
  end

  self:Print("Nameplate castbars " .. (enabled and "enabled." or "disabled."))
end
