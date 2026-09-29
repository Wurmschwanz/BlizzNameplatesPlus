BNP = BNP or {}

-- Quest nameplate indicators integrated from QuestPlatesOcto.
-- QuestPlatesOcto is MIT licensed, Copyright (c) 2026 Pap Gergő Rajmund.
-- Original project: https://github.com/papgergo/QuestPlatesOcto
-- The dependency/data lookup approach also credits GabHST/QuestPlates as in
-- the upstream project. See LICENSE-QuestPlatesOcto.txt shipped with BNP.

local KILL_TEXTURE = "Interface\\AddOns\\BlizzNameplatesPlus\\media\\quest_kill.tga"
local ITEM_TEXTURE = "Interface\\AddOns\\BlizzNameplatesPlus\\media\\quest_item.tga"
local ICON_SPACING = 5
local MAX_ICONS_PER_PLATE = 8

local questObjectives = {}
local questIdCache = {}
local questRevision = 0
local updatePending = true
local updateDelay = 0.50
local updateElapsed = 0

local function ClearTable(tbl)
  local key
  for key in pairs(tbl) do tbl[key] = nil end
end

local function Lower(value)
  if not value then return nil end
  return string.lower(tostring(value))
end

local function QuestieReady()
  return QuestieOcto and QuestieOcto.DatabaseAPI and
         QuestieOcto.DatabaseAPI.IsReady and
         QuestieOcto.DatabaseAPI:IsReady()
end

local function PfQuestReady()
  return pfDB and pfDB.quests and pfDB.quests.data and pfDB.quests.loc
end

function BNP:GetQuestPlateDependencyName()
  if QuestieReady() then return "Questie-Octo" end
  if PfQuestReady() then return "pfQuest" end
  return nil
end

local function GetQuestIdByTitle(title, level)
  if not title then return nil end
  local wantedTitle = Lower(title)
  local wantedLevel = tonumber(level)
  local cacheKey = wantedTitle .. "|" .. tostring(wantedLevel or "")
  if questIdCache[cacheKey] ~= nil then
    return questIdCache[cacheKey] or nil
  end

  if QuestieReady() then
    local DB = QuestieOcto.DatabaseAPI
    local ids = DB:GetQuestIDs()
    if ids then
      local i
      for i = 1, table.getn(ids) do
        local id = ids[i]
        local q = QuestieOcto.QuestModel:Get(id)
        if q and tonumber(q.level) == wantedLevel and Lower(q.title) == wantedTitle then
          questIdCache[cacheKey] = id
          return id
        end
      end
    end
  end

  if PfQuestReady() then
    local id
    for id in pairs(pfDB.quests.data) do
      local loc = pfDB.quests.loc[id]
      local questTitle = type(loc) == "table" and (loc.T or loc[1]) or loc
      local questData = pfDB.quests.data[id]
      local questLevel = questData and (questData.lvl or questData.level)
      if questTitle and tonumber(questLevel) == wantedLevel and Lower(questTitle) == wantedTitle then
        questIdCache[cacheKey] = id
        return id
      end
    end
  end

  -- false is used as a negative cache sentinel.
  questIdCache[cacheKey] = false
  return nil
end

local function GetDataFromQuestie(questId, itemName)
  if not QuestieReady() then return nil end
  local DB = QuestieOcto.DatabaseAPI
  local q = QuestieOcto.QuestModel:Get(questId)
  if not q or not q.objectives or not q.objectives.item then return nil end

  local mobs = {}
  local seen = {}
  local wanted = Lower(itemName) or ""
  local i
  for i = 1, table.getn(q.objectives.item) do
    local itemId = q.objectives.item[i]
    if Lower(DB:GetItemName(itemId) or "") == wanted then
      local sources = DB:GetItemSources(itemId)
      if sources and sources.Creature then
        local mobId
        for mobId in pairs(sources.Creature) do
          local mobName = DB:GetCreatureName(mobId)
          if mobName and not seen[mobName] then
            table.insert(mobs, mobName)
            seen[mobName] = true
          end
        end
      end
      if sources and sources.Reference then
        local refId
        for refId in pairs(sources.Reference) do
          local refLoot = DB:GetReferenceLootRaw(refId)
          if refLoot and refLoot.U then
            local mobId
            for mobId in pairs(refLoot.U) do
              local mobName = DB:GetCreatureName(mobId)
              if mobName and not seen[mobName] then
                table.insert(mobs, mobName)
                seen[mobName] = true
              end
            end
          end
        end
      end
    end
  end

  if table.getn(mobs) > 0 then return mobs end
  return nil
end

local function PfLocalizedName(loc, id)
  if not loc then return nil end
  local value = loc[id]
  if type(value) == "table" then return value.T or value[1] end
  return value
end

local function GetDataFromPfDb(questId, itemName)
  if not pfDB or not pfDB.quests or not pfDB.items or not pfDB.units then return nil end
  local questData = pfDB.quests.data and pfDB.quests.data[questId]
  if not questData or not questData.obj or not questData.obj.I then return nil end

  local qdata = pfDB.quests.data
  local itemData = pfDB.items.data
  local itemLoc = pfDB.items.loc
  local unitLoc = pfDB.units.loc
  local refloot = pfDB.refloot and pfDB.refloot.data
  if not qdata or not itemData or not itemLoc or not unitLoc then return nil end

  local wanted = Lower(itemName) or ""
  local mobs = {}
  local seen = {}
  local obj = qdata[questId] and qdata[questId].obj
  if not obj or not obj.I then return nil end

  local _, itemId
  for _, itemId in pairs(obj.I) do
    local sourceName = PfLocalizedName(itemLoc, itemId)
    if sourceName and Lower(sourceName) == wanted and itemData[itemId] then
      if itemData[itemId].U then
        local unitId
        for unitId in pairs(itemData[itemId].U) do
          local name = PfLocalizedName(unitLoc, unitId)
          if name and not seen[name] then
            table.insert(mobs, name)
            seen[name] = true
          end
        end
      end
      if itemData[itemId].R and refloot then
        local ref
        for ref in pairs(itemData[itemId].R) do
          if refloot[ref] and refloot[ref].U then
            local unitId
            for unitId in pairs(refloot[ref].U) do
              local name = PfLocalizedName(unitLoc, unitId)
              if name and not seen[name] then
                table.insert(mobs, name)
                seen[name] = true
              end
            end
          end
        end
      end
    end
  end

  if table.getn(mobs) > 0 then return mobs end
  return nil
end

local function GetItemDropSource(questId, itemName)
  if not questId or not itemName then return nil end
  local mobs
  if QuestieReady() then mobs = GetDataFromQuestie(questId, itemName) end
  if (not mobs or table.getn(mobs) == 0) and pfDB then
    mobs = GetDataFromPfDb(questId, itemName)
  end
  if mobs and table.getn(mobs) > 0 then return mobs end
  return nil
end

local function GetMonsterDataFromQuestie(questId)
  if not QuestieReady() then return nil end
  local DB = QuestieOcto.DatabaseAPI
  local q = QuestieOcto.QuestModel:Get(questId)
  if not q or not q.objectives or not q.objectives.monster then return nil end

  local mobs = {}
  local seen = {}
  local i
  for i = 1, table.getn(q.objectives.monster) do
    local mobId = q.objectives.monster[i]
    local mobName = DB:GetCreatureName(mobId)
    if mobName and not seen[mobName] then
      table.insert(mobs, mobName)
      seen[mobName] = true
    end
  end
  if table.getn(mobs) > 0 then return mobs end
  return nil
end

local function GetMonsterDataFromPfDb(questId)
  if not pfDB or not pfDB.quests or not pfDB.quests.data or
     not pfDB.units or not pfDB.units.loc then return nil end
  local questData = pfDB.quests.data[questId]
  if not questData or not questData.obj or not questData.obj.U then return nil end

  local mobs = {}
  local seen = {}
  local _, unitId
  for _, unitId in pairs(questData.obj.U) do
    local name = PfLocalizedName(pfDB.units.loc, unitId)
    if name and not seen[name] then
      table.insert(mobs, name)
      seen[name] = true
    end
  end
  if table.getn(mobs) > 0 then return mobs end
  return nil
end

local function IsMobMatchObjective(mobName, objectiveName)
  local lm = Lower(mobName) or ""
  local lo = Lower(objectiveName) or ""
  lo = string.gsub(lo, "%s*slain.*$", "")
  if lm == lo then return true end
  local singular = string.gsub(lo, "s$", "")
  if lm == singular then return true end
  if singular ~= "" and string.find(lm, singular, 1, true) then return true end
  if lm ~= "" and string.find(lo, lm, 1, true) then return true end
  return false
end

local function AddObjective(mobName, objectiveName, texture, remaining)
  local key = Lower(mobName)
  if not key or key == "" then return end
  if not questObjectives[key] then questObjectives[key] = {} end
  questObjectives[key][objectiveName] = {
    icon = texture,
    text = tostring(remaining),
  }
end

function BNP:UpdateQuestPlateObjectives()
  ClearTable(questObjectives)
  -- A dependency may have become ready after an earlier negative lookup.
  ClearTable(questIdCache)

  local oldSelection
  if GetQuestLogSelection then oldSelection = GetQuestLogSelection() end

  local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
  local i
  for i = 1, numEntries do
    SelectQuestLogEntry(i)
    local questTitle, questLevel, _, isHeader, _, isComplete = GetQuestLogTitle(i)
    if not isHeader and not isComplete and questTitle then
      local questId = GetQuestIdByTitle(questTitle, questLevel)
      local numObjectives = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards() or 0
      local monsterCount = 0
      local j

      for j = 1, numObjectives do
        local _, objectiveType = GetQuestLogLeaderBoard(j)
        if objectiveType == "monster" then monsterCount = monsterCount + 1 end
      end

      for j = 1, numObjectives do
        local description, objectiveType = GetQuestLogLeaderBoard(j)
        if description then
          -- WoW 1.12 uses Lua 5.0: string.find captures instead of string.match.
          local _, _, objectiveName, currentText, totalText =
            string.find(description, "^(.+):%s*(%d+)%s*/%s*(%d+)")
          local current = tonumber(currentText)
          local total = tonumber(totalText)
          if objectiveName and current and total and current < total then
            local mobs
            local texture

            if objectiveType == "monster" then
              if questId and QuestieReady() then mobs = GetMonsterDataFromQuestie(questId) end
              if (not mobs or table.getn(mobs) == 0) and questId and pfDB then
                mobs = GetMonsterDataFromPfDb(questId)
              end

              if mobs and monsterCount > 1 then
                local filtered = {}
                local _, mobName
                for _, mobName in pairs(mobs) do
                  if IsMobMatchObjective(mobName, objectiveName) then
                    table.insert(filtered, mobName)
                  end
                end
                if table.getn(filtered) > 0 then mobs = filtered end
              end

              if not mobs or table.getn(mobs) == 0 then
                local fallback = string.gsub(objectiveName, "%s+slain$", "")
                if fallback and fallback ~= "" then mobs = { fallback } end
              end
              texture = KILL_TEXTURE
            elseif objectiveType == "item" and questId then
              mobs = GetItemDropSource(questId, objectiveName)
              texture = ITEM_TEXTURE
            end

            if mobs and texture then
              local _, mobName
              for _, mobName in pairs(mobs) do
                AddObjective(mobName, objectiveName, texture, total - current)
              end
            end
          end
        end
      end
    end
  end

  if oldSelection and oldSelection > 0 and oldSelection <= numEntries then
    SelectQuestLogEntry(oldSelection)
  end

  questRevision = questRevision + 1
  if self.RefreshQuestPlateIndicators then self:RefreshQuestPlateIndicators() end
end

local function HideQuestIcons(plate)
  if not plate or not plate.BNPQuestIcons then return end
  local i
  for i = 1, table.getn(plate.BNPQuestIcons) do
    plate.BNPQuestIcons[i]:Hide()
  end
  plate.BNPQuestRenderKey = nil
end

local function GetQuestIcon(plate, index)
  plate.BNPQuestIcons = plate.BNPQuestIcons or {}
  local icon = plate.BNPQuestIcons[index]
  if icon then return icon end

  icon = CreateFrame("Frame", nil, plate)
  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetAllPoints(icon)

  icon.text = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  icon.text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
  if icon.text.SetShadowOffset then icon.text:SetShadowOffset(1, -1) end
  if icon.text.SetTextColor then icon.text:SetTextColor(1, 0.82, 0) end

  plate.BNPQuestIcons[index] = icon
  return icon
end

function BNP:UpdateQuestPlateIndicator(plate, force)
  if not plate then return end
  if not self:AreQuestPlateIndicatorsEnabled() then
    HideQuestIcons(plate)
    return
  end

  local healthbar = plate.healthbar
  local nameRegion = plate.name
  if not healthbar or not nameRegion or not nameRegion.GetText then
    HideQuestIcons(plate)
    return
  end

  local unitName = nameRegion:GetText()
  local objectives = unitName and questObjectives[Lower(unitName)] or nil
  if not objectives then
    HideQuestIcons(plate)
    return
  end

  local size = self:GetQuestPlateIconSize()
  local x = self:GetQuestPlateXOffset()
  local y = self:GetQuestPlateYOffset()
  local renderKey = tostring(questRevision) .. "|" .. tostring(unitName) .. "|" ..
                    tostring(size) .. "|" .. tostring(x) .. "|" .. tostring(y)
  if not force and plate.BNPQuestRenderKey == renderKey then return end
  plate.BNPQuestRenderKey = renderKey

  local entries = {}
  local objectiveName, data
  for objectiveName, data in pairs(objectives) do
    table.insert(entries, { name = objectiveName, data = data })
  end
  table.sort(entries, function(a, b) return tostring(a.name) < tostring(b.name) end)

  local previous
  local shown = 0
  local i
  for i = 1, table.getn(entries) do
    if shown >= MAX_ICONS_PER_PLATE then break end
    shown = shown + 1
    local icon = GetQuestIcon(plate, shown)
    icon:SetParent(healthbar)
    if icon.SetFrameLevel and healthbar.GetFrameLevel then
      icon:SetFrameLevel((healthbar:GetFrameLevel() or 1) + 8)
    end
    icon:SetWidth(size)
    icon:SetHeight(size)
    icon:ClearAllPoints()
    if previous then
      icon:SetPoint("LEFT", previous.text, "RIGHT", ICON_SPACING, 0)
    else
      icon:SetPoint("LEFT", healthbar, "RIGHT", x, y)
    end
    icon.texture:SetTexture(entries[i].data.icon)
    icon.text:SetText(entries[i].data.text or "")
    icon:Show()
    previous = icon
  end

  if plate.BNPQuestIcons then
    for i = shown + 1, table.getn(plate.BNPQuestIcons) do
      plate.BNPQuestIcons[i]:Hide()
    end
  end
end

function BNP:RefreshQuestPlateIndicators()
  local plate
  for plate in pairs(self.plates or {}) do
    if plate and plate.IsShown and plate:IsShown() then
      self:UpdateQuestPlateIndicator(plate, true)
    else
      HideQuestIcons(plate)
    end
  end
end

function BNP:RequestQuestPlateObjectiveUpdate()
  updatePending = true
  updateElapsed = 0
end

-- Nameplate integration: reuse BNP's existing 10 Hz plate update rather than
-- scanning WorldFrame a second time just for quest icons.
table.insert(BNP.libnameplate.OnShow, function(plate)
  plate.BNPQuestRenderKey = nil
  BNP:UpdateQuestPlateIndicator(plate, true)
end)

table.insert(BNP.libnameplate.OnUpdate, function(plate)
  BNP:UpdateQuestPlateIndicator(plate, false)
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
eventFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")

eventFrame:SetScript("OnEvent", function()
  BNP:RequestQuestPlateObjectiveUpdate()
end)

eventFrame:SetScript("OnUpdate", function()
  if not updatePending then return end
  updateElapsed = updateElapsed + arg1
  if updateElapsed < updateDelay then return end
  updatePending = false
  updateElapsed = 0
  BNP:UpdateQuestPlateObjectives()
end)
