BNP = BNP or {}

-- Expanded against ShaguPlates enUS debuff tables.
BNP.DruidAuras = {
  {
    key = "moonfire",
    names = { "Moonfire" },
    duration = 18,
  },
  {
    key = "rake",
    names = { "Rake" },
    duration = 9,
  },
  {
    key = "rip",
    names = { "Rip" },
    duration = 10,
    comboPointDurations = { [1]=10, [2]=12, [3]=14, [4]=16, [5]=18 },
  },
  {
    key = "faerie_fire",
    names = { "Faerie Fire" },
    duration = 40,
  },
  {
    key = "faerie_fire_feral",
    names = { "Faerie Fire (Feral)" },
    duration = 40,
  },
  {
    key = "entangling_roots",
    names = { "Entangling Roots" },
    duration = 27,
  },
  {
    key = "insect_swarm",
    names = { "Insect Swarm" },
    duration = 18,
  },
  {
    key = "bash",
    names = { "Bash" },
    duration = 4,
  },
  {
    key = "pounce",
    names = { "Pounce" },
    duration = 2,
    spellIDs = { 9005, 9823, 9827 },
    secondaryAuraKey = "pounce_bleed",
    secondarySpellIDs = { [9005] = 9007, [9823] = 9824, [9827] = 9826 },
  },
  {
    key = "pounce_bleed",
    names = { "Pounce Bleed" },
    duration = 18,
    spellIDs = { 9007, 9824, 9826 },
  },
  {
    key = "hibernate",
    names = { "Hibernate" },
    duration = 40,
  },
  {
    key = "demoralizing_roar",
    names = { "Demoralizing Roar" },
    duration = 30,
    aoe = true,
  },
  {
    key = "feral_charge_effect",
    names = { "Feral Charge Effect" },
    duration = 4,
  },
  {
    key = "challenging_roar",
    names = { "Challenging Roar" },
    duration = 6,
  },
  {
    key = "lacerate",
    names = { "Lacerate" },
    duration = 8,
  },
  {
    key = "mangle",
    names = { "Mangle" },
    duration = 2,
  },
}
