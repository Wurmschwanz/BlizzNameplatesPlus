BNP = BNP or {}

-- ShaguTweaks Darkened UI compatibility -------------------------------------
-- ShaguTweaks darkens a nameplate once and marks it with plate.darkened=true.
-- Blizzard can later recycle that same plate and restore its original gold
-- textures while the flag remains true. Shagu then skips the recycled plate.
--
-- BNP does not implement its own dark mode here. It simply asks ShaguTweaks
-- to run its own DarkenFrame() again whenever Blizzard reuses a nameplate.

local pending = {}

local function ShaguDarkModeActive()
  return ShaguTweaks
    and ShaguTweaks.DarkMode
    and ShaguTweaks.DarkenFrame
end

local function ReapplyShaguDarkMode(plate)
  if not plate or not plate:IsShown() then return end
  if not ShaguDarkModeActive() then return end

  -- Clear Shagu's one-time marker because this Blizzard plate may have been
  -- recycled for another unit and had its textures reset.
  plate.darkened = nil

  -- Use ShaguTweaks' own implementation/configuration as the single source of
  -- truth. Its blacklist already protects StatusBars, spell icons, portraits,
  -- etc. from being incorrectly darkened.
  ShaguTweaks.DarkenFrame(plate)
  plate.darkened = true
end

local function QueueReapply(plate)
  if not plate then return end

  -- Immediate pass handles normal OnShow.
  ReapplyShaguDarkMode(plate)

  -- Blizzard may restore some nameplate texture state immediately after
  -- OnShow. Do one delayed pass and then stop; no permanent scanner is needed.
  pending[plate] = GetTime() + 0.08
end

if BNP.libnameplate then
  table.insert(BNP.libnameplate.OnInit, function(plate)
    QueueReapply(plate or this)
  end)

  table.insert(BNP.libnameplate.OnShow, function(plate)
    QueueReapply(plate or this)
  end)
end

local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function()
  if not next(pending) then return end

  local now = GetTime()
  local plate, due
  for plate, due in pairs(pending) do
    if now >= due then
      pending[plate] = nil
      ReapplyShaguDarkMode(plate)
    end
  end
end)
