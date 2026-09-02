-- SuperWoW GUID probe.
-- This module does not alter aura tracking or rendering. It only inspects the
-- extended UnitExists return value and the unit token exposed by nameplates.

local function CleanText(text)
  if not text then return nil end
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  return text
end

local function SafePlateToken(plate)
  if not plate or not plate.GetName then return nil end

  -- SuperWoW extends frame:GetName(index). ShaguTweaks already uses
  -- plate:GetName(1) for its SuperWoW nameplate castbar implementation.
  local ok, token = pcall(function() return plate:GetName(1) end)
  if ok then return token end
  return nil
end

local function UnitExistsData(unit)
  if not unit then return nil, nil end
  local ok, exists, guid = pcall(UnitExists, unit)
  if not ok then return nil, nil end
  return exists, guid
end

function BNP:GetSuperWoWGUID(unit)
  local exists, guid = UnitExistsData(unit)
  if exists and guid then return guid end
  return nil
end

function BNP:GetPlateSuperWoWData(plate)
  local token = SafePlateToken(plate)
  local exists, guid = UnitExistsData(token)
  return token, exists, guid
end

function BNP:PrintGUIDDiagnostic()
  BNP:Print("=== SuperWoW GUID Diagnose ===")

  local targetName = UnitName("target")
  local targetExists, targetGUID = UnitExistsData("target")
  BNP:Print("Target: " .. tostring(targetName or "kein Ziel"))
  BNP:Print("UnitExists(target): " .. tostring(targetExists) .. " | GUID: " .. tostring(targetGUID))

  local visible = 0
  local sameName = 0
  local guidMatches = 0
  local index = 0

  for plate in pairs(BNP.plates) do
    if plate and plate:IsShown() then
      visible = visible + 1
      local plateName = plate.name and plate.name.GetText and CleanText(plate.name:GetText()) or nil

      if not targetName or plateName == targetName then
        sameName = sameName + 1
        index = index + 1
        local token, exists, guid = BNP:GetPlateSuperWoWData(plate)
        if targetGUID and guid and targetGUID == guid then guidMatches = guidMatches + 1 end

        BNP:Print("Plate " .. index .. ": " .. tostring(plateName))
        BNP:Print("  Token: " .. tostring(token) .. " | Exists: " .. tostring(exists))
        BNP:Print("  GUID: " .. tostring(guid) .. " | Target-Match: " .. tostring(targetGUID and guid == targetGUID or false))
      end
    end
  end

  BNP:Print("Sichtbar: " .. visible .. " | gleicher Name: " .. sameName .. " | GUID-Matches: " .. guidMatches)
end
