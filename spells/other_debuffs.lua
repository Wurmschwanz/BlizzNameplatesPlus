BNP = BNP or {}

-- Optional non-CC debuffs from other players/classes.
-- The selectable list and grouping are based on the Cursive Raid class menu,
-- adapted to BNP's nameplate aura renderer. Crowd Control is intentionally
-- excluded here because BNP's dedicated CC tracker/menu already owns it.
-- These definitions remain separate from the local player's own-cast tracker.

BNP.OtherDebuffClassOrder = {
  "warrior", "rogue", "hunter", "mage", "warlock",
  "priest", "druid", "shaman", "paladin",
}

BNP.OtherDebuffClassLabels = {
  warrior = "Warrior",
  rogue = "Rogue",
  hunter = "Hunter",
  mage = "Mage",
  warlock = "Warlock",
  priest = "Priest",
  druid = "Druid",
  shaman = "Shaman",
  paladin = "Paladin",
}

BNP.OtherDebuffClassColors = {
  warrior = { 0.78, 0.61, 0.43 },
  rogue = { 1.00, 0.96, 0.41 },
  hunter = { 0.67, 0.83, 0.45 },
  mage = { 0.41, 0.80, 0.94 },
  warlock = { 0.58, 0.51, 0.79 },
  priest = { 1.00, 1.00, 1.00 },
  druid = { 1.00, 0.49, 0.04 },
  shaman = { 0.00, 0.44, 0.87 },
  paladin = { 0.96, 0.55, 0.73 },
}

BNP.OtherDebuffDefs = {
  warrior = {
    { key="sunderarmor", label="Sunder Armor", category="armor", duration=30, maxStacks=5,
      spellIDs={7386,7405,8380,11596,11597}, description="30s\nReduce 450 Armor up to 5 Times (2250)" },
    { key="demoshout", label="Demoralizing Shout", category="tank", duration=30,
      spellIDs={1160,6190,11554,11555,11556}, description="30s\nReduces melee AP by 140" },
    { key="thunderclap", label="Thunder Clap", category="tank", duration=30,
      spellIDs={6343,8198,8204,8205,11580,11581}, description="30s\nReduces attack speed by 10%" },
    { key="mortalstrike", label="Mortal Strike", category="healing", duration=10,
      spellIDs={12294,21551,21552,21553}, description="10s\nReduces healing taken by 50%" },
  },
  rogue = {
    { key="exposearmor", label="Expose Armor", category="armor", duration=30,
      spellIDs={8647,8649,8650,11197,11198}, description="30s\nReduce 340 Armor per Combo Point (1700)" },
    { key="woundpoison", label="Wound Poison", category="healing", duration=15, maxStacks=5,
      spellIDs={13218}, description="15s\nReduces healing taken by 5% up to 5 Times (25%)" },
  },
  hunter = {
    { key="huntersmark", label="Hunter's Mark", category="utility", duration=120,
      spellIDs={1130,14323,14324,14325}, description="120s\nIncreases Ranged AP by 110" },
  },
  mage = {
    { key="firevulnerability", label="Fire Vulnerability", category="spellvuln", duration=30, maxStacks=5,
      spellIDs={22959}, description="30s\nIncreases Fire Damage by 3% up to 5 Times (15%)" },
    { key="winterschill", label="Winter's Chill", category="spellvuln", duration=15, maxStacks=5,
      spellIDs={12579}, description="15s\nIncreases Frost Crit Chance by 2% up to 5 Times (10%)" },
    { key="ignite", label="Ignite", category="personal", duration=4,
      spellIDs={12654}, description="4s\n40% of crit damage over 2 ticks" },
  },
  warlock = {
    { key="curseofrecklessness", label="Curse of Recklessness", category="armor", duration=120,
      spellIDs={704,7658,7659,11717}, description="120s\nReduce Armor by 640" },
    { key="curseoftheelements", label="Curse of the Elements", category="spellvuln", duration=300,
      spellIDs={1490,11721,11722}, description="300s\nReducing Fire and Frost Resistances by 75 and Increases Fire and Frost Damage by 10%" },
    { key="curseofshadow", label="Curse of Shadow", category="spellvuln", duration=300,
      spellIDs={17862,17937}, description="300s\nReducing Shadow and Arcane Resistances by 75 and Increases Shadow and Arcane Damage by 10%" },
    { key="curseoftongues", label="Curse of Tongues", category="utility", duration=30,
      spellIDs={1714,11719}, description="30s\nIncreases casting time by 50%" },
    { key="curseofweakness", label="Curse of Weakness", category="utility", duration=120,
      spellIDs={702,1108,6205,7646,11707,11708}, description="120s\nReduces melee AP by 31" },
    { key="shadowvulnerability", label="Shadow Vulnerability", category="spellvuln", duration=10,
      spellIDs={17794}, description="10s\nShadow Bolt and Drain Soul chance to Increases Shadow Damage by 20%" },
  },
  priest = {
    { key="shadowweaving", label="Shadow Weaving", category="spellvuln", duration=15, maxStacks=5,
      spellIDs={15258}, description="15s\nIncreases Shadow Damage by 3% up to 5 Times (15%)" },
    { key="burningzeal", label="Burning Zeal (Priest T3.5)", category="spellvuln", duration=18,
      spellIDs={52980}, description="18s\n852 Holy damage over 18s, +2% Holy damage taken (T3.5 Set Proc)" },
  },
  druid = {
    { key="faeriefire", label="Faerie Fire", category="armor", duration=40,
      spellIDs={770,778,9749,9907,16855,17387,17388,17389,16857,17390,17391,17392}, description="40s\nReduce Armor by 505" },
    { key="demoroar", label="Demoralizing Roar", category="tank", duration=30,
      spellIDs={99,1735,9490,9747,9898}, description="30s\nReduces melee AP by 108" },
  },
  shaman = {
    -- Cursive's shared-debuff class list intentionally has no Shaman entries.
  },
  paladin = {
    { key="judgementoflight", label="Judgement of Light", category="utility", duration=10,
      spellIDs={20185,20344,20345,20346}, description="10s\nMelee attacks heal attacker for 61" },
    { key="judgementofwisdom", label="Judgement of Wisdom", category="utility", duration=10,
      spellIDs={20186,20354,20355}, description="10s\nAttacks restore 33 mana to attacker" },
    { key="judgementofthecrusader", label="Judgement of the Crusader", category="utility", duration=10,
      spellIDs={21183,20188,20300,20301,20302,20303}, description="10s\nIncreases Holy damage taken by 140 and Increases melee and ranged AP" },
  },
}

BNP.OtherDebuffByID = BNP.OtherDebuffByID or {}
BNP.OtherDebuffByKey = BNP.OtherDebuffByKey or {}

local classIndex, classKey, defs, i, def, j, spellID
for classIndex = 1, table.getn(BNP.OtherDebuffClassOrder) do
  classKey = BNP.OtherDebuffClassOrder[classIndex]
  defs = BNP.OtherDebuffDefs[classKey] or {}
  for i = 1, table.getn(defs) do
    def = defs[i]
    def.class = classKey
    def.otherDebuff = true
    def.order = 1000 + (classIndex * 100) + i
    BNP.OtherDebuffByKey[def.key] = def
    for j = 1, table.getn(def.spellIDs or {}) do
      spellID = def.spellIDs[j]
      BNP.OtherDebuffByID[spellID] = def
    end
  end
end

-- Remove selections from older test builds (notably CC entries) that are no
-- longer part of Other Debuffs. This also prevents stale keys from keeping the
-- optional foreign-debuff scanner active.
if BNP_DB and type(BNP_DB.otherDebuffSelections) == "table" then
  local savedKey
  for savedKey in pairs(BNP_DB.otherDebuffSelections) do
    if not BNP.OtherDebuffByKey[savedKey] then
      BNP_DB.otherDebuffSelections[savedKey] = nil
    end
  end
end

function BNP:GetOtherDebuffDuration(def, spellID)
  if not def then return nil end
  if spellID and def.durations and def.durations[spellID] then
    return def.durations[spellID]
  end
  return def.duration
end

function BNP:GetOtherDebuffTexture(def)
  if not def then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  if def.texture then return def.texture end
  if SpellInfo and def.spellIDs then
    local i
    for i = 1, table.getn(def.spellIDs) do
      local _, _, texture = SpellInfo(def.spellIDs[i])
      if texture then
        def.texture = texture
        return texture
      end
    end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
