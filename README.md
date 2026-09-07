# ⚔️ Blizz Nameplates+

**Blizz Nameplates+** enhances the original Blizzard nameplates for **Vanilla WoW / WoW 1.12** while preserving their classic look and feel.

It adds reliable multi-target aura tracking, Crowd Control, PvP immunity tracking, castbars, Combo Points, PvP totem indicators and additional customization — without replacing the original Blizzard nameplate design.

**Current version:** `v1.0.9`  
**Required:** `SuperWoW.dll` + `ClassicAPI.dll`

---

## ✨ Features

### 🎯 Nameplates

- Adjustable **Nameplate Scale**
- Adjustable **Nameplate Y Offset**
- Adjustable **Non-Target Alpha**
- Enemy **Class Colors**
- **Tank Mode**
- Optional **Hide Player Names**
- Optional **Hide NPC / Mob Names**
- Adjustable **Name Font Size**
- Adjustable **Name Y Offset**
- Adjustable **Health Text Font Size**
- Health text font outline options
- Aura layouts automatically adjust when names are hidden
- Foreign-tagged mobs use a neutral grey healthbar
- **Target Glow** with customizable color
- **Target Plate on Top**
- Improved nameplate detection for better compatibility with other UI addons
- Clean nameplate, aura and castbar layering

---

### ❤️ Health Text

Health information can be displayed directly on the nameplate with additional customization.

Options include:

- Health percentage display
- Adjustable **Font Size**
- Font outline:
  - None
  - Outline
  - Thick Outline

Health text customization is independent from the global nameplate scale.

---

### ☠️ Debuffs & DoTs

- GUID-based multi-target tracking
- Numeric aura timers
- Stack counters
- Reliable tracking across multiple visible nameplates
- Adjustable **Debuff Icon Size**
- Independent **Debuff Y Offset**
- Instant target-alpha updates

Available debuff positions:

- **Top Mid**
- **Top Left**
- **Top Right**
- **Left**
- **Right**
- **Bottom Mid**
- **Bottom Left**
- **Bottom Right**

Bottom-positioned debuffs are automatically taken into account by the castbar layout.

Mixed debuff and CC icon sizes are also spaced correctly when sharing the same top row.

---

### 🌀 Crowd Control

Dedicated Crowd Control tracking with independent layout options.

Features:

- Enable / disable CC tracking
- Optional supported CC effects from other players
- Separate **CC Icon Size**
- Independent **CC Y Offset**
- Optional **Separate CC Row**

Available CC positions:

- **Top**
- **Left**
- **Right**

When using a separate top row, CCs work correctly with:

- **Top Mid**
- **Top Left**
- **Top Right**

CCs and debuffs can share the same row even when using different icon sizes without overlapping.

---

### 🛡️ PvP Immunities

Important PvP immunity and protection effects can be displayed directly on nameplates.

Supported effects include abilities such as:

- Divine Shield
- Divine Protection
- Blessing of Protection
- Ice Block
- Berserker Rage
- Death Wish
- Recklessness
- Fear Ward
- Will of the Forsaken

Features:

- Dedicated **PvP Immunities** toggle
- Separate **Immunity Icon Size**
- Independent **Immunity Y Offset**
- Independent positioning
- Strict spell whitelist
- Fast removal when an immunity ends or is cancelled
- Cleanup of invalid debuff / CC states after effects such as Divine Shield or Ice Block
- Protection against stale aura information

Available positions:

- **Top**
- **Left**
- **Right**

---

### 🔥 Totem Indicators

Shaman totems can be displayed as clean and recognizable spell icons instead of full nameplates.

- Automatically detects supported Shaman totems
- Replaces the full totem nameplate with the corresponding spell icon
- Removes unnecessary healthbar, name and level clutter
- Adjustable **Totem Icon Size**
- Supports ranked totems automatically
- Designed especially for clearer PvP situations

---

### ✨ Combo Points

Combo Points are supported for:

- **Rogue**
- **Druid**

Features:

- Combo Points displayed directly above the target nameplate
- Adjustable **Combo Point Y Offset**
- Independent positioning from the rest of the nameplate
- Combo Points can remain visible on the previous target until new Combo Points are generated on another target

---

### 🔥 Castbars

- Enemy castbars
- Spell icons
- Adjustable **Castbar Height**
- Adjustable **Castbar Spacing**
- Adjustable **Castbar Y Offset**
- Castbar test mode
- Automatically adjusts when debuffs are positioned below the nameplate
- Improved layering so Target Glow does not cover the castbar

---

## ⚡ Performance & Compatibility

Blizz Nameplates+ is designed to keep the original Blizzard nameplates instead of replacing them with a completely custom nameplate system.

Recent improvements include:

- Reduced unnecessary nameplate updates
- Optimized aura and castbar handling
- No unnecessary permanent layout scanning
- Improved compatibility with addons that modify Blizzard nameplates
- More robust nameplate detection
- Mouseover tooltip support restored
- Mouseover macros work correctly on nameplates
- Settings are stored **per character**

The goal is to add functionality while keeping the addon lightweight and close to the original Blizzard UI.

---

## 🆕 What's New in v1.0.9

### 🛡️ PvP Immunity Tracking

A dedicated immunity system has been added for important PvP effects such as:

**Divine Shield, Ice Block, Blessing of Protection, Berserker Rage, Fear Ward** and other supported abilities.

Immunities have their own:

- Enable / disable option
- Icon size
- Position
- Y Offset
- Independent display logic

A strict spell whitelist prevents unrelated buffs from appearing as immunity icons.

---

### ☠️ Expanded Aura Positioning

Debuffs can now be positioned at:

- Top Mid
- Top Left
- Top Right
- Left
- Right
- Bottom Mid
- Bottom Left
- Bottom Right

CCs and Immunities have their own independent positioning and Y offsets.

This allows much more control over the final nameplate layout.

---

### ↕️ Independent Y Offsets

Separate Y-offset settings have been added for:

- **Debuffs**
- **Crowd Control**
- **PvP Immunities**
- **Combo Points**
- **Name Text**

Each element can now be moved vertically without changing the global nameplate scale.

---

### 🔤 Improved Font Customization

Additional text customization has been added.

**Name Text:**

- Adjustable Font Size
- Adjustable Y Offset

**Health Text:**

- Adjustable Font Size
- None / Outline / Thick Outline

These options are independent from Nameplate Scale.

---

### 👤 Player & NPC Name Controls

Player and NPC names can now be controlled independently:

- **Hide Player Names**
- **Hide NPC / Mob Names**

When names are hidden, top-positioned aura icons automatically move closer to the healthbar.

---

### 🌀 Improved CC Layout

The optional **Separate CC Row** now works correctly with:

- Top Mid
- Top Left
- Top Right

Different icon sizes are also handled correctly.

For example:

**18 px Debuffs + 24 px CC icons**

can share the same area without overlapping.

---

### 🎯 Improved Nameplate Detection

Nameplate detection has been made more robust for setups where other UI or skin addons modify parts of the original Blizzard nameplate.

This should help prevent issues such as:

- Missing borders
- Nameplates not being detected correctly
- Other UI addons changing the Blizzard nameplate before BNP initializes it

The compatibility handling is intentionally lightweight and does not continuously force the entire nameplate layout.

---

### 🖱️ Mouseover Support

Nameplate mouse interaction has been improved.

- Mouseover tooltips work correctly
- Mouseover macros can properly detect units through their nameplates

---

### 💾 Per-Character Settings

Settings are now stored **per character** instead of being shared account-wide.

Each character can therefore have its own:

- Nameplate layout
- Aura positions
- Icon sizes
- Alpha settings
- Castbar settings
- Target settings
- Font settings

---

## 🔎 Missing Spell / Aura Recorder

Missing a spell, DoT, proc or custom-server aura?

The built-in recorder creates one complete, copyable diagnostic report — no screenshots or manual chat commands required.

1. Open the BNP settings.
2. Go to **Tools**.
3. Click **Missing Spell / Aura...**
4. Select the affected unit.
5. Click **Start Recording**.
6. Apply the aura.
7. Refresh it while it is active.
8. Let it expire or remove it.
9. Click **Stop**.
10. Click **Copy Report**.
11. Paste the report into your bug report or support message.

The report can include:

- Spell IDs
- Aura timing
- Target information
- Refresh events
- Relevant aura state changes

The recorder is completely inactive until **Start Recording** is pressed and stops when the recorder window is closed.

---

## 📦 Requirements

Both DLLs are required and must be loaded before the game starts.

### SuperWoW.dll

Provides GUID, unit, combat and cast information used for:

- Multi-target tracking
- Castbars
- Nameplate identification
- Unit tracking

[Download SuperWoW](https://github.com/balakethelock/SuperWoW)

### ClassicAPI.dll

Provides more reliable nameplate and aura information, including:

- Spell IDs
- Aura durations
- Expiration times
- Exact nameplate resolution
- Instant target updates
- Recorder functionality
- PvP immunity tracking

[Download ClassicAPI](https://github.com/brues-code/ClassicAPI)

> **Keep both DLLs up to date.**  
> Blizz Nameplates+ is not supported without SuperWoW and ClassicAPI.

---

## 📥 Installation

1. Install `SuperWoW.dll` and `ClassicAPI.dll` using the instructions supplied with those projects.

2. Make sure both DLLs are enabled in your DLL loader or `dlls.txt`.

3. Delete any older `BlizzNameplatesPlus` addon folder.

4. Extract the new addon into:

   `Interface\AddOns\`

5. Verify that the final path is:

   `Interface\AddOns\BlizzNameplatesPlus\BlizzNameplatesPlus.toc`

6. Start the game through your DLL-enabled launcher.

7. Enable enemy nameplates.

---

## ⚙️ Settings

Open the settings using the **BN+ minimap button** or type:

`/bnp`

### 🎯 Nameplates

**General**

- Nameplate Scale
- Nameplate Y Offset
- Non-Target Alpha
- Class Colors
- Tank Mode
- Hide Player Names
- Hide NPC / Mob Names

**Names**

- Name Font Size
- Name Y Offset

**Health Text**

- Health Text Mode
- Health Font Size
- Health Font Outline

**Combo Points**

- Enable Combo Points
- Combo Point Y Offset

---

### ☠️ Auras

**Debuffs**

- Enable Debuffs
- Debuff Icon Size
- Debuff Position
- Debuff Y Offset

**Crowd Control**

- Enable Crowd Control
- CC Icon Size
- CC Position
- CC Y Offset
- Separate CC Row
- Show CCs from Other Players

**PvP Immunities**

- Enable PvP Immunities
- Immunity Icon Size
- Immunity Position
- Immunity Y Offset

---

### 🔥 Totems

- Enable Totem Icons
- Totem Icon Size

---

### 🔥 Castbar

- Enable Castbars
- Castbar Height
- Castbar Spacing
- Castbar Y Offset
- Test Castbars

---

### 🎯 Target

- Target Glow
- Glow Color
- Glow Scale
- Glow Alpha
- Target Arrows
- Target Plate on Top

---

### 🛠️ Tools

- Missing Spell / Aura Recorder

Most settings are applied immediately.

---

## ❤️ Credits

Created by **Wurmschwanz**.

Thanks to everyone who tested **Blizz Nameplates+**, reported bugs, suggested features and supplied recorder data.

Special thanks to everyone helping test different classes, PvP situations, addon combinations and large raid environments. ❤️

Your feedback continues to make Blizz Nameplates+ better.
