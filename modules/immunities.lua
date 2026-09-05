if not BNP or not BNP.libnameplate then return end

-- PvP immunity / anti-fear indicators (strict whitelist) -------------------
-- Keep this deliberately close to BNP's proven aura/nameplate path:
-- SuperWoW's projected nameplate token (plate:GetName(1)) is used directly
-- with UnitBuff, just like auras.lua uses it directly with UnitDebuff.
-- No GUID -> token reverse conversion and no C_UnitAuras dependency here.

BNP.guidImmunities = BNP.guidImmunities or {}

local UI = BNP.UI or {}
local MAX_ICONS = 4
local ICON_SPACING = UI.ICON_SPACING or 2
local SIDE_SPACING = 4
local BOTTOM_SPACING = 4
local BASE_TOP_OFFSET = UI.ICON_OFFSET_Y or 15
local COMBO_LAYOUT_OFFSET = 16
local MISSING_GRACE = 0.20
local NAME_HIDDEN_COMPACT_SHIFT = 10

local _, playerClass = UnitClass("player")

local IMM_ERR_LAST = {}
local function ReportImmunityError(stage, err)
  local now = GetTime and GetTime() or 0
  local last = IMM_ERR_LAST[stage] or -100
  if now - last < 1.5 then return end
  IMM_ERR_LAST[stage] = now
  local msg = "|cffff4444BNP IMM ERROR [" .. tostring(stage) .. "]|r " .. tostring(err)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(msg)
  end
end

local IMMUNITY_DEFS = {
  {
    key = "divine_shield",
    names = { "Divine Shield", "Gottesschild" },
    spellIDs = { 642, 1020 },
    durations = { [642] = 10, [1020] = 12 },
    defaultDuration = 12,
    textureMatches = { "spell_holy_divineintervention" },
    selfOnly = true,
  },
  {
    key = "divine_protection",
    names = { "Divine Protection", "Göttlicher Schutz" },
    spellIDs = { 498, 5573 },
    durations = { [498] = 6, [5573] = 8 },
    defaultDuration = 8,
    selfOnly = true,
  },
  {
    key = "blessing_of_protection",
    names = { "Blessing of Protection", "Segen des Schutzes" },
    spellIDs = { 1022, 5599, 10278 },
    durations = { [1022] = 6, [5599] = 8, [10278] = 10 },
    defaultDuration = 10,
    textureMatches = { "spell_holy_sealofprotection" },
  },
  {
    key = "ice_block",
    names = { "Ice Block", "Eisblock" },
    spellIDs = { 11958 },
    durations = { [11958] = 10 },
    defaultDuration = 10,
    textureMatches = { "spell_frost_frost" },
    selfOnly = true,
  },
  {
    key = "berserker_rage",
    names = { "Berserker Rage", "Berserkerwut" },
    spellIDs = { 18499 },
    durations = { [18499] = 10 },
    defaultDuration = 10,
    selfOnly = true,
  },
  {
    key = "death_wish",
    names = { "Death Wish", "Todeswunsch" },
    spellIDs = { 12328 },
    durations = { [12328] = 30 },
    defaultDuration = 30,
    selfOnly = true,
  },
  {
    key = "recklessness",
    names = { "Recklessness", "Tollkühnheit" },
    spellIDs = { 1719 },
    durations = { [1719] = 15 },
    defaultDuration = 15,
    selfOnly = true,
  },
  {
    key = "fear_ward",
    names = { "Fear Ward", "Furchtzauberschutz" },
    spellIDs = { 6346 },
    durations = { [6346] = 600 },
    defaultDuration = 600,
  },
  {
    key = "will_of_the_forsaken",
    names = { "Will of the Forsaken", "Wille der Verlassenen" },
    spellIDs = { 7744 },
    durations = { [7744] = 5 },
    defaultDuration = 5,
    selfOnly = true,
  },
}

local DEF_BY_ID = {}
local DEF_BY_NAME = {}

local function Lower(value)
  if type(value) ~= "string" or value == "" then return nil end
  return string.lower(value)
end

local function DefDuration(def, spellID)
  if def and def.durations and spellID and def.durations[spellID] then
    return def.durations[spellID]
  end
  return def and def.defaultDuration or nil
end

local function BuildLookup()
  local i, j, def, id, name
  for i = 1, table.getn(IMMUNITY_DEFS) do
    def = IMMUNITY_DEFS[i]
    if def.names then
      for j = 1, table.getn(def.names) do
        name = Lower(def.names[j])
        if name then DEF_BY_NAME[name] = def end
      end
    end
    if def.spellIDs then
      for j = 1, table.getn(def.spellIDs) do
        id = def.spellIDs[j]
        DEF_BY_ID[id] = def
        if SpellInfo then
          local spellName = SpellInfo(id)
          spellName = Lower(spellName)
          if spellName then DEF_BY_NAME[spellName] = def end
        end
      end
    end
  end
end
BuildLookup()

local function TextureMatches(def, texture)
  local t = Lower(texture)
  if not def or not t or not def.textureMatches then return false end
  local i
  for i = 1, table.getn(def.textureMatches) do
    local pattern = Lower(def.textureMatches[i])
    if pattern and string.find(t, pattern, 1, true) then return true end
  end
  return false
end

local function FindDef(spellID, name, texture)
  -- STRICT WHITELIST: an aura is only an immunity when its spell ID or exact
  -- spell name is configured above. Do not guess from a shared icon/texture.
  -- Many unrelated server buffs reuse Blizzard icons (e.g. armor/world buffs),
  -- which previously allowed false positives such as Forest Armor.
  local sid = tonumber(spellID)
  if sid then
    return DEF_BY_ID[sid]
  end

  local n = Lower(name)
  if n then
    return DEF_BY_NAME[n]
  end

  return nil
end

local function GetIconSize()
  if BNP.GetImmunityIconSize then return BNP:GetImmunityIconSize() end
  if BNP.GetIconSize then return BNP:GetIconSize() end
  return 18
end

local function GetPosition()
  if BNP.GetImmunityPosition then return BNP:GetImmunityPosition() end
  return "top"
end

local function GetVisualParent(plate)
  if plate and plate.GetParent then
    local p = plate:GetParent()
    if p then return p end
  end
  return WorldFrame or UIParent
end

local function GetBaseTopOffset()
  local y = BASE_TOP_OFFSET
  if (playerClass == "ROGUE" or playerClass == "DRUID")
    and BNP.AreComboPointsEnabled and BNP:AreComboPointsEnabled() then
    y = y + COMBO_LAYOUT_OFFSET
  end
  return y
end

local function IsTopDebuffPosition(position)
  return position == "top" or position == "top_left" or position == "top_right"
end

local function GetTopOffset()
  local auraSize = BNP.GetIconSize and BNP:GetIconSize() or 18
  local ccSize = BNP.GetCCIconSize and BNP:GetCCIconSize() or auraSize
  local debuffPosition = BNP.GetDebuffPosition and BNP:GetDebuffPosition() or "top"
  local ccPosition = BNP.GetCCPosition and BNP:GetCCPosition() or debuffPosition
  local debuffs = not BNP.AreDebuffsEnabled or BNP:AreDebuffsEnabled()
  local ccs = not BNP.AreCrowdControlEnabled or BNP:AreCrowdControlEnabled()
  local separateCC = ccs and debuffs and ccPosition == "top" and IsTopDebuffPosition(debuffPosition)
    and BNP.IsSeparateCCRowEnabled and BNP:IsSeparateCCRowEnabled()
  local y = GetBaseTopOffset()

  if separateCC then
    y = y + auraSize + ICON_SPACING + ccSize + ICON_SPACING
  else
    local rowHeight = 0
    if debuffs and IsTopDebuffPosition(debuffPosition) then rowHeight = math.max(rowHeight, auraSize) end
    if ccs and ccPosition == "top" then rowHeight = math.max(rowHeight, ccSize) end
    if rowHeight > 0 then y = y + rowHeight + ICON_SPACING end
  end
  return y
end

local function FrameShown(frame)
  return frame and frame.IsShown and frame:IsShown() and true or false
end

local function GetBottomOffset(plate)
  local auraSize = BNP.GetIconSize and BNP:GetIconSize() or 18
  local ccSize = BNP.GetCCIconSize and BNP:GetCCIconSize() or auraSize
  local debuffPosition = BNP.GetDebuffPosition and BNP:GetDebuffPosition() or "top"
  local ccPosition = BNP.GetCCPosition and BNP:GetCCPosition() or debuffPosition
  local debuffs = not BNP.AreDebuffsEnabled or BNP:AreDebuffsEnabled()
  local ccs = not BNP.AreCrowdControlEnabled or BNP:AreCrowdControlEnabled()
  local separateCC = ccs and debuffs and ccPosition == "bottom" and debuffPosition == "bottom"
    and BNP.IsSeparateCCRowEnabled and BNP:IsSeparateCCRowEnabled()

  local harmfulDepth = 0
  if separateCC then
    -- The CC row is physically the second row, so preserve the first-row
    -- offset whenever that second row is visible.
    if FrameShown(plate and plate.BNPCCContainer) then
      harmfulDepth = auraSize + ICON_SPACING + ccSize
    elseif FrameShown(plate and plate.BNPAuraContainer) then
      harmfulDepth = auraSize
    end
  else
    if debuffs and debuffPosition == "bottom" and FrameShown(plate and plate.BNPAuraContainer) then
      harmfulDepth = math.max(harmfulDepth, auraSize)
    end
    if ccs and ccPosition == "bottom" then
      if ccPosition == debuffPosition then
        if FrameShown(plate and plate.BNPAuraContainer) then harmfulDepth = math.max(harmfulDepth, ccSize) end
      elseif FrameShown(plate and plate.BNPCCContainer) then
        harmfulDepth = math.max(harmfulDepth, ccSize)
      end
    end
  end

  local y = BOTTOM_SPACING
  if harmfulDepth > 0 then y = y + harmfulDepth + ICON_SPACING end
  return y
end

local function GetSideOffset(position)
  local auraSize = BNP.GetIconSize and BNP:GetIconSize() or 18
  local ccSize = BNP.GetCCIconSize and BNP:GetCCIconSize() or auraSize
  local debuffPosition = BNP.GetDebuffPosition and BNP:GetDebuffPosition() or "top"
  local ccPosition = BNP.GetCCPosition and BNP:GetCCPosition() or debuffPosition
  local debuffs = not BNP.AreDebuffsEnabled or BNP:AreDebuffsEnabled()
  local ccs = not BNP.AreCrowdControlEnabled or BNP:AreCrowdControlEnabled()
  local rowHeight = 0
  if debuffs and debuffPosition == position then rowHeight = math.max(rowHeight, auraSize) end
  if ccs and ccPosition == position then rowHeight = math.max(rowHeight, ccSize) end
  if rowHeight > 0 then return (rowHeight / 2) + ICON_SPACING + (GetIconSize() / 2) end
  return 0
end

local function GetRegionWidth(region)
  if not region then return 0 end
  if region.IsShown and not region:IsShown() then return 0 end
  if region.GetStringWidth then
    local w = tonumber(region:GetStringWidth()) or 0
    if w > 0 then return w end
  end
  if region.GetWidth then return math.max(0, tonumber(region:GetWidth()) or 0) end
  return 0
end

local function GetRightSpacing(plate)
  local extra = GetRegionWidth(plate and plate.level) + GetRegionWidth(plate and plate.levelicon)
  if extra > 0 then extra = extra + 6 end
  return SIDE_SPACING + extra
end

local function AnchorContainer(plate, container)
  if not plate or not container then return end
  container:ClearAllPoints()
  local position = GetPosition()
  local anchor = plate.healthbar or plate

  if position == "left" then
    container:SetPoint("RIGHT", anchor, "LEFT", -SIDE_SPACING, GetSideOffset("left"))
  elseif position == "right" then
    container:SetPoint("LEFT", anchor, "RIGHT", GetRightSpacing(plate), GetSideOffset("right"))
  else
    local nameHidden = (BNP.IsPlateNameHidden and BNP:IsPlateNameHidden(plate)) or plate.BNPNameHidden
    local compactShift = nameHidden and -NAME_HIDDEN_COMPACT_SHIFT or 0
    if plate.healthbar then
      container:SetPoint("BOTTOM", plate.healthbar, "TOP", 0, GetTopOffset() + compactShift)
    else
      container:SetPoint("BOTTOM", plate, "BOTTOM", 0, 24 + GetTopOffset() + compactShift)
    end
  end
end

function BNP:RefreshImmunityLayoutForPlate(plate)
  if not plate or not plate.BNPImmunityContainer then return end
  AnchorContainer(plate, plate.BNPImmunityContainer)
end

local function ApplyFrameLevel(plate, container)
  if not plate or not container then return end
  if plate.GetFrameStrata and container.GetFrameStrata and container.SetFrameStrata then
    local strata = plate:GetFrameStrata()
    if strata and container:GetFrameStrata() ~= strata then
      container:SetFrameStrata(strata)
    end
  end
  if plate.GetFrameLevel and container.GetFrameLevel and container.SetFrameLevel then
    local level = math.max(0, (tonumber(plate:GetFrameLevel()) or 0) + 1)
    if container:GetFrameLevel() ~= level then container:SetFrameLevel(level) end
    local i
    for i = 1, table.getn(container.icons or {}) do
      local icon = container.icons[i]
      if icon and icon.GetFrameLevel and icon.SetFrameLevel and icon:GetFrameLevel() ~= level then
        icon:SetFrameLevel(level)
      end
    end
  end
end

local function CreateIcon(parent, index)
  local size = GetIconSize()
  local icon = CreateFrame("Frame", nil, parent)
  icon:SetWidth(size)
  icon:SetHeight(size)

  local texture = icon:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(icon)
  icon.texture = texture

  local timer = icon:CreateFontString(nil, "OVERLAY")
  timer:SetFont(UI.TIMER_FONT or "Fonts\\FRIZQT__.TTF", UI.TIMER_SIZE or 8, "OUTLINE")
  timer:SetPoint("CENTER", icon, "CENTER", UI.TIMER_OFFSET_X or 0, UI.TIMER_OFFSET_Y or 0)
  timer:SetTextColor(1, 1, 1)
  icon.timer = timer

  icon.index = index
  icon:Hide()
  return icon
end

local function LayoutContainer(plate, container)
  if not plate or not container then return end
  local size = GetIconSize()
  local position = GetPosition()
  local i

  if container.BNPLastSize ~= size or container.BNPLastIconPosition ~= position then
    container.BNPLastSize = size
    container.BNPLastIconPosition = position
    container:SetWidth(size * MAX_ICONS + ICON_SPACING * (MAX_ICONS - 1))
    container:SetHeight(size)
    for i = 1, table.getn(container.icons or {}) do
      local icon = container.icons[i]
      icon:SetWidth(size)
      icon:SetHeight(size)
      icon:ClearAllPoints()
      if position == "left" then
        icon:SetPoint("RIGHT", container, "RIGHT", -((i - 1) * (size + ICON_SPACING)), 0)
      else
        icon:SetPoint("LEFT", container, "LEFT", (i - 1) * (size + ICON_SPACING), 0)
      end
    end
  end

  -- Cheap layout key; avoids touching anchors every scan.
  local layoutKey = tostring(position) .. ":" ..
    tostring(BNP.GetDebuffPosition and BNP:GetDebuffPosition() or "top") .. ":" ..
    tostring(BNP.GetCCPosition and BNP:GetCCPosition() or "top") .. ":" ..
    tostring(BNP.IsSeparateCCRowEnabled and BNP:IsSeparateCCRowEnabled()) .. ":" ..
    tostring(BNP.GetIconSize and BNP:GetIconSize() or 18) .. ":" ..
    tostring(BNP.GetCCIconSize and BNP:GetCCIconSize() or 18) .. ":" .. tostring(size) .. ":" ..
    tostring(plate.BNPNameHidden and true or false) .. ":" ..
    tostring(FrameShown(plate.BNPAuraContainer)) .. ":" ..
    tostring(FrameShown(plate.BNPCCContainer))

  if container.BNPLastLayoutKey ~= layoutKey then
    container.BNPLastLayoutKey = layoutKey
    AnchorContainer(plate, container)
  end
  ApplyFrameLevel(plate, container)
end

local function HideContainer(plate)
  local container = plate and plate.BNPImmunityContainer
  if not container then return end
  local i
  for i = 1, table.getn(container.icons or {}) do container.icons[i]:Hide() end
  container:Hide()
end

local function InstallHideGuard(plate)
  if not plate or plate.BNPImmunityHideGuard then return end
  local oldOnHide = plate:GetScript("OnHide")
  plate:SetScript("OnHide", function()
    if oldOnHide then oldOnHide() end
    HideContainer(this or plate)
  end)
  plate.BNPImmunityHideGuard = true
end

local function CreateContainer(plate)
  if not plate or plate.BNPImmunityContainer then return end
  if BNP.RegisterPlate then BNP:RegisterPlate(plate) end

  local container = CreateFrame("Frame", nil, GetVisualParent(plate))
  container.icons = {}
  local i
  for i = 1, MAX_ICONS do container.icons[i] = CreateIcon(container, i) end
  plate.BNPImmunityContainer = container
  LayoutContainer(plate, container)
  container:Hide()
  InstallHideGuard(plate)
end

local function GetCache(guid)
  if not guid then return nil end
  local cache = BNP.guidImmunities[guid]
  if not cache then
    cache = { _nextOrder = 0 }
    BNP.guidImmunities[guid] = cache
  end
  return cache
end

local function CommitSeen(guid, def, spellID, texture, duration, expires, now, source)
  if not guid or not def then return end
  local cache = GetCache(guid)
  local entry = cache[def.key]
  if not entry then
    cache._nextOrder = (cache._nextOrder or 0) + 1
    entry = { order = cache._nextOrder }
    cache[def.key] = entry
  end

  entry.spellID = tonumber(spellID) or entry.spellID
  entry.texture = texture or entry.texture
  entry.duration = tonumber(duration) or entry.duration or DefDuration(def, tonumber(spellID))
  entry.lastSeen = now
  entry.missingSince = nil
  if source == "capi" then
    entry.capiConfirmed = true
    entry.capiMissingSince = nil
  elseif source == "unitbuff" then
    entry.unitBuffConfirmed = true
    entry.unitBuffMissingSince = nil
  end

  expires = tonumber(expires)
  if expires and expires > now then
    entry.expires = expires
  elseif not entry.expires or entry.expires <= now then
    local d = entry.duration or DefDuration(def, entry.spellID)
    if d then entry.expires = now + d end
  end
end

-- These full immunities also cleanse harmful effects in Classic. Keep the
-- harmful-debuff module hard-suppressed while the immunity entry is active.
local CLEANSE_ALL = {
  divine_shield = true,
  ice_block = true,
}

local function ApplyCleanseSuppression(guid, def, entry, now)
  if not guid or not def or not CLEANSE_ALL[def.key] then return end
  if not entry then return end
  local remaining = entry.expires and (entry.expires - now) or nil
  if remaining and remaining <= 0 then return end
  if BNP.SuppressHarmfulAurasForImmunity then
    -- Renewable short hold: immediate cleanse now, but if Ice Block/Bubble is
    -- clicked off early the suppression naturally expires within a fraction
    -- of a second instead of hiding new debuffs until the guessed full timer.
    BNP:SuppressHarmfulAurasForImmunity(guid, 0.45)
  end
end

local function ParseDurationExpiry(now, a5, a6, a7, a8, a9, a10)
  local vals = { a5, a6, a7, a8, a9, a10 }
  local i
  for i = 1, table.getn(vals) - 1 do
    local d = tonumber(vals[i])
    local e = tonumber(vals[i + 1])
    if d and e and d > 0 and d <= 3600 and e > now then return d, e end
  end
  return nil, nil
end

local function ReconcileMissingSource(guid, source, seen, now)
  local cache = guid and BNP.guidImmunities[guid] or nil
  if not cache then return end

  local d, def, entry, confirmedKey, missingKey
  if source == "capi" then
    confirmedKey = "capiConfirmed"
    missingKey = "capiMissingSince"
  else
    confirmedKey = "unitBuffConfirmed"
    missingKey = "unitBuffMissingSince"
  end

  for d = 1, table.getn(IMMUNITY_DEFS) do
    def = IMMUNITY_DEFS[d]
    entry = cache[def.key]
    if entry and entry[confirmedKey] then
      if seen and seen[def.key] then
        entry[missingKey] = nil
      else
        if not entry[missingKey] then entry[missingKey] = now end
        if now - entry[missingKey] >= MISSING_GRACE then
          -- Once a live aura source has positively confirmed this exact
          -- immunity, that same source becomes authoritative for early
          -- removals (Ice Block clicked off, Bubble canceled/removed, dispel).
          cache[def.key] = nil
        end
      end
    end
  end
end

local function ScanClassicAPIBuffs(unit, guid, now)
  if not unit or not guid then return false end
  if type(C_UnitAuras) ~= "table" then return false end

  local seen = {}

  -- Preferred path: ask ClassicAPI directly for the whitelisted spell IDs.
  -- Its aura cache is evicted by the client's real OnAuraRemoved hook, so an
  -- Ice Block that is clicked off disappears here immediately instead of
  -- living until the guessed cast timer ends.
  if type(C_UnitAuras.GetUnitAuraBySpellID) == "function" then
    local anyCallWorked = false
    local d, j, def, sid, ok, aura
    for d = 1, table.getn(IMMUNITY_DEFS) do
      def = IMMUNITY_DEFS[d]
      if def.spellIDs then
        for j = 1, table.getn(def.spellIDs) do
          sid = def.spellIDs[j]
          ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, sid, "HELPFUL")
          if ok then
            anyCallWorked = true
            if type(aura) == "table" then
              local auraID = tonumber(aura.spellId or aura.spellID) or sid
              local matched = FindDef(auraID, aura.name, aura.icon or aura.texture)
              if matched then
                seen[matched.key] = true
                CommitSeen(guid, matched, auraID, aura.icon or aura.texture,
                  tonumber(aura.duration), tonumber(aura.expirationTime), now, "capi")
                break
              end
            end
          else
            -- If this build rejects the exact getter, fall back to index scan
            -- below and never use a failed call as negative evidence.
            anyCallWorked = false
            break
          end
        end
      end
      if not anyCallWorked and d == 1 then break end
    end

    if anyCallWorked then
      ReconcileMissingSource(guid, "capi", seen, now)
      return true
    end
  end

  local getter = nil
  local useFilter = false
  if type(C_UnitAuras.GetBuffDataByIndex) == "function" then
    getter = C_UnitAuras.GetBuffDataByIndex
  elseif type(C_UnitAuras.GetAuraDataByIndex) == "function" then
    getter = C_UnitAuras.GetAuraDataByIndex
    useFilter = true
  end
  if not getter then return false end

  local completed = true
  local i
  for i = 1, 48 do
    local ok, aura
    if useFilter then
      ok, aura = pcall(getter, unit, i, "HELPFUL")
    else
      ok, aura = pcall(getter, unit, i)
    end
    if not ok then completed = false break end
    if not aura then break end

    if type(aura) == "table" then
      local spellID = tonumber(aura.spellId or aura.spellID)
      local def = FindDef(spellID, aura.name, aura.icon or aura.texture)
      if def then
        seen[def.key] = true
        CommitSeen(guid, def, spellID, aura.icon or aura.texture,
          tonumber(aura.duration), tonumber(aura.expirationTime), now, "capi")
      end
    end
  end

  if completed then ReconcileMissingSource(guid, "capi", seen, now) end
  return completed
end

local function ScanUnitBuffs(unit, guid, now)
  if not unit or not guid or not UnitBuff then return false end

  local seen = {}
  local completed = true
  local i
  for i = 1, 64 do
    local ok, texture, applications, buffID, a4, a5, a6, a7, a8, a9, a10 = pcall(UnitBuff, unit, i)
    if not ok then completed = false break end
    if not texture then break end

    local spellID = tonumber(buffID)
    if not spellID then
      if type(a4) == "number" then spellID = a4
      elseif type(a5) == "number" then spellID = a5 end
    end
    if spellID and spellID < -1 then spellID = spellID + 65536 end

    local auraName = nil
    if spellID and SpellInfo then auraName = SpellInfo(spellID) end
    local def = FindDef(spellID, auraName, texture)
    if def then
      seen[def.key] = true
      local duration, expires = ParseDurationExpiry(now, a4, a5, a6, a7, a8, a9, a10)
      CommitSeen(guid, def, spellID, texture, duration, expires, now, "unitbuff")
    end
  end

  -- UnitBuff is only allowed to remove an immunity after UnitBuff itself has
  -- positively seen that exact whitelist entry at least once. This preserves
  -- the cast-event fallback on clients where hostile helpful auras are hidden,
  -- while still making clicked-off buffs disappear immediately when visible.
  if completed then ReconcileMissingSource(guid, "unitbuff", seen, now) end
  return completed
end

local function ResolveClassicAuraUnit(guid, targetGUID)
  if not guid then return nil end
  if targetGUID and guid == targetGUID then return "target" end

  if type(UnitTokenFromGUID) == "function" then
    local ok, token = pcall(UnitTokenFromGUID, guid)
    if ok and token and token ~= "" then return token end
  end
  return nil
end

local function FormatTimer(remaining)
  if not remaining or remaining <= 0 then return "" end
  if remaining >= 3600 then return math.ceil(remaining / 3600) .. "h" end
  if remaining >= 60 then return math.ceil(remaining / 60) .. "m" end
  return tostring(math.ceil(remaining))
end

local function Render(plate, guid, now)
  local container = plate and plate.BNPImmunityContainer
  if not container then return end
  LayoutContainer(plate, container)

  local cache = guid and BNP.guidImmunities[guid] or nil
  local active = {}
  local d, def, entry, remaining
  for d = 1, table.getn(IMMUNITY_DEFS) do
    def = IMMUNITY_DEFS[d]
    entry = cache and cache[def.key] or nil
    remaining = entry and entry.expires and (entry.expires - now) or nil
    if entry and (not entry.expires or (remaining and remaining > 0)) then
      ApplyCleanseSuppression(guid, def, entry, now)
      if table.getn(active) < MAX_ICONS then
        table.insert(active, { def = def, entry = entry, remaining = remaining })
      end
    elseif cache and entry and entry.expires and remaining and remaining <= 0 then
      cache[def.key] = nil
    end
  end

  if table.getn(active) > 1 then
    table.sort(active, function(a, b) return (a.entry.order or 0) < (b.entry.order or 0) end)
  end

  local count = table.getn(active)
  local size = GetIconSize()
  local visibleWidth = size
  if count > 1 then visibleWidth = size * count + ICON_SPACING * (count - 1) end
  container:SetWidth(visibleWidth)

  local i
  for i = 1, MAX_ICONS do
    local icon = container.icons[i]
    local item = active[i]
    if item then
      local texture = item.entry.texture
      if not texture and item.entry.spellID and SpellInfo then
        local _, _, spellTexture = SpellInfo(item.entry.spellID)
        texture = spellTexture
      end
      if texture then icon.texture:SetTexture(texture) end
      icon.timer:SetText(FormatTimer(item.remaining))
      icon:Show()
    else
      icon.timer:SetText("")
      icon:Hide()
    end
  end

  if count > 0 then container:Show() else container:Hide() end
end

local function GetTargetGUID()
  if not UnitExists then return nil end
  local exists, guid = UnitExists("target")
  if exists and guid then return guid end
  return nil
end

local function GetPlateGUID(plate)
  if not plate or not plate.GetName then return nil end
  local token = plate:GetName(1)
  if token and token ~= "" then return token end
  return nil
end

local function UpdatePlate(plate)
  if not plate or not plate:IsShown() then
    HideContainer(plate)
    return
  end
  if BNP.ArePvPImmunitiesEnabled and not BNP:ArePvPImmunitiesEnabled() then
    HideContainer(plate)
    return
  end
  if not plate.BNPImmunityContainer then CreateContainer(plate) end

  local now = GetTime()
  local guid = BNP.GetStablePlateAuraGUID and BNP.GetStablePlateAuraGUID(plate, now) or GetPlateGUID(plate)
  if not guid then HideContainer(plate) return end

  local targetGUID = GetTargetGUID()
  local unit = nil
  if targetGUID and targetGUID == guid then
    unit = "target"
  else
    unit = GetPlateGUID(plate)
  end

  -- Scan the two aura surfaces independently. ClassicAPI nameplateN tokens are
  -- preferred when available; SuperWoW's raw GUID token remains the legacy
  -- UnitBuff fallback. Do not let one resolver's player check block the other.
  local classicUnit = ResolveClassicAuraUnit(guid, targetGUID)
  local classicCanScan = classicUnit ~= nil
  if classicCanScan and UnitIsPlayer then
    classicCanScan = UnitIsPlayer(classicUnit) and true or false
  end
  if classicCanScan then ScanClassicAPIBuffs(classicUnit, guid, now) end

  local legacyCanScan = unit ~= nil
  if legacyCanScan and UnitIsPlayer then
    legacyCanScan = UnitIsPlayer(unit) and true or false
  end
  if legacyCanScan then ScanUnitBuffs(unit, guid, now) end

  Render(plate, guid, now)
end

-- UNIT_CASTEVENT is a fast timer seed. Once ClassicAPI/UnitBuff has
-- positively confirmed the aura, that live source also removes it early when
-- the buff is canceled, dispelled, or otherwise ends before its timer.
local castFrame = CreateFrame("Frame")
castFrame:RegisterEvent("UNIT_CASTEVENT")
local function HandleImmunityCastEvent()
  local casterGUID = arg1
  local targetGUID = arg2
  local eventType = arg3
  local spellID = tonumber(arg4)
  if spellID and spellID < -1 then spellID = spellID + 65536 end

  -- Keep the last raw event for /bnpimm diagnostics. This is intentionally
  -- cheap and lets us verify instant enemy casts without another addon.
  BNP._immLastCast = {
    casterGUID = casterGUID,
    targetGUID = targetGUID,
    eventType = eventType,
    spellID = spellID,
    time = GetTime(),
  }

  if not casterGUID or not spellID then return end
  if eventType ~= "CAST" and eventType ~= "CHANNEL" then return end

  local texture = nil
  local spellName = nil
  if SpellInfo then
    spellName, _, texture = SpellInfo(spellID)
  end
  local def = DEF_BY_ID[spellID] or FindDef(spellID, spellName, texture)
  if not def then return end

  local guid = def.selfOnly and casterGUID or (targetGUID or casterGUID)
  local now = GetTime()
  local duration = DefDuration(def, spellID)
  if duration then
    CommitSeen(guid, def, spellID, texture, duration, now + duration, now)
    local cache = BNP.guidImmunities and BNP.guidImmunities[guid]
    ApplyCleanseSuppression(guid, def, cache and cache[def.key], now)
  end
end

castFrame:SetScript("OnEvent", function()
  local ok, err = pcall(HandleImmunityCastEvent)
  if not ok then ReportImmunityError("cast", err) end
end)

function BNP:RefreshImmunityVisibility()
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate then
      if self:ArePvPImmunitiesEnabled() then
        if not plate.BNPImmunityContainer then CreateContainer(plate) end
      else
        HideContainer(plate)
      end
    end
  end
end

function BNP:RefreshAllImmunityLayouts()
  local plate
  for plate in pairs(BNP.plates or {}) do
    if plate and plate.BNPImmunityContainer then
      plate.BNPImmunityContainer.BNPLastLayoutKey = nil
      plate.BNPImmunityContainer.BNPLastSize = nil
      plate.BNPImmunityContainer.BNPLastIconPosition = nil
      LayoutContainer(plate, plate.BNPImmunityContainer)
    end
  end
end

-- Small temporary diagnostic for this test build. Target a bubbled player and
-- type /bnpimm. It prints the raw UnitBuff slots BNP sees, including spell ID
-- when SuperWoW exposes it. This makes server/client differences obvious without
-- relying on another addon's truncated error window.
SLASH_BNPIMMUNITYDEBUG1 = "/bnpimm"
SlashCmdList["BNPIMMUNITYDEBUG"] = function()
  if not DEFAULT_CHAT_FRAME then return end
  local exists, guid = UnitExists("target")
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BNP IMM DEBUG|r targetGUID=" .. tostring(guid or "nil") .. " player=" .. tostring(UnitIsPlayer and UnitIsPlayer("target")))

  local last = BNP._immLastCast
  if last then
    DEFAULT_CHAT_FRAME:AddMessage("  last CASTEVENT type=" .. tostring(last.eventType) .. " id=" .. tostring(last.spellID) .. " caster=" .. tostring(last.casterGUID) .. " target=" .. tostring(last.targetGUID))
  else
    DEFAULT_CHAT_FRAME:AddMessage("  last CASTEVENT: none seen")
  end

  if not exists then return end

  local capiFound = 0
  if type(C_UnitAuras) == "table" then
    local getter = nil
    local useFilter = false
    if type(C_UnitAuras.GetBuffDataByIndex) == "function" then
      getter = C_UnitAuras.GetBuffDataByIndex
    elseif type(C_UnitAuras.GetAuraDataByIndex) == "function" then
      getter = C_UnitAuras.GetAuraDataByIndex
      useFilter = true
    end
    DEFAULT_CHAT_FRAME:AddMessage("  ClassicAPI aura getter=" .. tostring(getter ~= nil))
    if getter then
      local i
      for i = 1, 16 do
        local ok, aura
        if useFilter then ok, aura = pcall(getter, "target", i, "HELPFUL")
        else ok, aura = pcall(getter, "target", i) end
        if not ok then
          DEFAULT_CHAT_FRAME:AddMessage("  CAPI error slot " .. tostring(i) .. ": " .. tostring(aura))
          break
        end
        if not aura then break end
        if type(aura) == "table" then
          local sid = tonumber(aura.spellId or aura.spellID)
          local def = FindDef(sid, aura.name, aura.icon or aura.texture)
          if def then capiFound = capiFound + 1 end
          if def then
            DEFAULT_CHAT_FRAME:AddMessage("  CAPI MATCH " .. tostring(i) .. " id=" .. tostring(sid) .. " name=" .. tostring(aura.name) .. " tex=" .. tostring(aura.icon or aura.texture))
          end
        else
          DEFAULT_CHAT_FRAME:AddMessage("  CAPI slot " .. tostring(i) .. " returned " .. type(aura) .. ": " .. tostring(aura))
        end
      end
    end
  else
    DEFAULT_CHAT_FRAME:AddMessage("  ClassicAPI C_UnitAuras: unavailable")
  end

  local ubFound = 0
  local i
  for i = 1, 32 do
    local ok, texture, stacks, buffID, a4, a5, a6 = pcall(UnitBuff, "target", i)
    if not ok then
      DEFAULT_CHAT_FRAME:AddMessage("  UnitBuff error slot " .. tostring(i) .. ": " .. tostring(texture))
      break
    end
    if not texture then break end
    local spellID = tonumber(buffID)
    if not spellID and type(a4) == "number" then spellID = a4 end
    if spellID and spellID < -1 then spellID = spellID + 65536 end
    local def = FindDef(spellID, spellID and SpellInfo and SpellInfo(spellID) or nil, texture)
    if def then ubFound = ubFound + 1 end
    if def then
      DEFAULT_CHAT_FRAME:AddMessage("  UB MATCH " .. tostring(i) .. " id=" .. tostring(spellID) .. " tex=" .. tostring(texture))
    end
  end
  if capiFound == 0 and ubFound == 0 then
    DEFAULT_CHAT_FRAME:AddMessage("  no configured immunity matched live target buffs")
  end
end

-- Sanity-check the whole module callback so one optional PvP feature can never
-- stop any other BNP nameplate module.
local function SafeCreateContainer(plate)
  local ok, err = pcall(CreateContainer, plate)
  if not ok then ReportImmunityError("create", err) end
end

local function SafeUpdatePlate(plate)
  local ok, err = pcall(UpdatePlate, plate)
  if not ok then ReportImmunityError("update", err) end
end

table.insert(BNP.libnameplate.OnInit, SafeCreateContainer)
table.insert(BNP.libnameplate.OnShow, SafeCreateContainer)
table.insert(BNP.libnameplate.OnUpdate, SafeUpdatePlate)
