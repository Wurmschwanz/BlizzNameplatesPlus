BNP = BNP or {}

local _, playerClass = UnitClass("player")
local COMBO_CLASS = (playerClass == "ROGUE" or playerClass == "DRUID")

local MAX_POINTS = 5
local POINT_GAP = 1

local function Enabled()
  return COMBO_CLASS and BNP.AreComboPointsEnabled and BNP:AreComboPointsEnabled()
end

local function GetTargetGUID()
  local exists, guid = UnitExists("target")
  if exists and guid then return guid end
  return nil
end

local function GetComboCount()
  if not GetComboPoints then return 0 end
  local count = tonumber(GetComboPoints()) or 0
  if count < 0 then count = 0 end
  if count > MAX_POINTS then count = MAX_POINTS end
  return count
end

local function GetSourcePoint()
  if getglobal then
    return getglobal("TargetFrameComboPoint1")
  end
  return nil
end

local function GetSourceSize()
  local source = GetSourcePoint()
  local w, h = 12, 16

  if source then
    if source.GetWidth then w = tonumber(source:GetWidth()) or w end
    if source.GetHeight then h = tonumber(source:GetHeight()) or h end
  end

  if w <= 0 then w = 12 end
  if h <= 0 then h = 16 end
  return w, h
end

local function ApplyTargetFrameScale(holder)
  if not holder then return end

  local source = GetSourcePoint()
  local parent = holder:GetParent()

  local sourceScale = 1.0
  local parentScale = 1.0

  -- Match the actual on-screen scale of Blizzard's TargetFrame combo points.
  if source and source.GetEffectiveScale then
    sourceScale = tonumber(source:GetEffectiveScale()) or 1.0
  elseif UIParent and UIParent.GetEffectiveScale then
    sourceScale = tonumber(UIParent:GetEffectiveScale()) or 1.0
  elseif UIParent and UIParent.GetScale then
    sourceScale = tonumber(UIParent:GetScale()) or 1.0
  end

  if parent and parent.GetEffectiveScale then
    parentScale = tonumber(parent:GetEffectiveScale()) or 1.0
  end

  if sourceScale <= 0 then sourceScale = 1.0 end
  if parentScale <= 0 then parentScale = 1.0 end

  holder:SetScale(sourceScale / parentScale)
end

local function CopySourceTextureAppearance(dst, src)
  if not dst or not src then return end

  if src.GetTexture and dst.SetTexture then
    dst:SetTexture(src:GetTexture())
  end

  if src.GetTexCoord and dst.SetTexCoord then
    local l, r, t, b = src:GetTexCoord()
    if l then dst:SetTexCoord(l, r, t, b) end
  end

  if src.GetVertexColor and dst.SetVertexColor then
    local r, g, b, a = src:GetVertexColor()
    if r then dst:SetVertexColor(r, g, b, a or 1) end
  end

  if src.GetBlendMode and dst.SetBlendMode then
    local mode = src:GetBlendMode()
    if mode then dst:SetBlendMode(mode) end
  end
end

local function CreateExactPoint(parent)
  local source = GetSourcePoint()
  local pointW, pointH = GetSourceSize()

  local point = CreateFrame("Frame", nil, parent)
  point:SetWidth(pointW)
  point:SetHeight(pointH)

  local copied = false

  -- Clone the actual texture regions from Blizzard's TargetFrame combo point.
  -- This guarantees the same client artwork/skin instead of guessing atlas cuts.
  if source and source.GetRegions then
    local regions = { source:GetRegions() }
    local i

    for i = 1, table.getn(regions) do
      local src = regions[i]
      if src and src.GetObjectType and src:GetObjectType() == "Texture" then
        local tex = point:CreateTexture(nil, "ARTWORK")
        CopySourceTextureAppearance(tex, src)

        local w = src.GetWidth and tonumber(src:GetWidth()) or pointW
        local h = src.GetHeight and tonumber(src:GetHeight()) or pointH
        if not w or w <= 0 then w = pointW end
        if not h or h <= 0 then h = pointH end

        tex:SetWidth(w)
        tex:SetHeight(h)

        -- Preserve the standard TargetFrame relative offsets where possible.
        local anchored = false
        if src.GetPoint then
          local pnt, rel, relp, x, y = src:GetPoint(1)
          if pnt then
            -- Source textures are normally anchored to their own combo frame.
            -- Re-anchor them to our clone with the same point/offset.
            tex:SetPoint(pnt, point, relp or pnt, x or 0, y or 0)
            anchored = true
          end
        end

        if not anchored then
          tex:SetPoint("CENTER", point, "CENTER", 0, 0)
        end

        copied = true
      end
    end
  end

  -- Fallback only if the client does not expose TargetFrameComboPoint1 regions.
  if not copied then
    local base = point:CreateTexture(nil, "BACKGROUND")
    base:SetTexture("Interface\\ComboFrame\\ComboPoint")
    base:SetWidth(12)
    base:SetHeight(16)
    base:SetPoint("TOPLEFT", point, "TOPLEFT", 0, 0)
    base:SetTexCoord(0, 0.375, 0, 1)

    local highlight = point:CreateTexture(nil, "ARTWORK")
    highlight:SetTexture("Interface\\ComboFrame\\ComboPoint")
    highlight:SetWidth(8)
    highlight:SetHeight(16)
    highlight:SetPoint("TOPLEFT", point, "TOPLEFT", 2, 0)
    highlight:SetTexCoord(0.375, 0.5625, 0, 1)
  end

  point:Hide()
  return point
end

local function EnsurePoints(plate)
  if plate.BNPComboPoints then
    ApplyTargetFrameScale(plate.BNPComboPoints)
    return plate.BNPComboPoints
  end

  if not plate or not plate.name then return nil end

  local pointW, pointH = GetSourceSize()
  local parent = plate.BNPScaleWrapper or plate

  local holder = CreateFrame("Frame", nil, parent)
  holder:SetWidth(MAX_POINTS * pointW + (MAX_POINTS - 1) * POINT_GAP)
  holder:SetHeight(pointH)

  -- Keep the position the user already approved.
  holder:SetPoint("BOTTOM", plate.name, "TOP", 0, 2)
  holder:SetFrameLevel((plate:GetFrameLevel() or 1) + 12)
  holder.points = {}
  holder:Hide()

  local i
  for i = 1, MAX_POINTS do
    local point = CreateExactPoint(holder)

    if i == 1 then
      point:SetPoint("LEFT", holder, "LEFT", 0, 0)
    else
      point:SetPoint("LEFT", holder.points[i - 1], "RIGHT", POINT_GAP, 0)
    end

    holder.points[i] = point
  end

  ApplyTargetFrameScale(holder)
  plate.BNPComboPoints = holder
  return holder
end

local function HidePoints(plate)
  local holder = plate and plate.BNPComboPoints
  if not holder then return end

  local i
  for i = 1, MAX_POINTS do
    holder.points[i]:Hide()
  end
  holder:Hide()
end

local function UpdatePlate(plate)
  if not plate or not plate:IsShown() then return end

  if not Enabled() then
    HidePoints(plate)
    return
  end

  local targetGUID = GetTargetGUID()
  local plateGUID = plate.GetName and plate:GetName(1) or nil

  if not targetGUID or not plateGUID or targetGUID ~= plateGUID then
    HidePoints(plate)
    return
  end

  local count = GetComboCount()
  if count <= 0 then
    HidePoints(plate)
    return
  end

  local holder = EnsurePoints(plate)
  if not holder then return end
  ApplyTargetFrameScale(holder)

  local i
  for i = 1, MAX_POINTS do
    if i <= count then
      holder.points[i]:Show()
    else
      holder.points[i]:Hide()
    end
  end

  holder:Show()
end

function BNP:RefreshComboPoints()
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate:IsShown() then
      UpdatePlate(plate)
    else
      HidePoints(plate)
    end
  end

  if BNP.RefreshAllAuraLayouts then
    BNP:RefreshAllAuraLayouts()
  end
end

table.insert(BNP.libnameplate.OnInit, function(plate)
  if COMBO_CLASS then
    EnsurePoints(plate)
    HidePoints(plate)
  end
end)

table.insert(BNP.libnameplate.OnShow, function(plate)
  if COMBO_CLASS then
    HidePoints(plate)
    UpdatePlate(plate)
  end
end)

table.insert(BNP.libnameplate.OnUpdate, function(plate)
  if COMBO_CLASS then UpdatePlate(plate) end
end)

if COMBO_CLASS then
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("PLAYER_COMBO_POINTS")
  events:SetScript("OnEvent", function()
    BNP:RefreshComboPoints()
  end)
end
