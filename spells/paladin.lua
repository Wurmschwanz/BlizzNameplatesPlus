BNP = BNP or {}

-- Expanded against ShaguPlates enUS debuff tables.
BNP.PaladinAuras = {
  {
    key = "judgement_light",
    names = { "Judgement of Light" },
    duration = 10,
    spellIDs = { 20344 },
  },
  {
    key = "judgement_wisdom",
    names = { "Judgement of Wisdom" },
    duration = 10,
    spellIDs = { 20355 },
  },
  {
    key = "judgement_justice",
    names = { "Judgement of Justice" },
    duration = 10,
    spellIDs = { 20184 },
  },
  {
    key = "judgement_crusader",
    names = { "Judgement of the Crusader" },
    duration = 10,
    spellIDs = { 20302 },
  },
  {
    key = "hammer_of_justice",
    names = { "Hammer of Justice" },
    duration = 6,
  },
  {
    key = "repentance",
    names = { "Repentance" },
    duration = 6,
  },
  {
    key = "turn_undead",
    names = { "Turn Undead" },
    duration = 20,
  },
  {
    key = "hand_of_reckoning",
    names = { "Hand of Reckoning" },
    duration = 3,
  },
  {
    key = "crusader_strike",
    names = { "Crusader Strike" },
    duration = 30,

    -- Server variants differ: some apply a real hostile Crusader Strike
    -- aura, while others only grant a player-side buff. PROC forces BNP's
    -- strict UnitDebuff-confirmation path so the cast itself can never create
    -- a fake enemy-nameplate debuff.
    category = "PROC",
  },
}
