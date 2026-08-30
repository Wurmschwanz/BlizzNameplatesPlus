if not BNP.libnameplate then return end

-- Lightweight PvP totem indicators ------------------------------------------
-- Totem detection is intentionally nameplate/name based. It never reads or
-- modifies the aura cache, combat log timers or CC tracking.

local TOTEM_DEFS = {
  { key = "earthbind", spellID = 2484, names = { "Earthbind Totem", "Totem der Erdbindung" }, texture = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02" },
  { key = "stoneskin", spellID = 8071, names = { "Stoneskin Totem", "Totem der Steinhaut" }, texture = "Interface\\Icons\\Spell_Nature_StoneSkinTotem" },
  { key = "strengthofearth", spellID = 8075, names = { "Strength of Earth Totem", "Totem der Erdstärke" }, texture = "Interface\\Icons\\Spell_Nature_EarthBindTotem" },
  { key = "tremor", spellID = 8143, names = { "Tremor Totem", "Totem des Erdstosses", "Totem des Erdstoßes" }, texture = "Interface\\Icons\\Spell_Nature_TremorTotem" },
  { key = "grounding", spellID = 8177, names = { "Grounding Totem", "Totem der Erdung" }, texture = "Interface\\Icons\\Spell_Nature_GroundingTotem" },
  { key = "stoneclaw", spellID = 5730, names = { "Stoneclaw Totem", "Totem der Steinklaue" }, texture = "Interface\\Icons\\Spell_Nature_StoneClawTotem" },

  { key = "searing", spellID = 3599, names = { "Searing Totem", "Totem der Verbrennung" }, texture = "Interface\\Icons\\Spell_Fire_SearingTotem" },
  { key = "flametongue", spellID = 8227, names = { "Flametongue Totem", "Totem der Flammenzunge" }, texture = "Interface\\Icons\\Spell_Nature_GuardianWard" },
  { key = "magma", spellID = 8190, names = { "Magma Totem", "Totem des glühenden Magmas" }, texture = "Interface\\Icons\\Spell_Fire_SelfDestruct" },
  { key = "firenova", spellID = 1535, names = { "Fire Nova Totem", "Totem der Feuernova" }, texture = "Interface\\Icons\\Spell_Fire_SealOfFire" },
  { key = "frostres", spellID = 8181, names = { "Frost Resistance Totem", "Totem des Frostwiderstands" }, texture = "Interface\\Icons\\Spell_FrostResistanceTotem_01" },
  { key = "fireres", spellID = 8184, names = { "Fire Resistance Totem", "Totem des Feuerwiderstands" }, texture = "Interface\\Icons\\Spell_FireResistanceTotem_01" },

  { key = "healingstream", spellID = 5394, names = { "Healing Stream Totem", "Totem des heilenden Flusses" }, texture = "Interface\\Icons\\INV_Spear_04" },
  { key = "manaspring", spellID = 5675, names = { "Mana Spring Totem", "Totem der Manaquelle" }, texture = "Interface\\Icons\\Spell_Nature_ManaRegenTotem" },
  { key = "poisoncleansing", spellID = 8166, names = { "Poison Cleansing Totem", "Totem der Giftreinigung" }, texture = "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem" },
  { key = "diseasecleansing", spellID = 8170, names = { "Disease Cleansing Totem", "Totem der Krankheitsreinigung" }, texture = "Interface\\Icons\\Spell_Nature_DiseaseCleansingTotem" },
  { key = "manatide", spellID = 16190, names = { "Mana Tide Totem", "Totem der Manaflut" }, texture = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" },
  { key = "natureres", spellID = 10595, names = { "Nature Resistance Totem", "Totem des Naturwiderstands" }, texture = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem" },

  { key = "windfury", spellID = 8512, names = { "Windfury Totem", "Totem des Windzorns" }, texture = "Interface\\Icons\\Spell_Nature_Windfury" },
  { key = "sentry", spellID = 6495, names = { "Sentry Totem", "Totem des Wachens" }, texture = "Interface\\Icons\\Spell_Nature_RemoveCurse" },
  { key = "graceofair", spellID = 8835, names = { "Grace of Air Totem", "Totem der Luftanmut" }, texture = "Interface\\Icons\\Spell_Nature_InvisibilityTotem" },
  { key = "tranquilair", spellID = 25908, names = { "Tranquil Air Totem", "Totem der beruhigenden Winde" }, texture = "Interface\\Icons\\Spell_Nature_Brilliance" },
  { key = "windwall", spellID = 15107, names = { "Windwall Totem", "Totem der Windmauer" }, texture = "Interface\\Icons\\Spell_Nature_EarthBind" },
}


local function CleanName(text)
  if not text then return nil end
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  if text == "" then return nil end
  return text
end

local function NormalizeTotemName(text)
  text = CleanName(text)
  if not text then return nil end

  text = string.lower(text)
  -- Vanilla totem NPCs often carry their spell rank in the NPC name, e.g.
  -- "Searing Totem VI" or "Windfury Totem II". Match the base totem name.
  text = string.gsub(text, "%s+rank%s+%d+$", "")
  text = string.gsub(text, "%s+%d+$", "")
  text = string.gsub(text, "%s+[ivxlcdm]+$", "")
  text = string.gsub(text, "%s+$", "")
  return text
end

local function AddName(def, name)
  if not name or name == "" then return end
  local normalized = NormalizeTotemName(name)
  local i
  for i = 1, table.getn(def.names) do
    if NormalizeTotemName(def.names[i]) == normalized then return end
  end
  table.insert(def.names, name)
end

local definitionsResolved = false
local function ResolveDefinitions()
  if definitionsResolved then return end
  definitionsResolved = true

  if not SpellInfo then return end
  local i
  for i = 1, table.getn(TOTEM_DEFS) do
    local def = TOTEM_DEFS[i]
    local ok, name, _, texture = pcall(SpellInfo, def.spellID)
    if ok then
      AddName(def, name)
      if texture and texture ~= "" then def.texture = texture end
    end
  end
end

local GENERIC_TOTEM_DEF = {
  key = "generic",
  names = {},
  texture = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
}

local function FindTotemDefinition(name)
  local normalized = NormalizeTotemName(name)
  if not normalized then return nil end

  local i, n
  for i = 1, table.getn(TOTEM_DEFS) do
    local def = TOTEM_DEFS[i]
    for n = 1, table.getn(def.names) do
      if normalized == NormalizeTotemName(def.names[n]) then return def end
    end
  end

  -- Future/custom server totems still get icon-only treatment even when BNP
  -- does not yet know their exact spell icon. Standard Classic totems above
  -- keep their proper icon; unknown names containing "totem" use a neutral
  -- fallback icon instead of leaving the full nameplate visible.
  if string.find(normalized, "totem", 1, true) then
    return GENERIC_TOTEM_DEF
  end

  return nil
end

local function GetPlateName(plate)
  if plate and plate.name and plate.name.GetText then
    local name = CleanName(plate.name:GetText())
    if name then return name end
  end

  if plate and plate.GetName and UnitName then
    local token = plate:GetName(1)
    if token then
      local ok, name = pcall(UnitName, token)
      if ok then return CleanName(name) end
    end
  end

  return nil
end

local function PositionIndicator(plate, indicator)
  if not plate or not indicator then return end
  indicator:ClearAllPoints()

  -- Icon-only mode: replace the visible nameplate at its original position.
  if plate.healthbar then
    indicator:SetPoint("CENTER", plate.healthbar, "CENTER", 0, 0)
  else
    indicator:SetPoint("CENTER", plate, "CENTER", 0, 0)
  end
end

local function RememberAndHideVisual(object, state)
  if not object or object == state.indicator then return end
  if not object.SetAlpha or not object.GetAlpha then return end

  if state.alpha[object] == nil then
    state.alpha[object] = object:GetAlpha()
  end
  object:SetAlpha(0)
end

local function SuppressTotemPlateVisuals(plate)
  if not plate then return end

  local indicator = plate.BNPTotemIndicator
  local state = plate.BNPTotemVisualState
  if not state then
    state = { alpha = {}, indicator = indicator }
    plate.BNPTotemVisualState = state
  else
    state.indicator = indicator
  end

  -- Important PvP totems should remain clearly visible even when BNP's
  -- non-target alpha option would normally fade the underlying nameplate.
  if plate.SetAlpha then plate:SetAlpha(1) end

  local regions = { plate:GetRegions() }
  local i
  for i = 1, table.getn(regions) do
    RememberAndHideVisual(regions[i], state)
  end

  local children = { plate:GetChildren() }
  for i = 1, table.getn(children) do
    RememberAndHideVisual(children[i], state)
  end

  -- BNPTotemIndicator is itself a direct child of the plate.
  if indicator and indicator.SetAlpha then indicator:SetAlpha(1) end
end

local function RestoreTotemPlateVisuals(plate)
  if not plate then return end
  local state = plate.BNPTotemVisualState
  if not state then return end

  local object, alpha
  for object, alpha in pairs(state.alpha or {}) do
    if object and object.SetAlpha then
      object:SetAlpha(alpha or 1)
    end
  end

  plate.BNPTotemVisualState = nil
end

-- Blizzard can restore parts of a projected nameplate every frame. Once a
-- plate has been identified as a totem, suppress every normal visual again
-- after the plate's native/fullalpha OnUpdate has run. The replacement icon
-- remains a child of the plate and is explicitly excluded, so it keeps the
-- same proven projection/positioning path as the working detection version.
local function InstallTotemVisualGuard(plate)
  if not plate or plate.BNPTotemVisualGuard then return end

  local oldOnUpdate = plate:GetScript("OnUpdate")
  plate:SetScript("OnUpdate", function()
    if oldOnUpdate then oldOnUpdate() end
    local current = this or plate
    if not current then return end

    if current.BNPTotemLastKey and
       BNP.AreTotemIndicatorsEnabled and BNP:AreTotemIndicatorsEnabled() then
      SuppressTotemPlateVisuals(current)
      if current.BNPTotemIndicator then
        current.BNPTotemIndicator:SetAlpha(1)
        current.BNPTotemIndicator:Show()
      end
    elseif current.BNPTotemVisualState then
      RestoreTotemPlateVisuals(current)
    end
  end)

  plate.BNPTotemVisualGuard = true
end

local function InstallTotemHideGuard(plate)
  if not plate or plate.BNPTotemHideGuard then return end

  local oldOnHide = plate:GetScript("OnHide")
  plate:SetScript("OnHide", function()
    if oldOnHide then oldOnHide() end
    local current = this or plate
    if not current then return end

    if current.BNPTotemIndicator then current.BNPTotemIndicator:Hide() end
    RestoreTotemPlateVisuals(current)
    current.BNPTotemLastName = nil
    current.BNPTotemLastKey = nil
  end)

  plate.BNPTotemHideGuard = true
end

local function ApplyIndicatorLayout(plate, force)
  local indicator = plate and plate.BNPTotemIndicator
  if not indicator then return end

  local size = BNP.GetTotemIconSize and BNP:GetTotemIconSize() or 24
  local level = plate.GetFrameLevel and ((plate:GetFrameLevel() or 0) + 2) or 2

  if not force and
     indicator.BNPLastSize == size and
     indicator.BNPLastFrameLevel == level then
    return
  end

  indicator.BNPLastSize = size
  indicator.BNPLastFrameLevel = level
  indicator:SetWidth(size)
  indicator:SetHeight(size)
  if indicator.SetFrameLevel then indicator:SetFrameLevel(level) end
  PositionIndicator(plate, indicator)
end

local function CreateIndicator(plate)
  if not plate or plate.BNPTotemIndicator then return end

  local indicator = CreateFrame("Frame", nil, plate)
  local size = BNP.GetTotemIconSize and BNP:GetTotemIconSize() or 24
  indicator:SetWidth(size)
  indicator:SetHeight(size)
  indicator:SetFrameLevel((plate.GetFrameLevel and plate:GetFrameLevel() or 0) + 2)

  local border = indicator:CreateTexture(nil, "BACKGROUND")
  border:SetTexture(0, 0, 0, 1)
  border:SetPoint("TOPLEFT", indicator, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", 1, -1)
  indicator.border = border

  local texture = indicator:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(indicator)
  texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  indicator.texture = texture

  indicator:Hide()
  plate.BNPTotemIndicator = indicator
  ApplyIndicatorLayout(plate, true)
end

local function UpdateIndicator(plate, force)
  if not plate then return end
  CreateIndicator(plate)
  local indicator = plate.BNPTotemIndicator
  if not indicator then return end

  ApplyIndicatorLayout(plate, force)

  if not (BNP.AreTotemIndicatorsEnabled and BNP:AreTotemIndicatorsEnabled()) then
    indicator:Hide()
    RestoreTotemPlateVisuals(plate)
    plate.BNPTotemLastName = nil
    plate.BNPTotemLastKey = nil
    return
  end

  ResolveDefinitions()
  local name = GetPlateName(plate)
  if not force and name == plate.BNPTotemLastName then
    if plate.BNPTotemLastKey then
      indicator:Show()
      SuppressTotemPlateVisuals(plate)
    else
      indicator:Hide()
      RestoreTotemPlateVisuals(plate)
    end
    return
  end

  plate.BNPTotemLastName = name
  plate.BNPTotemLastKey = nil

  local def = FindTotemDefinition(name)
  if not def then
    indicator:Hide()
    RestoreTotemPlateVisuals(plate)
    return
  end

  plate.BNPTotemLastKey = def.key
  indicator.texture:SetTexture(def.texture)
  indicator:Show()
  SuppressTotemPlateVisuals(plate)
end

function BNP:RefreshTotemIndicators()
  ResolveDefinitions()
  local plate
  for plate in pairs(self.plates or {}) do
    if plate then UpdateIndicator(plate, true) end
  end
end

-- Public table keeps the totem definitions centralized and easy to extend.
BNP.TotemIndicatorDefinitions = TOTEM_DEFS

table.insert(BNP.libnameplate.OnInit, function(plate)
  CreateIndicator(plate)
  InstallTotemVisualGuard(plate)
  InstallTotemHideGuard(plate)
  UpdateIndicator(plate, true)
end)

table.insert(BNP.libnameplate.OnShow, function(plate)
  InstallTotemVisualGuard(plate)
  InstallTotemHideGuard(plate)
  plate.BNPTotemLastName = nil
  plate.BNPTotemLastKey = nil
  UpdateIndicator(plate, true)
end)

table.insert(BNP.libnameplate.OnUpdate, function(plate)
  UpdateIndicator(plate, false)
end)
