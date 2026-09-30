# SCP: Roleplay — Silent Aim + Player ESP (merged)

Eine Datei, die zwei Dinge kombiniert:

| Abschnitt | Inhalt |
|---|---|
| `[2]` | Config: `getgenv().sneeky_silent_aim`, `getgenv().sneeky_fov_size` |
| `[5]` | Silent Aim: Zielsuche + Aim-UI + **der `BulletHit`-Hook** (Inhalt von `SCP_Roleplay/main.luau`) |
| `[6]` | DeepHat Player-Only ESP: ein `Highlight` pro Spieler, Toggle-Button, `K` versteckt die GUI |
| `[7]` | Status-Panel (`F3` blendet aus), nur aktiv mit `DEBUG_AIM = true` |

## Benutzen

Im Executor ausführen — lädt immer die aktuelle Version aus diesem Repo:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/loader.lua"))()
```

Alternativ direkt `silent_aim_esp_merged.lua` laden (Datei oder raw-URL):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/silent_aim_esp_merged.lua"))()
```

Repo: **[Cursip/SCP-RP-SCRIPT-PUBLIC](https://github.com/Cursip/SCP-RP-SCRIPT-PUBLIC)** (öffentlich — nötig, damit die raw-URL im Executor ohne Token ladbar ist).

## Flags (Abschnitt `[2]`)

| Flag | Default | Bedeutung |
|---|---|---|
| `PREFER_REMOTE_BUILD` | `false` | `true` lädt `SCP_Roleplay/main.luau` frisch vom Author-Server, statt die eingebaute Kopie zu benutzen — nach einem Spielupdate die sicherere Variante |
| `FETCH_TEAM_ALIASES` | `false` | `true` lädt zusätzlich `Teams.luau`, die Alias-Tabelle des Authors (gruppiert Teams, die nur nach Name/Instanz verschieden sind) |
| `DEBUG_AIM` | `true` | Status-Panel oben links; `false` entfernt es komplett |

## Warum der Hook der entscheidende Teil ist

`UIs/silent_aim.luau` zeichnet nur FOV-Kreis und Tracer. Getroffen wird ausschließlich über den
`hookfunction` auf `getsenv(Controller).BulletHit`, der die Trefferdaten
(`{Instance, Position, Normal, Material}`) durch das Ziel ersetzt. Fehlt dieser Block, sieht alles
funktionierend aus (Tracer sind da), aber die Kugeln fliegen weiter genau dorthin, wo du zielst.

Am Status-Panel erkennst du das an Zeile 3: `BulletHit hook: installed on Controller.BulletHit`.

## Update-Workflow

1. `silent_aim_esp_merged.lua` bearbeiten
2. `git commit -am "..." && git push`
3. im Executor `loader.lua` neu ausführen → neueste Version

## Herkunft

Der Silent-Aim-Teil stammt aus `sneekysscripts.uk` (`SCP_Roleplay/main.luau`,
`UIs/silent_aim.luau`, `Teams.luau`); der ESP-Teil ist das separat gelieferte
„DeepHat Player-Only ESP". Diese Datei ist nur die Zusammenführung beider Teile.
