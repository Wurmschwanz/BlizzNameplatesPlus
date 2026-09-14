BNP = BNP or {}
BNP.version = "1.0.10 ClassicAPI Event Test"
BNP.plates = BNP.plates or {}
BNP.detected = 0
BNP.debugEnabled = false

function BNP:Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Blizz Nameplates+:|r " .. tostring(msg))
  end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:SetScript("OnEvent", function()
  BNP_DB = BNP_DB or {}

  if BNP.InitConfig then BNP:InitConfig() end
  if BNP.CreateMinimapButton then BNP:CreateMinimapButton() end
  if BNP.InstallTankMode then BNP:InstallTankMode() end

  if BNP_DB.debugEnabled == nil then BNP_DB.debugEnabled = false end
  BNP.debugEnabled = BNP_DB.debugEnabled

  local classicNameplates = CLASSIC_API_VERSION and C_NamePlate and
                            type(C_NamePlate.GetNamePlateForUnit) == "function"

  if CombatLogAdd and SpellInfo and classicNameplates then
    BNP:Print(BNP.version .. " loaded. SuperWoW + ClassicAPI nameplate tracking active.")
    if C_UnitAuras and type(C_UnitAuras.GetAuraSlots) == "function"
      and type(C_UnitAuras.UnitAuraBySlot) == "function" then
      BNP:Print("ClassicAPI v1.15.6 aura bridge active: UNIT_AURA + allocation-free slot scans.")
    elseif C_UnitAuras and type(C_UnitAuras.UnitDebuff) == "function" then
      BNP:Print("ClassicAPI aura bridge active, but event-driven v1.15.6 features are unavailable.")
    else
      BNP:Print("ClassicAPI aura bridge unavailable; legacy UnitDebuff fallback active.")
    end
    if ShaguTweaks then
      BNP:ApplyShaguTweaksCompatibility()
      local count = 0
      local k
      for k in pairs(BNP.shaguCompat.patched or {}) do count = count + 1 end
      BNP:Print("ShaguTweaks compatibility active (" .. tostring(count) .. "/3 nameplate modules suppressed).")
    end
  elseif not CombatLogAdd or not SpellInfo then
    BNP:Print("ERROR: SuperWoW API not detected. Blizz Nameplates+ requires SuperWoW.")
  else
    BNP:Print("ERROR: ClassicAPI nameplate API not detected. Please update ClassicAPI.dll.")
  end
end)
