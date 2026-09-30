# SCP: Roleplay — Silent Aim + Player ESP + Mod Menu

Ein Skript mit eigenem Menü (kein Einzel-Button mehr): Tabs, Toggle, Slider, Dropdowns,
Farb- und Keybind-Picker, Config-Speicherung.

| Abschnitt | Inhalt |
|---|---|
| `[2]` | Flags (Remote-Build, Fremd-UI, Team-Aliase, Debug) |
| `[3]` | Toasts + Konsolenausgabe |
| `[4]` | eigene UI-Library (Fenster, Tabs, Elemente) |
| `[7]` | Alle Optionen als Defaults + Speichern/Laden (JSON) |
| `[8]` | Silent Aim: Zielsuche + **`BulletHit`-Hook** |
| `[9]` | ESP: Highlight (Chams) + Box + Name + Distanz + Healthbar |
| `[10]` | Extra-Features: Noclip, Fullbright — Vorlage für neue Features |
| `[11]` | Menü-Aufbau (hier bindest du Optionen) |
| `[12]` | Render-/Input-Loops |
| `[13]` | Start + Unload |

## Benutzen

Im Executor ausführen (lädt immer die aktuelle Version aus diesem Repo):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/loader.lua"))()
```

Oder direkt das Skript:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/silent_aim_esp_merged.lua"))()
```

## Tasten (alle im Menü änderbar)

| Taste | Wirkung |
|---|---|
| `K` | Menü ein-/ausblenden |
| `RightShift` | Silent Aim an/aus (bzw. halten, wenn „Nur solange Taste gehalten" aktiv ist) |
| `V` | ESP an/aus |
| `N` | Noclip |
| `B` | Fullbright |

Keybind ändern: im Menü auf den Tasten-Button rechts am Toggle klicken und die neue Taste drücken.

## Optionen

**Silent Aim**
- aktiv, „nur solange Taste gehalten", FOV-Radius, max. Distanz
- Team-Check, nur sichtbare Ziele, ForceField ignorieren, Ziel-Part (`Head` / `HumanoidRootPart` / `Nearest`)
- FOV-Kreis + Farbe, Tracer + Farbe + Dicke, Ziel-Info (Name/HP/Distanz) am Fadenkreuz

**ESP**
- aktiv, Team-Check, nur sichtbare Spieler, max. Distanz
- Chams/Highlight mit Farbmodus (`Static` / `Team` / `Health` / `Distance`), Füll- und Umrissfarbe, Transparenzen, „immer durch Wände sichtbar"
- Box (Dicke/Transparenz), Name (Farbe/Größe), Distanz (Farbe/Größe), Healthbar (Breite)

**Player**
- Noclip (mit Keybind), Fullbright (mit Keybind)

**Einstellungen**
- Menü sichtbar, UI-Größe
- Config speichern / laden / löschen
- Menü neu positionieren, Unload (entfernt GUI, Hooks und stellt Noclip/Fullbright zurück)

## Flags (Abschnitt `[2]`)

| Flag | Default | Bedeutung |
|---|---|---|
| `PREFER_REMOTE_BUILD` | `false` | `true` lädt `SCP_Roleplay/main.luau` frisch vom Author-Server statt der eingebauten Kopie |
| `USE_AUTHOR_AIM_UI` | `false` | `true` lädt zusätzlich die Fremd-UI des Authors (eigener FOV-Kreis/Tracer) |
| `FETCH_TEAM_ALIASES` | `false` | `true` lädt zusätzlich `Teams.luau` (Alias-Tabelle des Authors) |
| `DEBUG_AIM` | `true` | Debug-Tab mit Hook-Status, `getTarget`-Statistik und Team-Ansicht |

## Neues Feature hinzufügen (z. B. Noclip)

1. Default ergänzen (Abschnitt `[7]`):
   ```lua
   Player = {
       Noclip = false,
       MeinFeature = false,   -- neu
   },
   ```
2. Funktion schreiben (Abschnitt `[10]`):
   ```lua
   local function setMeinFeature(on)
       -- an/aus
   end
   ```
3. Toggle binden (Abschnitt `[11]`):
   ```lua
   local s = playerTab:Section("Mein Bereich")
   s:Toggle{
       text = "Mein Feature", path = "Player.MeinFeature",
       keybind = "MeinFeature",              -- optional
       onChanged = function(v) setMeinFeature(v) end,
   }
   ```
   Für Zahlen/Farben/Auswahlen: `s:Slider{...}`, `s:Color{...}`, `s:Dropdown{...}`.
   Der Keybind muss zusätzlich in `Config.Keybinds` stehen.

Speichern/Laden, Keybind-Anzeige und Haken-Optik kommen automatisch mit.

## Warum der Hook der entscheidende Teil ist

`UIs/silent_aim.luau` malt nur FOV-Kreis und Tracer. Getroffen wird ausschließlich über den
`hookfunction` auf `getsenv(Controller).BulletHit`, der die Trefferdaten
(`{Instance, Position, Normal, Material}`) gegen das Ziel tauscht. Fehlt dieser Block, sieht alles
funktionierend aus (Tracer sind da), aber die Kugeln fliegen weiter dorthin, wo du zielst.
Der Debug-Tab zeigt `Hook: installiert auf Controller.BulletHit`, wenn es passt.

## Update-Workflow

1. `silent_aim_esp_merged.lua` bearbeiten
2. `git commit -am "..." && git push`
3. im Executor `loader.lua` neu ausführen → neueste Version (raw-CDN braucht ggf. 1–5 Minuten)

## Herkunft

Der Silent-Aim-Teil stammt aus `sneekysscripts.uk` (`SCP_Roleplay/main.luau`,
`UIs/silent_aim.luau`, `Teams.luau`); der ESP-Teil ist das separat gelieferte
„DeepHat Player-Only ESP". Menü, Optionen und Zusatzfeatures sind hier zusammengeführt.
