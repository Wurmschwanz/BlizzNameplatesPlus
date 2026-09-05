BNP = BNP or {}

-- Shadow-only spell registry.
-- This module never controls tracking or rendering. It only audits whether a
-- successful local cast could be resolved by a future SpellDB implementation.
BNP.SpellDBShadow = BNP.SpellDBShadow or {
  byID = {},
  byName = {},
  byTexture = {},
  stats = { total = 0, id = 0, name = 0, texture = 0, unknown = 0, ignored = 0 },
  recent = {},
}

local DB = BNP.SpellDBShadow

-- Successful SuperWoW cast events which are not hostile target auras and must
-- not count as missing SpellDB entries. More can be added as Turtle exposes
-- additional proc/engine events during testing.
local IGNORED_SPELL_IDS = {
  [17941] = true, -- Shadow Trance / Nightfall proc
  [836] = true,   -- LOGINEFFECT engine event
}

local function Lower(value)
  if not value then return nil end
  return string.lower(value)
end

local function RegisterDef(def)
  if not def then return end

  if def.names then
    for _, name in ipairs(def.names) do
      DB.byName[Lower(name)] = def
    end
  end

  if def.textureMatch then
    DB.byTexture[Lower(def.textureMatch)] = def
  end

  if def.durations then
    for spellID in pairs(def.durations) do
      DB.byID[spellID] = def
    end
  end

  if def.spellIDs then
    for _, spellID in ipairs(def.spellIDs) do
      DB.byID[spellID] = def
    end
  end
end

for _, def in ipairs(BNP.WarlockAuras or {}) do
  RegisterDef(def)
end

local function FindByTexture(texture)
  local lowerTexture = Lower(texture)
  if not lowerTexture then return nil end

  for fragment, def in pairs(DB.byTexture) do
    if string.find(lowerTexture, fragment) then
      return def
    end
  end

  return nil
end

local function PushRecent(spellID, spellName, result, key)
  local recent = DB.recent
  table.insert(recent, 1, {
    id = spellID,
    name = spellName or "?",
    result = result,
    key = key or "?",
  })

  while table.getn(recent) > 10 do
    table.remove(recent)
  end
end

function BNP:AuditSpellDB(spellID)
  if not spellID or not SpellInfo then return end

  if IGNORED_SPELL_IDS[spellID] then
    DB.stats.ignored = (DB.stats.ignored or 0) + 1
    return
  end

  local spellName, _, texture = SpellInfo(spellID)
  local def = DB.byID[spellID]
  local result = "ID"

  if not def and spellName then
    def = DB.byName[Lower(spellName)]
    result = "NAME"
  end

  if not def and texture then
    def = FindByTexture(texture)
    result = "TEXTURE"
  end

  DB.stats.total = DB.stats.total + 1

  if def then
    if result == "ID" then
      DB.stats.id = DB.stats.id + 1
    elseif result == "NAME" then
      DB.stats.name = DB.stats.name + 1
    else
      DB.stats.texture = DB.stats.texture + 1
    end
    PushRecent(spellID, spellName, result, def.key)
  else
    DB.stats.unknown = DB.stats.unknown + 1
    PushRecent(spellID, spellName, "UNKNOWN", "-")
  end
end

function BNP:PrintSpellDBAudit()
  local stats = DB.stats
  self:Print("SpellDB Schattenmodus – Renderer unverändert.")
  self:Print("Casts: " .. stats.total .. " | ID: " .. stats.id .. " | Name: " .. stats.name .. " | Textur: " .. stats.texture .. " | Unbekannt: " .. stats.unknown .. " | Ignoriert: " .. (stats.ignored or 0))

  if table.getn(DB.recent) == 0 then
    self:Print("Noch keine eigenen erfolgreichen Casts protokolliert.")
    return
  end

  self:Print("Letzte Casts:")
  for i = 1, table.getn(DB.recent) do
    local entry = DB.recent[i]
    self:Print(entry.name .. " [" .. tostring(entry.id) .. "] -> " .. entry.result .. " (" .. entry.key .. ")")
  end
end

function BNP:ResetSpellDBAudit()
  DB.stats.total = 0
  DB.stats.id = 0
  DB.stats.name = 0
  DB.stats.texture = 0
  DB.stats.unknown = 0
  DB.stats.ignored = 0
  for i = table.getn(DB.recent), 1, -1 do
    table.remove(DB.recent, i)
  end
  self:Print("SpellDB-Protokoll zurückgesetzt.")
end
