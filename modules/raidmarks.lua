BNP = BNP or {}

-- Raid marks use simple, deterministic anchors. There is deliberately no
-- automatic aura/CC collision avoidance here: X/Y sliders let the user place
-- the mark exactly where they want it.
local TOP_BASE_X = 3      -- matches Health Percent / HP text center
local TOP_BASE_Y = 20
local SIDE_BASE_X = 10

local function PointMatches(icon, point, relativeTo, relativePoint, x, y)
  if not icon or not icon.GetPoint then return false end
  if icon.GetNumPoints and (icon:GetNumPoints() or 0) ~= 1 then return false end

  local currentPoint, currentRelativeTo, currentRelativePoint, currentX, currentY = icon:GetPoint(1)
  return currentPoint == point
    and currentRelativeTo == relativeTo
    and currentRelativePoint == relativePoint
    and math.abs((currentX or 0) - (x or 0)) < 0.01
    and math.abs((currentY or 0) - (y or 0)) < 0.01
end

local function GetCustomAnchor(plate, position)
  local anchor = plate and (plate.healthbar or plate.BNPScaleWrapper or plate)
  if not anchor then return nil end

  local xOffset = BNP.GetRaidMarkXOffset and BNP:GetRaidMarkXOffset() or 0
  local yOffset = BNP.GetRaidMarkYOffset and BNP:GetRaidMarkYOffset() or 0

  if position == "left" then
    return "RIGHT", anchor, "LEFT", -SIDE_BASE_X + xOffset, yOffset
  elseif position == "right" then
    return "LEFT", anchor, "RIGHT", SIDE_BASE_X + xOffset, yOffset
  end

  -- Top is centered on the exact same horizontal center used by BNP's
  -- Percent / HP text (healthbar CENTER +3). The mark itself sits above the
  -- bar; X/Y Offset then apply directly on top of that base position.
  return "BOTTOM", anchor, "TOP", TOP_BASE_X + xOffset, TOP_BASE_Y + yOffset
end

function BNP:ApplyRaidMarkPosition(plate)
  if not plate then return end
  local icon = plate.raidicon
  if not icon then return end

  local position = self.GetRaidMarkPosition and self:GetRaidMarkPosition() or "top"
  local point, relativeTo, relativePoint, x, y = GetCustomAnchor(plate, position)
  if not point or not relativeTo then return end

  -- Keep the native icon with the scaled plate visuals if the client restores
  -- its parent. This preserves the same scaling and alpha as the healthbar.
  local wrapper = plate.BNPScaleWrapper
  if wrapper and icon.GetParent and icon.SetParent and icon:GetParent() ~= wrapper then
    icon:SetParent(wrapper)
  end

  if not PointMatches(icon, point, relativeTo, relativePoint, x, y) then
    if not icon.ClearAllPoints or not icon.SetPoint then return end
    icon:ClearAllPoints()
    icon:SetPoint(point, relativeTo, relativePoint, x, y)
  end

  plate.BNPLastRaidMarkPosition = position
end

function BNP:MaintainRaidMarkPosition(plate)
  if not plate or not plate.IsShown or not plate:IsShown() then return end
  local icon = plate.raidicon
  if not icon then return end
  -- This path runs after native/offset updates on EVERY rendered frame. A
  -- throttled repair leaves the native anchor visible between repairs.
  -- Most plates have no active
  -- raid mark, so avoid GetPoint/anchor comparisons until Blizzard actually
  -- shows the icon. The first visible frame will still be corrected instantly.
  if icon.IsShown and not icon:IsShown() then return end
  self:ApplyRaidMarkPosition(plate)
end

function BNP:RefreshRaidMarkPositions()
  local plate
  for plate in pairs(self.plates or {}) do
    if plate then self:ApplyRaidMarkPosition(plate) end
  end
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    local current = plate or this
    if current then BNP:ApplyRaidMarkPosition(current) end
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    local current = plate or this
    if current then BNP:ApplyRaidMarkPosition(current) end
  end)
end
