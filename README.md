# ⚔️ Blizz Nameplates+

**Blizz Nameplates+** enhances the original Blizzard nameplates for **Vanilla WoW / WoW 1.12** while preserving their classic look and feel.

It adds reliable multi-target aura tracking, Crowd Control, castbars, Combo Points, PvP totem indicators and additional visual customization without replacing the original Blizzard nameplate design.

**Current version:** `v1.0.8`  
**Required:** `SuperWoW.dll` and `ClassicAPI.dll`

---

## ✨ Features

### 🎯 Nameplates

- Adjustable nameplate scale and Y offset
- Adjustable non-target alpha
- Enemy class colors
- Tank Mode
- Health text options
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
- Debuff positioning:
  - **Top**
  - **Left**
  - **Right**
- Instant target-alpha updates

### 🌀 Crowd Control

- Dedicated Crowd Control tracking
- Optional supported CC effects from other players
- Separate **CC Icon Size**
- Optional dedicated CC row when using the **Top** aura layout
- Side layouts automatically keep CCs compact with the other aura icons

### 🔥 Totem Indicators

Shaman totems can now be displayed as clean, easily recognizable icons instead of full nameplates.

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

---

## 🆕 What's New in v1.0.8

### New Aura Positioning

Aura icons can now be positioned:

- **Top**
- **Left**
- **Right**

This is especially useful when many nameplates overlap and a horizontal layout provides better visibility.

### Separate CC Icon Size

Crowd Control icons now have their own independent size setting.

You can keep regular DoTs compact while making important CC effects larger and easier to recognize.

### Totem Icon Mode

Shaman totem nameplates can now be automatically replaced by their spell icons.

Instead of several small 5 HP nameplates filling the screen, important battlefield objects remain immediately recognizable with significantly less visual clutter.

### Redesigned Options Menu

The settings menu has been reorganized into compact tabs:

- **Nameplates**
- **Auras**
- **Totems**
- **Castbar**
- **Target**
- **Tools**

This keeps the interface much cleaner as Blizz Nameplates+ continues to grow.

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
- Combo Points

### Auras

- Aura Icon Size
- Debuffs
- Aura Position: Top / Left / Right
- Crowd Control
- CC Icon Size
- Separate CC Row
- CCs from other players

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
