# ⚔️ Blizz Nameplates+

**Blizz Nameplates+** enhances the original Blizzard nameplates for **Vanilla WoW / WoW 1.12** while preserving their classic look and feel.

It adds multi-target aura tracking, Crowd Control, PvP immunities, castbars, Combo Points, totem indicators and extensive customization without replacing the original Blizzard nameplate system.

**Current version:** `v1.1.0`  
**Required:** `SuperWoW.dll` + `ClassicAPI.dll`

---

## ✨ Features

### 🎯 Nameplates

- Adjustable **Nameplate Scale** and **Y Offset**
- Adjustable **Non-Target Alpha**
- Enemy **Class Colors**
- **Tank Mode**
  - Green = Aggro
  - Red = No Aggro
- **Invert Tank Colors**
  - Custom Aggro / No Aggro colors
  - Full color picker + Reset
- Optional **Hide Player Names**
- Optional **Hide NPC Names**
- Optional **Hide Level**
- Optional **Hide Border**
- Optional **Dark Border**
- Adjustable **Name Font Size** and **Y Offset**
- **Black Health Background**
- Neutral grey healthbar for foreign-tagged mobs
- Improved Blizzard nameplate detection and recycling

---

### 🎯 Target Highlighting

- Customizable **Target Glow**
- Customizable **Target Arrows**
- One shared **Target Color** for Glow + Arrows
- Full color picker with Reset
- Adjustable Glow size and opacity
- Multiple Arrow styles
- Adjustable Arrow size
- Thick / thin Arrow variants
- **Target Plate on Top**

---

### ❤️ Health Text

Display health directly on the nameplate:

- Off
- Percent
- HP
- HP + Percent
- Adjustable font size
- Outline / Thick Outline / None

---

### ☠️ Debuffs & DoTs

- GUID-based **multi-target tracking**
- Tracks your debuffs across multiple visible nameplates
- Numeric timers
- Stack counters
- Optional smooth **Cooldown Spiral**
- Independent **Aura Font Size**
- Adjustable icon size
- Independent Y Offset
- Multiple positioning options
- Spell-specific durations
- Improved projectile, resist and miss handling
- Reliable cleanup on dispels, deaths and invalid aura states

Supported positions:

- Top Mid
- Top Left
- Top Right
- Left
- Right
- Bottom Mid
- Bottom Left
- Bottom Right

---

### 🌀 Crowd Control

- Dedicated CC tracking
- Optional supported CC effects from other players
- Separate CC icon size
- Independent Y Offset
- Optional separate CC row
- Improved pet nameplate handling
- Automatic cleanup of invalid CC states

Positions:

- Top
- Left
- Right

---

### 🛡️ PvP Immunities

Tracks important protection and immunity effects such as:

- Divine Shield
- Divine Protection
- Blessing of Protection
- Ice Block
- Berserker Rage
- Death Wish
- Recklessness
- Fear Ward
- Will of the Forsaken

Includes independent icon size, position and Y Offset.

---

### 🔥 Totem Indicators

Shaman totems can be displayed as clean spell icons instead of full nameplates.

- Automatic totem detection
- Ranked totem support
- Adjustable icon size
- Removes unnecessary name, level and healthbar clutter
- Designed for clearer PvP situations

---

### ✨ Combo Points

Available for **Rogue** and **Druid** only.

- Combo Points displayed above the target nameplate
- Adjustable Y Offset
- Optional **Dark Combo Point Border**
- Previous target Combo Points can remain visible until new points are generated

---

### 🔥 Castbars

- Enemy castbars
- Spell icons
- Classic / modern styling
- Adjustable height
- Adjustable spacing
- Adjustable X / Y Offset
- Castbar test mode
- Improved enemy cast detection through ClassicAPI
- Interruptibility support
- Automatic positioning around bottom auras
- Clean Target Glow / castbar layering
- Successful casts receive a visual completion effect

---

## ⚡ Performance & Compatibility

Blizz Nameplates+ keeps the original Blizzard nameplates and builds functionality around them instead of replacing the entire system.

v1.1.0 includes major ClassicAPI-based improvements:

- More reliable nameplate-to-unit resolution
- Improved aura updates
- More efficient enemy castbar handling
- Reduced unnecessary scanning
- Improved recycled nameplate handling
- Better multi-target accuracy
- Improved compatibility with UI addons modifying Blizzard nameplates
- Mouseover tooltip support
- Mouseover macro support
- Settings stored **per character**

---

## 🆕 v1.1.0 Highlights

- Major **ClassicAPI integration improvements**
- Smoother optional **Cooldown Spirals**
- Independent Aura Font Size
- Improved CC and pet-nameplate handling
- Improved miss / resist detection
- Fixed false Rake applications after misses
- Hide Level option
- Hide Border option
- Custom colors for **Invert Tank Mode**
- Shared custom color for **Target Glow + Target Arrows**
- Improved and reorganized options menu
- Color picker with Reset and movable window
- Additional performance and nameplate recycling fixes

---

## 🔎 Missing Spell / Aura Recorder

Missing a spell, DoT, proc or custom-server aura?

Open:

**BNP Settings → Tools → Missing Spell / Aura**

The recorder can collect:

- Spell IDs
- Aura durations
- Expiration times
- Refresh events
- Target information
- Aura state changes

The recorder is inactive until **Start Recording** is pressed.

---

## 📦 Requirements

### SuperWoW.dll

Used for GUID, combat, cast and unit information.

[Download SuperWoW](https://github.com/balakethelock/SuperWoW)

### ClassicAPI.dll

Used for reliable nameplate, aura and spell information.

[Download ClassicAPI](https://github.com/brues-code/ClassicAPI)

> **Both DLLs are required. Keep them up to date.**

---

## 📥 Installation

1. Install `SuperWoW.dll` and `ClassicAPI.dll`
2. Delete any older `BlizzNameplatesPlus` folder
3. Extract the addon into:

`Interface\AddOns\`

The final path should be:

`Interface\AddOns\BlizzNameplatesPlus\BlizzNameplatesPlus.toc`

4. Start the game through your DLL-enabled launcher
5. Enable enemy nameplates

---

## ❤️ Credits

Created by **Wurmschwanz**.

Thanks to everyone testing **Blizz Nameplates+**, reporting bugs, suggesting features and providing recorder data. ❤️
