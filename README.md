# ⚔️ Blizz Nameplates+

**Blizz Nameplates+** enhances the original Blizzard nameplates for **Vanilla WoW / WoW 1.12** while preserving their classic look and feel.

It adds reliable multi-target aura tracking, Crowd Control, PvP immunity tracking, castbars, Combo Points, PvP totem indicators and additional customization — without replacing the original Blizzard nameplate design.

**Current version:** `v1.0.10`
**Required:** `SuperWoW.dll` + `ClassicAPI.dll`

---

## ✨ Features

### 🎯 Nameplates

* Adjustable **Nameplate Scale**
* Adjustable **Nameplate Y Offset**
* Adjustable **Non-Target Alpha**
* Enemy **Class Colors**
* **Tank Mode**
* Optional **Hide Player Names**
* Optional **Hide NPC / Mob Names**
* Adjustable **Name Font Size**
* Adjustable **Name Y Offset**
* Adjustable **Health Text Font Size**
* Health text outline options
* Aura layouts automatically adjust when names are hidden
* Foreign-tagged mobs use a neutral grey healthbar
* Customizable **Target Glow**
* **Target Plate on Top**
* Improved nameplate detection for better compatibility with other UI addons
* Clean nameplate, aura and castbar layering

---

### ❤️ Health Text

Health information can be displayed directly on the nameplate.

Options include:

* Health percentage display
* Adjustable **Font Size**
* Font outline:

  * None
  * Outline
  * Thick Outline

Health text customization is independent from the global nameplate scale.

---

### ☠️ Debuffs & DoTs

* GUID-based multi-target tracking
* Numeric aura timers
* Stack counters
* Reliable tracking across multiple visible nameplates
* Spell-specific duration handling
* Improved projectile-based DoT tracking
* Better handling of missed ranged aura applications
* Adjustable **Debuff Icon Size**
* Independent **Debuff Y Offset**
* Instant target-alpha updates

#### Debuff Positions

* **Top Mid**
* **Top Left**
* **Top Right**
* **Left**
* **Right**
* **Bottom Mid**
* **Bottom Left**
* **Bottom Right**

Bottom-positioned debuffs are automatically taken into account by the castbar layout.

Different debuff and CC icon sizes can share the same area without overlapping.

---

### 🌀 Crowd Control

Dedicated Crowd Control tracking with independent layout options.

* Enable / disable CC tracking
* Optional supported CC effects from other players
* Separate **CC Icon Size**
* Independent **CC Y Offset**
* Optional **Separate CC Row**

Available positions:

* **Top**
* **Left**
* **Right**

The separate top CC row works correctly with:

* Top Mid
* Top Left
* Top Right

---

### 🛡️ PvP Immunities

Important PvP immunity and protection effects can be displayed directly on nameplates.

Supported effects include abilities such as:

* Divine Shield
* Divine Protection
* Blessing of Protection
* Ice Block
* Berserker Rage
* Death Wish
* Recklessness
* Fear Ward
* Will of the Forsaken

Features:

* Dedicated **PvP Immunities** toggle
* Separate **Immunity Icon Size**
* Independent **Immunity Y Offset**
* Independent positioning
* Strict spell whitelist
* Fast removal when an immunity ends or is cancelled
* Cleanup of invalid debuff / CC states
* Protection against stale aura information

Available positions:

* **Top**
* **Left**
* **Right**

---

### 🔥 Totem Indicators

Shaman totems can be displayed as clean spell icons instead of full nameplates.

* Automatically detects supported Shaman totems
* Replaces the full totem nameplate with the corresponding spell icon
* Removes unnecessary healthbar, name and level clutter
* Adjustable **Totem Icon Size**
* Supports ranked totems automatically
* Designed especially for clearer PvP situations

---

### ✨ Combo Points

Combo Points are supported for:

* **Rogue**
* **Druid**

Features:

* Combo Points displayed directly above the target nameplate
* Adjustable **Combo Point Y Offset**
* Independent positioning
* Combo Points can remain visible on the previous target until new Combo Points are generated on another target

---

### 🔥 Castbars

* Enemy castbars
* Spell icons
* Adjustable **Castbar Height**
* Adjustable **Castbar Spacing**
* Adjustable **Castbar Y Offset**
* Castbar test mode
* Automatically adjusts when debuffs are positioned below the nameplate
* Improved layering so Target Glow does not cover the castbar

---

## ⚡ Performance & Compatibility

Blizz Nameplates+ keeps the original Blizzard nameplates instead of replacing them with a completely custom nameplate system.

Recent improvements include:

* Reduced unnecessary nameplate updates
* Optimized aura and castbar handling
* No unnecessary permanent layout scanning
* Improved compatibility with addons that modify Blizzard nameplates
* More robust nameplate detection
* Mouseover tooltip support
* Mouseover macros work correctly on nameplates
* Settings stored **per character**

The goal is to add functionality while keeping the addon lightweight and visually close to the original Blizzard UI.

---

# 🆕 What's New in v1.0.10

## 🐾 Improved Druid Debuff Tracking

Druid aura tracking has been expanded and corrected.

* Added **Demoralizing Roar** debuff tracking
* **Rip** now uses the correct duration based on Combo Points
* Rip scales from **10 seconds at 1 Combo Point** to **18 seconds at 5 Combo Points**
* Multi-target and GUID-based tracking continue to work normally

---

## 🏹 Improved Projectile & Miss Handling

Aura application handling has been improved for abilities whose projectile reaches the target after the initial cast or shot event.

This prevents situations where a DoT briefly appears on the nameplate and is immediately removed because the projectile ultimately missed.

Improvements include:

* Better handling of delayed projectile impacts
* Reduced false temporary DoT displays
* More reliable miss cleanup
* Especially useful for Hunter-style ranged DoT applications
* Direct caster DoTs continue to update normally

---

## ☠️ Aura Tracking Improvements

Additional aura handling improvements include:

* Better recognition of attack-power reduction debuffs
* Improved spell-specific duration handling
* Reliable resist / miss cleanup
* Better synchronization between aura state and visible nameplates

---

## 🛠️ Additional v1.0.10 Improvements

v1.0.10 also includes and retains the recent improvements from v1.0.9:

* Mouseover tooltips
* Mouseover macro support
* Per-character settings
* Improved nameplate detection
* Independent aura Y offsets
* Improved CC / debuff spacing
* PvP immunity tracking
* Fast immunity cleanup
* Castbar / Target Glow layering fixes
* Adjustable name and health text
* Separate player and NPC name visibility
* Expanded debuff positioning

---

## 🔎 Missing Spell / Aura Recorder

Missing a spell, DoT, proc or custom-server aura?

The built-in recorder creates one complete, copyable diagnostic report — no screenshots or manual chat commands required.

1. Open the BNP settings
2. Go to **Tools**
3. Click **Missing Spell / Aura...**
4. Select the affected unit
5. Click **Start Recording**
6. Apply the aura
7. Refresh it while active
8. Let it expire or remove it
9. Click **Stop**
10. Click **Copy Report**
11. Paste the report into your bug report or support message

The report can include:

* Spell IDs
* Aura timing
* Target information
* Refresh events
* Relevant aura state changes

The recorder is completely inactive until **Start Recording** is pressed.

---

## 📦 Requirements

Both DLLs are required and must be loaded before the game starts.

### SuperWoW.dll

Provides GUID, unit, combat and cast information used for:

* Multi-target tracking
* Castbars
* Nameplate identification
* Unit tracking

[Download SuperWoW](https://github.com/balakethelock/SuperWoW)

### ClassicAPI.dll

Provides more reliable nameplate and aura information, including:

* Spell IDs
* Aura durations
* Expiration times
* Exact nameplate resolution
* Instant target updates
* Recorder functionality
* PvP immunity tracking

[Download ClassicAPI](https://github.com/brues-code/ClassicAPI)

> **Keep both DLLs up to date.**
> Blizz Nameplates+ is not supported without SuperWoW and ClassicAPI.

---

## 📥 Installation

1. Install `SuperWoW.dll` and `ClassicAPI.dll`
2. Make sure both DLLs are enabled in your DLL loader or `dlls.txt`
3. Delete any older `BlizzNameplatesPlus` addon folder
4. Extract the new addon into:

`Interface\AddOns\`

5. Verify that the final path is:

`Interface\AddOns\BlizzNameplatesPlus\BlizzNameplatesPlus.toc`

6. Start the game through your DLL-enabled launcher
7. Enable enemy nameplates

---

## ❤️ Credits

Created by **Wurmschwanz**.

Thanks to everyone who tested **Blizz Nameplates+**, reported bugs, suggested features and supplied recorder data.

Special thanks to everyone helping test different classes, PvP situations, addon combinations and large raid environments. ❤️

Your feedback continues to make **Blizz Nameplates+** better.
