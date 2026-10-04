if not BNP.libnameplate then return end

local function CreateMarker(plate)
  if not plate then return end
  BNP:RegisterPlate(plate)

  -- Debug is disabled for normal gameplay. Do not allocate an extra Frame,
  -- Texture and FontString on every nameplate unless the user actually enables
  -- the marker. Existing markers are simply hidden when debug is off.
  if not BNP.debugEnabled then
    if plate.BNPMarker and plate.BNPMarker.IsShown and plate.BNPMarker:IsShown() then
      plate.BNPMarker:Hide()
    end
    return
  end

  if not plate.BNPMarker then
    local marker = CreateFrame("Frame", nil, plate)
    marker:SetWidth(14)
    marker:SetHeight(14)
    marker:SetPoint("BOTTOM", plate, "TOP", 0, 34)
    marker:SetFrameLevel(30)

    marker.texture = marker:CreateTexture(nil, "OVERLAY")
    marker.texture:SetAllPoints(marker)
    marker.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    marker.texture:SetVertexColor(1, 0, 0, 1)

    marker.text = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    marker.text:SetPoint("CENTER", marker, "CENTER", 0, 0)
    marker.text:SetText("+")
    marker.text:SetTextColor(1, 1, 1)
    plate.BNPMarker = marker
  end

  plate.BNPMarker:Show()
end

table.insert(BNP.libnameplate.OnInit, CreateMarker)
table.insert(BNP.libnameplate.OnShow, CreateMarker)

function BNP:SetDebug(enabled)
  BNP.debugEnabled = enabled
  BNP_DB = BNP_DB or {}
  BNP_DB.debugEnabled = enabled
  local plate
  for plate in pairs(BNP.plates) do
    if enabled then
      CreateMarker(plate)
    elseif plate.BNPMarker then
      plate.BNPMarker:Hide()
    end
  end
  BNP:Print("Debug-Marker " .. (enabled and "aktiviert" or "deaktiviert") .. ".")
end
