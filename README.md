# ⚔️ Blizz Nameplates+

**Blizz Nameplates+** enhances the original Blizzard nameplates for **Vanilla WoW / WoW 1.12** while preserving their classic look and feel.

It adds reliable multi-target aura tracking, Crowd Control, PvP immunities, castbars, Combo Points, quest indicators, totem icons, Raid Marks and extensive customization — without replacing the original Blizzard nameplate system.

**Current version:** `v1.1.0`  
**Required:** `SuperWoW.dll` + `ClassicAPI.dll`

---

## ✨ Features

### 🎯 Nameplates

- Adjustable **Scale**, **Y Offset** and **Non-Target Alpha**
- Enemy **Class Colors**
- **Tank Mode** with custom Aggro / No Aggro colors
- Optional **Hide Player Names**, **NPC Names**, **Level** and **Border**
- Optional **Dark Border**
- Adjustable Name font size / position
- **Black Health Background**
- Neutral grey healthbar for foreign-tagged mobs
- Improved nameplate detection and recycling

---

### 🎯 Target

- Customizable **Target Glow**
- Customizable **Target Arrows**
- Shared **Glow / Arrow Color**
- Adjustable Glow scale and opacity
- Multiple Arrow styles and sizes
- Custom **Target Border Color**
- Optional **Bold Target Border**
- Adjustable **Target Scale**
- **Target Plate on Top**

---

### ❤️ Health Text

Display health directly on the nameplate:

**Off • Percent • HP • HP + Percent**

Includes adjustable font size and outline options.

---

### ☠️ Debuffs & DoTs

- GUID-based **multi-target tracking**
- Numeric timers and stack counters
- Optional smooth **Cooldown Spiral**
- Independent Aura font and icon size
- Multiple positioning options + Y Offset
- Improved miss, resist and projectile handling
- Reliable cleanup on dispels, deaths and invalid states

---

### 🌀 Crowd Control

- Dedicated CC tracking
- Optional CCs from other players
- Independent icon size and position
- Optional separate CC row
- Improved pet-nameplate handling
- Event-driven ClassicAPI tracking
- Fixed CC flickering / temporary disappearing

---

### 🛡️ PvP Immunities

Tracks important effects such as:

**Divine Shield, Divine Protection, Blessing of Protection, Ice Block, Berserker Rage, Death Wish, Recklessness, Fear Ward and Will of the Forsaken**

Includes independent size and positioning.

---

### 🗿 Totem Indicators

- Automatic Shaman totem detection
- Ranked totem support
- Displays clean spell icons instead of full nameplates
- Adjustable icon size

---

### 📜 Quest Indicators

**QuestPlatesOcto functionality is now integrated directly into BNP.**

- Quest mob and item indicators
- Remaining objective count
- Adjustable **Icon Size**
- Adjustable **X / Y Offset**
- Supports **Questie-Octo** and **pfQuest**

No separate QuestPlatesOcto addon is required.

---

### 🔷 Raid Marks

- Displays Raid Mark icons directly on nameplates
- Adjustable **X / Y Offset**
- Integrated into the BNP Icons settings

---

### ✨ Combo Points

For **Rogue** and **Druid**:

- Combo Points above the target nameplate
- Adjustable Y Offset
- Optional Dark Combo Point Border
- Previous-target point retention

---

### 🔥 Castbars

- Enemy castbars with spell icons
- Classic / modern styling
- Adjustable height, spacing and X / Y Offset
- Interruptibility support
- ClassicAPI-based enemy cast detection
- Automatic positioning around bottom auras
- Successful-cast completion effect

---

## ⚡ Performance & Compatibility

v1.1.0 includes major **ClassicAPI** improvements:

- More reliable nameplate-to-unit resolution
- Event-driven aura updates
- Improved multi-target accuracy
- More efficient cast handling
- Reduced unnecessary scanning
- Better recycled-nameplate handling
- Mouseover tooltip and macro support
- Improved compatibility with UI addons
- Settings stored **per character**

---

## 🆕 v1.1.0 Highlights

- Major ClassicAPI integration
- Integrated **Quest Indicators**
- New **Target Border Color**
- Optional **Bold Target Border**
- Improved **Raid Marks** with X / Y positioning
- Fixed CC flickering
- Cooldown Spirals
- Independent Aura Font Size
- Custom Tank Mode colors
- Improved miss / resist handling
- Hide Level / Hide Border options
- Reorganized and cleaner options menu
- Additional performance and recycling fixes

---

## 🔎 Missing Spell / Aura Recorder

Open:

**BNP Settings → Tools → Missing Spell / Aura**

The recorder can collect Spell IDs, durations, expiration times, refresh events, target information and aura state changes.

---

## 📦 Requirements

### SuperWoW.dll
Provides GUID, combat, cast and unit information.

[Download SuperWoW](https://github.com/balakethelock/SuperWoW)

### ClassicAPI.dll
Provides reliable nameplate, aura and spell information.

[Download ClassicAPI](https://github.com/brues-code/ClassicAPI)

> **Both DLLs are required and should be kept up to date.**

---

## 📥 Installation

1. Install `SuperWoW.dll` and `ClassicAPI.dll`
2. Delete any older `BlizzNameplatesPlus` folder
3. Extract the addon into:

`Interface\AddOns\`

Final path:

`Interface\AddOns\BlizzNameplatesPlus\BlizzNameplatesPlus.toc`

4. Start the game through your DLL-enabled launcher
5. Enable enemy nameplates

---

## ❤️ Credits

Created by **Wurmschwanz**.

Thanks to everyone testing **Blizz Nameplates+**, reporting bugs, suggesting features and providing recorder data. ❤️
