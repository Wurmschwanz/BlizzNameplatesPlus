BNP = BNP or {}

-- Expanded against ShaguPlates enUS debuff tables.
BNP.WarriorAuras = {
  {
    key = "rend",
    names = { "Rend" },
    duration = 21,
  },
  {
    key = "hamstring",
    names = { "Hamstring" },
    duration = 15,
  },
  {
    key = "improved_hamstring",
    names = { "Improved Hamstring" },
    duration = 5,
  },
  {
    key = "thunder_clap",
    names = { "Thunder Clap" },
    duration = 30,
    aoe = true,
  },
  {
    key = "demoralizing_shout",
    names = { "Demoralizing Shout" },
    duration = 30,
    aoe = true,
  },
  {
    key = "sunder_armor",
    names = { "Sunder Armor" },
    duration = 30,
  },
  {
    key = "piercing_howl",
    names = { "Piercing Howl" },
    duration = 6,
    aoe = true,
  },
  {
    key = "mortal_strike",
    names = { "Mortal Strike" },
    duration = 10,
  },
  {
    key = "intimidating_shout",
    names = { "Intimidating Shout" },
    duration = 8,
    -- Intimidating Shout applies its CC to the primary target and nearby
    -- enemies. Treat it as an AoE aura so every affected visible GUID is
    -- live-confirmed and receives its own 8-second timer.
    aoe = true,
  },
  {
    key = "mocking_blow",
    names = { "Mocking Blow" },
    duration = 6,
  },
  {
    key = "disarm",
    names = { "Disarm" },
    duration = 10,
  },
  {
    key = "taunt",
    names = { "Taunt" },
    duration = 3,
  },
  {
    key = "challenging_shout",
    names = { "Challenging Shout" },
    duration = 6,
    aoe = true,
  },
  {
    key = "charge_stun",
    names = { "Charge Stun" },
    duration = 1,
  },
  {
    key = "intercept_stun",
    names = { "Intercept Stun" },
    duration = 3,
  },
  {
    key = "concussion_blow",
    names = { "Concussion Blow" },
    duration = 5,
  },
  {
    key = "revenge_stun",
    names = { "Revenge Stun" },
    duration = 3,
  },
  {
    key = "pummel",
    names = { "Pummel" },
    duration = 4,
  },
  {
    key = "shield_bash",
    names = { "Shield Bash" },
    duration = 6,
  },
  {
    key = "deep_wound",
    names = { "Deep Wound", "Deep Wounds" },
    duration = 12,
  },
}
