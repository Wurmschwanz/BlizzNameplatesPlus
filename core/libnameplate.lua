BNP = BNP or {}

BNP.libnameplate = BNP.libnameplate or {
  OnInit = {},
  OnShow = {},
  OnUpdate = {},
}

local lib = BNP.libnameplate
local known = {}
local initializedChildren = 0

local function IsNamePlate(frame)
  if not frame or not frame.GetObjectType then return false end
  if frame:GetObjectType() ~= "Button" then return false end

  local firstRegion = frame:GetRegions()
  if not firstRegion or not firstRegion.GetObjectType or not firstRegion.GetTexture then
    return false
  end

  if firstRegion:GetObjectType() ~= "Texture" then return false end
  return firstRegion:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

local function AttachPlateShortcuts(plate)
  if plate.BNPShortcutsReady then return end

  -- Vanilla Blizzard nameplates expose the health StatusBar as their first child.
  local healthbar = plate:GetChildren()
  plate.healthbar = healthbar

  -- Vanilla region order:
  -- 1 border, 2 glow, 3 name, 4 level, 5 level icon, 6 raid icon.
  local regions = { plate:GetRegions() }
  plate.border = regions[1]
  plate.glow = regions[2]
  plate.name = regions[3]
  plate.level = regions[4]
  plate.levelicon = regions[5]
  plate.raidicon = regions[6]

  plate.BNPShortcutsReady = true
end

local function Fire(list, plate)
  plate = plate or this
  if not plate then return end

  local i
  for i = 1, table.getn(list) do
    if list[i] then
      pcall(list[i], plate)
    end
  end
end

local function RegisterPlate(plate)
  plate = plate or this
  if not plate then return end
  if known[plate] then return end
  known[plate] = true

  AttachPlateShortcuts(plate)

  if BNP.RegisterPlate then
    BNP:RegisterPlate(plate)
  end

  Fire(lib.OnInit, plate)
  if plate:IsShown() then
    Fire(lib.OnShow, plate)
  end

  -- Run OnShow callbacks when Blizzard reuses the same plate.
  local oldOnShow = plate:GetScript("OnShow")
  plate:SetScript("OnShow", function(self)
    local current = self or this or plate
    if not current then return end
    if oldOnShow then oldOnShow(current) end
    AttachPlateShortcuts(current)
    Fire(lib.OnShow, current)
  end)
end

local scanner = CreateFrame("Frame")
local scanElapsed = 0

scanner:SetScript("OnUpdate", function()
  scanElapsed = scanElapsed + arg1
  if scanElapsed < 0.10 then return end
  scanElapsed = 0

  local count = WorldFrame:GetNumChildren()

  -- Full scan only when WorldFrame gained children. This mirrors the lightweight
  -- discovery strategy used by Shagu's Vanilla nameplate code.
  if count > initializedChildren then
    local children = { WorldFrame:GetChildren() }
    local i
    for i = 1, table.getn(children) do
      local frame = children[i]
      if not known[frame] and IsNamePlate(frame) then
        RegisterPlate(frame)
      end
    end
    initializedChildren = count
  end

  -- Compatibility callback list for modules that want a throttled plate update.
  if table.getn(lib.OnUpdate) > 0 then
    local plate
    for plate in pairs(known) do
      if plate:IsShown() then
        Fire(lib.OnUpdate, plate)
      end
    end
  end
end)
