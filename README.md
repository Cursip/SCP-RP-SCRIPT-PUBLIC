# SCP: Roleplay — Silent Aim + Player ESP + Mod Menu

One script with its own mod menu (no more lone toggle button): tabs, switches, sliders,
dropdowns, colour pickers and keybind fields, plus config save/load.

| Section | Contents |
|---|---|
| `[2]` | Flags (remote build, author UI, team aliases, debug) |
| `[3]` | Toasts + console output |
| `[4]` | Custom UI library (window, tabs, elements) |
| `[7]` | Every option as a default + save/load (JSON) |
| `[8]` | Silent aim: target finder + **`BulletHit` hook** |
| `[9]` | ESP: highlight (chams) + box + name + distance + healthbar |
| `[9b]` | Player list window (team, role, HP, distance, ignored marking) |
| `[10]` | Extra features: noclip, fullbright — template for new features |
| `[10b]` | Utility (anti-AFK, FPS boost) + server stats |
| `[10c]` | Camera assist, auto fire, camera FOV, rejoin, server hop |
| `[10d]` | Staff detector, panic mode, hitbox expander |
| `[11]` | Menu build — this is where you bind options |
| `[12]` | Render and input loops |
| `[13]` | Start + unload |

## Usage

Run this in your executor (always pulls the latest version from this repo):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/loader.lua"))()
```

Or load the script directly:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/silent_aim_esp_merged.lua"))()
```

## Keys (all rebindable in the menu)

| Key | Action |
|---|---|
| `K` | show/hide the menu (the FOV ring, target info, ESP and toasts stay visible — they live in their own ScreenGui) |
| `RightShift` | toggle silent aim (or hold it, if "Only while key is held" is on) |
| `V` | toggle ESP |
| `N` | noclip |
| `B` | fullbright |
| `Delete` | unload (same as the button in Settings → Script) |

To rebind: click the key button on the right of a switch, then press the new key.

## Options

**Silent Aim**
- enabled, hold-to-aim, FOV radius, max distance
- **aim mode**: `Silent (BulletHit)` — SCP:RP only, hooks the game's shot function — or `Camera assist`, which turns your own camera and therefore works in any game (with a smoothness slider)
- optional auto-fire when the crosshair is on the target (risky, off by default)
- prediction slider (leads moving targets) and a hitbox expander (enlarges other players' head locally, mostly useful in games that hit-test on the client)
- team check, visible targets only, ignore ForceField, target part (`Head` / `HumanoidRootPart` / `Nearest`)
- "never target researchers": a role filter (researchers are a role, not always a team, so team name, role attributes and the character's labels are checked). The words to match live in `Config.Aim.RoleIgnoreList` (`researcher`, `forscher`, `research`, `wissenschaftler`) — the menu shows the current list, add words in the file if the game reports something else. The Debug tab shows per player what was detected (`ignored=true/false role="..."`).
- FOV circle + colour, target info (name / HP / distance) at the crosshair

**ESP**
- enabled, team check, visible players only, max distance
- chams/highlight with colour mode (`Static` / `Team` / `Health` / `Distance`), fill and outline colour, transparencies, "always visible through walls"
- box (thickness/transparency), name (colour/size), distance (colour/size), healthbar (width)
- name tag can show the detected role (e.g. "Forscher"), the player list window shows everyone with team, role, HP, distance and marks ignored players

**Player**
- noclip and fullbright, both with keybinds
- noclip safety: hold the key (default) so it stops on release, an on-screen indicator while active, an automatic off in toggle mode and it is never switched on by a config or preset
- movement (own section, all off by default): anti-ragdoll, infinite jump, bunnyhop, jump height, walkspeed, fly with fly speed
- anti-AFK (keeps you in the server), FPS boost (post effects and particle emitters off, fully restored when disabled)
- camera FOV slider, rejoin this server, server hop, remove fog and atmosphere

**Safety** (own tab)
- staff detector: checks a configurable group id and minimum rank (`GetRankInGroup`, cached for 10 s) and falls back to keywords in the role labels
- notifies when staff is in the server, marks them `[STAFF]` in red in the ESP and the player list
- panic mode: switches aim, ESP and noclip off while staff is present (they stay off until you enable them again)

**Settings**
- menu visible, UI scale
- save / load / delete config
- presets: three slots (`scp_aim_esp_slot1.json` ...) with save/load buttons and "auto-load this slot at start"; the working config is loaded at start and remembers the slot
- live server info (players, ping, FPS, server uptime, job id)
- re-centre menu, unload (removes menu, FOV ring, ESP and toasts, restores the aim hook, turns noclip/fullbright off)

## Flags (section `[2]`)

| Flag | Default | Meaning |
|---|---|---|
| `PREFER_REMOTE_BUILD` | `false` | `true` downloads `SCP_Roleplay/main.luau` fresh from the author's server instead of the inlined copy |
| `USE_AUTHOR_AIM_UI` | `false` | `true` also loads the author's own UI (its own FOV circle/tracers) |
| `FETCH_TEAM_ALIASES` | `false` | `true` also loads `Teams.luau` (the author's team alias table) |
| `DEBUG_AIM` | `true` | Debug tab with hook state, `getTarget` stats and the per-player team view |

## Adding a new feature (e.g. noclip)

1. Add a default (section `[7]`):
   ```lua
   Player = {
       Noclip = false,
       MyFeature = false,   -- new
   },
   ```
2. Write the setter (section `[10]`):
   ```lua
   local function setMyFeature(on)
       -- enable/disable
   end
   ```
3. Bind a toggle (section `[11]`):
   ```lua
   local s = playerTab:Section("My section")
   s:Toggle{
       text = "My feature", path = "Player.MyFeature",
       keybind = "MyFeature",                 -- optional, also add it to Config.Keybinds
       onChanged = function(v) setMyFeature(v) end,
   }
   ```
   For numbers, colours and choices use `s:Slider{...}`, `s:Color{...}` and `s:Dropdown{...}`.

Saving/loading, the keybind display and the switch styling come for free.

## Why the hook is the part that matters

`UIs/silent_aim.luau` only draws the FOV circle and tracers. Hits happen exclusively through the
`hookfunction` on `getsenv(Controller).BulletHit`, which swaps the hit data
(`{Instance, Position, Normal, Material}`) for the target. Without that block everything looks like
it works (tracers appear) while the bullets keep flying exactly where you aim.
The Debug tab shows `Hook: installed on Controller.BulletHit` when it is set up correctly.

## Update workflow

1. edit `silent_aim_esp_merged.lua`
2. `git commit -am "..." && git push`
3. run `loader.lua` in the executor again → latest version (the raw CDN may lag 1–5 minutes)

## Disclaimer

This repository contains **dual-use game-modding code**, published for private use in your own
Roblox session and for reading. It is not malware: it runs on the client, talks to no server of
ours and collects nothing. What it *can* do is break the rules of the game you use it in — Roblox's
Terms of Use and the game's own rules — and that is what can get an account banned, not GitHub.
No warranty, use at your own risk.

It builds on code from `sneekysscripts.uk` (see Credits) and claims no ownership of that code. If
you are a rights holder and want something changed or removed, please open an issue on this
repository before filing an abuse report — see [SECURITY.md](SECURITY.md).

## Credits

The silent aim part comes from `sneekysscripts.uk` (`SCP_Roleplay/main.luau`,
`UIs/silent_aim.luau`, `Teams.luau`); the ESP part is the separately supplied
"DeepHat Player-Only ESP". This repo merges both and adds the menu, the options and the extra
features.
