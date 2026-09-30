BNP = BNP or {}

-- Optional live debuffs from other players/classes.
-- Kept outside auras.lua because that file is already close to Vanilla Lua's
-- per-chunk local-variable limit. This module owns only the foreign live cache;
-- BNP's proven own-cast tracker remains completely separate.

BNP.guidOtherDebuffs = BNP.guidOtherDebuffs or {}

local SEEN = {}
local seenGeneration = 0

function BNP:WantsOtherDebuffs()
  return self.AreOtherDebuffsEnabled and self:AreOtherDebuffsEnabled()
    and self.HasSelectedOtherDebuffs and self:HasSelectedOtherDebuffs()
    and self.OtherDebuffByID ~= nil
end

function BNP:IsOtherDebuffDefSelected(def)
  return def and self.IsOtherDebuffSelected and self:IsOtherDebuffSelected(def.key)
end

function BNP:SyncOtherDebuffs(unit, guid, now, snapshot, eventAuthoritative)
  if not unit or not guid then return end

  if not self:WantsOtherDebuffs() then
    self.guidOtherDebuffs[guid] = nil
    return
  end

  seenGeneration = seenGeneration + 1
  local generation = seenGeneration
  local live = self.guidOtherDebuffs[guid]
  local i
  local maxIndex = snapshot and snapshot.count or 64

  for i = 1, maxIndex do
    local texture, stacks, auraSpellID, duration, expirationTime, source
    if snapshot then
      local entry = snapshot.entries[i]
      if not entry then break end
      texture = entry[1]
      stacks = entry[2]
      auraSpellID = entry[4]
      duration = entry[5]
      expirationTime = entry[6]
      source = entry[7]
    else
      local dtype
      texture, stacks, dtype, auraSpellID, duration, expirationTime, source = self:_ReadClassicDebuff(unit, i)
      if not texture then break end
    end

    local def = auraSpellID and self.OtherDebuffByID and self.OtherDebuffByID[auraSpellID] or nil
    -- This feature is specifically for auras from other players/classes. When
    -- ClassicAPI positively identifies our own source, let the proven own-cast
    -- tracker remain the only owner of that icon/timer.
    if def and self:IsOtherDebuffDefSelected(def) and not self:_IsOwnClassicAuraSource(source) then
      SEEN[def.key] = generation
      if not live then
        live = {}
        self.guidOtherDebuffs[guid] = live
      end

      local aura = live[def.key]
      if not aura then
        aura = {
          firstSeen = now,
          order = def.order or (1000 + i),
        }
        live[def.key] = aura
      end

      local previousStacks = tonumber(aura.stacks) or 0
      local currentStacks = tonumber(stacks) or 0
      aura.def = def
      aura.spellID = auraSpellID
      aura.texture = texture or (self.GetOtherDebuffTexture and self:GetOtherDebuffTexture(def)) or def.texture
      aura.stacks = currentStacks
      aura.lastSeen = now
      aura.livePresence = true
      aura.eventDriven = eventAuthoritative and true or false
      aura.missingScans = nil

      local fallbackDuration = self.GetOtherDebuffDuration and self:GetOtherDebuffDuration(def, auraSpellID) or def.duration
      local liveDuration = tonumber(duration)
      local liveExpires = tonumber(expirationTime)
      if liveExpires and liveExpires > now then
        aura.duration = liveDuration and liveDuration > 0 and liveDuration or fallbackDuration
        aura.expires = liveExpires
        aura.estimated = nil
      elseif not aura.expires then
        aura.duration = fallbackDuration
        if fallbackDuration and fallbackDuration > 0 then
          aura.expires = now + fallbackDuration
          aura.estimated = true
        end
      elseif currentStacks > previousStacks and fallbackDuration and fallbackDuration > 0 then
        -- Stack-building raid debuffs commonly refresh their duration when a
        -- new stack lands. Only use this estimate when ClassicAPI supplied no
        -- authoritative expiration timestamp.
        aura.duration = fallbackDuration
        aura.expires = now + fallbackDuration
        aura.estimated = true
      end
    end
  end

  if live then
    local key, aura
    for key, aura in pairs(live) do
      local def = aura and aura.def
      if not def or not self:IsOtherDebuffDefSelected(def) then
        live[key] = nil
      elseif SEEN[key] ~= generation then
        aura.missingScans = (aura.missingScans or 0) + 1
        if eventAuthoritative or (aura.missingScans >= 3 and now - (aura.lastSeen or 0) >= 0.40) then
          live[key] = nil
        end
      else
        aura.missingScans = nil
      end
    end
  end
end

function BNP:RefreshOtherDebuffs()
  if not self:AreOtherDebuffsEnabled() then
    self.guidOtherDebuffs = {}
  else
    local guid, live, key, aura
    for guid, live in pairs(self.guidOtherDebuffs or {}) do
      for key, aura in pairs(live or {}) do
        if not aura or not aura.def or not self:IsOtherDebuffSelected(aura.def.key) then
          live[key] = nil
        end
      end
    end
  end

  if self.RefreshDebuffVisibility then self:RefreshDebuffVisibility() end
end

function BNP:ActiveAuraHasSpellID(active, count, spellID)
  if not spellID then return false end
  local i
  for i = 1, count do
    local entry = active[i]
    if entry and entry.aura and entry.aura.spellID == spellID then return true end
  end
  return false
end
