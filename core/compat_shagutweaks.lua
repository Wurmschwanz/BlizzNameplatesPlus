BNP = BNP or {}

-- Robust ShaguTweaks compatibility.
-- BNP owns Scale / Class Colors / Castbar while loaded.
-- ShaguTweaks settings are NOT changed.

BNP.shaguCompat = BNP.shaguCompat or {
  patched = {},
  registerHooked = false,
}

local wanted = {
  ["Nameplate Scale"] = true,
  ["Nameplate Class Colors"] = true,
  ["Nameplate Castbar"] = true,
}

local function IsWantedTitle(title)
  if not title then return false end

  if wanted[title] then return true end

  if ShaguTweaks and ShaguTweaks.T then
    if title == ShaguTweaks.T["Nameplate Scale"] then return true end
    if title == ShaguTweaks.T["Nameplate Class Colors"] then return true end
    if title == ShaguTweaks.T["Nameplate Castbar"] then return true end
  end

  return false
end

local function DisableModule(mod)
  if not mod or type(mod) ~= "table" then return false end
  if not IsWantedTitle(mod.title) then return false end
  if mod.BNPCompatibilityPatched then return true end

  mod.BNPOriginalEnable = mod.enable
  mod.enable = function(self)
    return
  end

  mod.BNPCompatibilityPatched = true
  BNP.shaguCompat.patched[mod.title or "?"] = true
  return true
end

local function PatchExistingModules()
  if not ShaguTweaks or not ShaguTweaks.mods then return end

  local title, mod
  for title, mod in pairs(ShaguTweaks.mods) do
    -- Some registered module tables use localized title as the map key.
    if mod and not mod.title then mod.title = title end
    DisableModule(mod)
  end
end

local function HookRegister()
  if not ShaguTweaks or not ShaguTweaks.register then return end
  if BNP.shaguCompat.registerHooked then return end

  local originalRegister = ShaguTweaks.register

  ShaguTweaks.register = function(self, mod)
    local registered = originalRegister(self, mod)
    DisableModule(registered or mod)
    return registered
  end

  BNP.shaguCompat.registerHooked = true
end

function BNP:ApplyShaguTweaksCompatibility()
  if not ShaguTweaks then return false end

  -- Covers BNP loading before Shagu's modules register.
  HookRegister()

  -- Covers BNP loading after Shagu's modules registered.
  PatchExistingModules()

  return true
end

-- Try immediately in case ShaguTweaks is already loaded.
BNP:ApplyShaguTweaksCompatibility()

-- Also retry after every addon load. This safely covers all Vanilla/Turtle
-- load-order variations without touching ShaguTweaks saved settings.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  BNP:ApplyShaguTweaksCompatibility()
end)
