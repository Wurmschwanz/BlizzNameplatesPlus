BNP = BNP or {}

local MIN_SCALE = 0.50
local MAX_SCALE = 1.50
local DEFAULT_SCALE = 1.00

local function Clamp(value)
  if value < MIN_SCALE then return MIN_SCALE end
  if value > MAX_SCALE then return MAX_SCALE end
  return value
end

function BNP:GetNameplateScale()
  BNP_DB = BNP_DB or {}
  return Clamp(tonumber(BNP_DB.nameplateScale) or DEFAULT_SCALE)
end

local function EffectiveScale()
  local uiScale = 1.0
  if UIParent and UIParent.GetScale then
    uiScale = UIParent:GetScale() or 1.0
  end
  return uiScale * BNP:GetNameplateScale()
end

local function CaptureAnchorState(object, plate, wrapper)
  if not object or not object.GetPoint then return nil end

  local state = {
    object = object,
    points = {},
  }

  local count = 1
  if object.GetNumPoints then
    count = object:GetNumPoints() or 1
    if count < 1 then count = 1 end
  end

  local i
  for i = 1, count do
    local point, relativeTo, relativePoint, x, y = object:GetPoint(i)
    if point then
      if relativeTo == plate then
        relativeTo = wrapper
      end

      state.points[table.getn(state.points) + 1] = {
        point = point,
        relativeTo = relativeTo or wrapper,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
      }
    end
  end

  return state
end

local function AnchorStateMatches(state)
  if not state or not state.object or not state.object.GetPoint then return false end

  local object = state.object
  local expectedCount = table.getn(state.points)
  local currentCount = expectedCount

  if object.GetNumPoints then
    currentCount = object:GetNumPoints() or 0
  end

  if currentCount ~= expectedCount then
    return false
  end

  local i
  for i = 1, expectedCount do
    local expected = state.points[i]
    local point, relativeTo, relativePoint, x, y = object:GetPoint(i)

    if point ~= expected.point
      or relativeTo ~= expected.relativeTo
      or relativePoint ~= expected.relativePoint
      or math.abs((x or 0) - expected.x) > 0.01
      or math.abs((y or 0) - expected.y) > 0.01 then
      return false
    end
  end

  return true
end

local function RestoreAnchorState(state, wrapper)
  if not state or not state.object then return end

  local object = state.object

  if object.GetParent and object.SetParent and object:GetParent() ~= wrapper then
    object:SetParent(wrapper)
  end

  -- Do nothing in the common case. Blizzard normally only rewrites a subset
  -- of nameplate anchors while moving, most notably the level FontString.
  if AnchorStateMatches(state) then return end

  if not object.ClearAllPoints or not object.SetPoint then return end

  object:ClearAllPoints()

  local i
  for i = 1, table.getn(state.points) do
    local p = state.points[i]
    object:SetPoint(
      p.point,
      p.relativeTo or wrapper,
      p.relativePoint or p.point,
      p.x,
      p.y
    )
  end
end

local function SetHoverGlow(plate, shown)
  if not plate or not plate.glow then return end

  if shown then
    if plate.glow.Show then
      plate.glow:Show()
    end
  else
    if plate.glow.Hide then
      plate.glow:Hide()
    end
  end
end

local function SetYOffsetMouseMode(plate, wrapper, offset)
  if not plate or not wrapper then return end

  -- Always use the visual wrapper as BNP's interactive frame, including at
  -- Y Offset 0. Previously offset 0 used Blizzard's native Button while
  -- positive offsets used BNPScaleWrapper. That split mouse path caused the
  -- original Blizzard mouseover glow to disappear at offset 0.
  --
  -- Keeping clicks, hit geometry and hover feedback on the same frame also
  -- guarantees that the clickable area follows the visible plate at every
  -- configured Y offset.
  if plate.EnableMouse then
    plate:EnableMouse(false)
  end

  if wrapper.EnableMouse then
    wrapper:EnableMouse(true)
  end

  if wrapper.RegisterForClicks then
    -- Preserve the classic Blizzard nameplate mouse behavior:
    -- left click selects the unit, right click selects it and starts auto attack.
    wrapper:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  end

  if not wrapper.BNPClickForwardInstalled then
    wrapper:SetScript("OnClick", function()
      local current = this or wrapper
      local parent = current and current.plate or plate
      if parent and parent:IsShown() and parent.Click then
        -- The native Blizzard nameplate click reliably selects the plate's unit.
        parent:Click()

        -- In Vanilla OnClick exposes the mouse button through arg1.  The wrapper
        -- previously registered only LeftButtonUp, which made right click a no-op.
        -- After selecting the unit, mirror Blizzard's right-click behavior by
        -- starting auto attack on the newly selected target.
        if arg1 == "RightButton" and AttackTarget then
          AttackTarget()
        end
      end
    end)
    wrapper.BNPClickForwardInstalled = true
  end

  if not wrapper.BNPMouseoverFeedbackInstalled then
    wrapper:SetScript("OnEnter", function()
      local current = this or wrapper
      local parent = current and current.plate or plate
      SetHoverGlow(parent, true)
    end)

    wrapper:SetScript("OnLeave", function()
      local current = this or wrapper
      local parent = current and current.plate or plate
      SetHoverGlow(parent, false)
    end)

    wrapper.BNPMouseoverFeedbackInstalled = true
  end
end

local function ApplyWrapperOffset(plate, wrapper)
  if not plate or not wrapper then return end

  local offset = 0
  if BNP.GetNameplateYOffset then
    offset = BNP:GetNameplateYOffset()
  end

  -- Move only the child visual container. The WorldFrame-projected Blizzard
  -- nameplate itself keeps its original anchor and can continue to be
  -- repositioned by the client every frame.
  wrapper:ClearAllPoints()
  wrapper:SetPoint("TOPLEFT", plate, "TOPLEFT", 0, offset)
  wrapper:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 0, offset)

  SetYOffsetMouseMode(plate, wrapper, offset)
end

local function EnsureScaleWrapper(plate)
  if not plate or plate.BNPScaleWrapper then return end

  local originalWidth = plate:GetWidth()
  local originalHeight = plate:GetHeight()

  local wrapper = CreateFrame("Button", nil, plate)
  wrapper:SetAllPoints(plate)
  wrapper.plate = plate
  wrapper.originalWidth = originalWidth
  wrapper.originalHeight = originalHeight
  wrapper.BNPAnchorStates = {}
  wrapper:EnableMouse(false)

  plate.BNPScaleWrapper = wrapper

  -- Capture the ORIGINAL Blizzard anchors before changing parentage.
  -- Those stored anchors become BNP's authoritative visual layout whenever
  -- Y-offset is enabled.
  if plate.healthbar then
    local state = CaptureAnchorState(plate.healthbar, plate, wrapper)
    if state then
      table.insert(wrapper.BNPAnchorStates, state)
    end

    plate.healthbar:SetParent(wrapper)
    RestoreAnchorState(state, wrapper)
    plate.healthbar:SetFrameLevel(1)
  end

  local regions = { plate:GetRegions() }
  local i, object
  for i, object in pairs(regions) do
    if object and object.SetParent then
      local state = CaptureAnchorState(object, plate, wrapper)
      if state then
        table.insert(wrapper.BNPAnchorStates, state)
      end

      object:SetParent(wrapper)
      RestoreAnchorState(state, wrapper)
    end
  end

  ApplyWrapperOffset(plate, wrapper)
end

function BNP:ApplyNameplateScale(plate)
  if not plate then return end
  EnsureScaleWrapper(plate)

  local wrapper = plate.BNPScaleWrapper
  if not wrapper then return end

  local scale = EffectiveScale()
  wrapper:SetScale(scale)
  ApplyWrapperOffset(plate, wrapper)

  -- ShaguTweaks also adjusts the original frame bounds so Blizzard's world
  -- positioning remains correct while the child visuals honor UI scale.
  plate:SetWidth(wrapper.originalWidth * scale)
  plate:SetHeight(wrapper.originalHeight * scale)
end

function BNP:ApplyNameplateScaleAll()
  local plate
  for plate in pairs(self.plates) do
    self:ApplyNameplateScale(plate)
  end
end

function BNP:ApplyNameplateYOffsetAll()
  local plate
  for plate in pairs(self.plates or {}) do
    if plate then
      self:ApplyNameplateScale(plate)
    end
  end
end

function BNP:MaintainNameplateYOffset(plate)
  if not plate or not plate:IsShown() then return end
  if not self.GetNameplateYOffset or self:GetNameplateYOffset() <= 0 then return end

  EnsureScaleWrapper(plate)

  local wrapper = plate.BNPScaleWrapper
  if not wrapper then return end

  -- Never rediscover regions through plate:GetRegions() here. Once BNP moves
  -- Blizzard regions into the wrapper they are no longer guaranteed to be
  -- returned by plate:GetRegions(). Keep and maintain the original region
  -- objects captured during wrapper creation instead.
  local states = wrapper.BNPAnchorStates or {}
  local i
  for i = 1, table.getn(states) do
    RestoreAnchorState(states[i], wrapper)
  end

  ApplyWrapperOffset(plate, wrapper)
end

function BNP:SetNameplateScale(value)
  value = tonumber(value)
  if not value then
    self:Print("Usage: /bnp scale 0.5-1.5")
    return
  end

  value = Clamp(value)
  BNP_DB = BNP_DB or {}
  BNP_DB.nameplateScale = value
  self:ApplyNameplateScaleAll()

  self:Print("Nameplate scale multiplier set to " .. tostring(value) .. ".")
end

function BNP:ResetNameplateScale()
  BNP_DB = BNP_DB or {}
  BNP_DB.nameplateScale = DEFAULT_SCALE
  self:ApplyNameplateScaleAll()
  self:Print("Nameplate scale multiplier reset to 1.0 (Shagu/UI scale behavior).")
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    local current = plate or this
    if not current then return end
    BNP:ApplyNameplateScale(current)
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    local current = plate or this
    if not current then return end
    BNP:ApplyNameplateScale(current)
  end)
end
