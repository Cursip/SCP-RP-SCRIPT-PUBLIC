# Features

Current build: **v4.6-beta2** (the build stamp in the title bar tells you which revision is running).
9 tabs, 30 sections, **97 configurable options**, 45 console commands, 17 action buttons. Every
switch and every button has a keybind slot.

## Silent Aim (`Aim`)

- **silent aim** — hooks the game's shot function (`Controller.BulletHit`) and redirects the hit to the
  selected target part. SCP:RP only, because that function is game-specific
- **camera assist** — the portable alternative: turns your own camera towards the target, works in any
  game, with a smoothing slider
- **FOV radius** with ring and colour; the ring is always centred on the crosshair and stays put in
  every camera mode
- hold-to-aim, max distance, target part (`Head` / `HumanoidRootPart` / `Nearest`)
- filters: team check, visible only (line of sight), ignore ForceField, ignore whole roles
  (`researcher`, `forscher`, `research`, `wissenschaftler` — editable in the config)
- **prediction** slider, used by camera assist only. Silent aim always sends the exact impact
  position, because tests showed the game evaluates it
- **hitbox expander** (target head size + transparency, restored on disable)
- target info overlay (name, HP, distance) next to the FOV ring
- auto fire when the crosshair is on the target (off by default, flagged as the riskiest option)

## ESP (`ESP`)

- **highlight (chams)** with team colours, fill and outline colour, transparency, always-on-top
- **box** (thickness, transparency)
- **name tags** with the role from the game, size and colour
- **distance** in studs, **HP number**, **weapon name** (all optional)
- **healthbar** with adjustable width
- filters: team check, visible only, max distance
- detected staff is marked `[STAFF]` in red

## Player list (`List`)

- its own draggable window with a scroll area: name, role, team, HP, distance
- marks ignored players (dimmed) and staff (red `STAFF`)

## Player and movement (`Player`, `Movement`)

- **noclip**: hold the key by default, on-screen indicator while active, automatic off in toggle mode,
  and a config never switches it on by itself
- **fullbright**
- anti-ragdoll, infinite jump, bunnyhop, jump height, walkspeed
- **fly** (WASD, Space up, Ctrl down) with speed slider
- pranks that change your own physics: **moon gravity**, **ice mode** (no friction), **moonwalk**
  (velocity inverted), **marionette** (`PlatformStand` + angular velocity)

## Fun (`Fun`) — animations and pranks

- **animation player**: plays the animations the game itself ships; the list is read from the game
  (character, `ReplicatedStorage`, `PlayerScripts`) instead of being guessed
- **SCP-173 mode**: while another player faces you with a clear line of sight your movement stops and
  your animation tracks freeze, so you look like a statue. Status line names the watcher
- **SCP-096 mode**: same line-of-sight check, but plays an animation at double speed and can charge
  at whoever saw you
- **echo**: record where you walk and replay it — the character follows the path alone
- **mimic**: copies the nearest player's animations, including their playback speed
- **beyblade**: spins the character in place
- local gags (only you see them): fake breach alert, fake staff warning, with a duration slider

Everything above is visible to other players, because it uses what a client really owns: its
animation state, its character's physics and its movement. Locally created instances, sounds and part
properties never replicate, which is why they are not used for pranks.

## Safety (`Safety`)

- **staff detector**: checks a group id and minimum rank (`GetRankInGroup`) and names the reason in
  the message
  - default group **5479038 = "SCP | Roleplay Community"**, the official game group. Verified through
    the Roblox API: rank `1` is a normal member, `248` Trial Moderator, `249`-`251` Game/Senior/Head
    Moderator, `252`-`255` Developer to Administrator. Staff therefore starts at **248**
  - the label scan is **off by default** (a substring search once flagged a normal player) and only
    matches whole words when enabled
  - `KnownNames` / `IgnoreNames` override everything by player name
- **panic mode**: switches aim, ESP and noclip off while staff is present
- **anti-moderator**: unload the script and leave the server when staff joins

## Utility (`Utility`, `Misc`)

- **anti-AFK** (stays in the server), **FPS boost** (post effects and particle emitters off, fully
  restored when disabled)
- **camera FOV** slider, **remove fog and atmosphere** (both restored)
- **rejoin this server**, **server hop**
- **watermark HUD** (build, FPS, players, executor)
- live server stats: players, ping, FPS, server uptime, job id

## Menu and UI

- own UI library: window, tabs, sections, toggles, sliders, dropdowns, colour pickers, buttons
- **theme**: six presets (`Blue`, `Emerald`, `Crimson`, `Violet`, `Amber`, `Graphite`) plus colour
  pickers for accent, window, rows and text. Applied **live** without rebuilding the menu; panel,
  sidebar, borders, hover shades and dim text are derived automatically
- **colour pickers** show the current value as `R G B`, offer eight quick-pick chips and confirm with
  a toast, so a change is never ambiguous
- **keybind slot on every switch and every button** — only five come with a default (`K`, `RightShift`,
  `V`, `N`, `B`); `Backspace` clears a binding
- **console tab**: 45 commands, `set <path> <value>` for all 97 options (including side effects),
  `list`, `get`, shortcuts, Up/Down history
- **config**: save / load / delete, plus three preset slots with "auto-load this slot at start"
- **unload**: restores the aim hook, noclip, fullbright, fog, hitbox, gravity, ice, animations, zoom
  and GUI state
- the wheel scrolls the menu without zooming the camera; the menu leaves the instance tree while it is
  hidden and both GUIs use neutral names

## Diagnostics

- **Debug tab**: hook state, target statistics, per-player role and team with the exact reason a
  player is skipped (`ignored=role "..."` / `attr ...` / `team ...`), the animations this game
  actually provides, and the wheel/zoom state

## Deliberately not included

- **server-side actions**: giving items, spawning objects for others, triggering game events, moving
  or teleporting other players, faking chat. All of that is server-authoritative, so only a remote
  request could do it — and one the game does not validate is abuse of that game's code, the fastest
  way to lose the account, and it affects other players
- **anti-cheat evasion**: bypasses, spoofers, HWID cleaners, driver disguises
- **tracers** were removed on request, and **auto fire** is off by default
