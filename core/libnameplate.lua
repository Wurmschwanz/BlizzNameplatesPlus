BNP = BNP or {}

BNP.libnameplate = BNP.libnameplate or {
  OnInit = {},
  OnShow = {},
  OnUpdate = {},
}

local lib = BNP.libnameplate
local known = {}
local initializedChildren = 0

local function FindHealthBar(frame)
  if not frame or not frame.GetChildren then return nil end

  local children = { frame:GetChildren() }
  local i
  for i = 1, table.getn(children) do
    local child = children[i]
    if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
      return child
    end
  end

  return nil
end

local function IsNamePlate(frame)
  if not frame or not frame.GetObjectType then return false end
  if frame:GetObjectType() ~= "Button" then return false end

  -- Fast path for untouched Blizzard nameplates.
  local firstRegion = frame:GetRegions()
  if firstRegion and firstRegion.GetObjectType and firstRegion.GetTexture and
     firstRegion:GetObjectType() == "Texture" and
     firstRegion:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" then
    return true
  end

  -- Compatibility fallback: some UI/skin addons replace, blank or hide the
  -- native border before BNP's WorldFrame scan sees the plate. Do not make
  -- nameplate discovery depend on a mutable texture path.
  local replacement = frame.nameplate
  local original = replacement and replacement.original

  -- Known replacement-overlay shape: the addon kept references to Blizzard's
  -- original health/name/level objects even if it already reparented them.
  if original and (original.health or original.healthbar) and
     original.name and original.level then
    return true
  end

  -- Generic safe fallback. Keep the structural test deliberately strict to
  -- avoid mistaking unrelated WorldFrame Buttons for nameplates.
  if not firstRegion or not firstRegion.GetObjectType or
     firstRegion:GetObjectType() ~= "Texture" then
    return false
  end
  if not FindHealthBar(frame) then return false end

  local fontStrings = 0
  local regions = { frame:GetRegions() }
  local i
  for i = 1, table.getn(regions) do
    local region = regions[i]
    if region and region.GetObjectType and region:GetObjectType() == "FontString" then
      fontStrings = fontStrings + 1
      if fontStrings >= 2 then return true end
    end
  end

  return false
end

local function AttachPlateShortcuts(plate)
  if plate.BNPShortcutsReady then return end

  -- Do not assume another addon left the native StatusBar as the first child.
  local replacement = plate.nameplate
  local original = replacement and replacement.original
  plate.healthbar = (original and (original.health or original.healthbar)) or
                    FindHealthBar(plate)

  -- Vanilla region order:
  -- 1 border, 2 glow, 3 name, 4 level, 5 level icon, 6 raid icon.
  -- Fall back to common replacement-overlay references only when direct native
  -- regions are unavailable; normal Blizzard plates keep the exact old path.
  local regions = { plate:GetRegions() }
  plate.border = (original and original.border) or regions[1]
  plate.glow = regions[2] or (original and original.glow)
  plate.name = regions[3] or (original and original.name)
  plate.level = regions[4] or (original and original.level)
  plate.levelicon = regions[5] or (original and (original.levelicon or original.bossicon))
  plate.raidicon = regions[6] or (replacement and replacement.raidicon) or
                   (original and original.raidicon)

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
