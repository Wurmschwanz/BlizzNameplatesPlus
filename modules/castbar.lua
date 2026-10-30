BNP = BNP or {}

local casts = {}
local castFeedback = {}
local BAR_HEIGHT = 6
local BAR_GAP = 4
local MODERN_ICON_BORDER_SCALE = 23 / 14
local CLASSIC_FRAME_INSET = 3
local CLASSIC_GOLD_R, CLASSIC_GOLD_G, CLASSIC_GOLD_B = 1.0, 0.8, 0.0
local CAST_SPARK_SIZE = 20
local CAST_SUCCESS_FEEDBACK_DURATION = 0.60
local CAST_FAIL_FEEDBACK_DURATION = 0.30
local TEST_CAST_FEEDBACK_DURATION = 0.60
local CLASSIC_BACKDROP = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 8,
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

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
  if testCastStart == 0 then
    ResetTestCast(now)
  end

  if now < testCast.endTime then
    return testCast, nil
  end

  local feedbackEnd = testCast.endTime + TEST_CAST_FEEDBACK_DURATION
  if now < feedbackEnd then
    return nil, {
      state = "success",
      name = testCast.name,
      texture = testCast.texture,
      duration = testCast.duration,
      value = testCast.duration,
      percent = 1,
      endTime = feedbackEnd,
      flashDuration = TEST_CAST_FEEDBACK_DURATION,
    }
  end

  ResetTestCast(now)
  return testCast, nil
end

local function GetCastbarHeight()
  if BNP.GetCastbarHeight then return BNP:GetCastbarHeight() end
  return BAR_HEIGHT
end

local function GetCastbarFontSize()
  if BNP.GetCastbarFontSize then return BNP:GetCastbarFontSize() end
  return 10
end

local function GetCastbarStyle()
  if BNP.GetCastbarStyle then return BNP:GetCastbarStyle() end
  return "modern"
end

local function IsClassicCastbarStyle()
  return GetCastbarStyle() == "classic"
end

local function IsCastbarIconEnabled()
  if BNP.IsCastbarIconEnabled then return BNP:IsCastbarIconEnabled() end
  return not BNP_DB or BNP_DB.castbarIcon ~= false
end

local function GetCastbarIconSize()
  if IsClassicCastbarStyle() then
    -- The Classic castbar backdrop extends three pixels above and below the
    -- configured bar height. Give the icon the same complete outer height.
    return GetCastbarHeight() + (CLASSIC_FRAME_INSET * 2)
  end
  -- Modern keeps the spell icon exactly square with the configured castbar
  -- height. Both frames share the same top anchor, so their visible rows stay
  -- aligned at every slider value from 4 to 20.
  return GetCastbarHeight()
end

local function GetCastbarStartOffset()
  if not IsCastbarIconEnabled() then return 0 end
  if IsClassicCastbarStyle() then return GetCastbarIconSize() end
  return GetCastbarIconSize() + 1
end

local function GetCastbarXOffset()
  if BNP.GetCastbarXOffset then return BNP:GetCastbarXOffset() end
  return 0
end

local function GetCastbarYOffset()
  if BNP.GetCastbarYOffset then return BNP:GetCastbarYOffset() end
  return 0
end

local function SetCastbarSpark(bar, state, alpha)
  if not bar or not bar.spark then return end
  -- On the Vanilla 1.12 client GetWidth() can lag a layout update.
  -- Use the validated fixed logical width also used by the castbar itself,
  -- never a transient/projected healthbar measurement.
  local minValue, maxValue = bar:GetMinMaxValues()
  local currentValue = bar:GetValue() or minValue or 0
  minValue = minValue or 0
  maxValue = maxValue or 1

  local percent = 0
  if maxValue > minValue then
    percent = (currentValue - minValue) / (maxValue - minValue)
  end
  if percent < 0 then percent = 0 end
  if percent > 1 then percent = 1 end

  local width = bar.BNPRenderWidth or bar:GetWidth() or 0
  bar.spark:ClearAllPoints()
  bar.spark:SetPoint("CENTER", bar, "LEFT", width * percent, 0)

  if state == "success" then
    bar.spark:SetVertexColor(0.20, 1.00, 0.20)
  elseif state == "fail" then
    bar.spark:SetVertexColor(1.00, 0.20, 0.20)
  else
    -- Untinted during the cast, matching ShaguTweaks' original spark.
    bar.spark:SetVertexColor(1.00, 1.00, 1.00)
  end

  bar.spark:SetAlpha(alpha or 1)
  bar.spark:Show()
end

local function ApplyCastbarFont(text)
  if not text or not text.GetFont or not text.SetFont then return end

  local font, currentSize, flags = text:GetFont()
  if not font then return end

  local size = GetCastbarFontSize()
  if text.BNPModernFontFlags == nil then text.BNPModernFontFlags = flags or "" end
  local wantedFlags = IsClassicCastbarStyle() and "THINOUTLINE" or text.BNPModernFontFlags
  if currentSize ~= size or (flags or "") ~= wantedFlags then
    -- Keep Blizzard's font face. Classic adds ShaguTweaks' thin outline;
    -- Modern restores the original font flags.
    text:SetFont(font, size, wantedFlags)
  end
end

local BOTTOM_AURA_EDGE_GAP = 4

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

local function RegionShown(region)
  if not region then return false end
  if region.IsShown then return region:IsShown() end
  return true
end

local function GetCastbarEndExtension(plate)
  -- Preserve the classic +14px room while either native right-side level
  -- region is actually visible. When Hide Level removes the numeric text and
  -- there is no boss/level icon, the castbar ends flush with the healthbar.
  if plate and (RegionShown(plate.level) or RegionShown(plate.levelicon)) then
    return 14
  end
  return 0
end

-- Occasionally the projected Blizzard healthbar reports transitional geometry
-- when its nameplate moves/recycles. Do not let one bad width stretch the castbar
-- across the screen or displace its progress spark. Dimensions here are local
-- frame units; the normal nameplate/target scale still comes from the wrapper.
local CAST_MIN_HEALTH_WIDTH = 25
local CAST_MAX_HEALTH_WIDTH = 400
local CAST_WIDTH_JUMP_FACTOR = 1.50
local CAST_FALLBACK_HEALTH_WIDTH = 110

local function GetSafeHealthbarWidth(plate, bar)
  if not plate or not plate.healthbar or not bar then return CAST_FALLBACK_HEALTH_WIDTH end

  local measured = plate.healthbar:GetWidth()
  local previous = bar.BNPStableHealthWidth
  local wrapper = plate.BNPScaleWrapper
  local originalWidth = wrapper and wrapper.originalWidth
  -- Reject an oversized FIRST measurement too: otherwise the bad value
  -- itself would be cached as the reference for all subsequent casts.
  local firstWidthPlausible = previous or
    type(originalWidth) ~= "number" or
    originalWidth < 80 or originalWidth > CAST_MAX_HEALTH_WIDTH or
    (type(measured) == "number" and measured <= originalWidth * 2)
  if type(measured) == "number" and
     measured >= CAST_MIN_HEALTH_WIDTH and measured <= CAST_MAX_HEALTH_WIDTH and
     firstWidthPlausible and
     (not previous or
      (measured >= (previous / CAST_WIDTH_JUMP_FACTOR) and
       measured <= (previous * CAST_WIDTH_JUMP_FACTOR))) then
    bar.BNPStableHealthWidth = measured
    return measured
  end

  if previous then return previous end

  -- Even the first cast on a newly projected nameplate can land on a bad
  -- geometry frame. The original plate width is a better fallback than the
  -- transient healthbar width; if missing, use a Classic-sized default.
  local fallback = originalWidth
  if type(fallback) ~= "number" or
     fallback < CAST_MIN_HEALTH_WIDTH or fallback > CAST_MAX_HEALTH_WIDTH then
    fallback = CAST_FALLBACK_HEALTH_WIDTH
  end
  return fallback
end

local function ApplyCastbarLayout(plate, bar, healthWidth)
  if not plate or not plate.healthbar or not bar then return end
  local gap = BAR_GAP + GetBottomAuraClearance(plate)
  local xOffset = GetCastbarXOffset()
  local yOffset = GetCastbarYOffset()
  local barStartOffset = GetCastbarStartOffset()
  local endExtension = GetCastbarEndExtension(plate)
  healthWidth = healthWidth or GetSafeHealthbarWidth(plate, bar)

  -- A recycled plate may have received the wrapper AFTER the castbar was
  -- created. Both castbar and icon must inherit the exact same parent scale.
  local parent = plate.BNPScaleWrapper or plate
  if bar:GetParent() ~= parent then bar:SetParent(parent) end
  if bar.icon and bar.icon:GetParent() ~= parent then bar.icon:SetParent(parent) end

  -- Anchor only the left edge and set a validated logical width explicitly.
  -- The old dual-edge TOPLEFT/TOPRIGHT stretch followed bad healthbar geometry
  -- during projection/movement, sometimes leaving a huge castbar for one unit.
  local renderWidth = healthWidth + endExtension - barStartOffset
  if renderWidth < 1 then renderWidth = 1 end
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", plate.healthbar, "BOTTOMLEFT", barStartOffset + xOffset, -gap + yOffset)
  bar:SetWidth(renderWidth)
  bar.BNPRenderWidth = renderWidth
  bar.BNPLayoutHealthWidth = healthWidth
  bar.BNPLayoutEndExtension = endExtension

  if bar.icon then
    bar.icon:ClearAllPoints()
    local iconYOffset = IsClassicCastbarStyle() and CLASSIC_FRAME_INSET or 0
    bar.icon:SetPoint("TOPLEFT", plate.healthbar, "BOTTOMLEFT", xOffset, -gap + yOffset + iconYOffset)
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

-- Only the presentation changes between styles. Cast state and animation stay
-- on BNP's GUID-based path instead of ShaguTweaks' name-based fallback.
local function ApplyCastbarStyle(bar)
  if not bar then return end

  local classic = IsClassicCastbarStyle()

  if bar.classicBackdrop then
    if classic then bar.classicBackdrop:Show() else bar.classicBackdrop:Hide() end
  end

  if bar.icon then
    local iconSize = GetCastbarIconSize()
    bar.icon:SetWidth(iconSize)
    bar.icon:SetHeight(iconSize)

    if bar.icon.texture then
      bar.icon.texture:ClearAllPoints()
      if classic then
        bar.icon.texture:SetPoint("CENTER", bar.icon, "CENTER", 0, 0)
        bar.icon.texture:SetWidth(GetCastbarHeight())
        bar.icon.texture:SetHeight(GetCastbarHeight())
      else
        bar.icon.texture:SetAllPoints(bar.icon)
      end
    end

    if bar.icon.border then
      if classic then
        bar.icon.border:Hide()
      else
        local borderSize = math.floor((iconSize * MODERN_ICON_BORDER_SCALE) + 0.5)
        bar.icon.border:SetWidth(borderSize)
        bar.icon.border:SetHeight(borderSize)
        bar.icon.border:Show()
      end
    end
    if bar.icon.classicBackdrop then
      if classic then bar.icon.classicBackdrop:Show() else bar.icon.classicBackdrop:Hide() end
    end
    if not IsCastbarIconEnabled() then bar.icon:Hide() end
  end

  ApplyCastbarFont(bar.text)
end

local function CreateCastbar(plate)
  if plate.BNPCastbar then return plate.BNPCastbar end
  if not plate.healthbar then return nil end

  local parent = plate.BNPScaleWrapper or plate
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetHeight(GetCastbarHeight())
  -- Center the castbar under the complete Blizzard nameplate.
  -- Extend beneath the level badge instead of stopping at the healthbar edge.
  -- Compact row: with the optional icon enabled, icon + castbar together span
  -- the complete plate width. Without it, the bar starts at the left edge and
  -- uses the freed space itself.
  local gap = BAR_GAP + GetBottomAuraClearance(plate)
  local xOffset = GetCastbarXOffset()
  local yOffset = GetCastbarYOffset()
  -- Initial placement uses the same guarded one-edge geometry as all later
  -- layout updates. Never stretch the first frame between two live anchors.
  local initialStartOffset = GetCastbarStartOffset()
  local initialHealthWidth = GetSafeHealthbarWidth(plate, bar)
  local initialEndExtension = GetCastbarEndExtension(plate)
  local initialRenderWidth = initialHealthWidth + initialEndExtension - initialStartOffset
  if initialRenderWidth < 1 then initialRenderWidth = 1 end
  bar:SetPoint("TOPLEFT", plate.healthbar, "BOTTOMLEFT", initialStartOffset + xOffset, -gap + yOffset)
  bar:SetWidth(initialRenderWidth)
  bar.BNPRenderWidth = initialRenderWidth
  bar.BNPLayoutHealthWidth = initialHealthWidth
  bar.BNPLayoutEndExtension = initialEndExtension
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
  ApplyCastbarFont(text)
  text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  text:SetTextColor(1, 1, 1)
  bar.text = text

  -- ShaguTweaks-style spark attached to the actual BNP cast progress.
  -- This is presentation-only: it shares the existing frame-perfect updater
  -- and does not add another scan or OnUpdate loop.
  local spark = bar:CreateTexture(nil, "OVERLAY")
  spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  spark:SetWidth(CAST_SPARK_SIZE)
  spark:SetHeight(CAST_SPARK_SIZE)
  spark:SetBlendMode("ADD")
  spark:Hide()
  bar.spark = spark

  -- ShaguTweaks-inspired Classic frame. It remains hidden in the default
  -- Modern style and adds no second progress or animation layer.
  local classicBackdrop = CreateFrame("Frame", nil, bar)
  classicBackdrop:SetFrameLevel(bar:GetFrameLevel())
  classicBackdrop:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
  classicBackdrop:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
  classicBackdrop:SetBackdrop(CLASSIC_BACKDROP)
  classicBackdrop:SetBackdropBorderColor(CLASSIC_GOLD_R, CLASSIC_GOLD_G, CLASSIC_GOLD_B)
  classicBackdrop:Hide()
  bar.classicBackdrop = classicBackdrop

  -- Spell icon to the left of the castbar.
  local icon = CreateFrame("Frame", nil, parent)
  icon:SetWidth(14)
  icon:SetHeight(14)
  local iconYOffset = IsClassicCastbarStyle() and CLASSIC_FRAME_INSET or 0
  icon:SetPoint("TOPLEFT", plate.healthbar, "BOTTOMLEFT", xOffset, -gap + yOffset + iconYOffset)
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

  local iconClassicBackdrop = CreateFrame("Frame", nil, icon)
  iconClassicBackdrop:SetFrameLevel(icon:GetFrameLevel() + 1)
  iconClassicBackdrop:SetAllPoints(icon)
  iconClassicBackdrop:SetBackdrop(CLASSIC_BACKDROP)
  iconClassicBackdrop:SetBackdropBorderColor(CLASSIC_GOLD_R, CLASSIC_GOLD_G, CLASSIC_GOLD_B)
  iconClassicBackdrop:Hide()
  icon.classicBackdrop = iconClassicBackdrop

  icon:Hide()
  bar.icon = icon

  plate.BNPCastbar = bar
  ApplyCastbarStyle(bar)
  return bar
end

local function Hide(plate)
  if plate and plate.BNPCastbar then
    if plate.BNPCastbar.spark then
      plate.BNPCastbar.spark:Hide()
      plate.BNPCastbar.spark:SetAlpha(1)
      plate.BNPCastbar.spark:SetVertexColor(1.00, 1.00, 1.00)
    end
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

  -- SuperWoW CAST is the successful completion event for a cast already
  -- started with START/CHANNEL. Do not use arg5/timerMS to identify completion:
  -- SuperWoW may still provide a non-zero timer on CAST. Match the running spell
  -- instead, mirroring SuperAPI_Castlib's live-event handling.
  if eventType == "CAST" then
    local previous = casts[guid]
    local sameSpell = previous and (previous.spellID == nil or spellID == nil or tostring(previous.spellID) == tostring(spellID))
    if previous and sameSpell and previous.duration and previous.duration > 0 then
      local now = GetTime()
      castFeedback[guid] = {
        state = "success",
        name = previous.name,
        texture = previous.texture,
        duration = previous.duration,
        value = previous.channel and 0 or previous.duration,
        percent = previous.channel and 0 or 1,
        endTime = now + CAST_SUCCESS_FEEDBACK_DURATION,
        flashDuration = CAST_SUCCESS_FEEDBACK_DURATION,
      }
      casts[guid] = nil
    end
    -- A CAST without a matching running cast is an instant/proc/non-bar event.
    -- It must not create or restart a castbar.
    return
  end

  if eventType == "START" or eventType == "CHANNEL" then
    if timerMS <= 0 then
      -- Instant casts do not need a visible castbar.
      casts[guid] = nil
      castFeedback[guid] = nil
      return
    end

    local name, texture = SpellData(spellID)
    local now = GetTime()
    local duration = timerMS / 1000

    -- A fresh cast immediately replaces any short success/fail flash that may
    -- still be visible from the previous cast on this GUID.
    castFeedback[guid] = nil
    casts[guid] = {
      name = name,
      texture = texture,
      spellID = spellID,
      startTime = now,
      endTime = now + duration,
      duration = duration,
      channel = eventType == "CHANNEL",
    }
  elseif eventType == "FAIL" then
    local previous = casts[guid]
    if previous and previous.duration and previous.duration > 0 then
      local now = GetTime()
      local current = now - previous.startTime
      if current < 0 then current = 0 end
      if current > previous.duration then current = previous.duration end

      local value = previous.channel and (previous.duration - current) or current
      if value < 0 then value = 0 end

      castFeedback[guid] = {
        state = "fail",
        name = previous.name,
        texture = previous.texture,
        duration = previous.duration,
        value = value,
        percent = value / previous.duration,
        endTime = now + CAST_FAIL_FEEDBACK_DURATION,
        flashDuration = CAST_FAIL_FEEDBACK_DURATION,
      }
    end
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

  -- No active timed cast and no short success/fail feedback means there is
  -- nothing to discover. UNIT_CASTEVENT wakes this path automatically by
  -- creating an entry in casts/castFeedback, so idle gameplay no longer walks
  -- every visible nameplate 20 times per second.
  if not castbarTestMode and not next(casts) and not next(castFeedback) then
    local plate
    for plate in pairs(activeCastPlates) do
      MarkCastPlateInactive(plate)
    end
    return
  end

  local now = GetTime()

  -- Drop expired feedback even if its nameplate disappeared before the short
  -- flash could be rendered. This keeps the GUID table bounded over time.
  local feedbackGUID, staleFeedback
  for feedbackGUID, staleFeedback in pairs(castFeedback) do
    if not staleFeedback.endTime or now >= staleFeedback.endTime then
      castFeedback[feedbackGUID] = nil
    end
  end

  local plate
  for plate in pairs(BNP.plates) do
    if plate:IsShown() then
      if castbarTestMode then
        -- Preview every visible nameplate. No GUID/cast lookup is needed.
        MarkCastPlateActive(plate)
      else
        local guid = GetPlateGUID(plate)
        local cast = guid and casts[guid]
        local feedback = guid and castFeedback[guid]

        -- If the 20 Hz discovery pass happens to run on the exact frame a cast
        -- completes, preserve the active plate and hand it a success flash.
        -- Otherwise discovery could hide the bar before the frame updater gets
        -- a chance to render the green endpoint.
        if guid and cast and now >= cast.endTime then
          if activeCastPlates[plate] then
            castFeedback[guid] = {
              state = "success",
              name = cast.name,
              texture = cast.texture,
              duration = cast.duration,
              value = cast.channel and 0 or cast.duration,
              percent = cast.channel and 0 or 1,
              endTime = now + CAST_SUCCESS_FEEDBACK_DURATION,
          flashDuration = CAST_SUCCESS_FEEDBACK_DURATION,
            }
            feedback = castFeedback[guid]
          end
          casts[guid] = nil
          cast = nil
        end

        if (cast and now < cast.endTime) or (feedback and now < feedback.endTime) then
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
-- castbars are updated every rendered frame. The Shagu-style spark rides this
-- same update, so it adds no extra per-frame scan.
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
      local feedback

      if castbarTestMode then
        cast, feedback = GetTestCast(now)
      else
        guid = GetPlateGUID(plate)
        cast = guid and casts[guid]
        feedback = guid and castFeedback[guid]
      end

      -- A naturally completed timed cast is considered successful unless
      -- SuperWoW already sent FAIL, which removes the cast and creates the red
      -- feedback state in the event handler above.
      if (not castbarTestMode) and guid and cast and now >= cast.endTime then
        castFeedback[guid] = {
          state = "success",
          name = cast.name,
          texture = cast.texture,
          duration = cast.duration,
          value = cast.channel and 0 or cast.duration,
          percent = cast.channel and 0 or 1,
          endTime = now + CAST_SUCCESS_FEEDBACK_DURATION,
          flashDuration = CAST_SUCCESS_FEEDBACK_DURATION,
        }
        casts[guid] = nil
        cast = nil
        feedback = castFeedback[guid]
      end

      if feedback and now >= feedback.endTime then
        if guid then castFeedback[guid] = nil end
        feedback = nil
      end

      if not cast and not feedback then
        MarkCastPlateInactive(plate)
      else
        local bar = CreateCastbar(plate)
        if bar then
          -- Active bars already run through this updater. Check only their
          -- lightweight geometry here; no additional nameplate scan is added.
          -- Recover on the next frame when projected width/parent changes,
          -- while rejecting any transient oversized healthbar measurement.
          local bottomClearance = GetBottomAuraClearance(plate)
          local healthWidth = GetSafeHealthbarWidth(plate, bar)
          local endExtension = GetCastbarEndExtension(plate)
          local expectedParent = plate.BNPScaleWrapper or plate
          if bar.BNPBottomAuraClearance ~= bottomClearance or
             bar.BNPLayoutHealthWidth ~= healthWidth or
             bar.BNPLayoutEndExtension ~= endExtension or
             bar:GetParent() ~= expectedParent or
             (bar.icon and bar.icon:GetParent() ~= expectedParent) then
            ApplyCastbarLayout(plate, bar, healthWidth)
          end

          -- Do not allow an external layout reset or reused nameplate frame
          -- to leave the castbar/icon at a different local scale or height.
          -- Normal target/nameplate scaling is inherited from the wrapper.
          if bar:GetScale() ~= 1 then bar:SetScale(1) end
          if bar.icon and bar.icon:GetScale() ~= 1 then bar.icon:SetScale(1) end
          local desiredHeight = GetCastbarHeight()
          if math.abs((bar:GetHeight() or 0) - desiredHeight) > 0.1 then
            bar:SetHeight(desiredHeight)
          end
          local desiredWidth = bar.BNPRenderWidth or 1
          local currentWidth = bar:GetWidth() or 0
          if currentWidth > desiredWidth * 1.5 or
             (currentWidth > 1 and currentWidth < desiredWidth / 1.5) then
            bar:SetWidth(desiredWidth)
          end

          local name
          local texture
          local value
          local duration
          local percent
          local sparkState
          local sparkAlpha = 1

          if cast then
            local current = now - cast.startTime
            if current < 0 then current = 0 end
            if current > cast.duration then current = cast.duration end

            duration = cast.duration
            if cast.channel then
              value = cast.duration - current
            else
              value = current
            end

            if duration > 0 then percent = value / duration else percent = 0 end
            name = cast.name
            texture = cast.texture
          else
            duration = feedback.duration
            value = feedback.value
            percent = feedback.percent
            name = feedback.name
            texture = feedback.texture
            sparkState = feedback.state

            -- Keep the success/fail flash crisp at first, then softly fade the
            -- spark during the final part of its short lifetime.
            local remaining = feedback.endTime - now
            local flashDuration = feedback.flashDuration or CAST_FAIL_FEEDBACK_DURATION
            sparkAlpha = remaining / flashDuration
            if sparkAlpha < 0 then sparkAlpha = 0 end
            if sparkAlpha > 1 then sparkAlpha = 1 end
          end

          bar:SetMinMaxValues(0, duration or 1)
          bar:SetValue(value or 0)
          bar.text:SetText(name or "Casting")
          bar:SetAlpha(1)

          -- Make cast feedback unmistakable without adding any extra updater.
          -- The normal bar stays Blizzard-gold; a finished cast briefly turns
          -- the filled bar + spark green, while a failed/interrupted cast turns
          -- them red. The next active cast restores the normal color immediately.
          if sparkState == "success" then
            bar:SetStatusBarColor(0.10, 1.00, 0.10)
          elseif sparkState == "fail" then
            bar:SetStatusBarColor(1.00, 0.15, 0.15)
          else
            bar:SetStatusBarColor(1.00, 0.80, 0.00)
          end

          if bar.icon then
            if IsCastbarIconEnabled() and texture then
              bar.icon.texture:SetTexture(texture)
              bar.icon:SetAlpha(1)
              bar.icon:Show()
            else
              bar.icon:Hide()
            end
          end

          SetCastbarSpark(bar, sparkState, sparkAlpha)
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
      ApplyCastbarStyle(plate.BNPCastbar)
      ApplyCastbarLayout(plate, plate.BNPCastbar)
    end
  end
end

function BNP:RefreshCastbarStyle()
  self:RefreshCastbarLayout()
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
