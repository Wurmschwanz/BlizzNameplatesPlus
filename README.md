# ⚔️ Blizz Nameplates+

**Blizz Nameplates+** enhances the original Blizzard nameplates for **Vanilla WoW / WoW 1.12** while preserving their classic look and feel.

It adds reliable multi-target aura tracking, Crowd Control, PvP immunity tracking, castbars, Combo Points, PvP totem indicators and additional visual customization without replacing the original Blizzard nameplate design.

**Current version:** `v1.0.9`  
**Required:** `SuperWoW.dll` and `ClassicAPI.dll`

---

## ✨ Features

### 🎯 Nameplates

- Adjustable nameplate scale and Y offset
- Adjustable non-target alpha
- Enemy class colors
- Tank Mode
- Health text options
- Optional **Hide Player Names**
- Optional **Hide NPC/Mob Names**
- Aura layout automatically becomes more compact when names are hidden
- Foreign-tagged mobs shown with a neutral grey healthbar
- Target Glow with selectable glow color
- Target Plate on Top
- Clean nameplate and aura layering

### ☠️ Auras & Debuffs

- GUID-based multi-target debuff and DoT tracking
- Numeric aura timers
- Stack counters
- Reliable tracking across multiple visible nameplates
- Adjustable aura icon size
- Independent debuff positioning:
  - **Top Mid**
  - **Top Left**
  - **Top Right**
  - **Left**
  - **Right**
  - **Bottom Mid**
  - **Bottom Left**
  - **Bottom Right**
- Bottom-positioned debuffs are automatically taken into account by the castbar layout
- Mixed debuff and CC icon sizes are spaced correctly when sharing the same top row
- Instant target-alpha updates

### 🌀 Crowd Control

- Dedicated Crowd Control tracking
- Optional supported CC effects from other players
- Separate **CC Icon Size**
- CC positioning:
  - **Top**
  - **Left**
  - **Right**
- Optional dedicated CC row for:
  - **Top Mid**
  - **Top Left**
  - **Top Right**
- CCs can share the top aura row with debuffs without overlapping, even when different icon sizes are used

### 🛡️ PvP Immunities

Important PvP immunity and protection effects can be displayed directly on nameplates.

Supported effects include relevant abilities such as:

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
- Independent immunity positioning:
  - **Top**
  - **Left**
  - **Right**
- Strict spell whitelist to prevent unrelated buffs from being displayed as immunities
- Immunity icons disappear when the corresponding aura is removed or cancelled
- Divine Shield and Ice Block immediately clear invalid BNP debuff/CC display states where appropriate
- Protection against stale aura information causing removed debuffs to briefly reappear

### 🔥 Totem Indicators

Shaman totems can be displayed as clean, easily recognizable icons instead of full nameplates.

- Automatically detects supported Shaman totems
- Replaces the entire totem nameplate with the corresponding spell icon
- No healthbar, name or level clutter
- Adjustable **Totem Icon Size**
- Designed especially for clearer PvP situations
- Supports ranked totems without requiring separate configuration

### ✨ Class Features

- Blizzard-style Combo Points for:
  - Rogue
  - Druid

### 🔥 Castbars

- Enemy castbars
- Spell icons
- Adjustable castbar height
- Adjustable spacing
- Castbar test mode
- Automatically adjusts when debuffs are positioned below the nameplate

---

## 🆕 What's New in v1.0.9

### 🛡️ PvP Immunity Tracking

A new dedicated immunity system has been added for important PvP effects such as **Divine Shield, Ice Block, Blessing of Protection, Berserker Rage, Fear Ward** and other supported abilities.

Immunity tracking uses a strict spell whitelist so unrelated buffs cannot accidentally appear as immunity icons.

Immunities have their own:

- Enable/disable option
- Icon size
- Position setting
- Independent display logic

Supported positions are:

- **Top**
- **Left**
- **Right**

Immunity icons are also removed quickly when the aura ends or is cancelled.

### ✨ Divine Shield / Ice Block Cleanup

Protection effects such as **Divine Shield** and **Ice Block** now correctly clean up BNP's stored aura state where appropriate.

This prevents removed debuffs or Crowd Control effects from remaining visible because of stale aura information.

### 👤 Hide Player and NPC Names

Two new nameplate options have been added:

- **Hide Player Names**
- **Hide NPC/Mob Names**

These settings are independent, allowing player names and NPC names to be controlled separately.

When a name is hidden, top-positioned aura icons automatically move closer to the healthbar to use the newly available space.

### ☠️ Expanded Debuff Positioning

Debuff placement has been significantly expanded.

Available positions are now:

- **Top Mid**
- **Top Left**
- **Top Right**
- **Left**
- **Right**
- **Bottom Mid**
- **Bottom Left**
- **Bottom Right**

`Top Mid` replaces the previous standard `Top` layout and remains the default.

Bottom layouts also interact correctly with castbar positioning.

### 🌀 Improved CC Row Layout

The optional **Separate CC Row** can now be used with all three top debuff alignments:

- **Top Mid**
- **Top Left**
- **Top Right**

When CCs and debuffs share the same row, their individual icon sizes are now taken into account.

For example, **18 px debuffs** and **24 px CC icons** can be displayed together without overlapping.

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

Provides the GUID, unit, combat and cast information used for:

- Multi-target tracking
- Castbars
- Nameplate identification
- Unit tracking

[Download SuperWoW](https://github.com/balakethelock/SuperWoW)

### ClassicAPI.dll

Provides exact nameplate resolution and more reliable aura information, including:

- Spell IDs
- Aura durations
- Expiration times
- Exact nameplate resolution
- Instant target updates
- Recorder functionality
- PvP immunity tracking

[Download ClassicAPI](https://github.com/brues-code/ClassicAPI)

> **Keep both DLLs up to date.**  
> Without SuperWoW and ClassicAPI, Blizz Nameplates+ is not supported.

---

## 📥 Installation

1. Install `SuperWoW.dll` and `ClassicAPI.dll` using the instructions supplied with those projects.

2. Make sure both DLLs are enabled in your DLL loader or `dlls.txt`.

3. Delete any older `BlizzNameplatesPlus` addon folder.

4. Extract the new addon folder into:

   `Interface\AddOns\`

5. Verify that the final path is:

   `Interface\AddOns\BlizzNameplatesPlus\BlizzNameplatesPlus.toc`

6. Start the game through your DLL-enabled launcher.

7. Enable enemy nameplates.

---

## ⚙️ Settings

Open the settings through the **BN+ minimap button** or type:

`/bnp`

### Nameplates

- Nameplate Scale
- Y Offset
- Non-Target Alpha
- Class Colors
- Tank Mode
- Health Text
- Hide Player Names
- Hide NPC/Mob Names
- Combo Points

### Auras

- Aura Icon Size
- Debuffs
- Debuff Position:
  - Top Mid
  - Top Left
  - Top Right
  - Left
  - Right
  - Bottom Mid
  - Bottom Left
  - Bottom Right
- Crowd Control
- CC Icon Size
- CC Position:
  - Top
  - Left
  - Right
- Separate CC Row
- CCs from Other Players
- PvP Immunities
- Immunity Position:
  - Top
  - Left
  - Right
- Immunity Icon Size

### Totems

- Enable Totem Icons
- Totem Icon Size

### Castbar

- Enable Castbars
- Castbar Height
- Castbar Spacing
- Test Castbars

### Target

- Target Glow
- Glow Color
- Target Plate on Top

### Tools

- Missing Spell / Aura Recorder

Most changes are applied immediately.

---

## ❤️ Credits

Created by **Wurmschwanz**.

Thanks to everyone who tested **Blizz Nameplates+**, reported bugs, suggested features and supplied recorder data.

Special thanks to everyone helping test different classes, PvP situations and large raid environments. ❤️
