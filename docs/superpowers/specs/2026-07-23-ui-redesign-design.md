# UI-Redesign „Dragon Quest Monster Showdown" — Design-Spec

**Datum:** 2026-07-23
**Arbeitskopie:** `Dragon-Quest-Monster-UI-Redesign/` (separate Kopie; das Original-Repo bleibt unangetastet)
**Ziel:** Komplette Neugestaltung der grafischen Seite (UI/GUI) im Stil von Pokémon Showdown — Lobby, Team-Builder und Kampfbildschirm — in klassischer Dragon-Quest-Menüoptik. Godot 4.7, Desktop (kein Web).

## Rahmenentscheidungen (mit dem Nutzer abgestimmt)

| Frage | Entscheidung |
|---|---|
| Umfang | Alles: Lobby (neu) + Battle-Setup + Team-Builder + Kampfbildschirm + Dialoge |
| Art-Direction | Klassischer Dragon-Quest-Stil: Nachtblau, Panels mit weißem Doppelrahmen, Gold-Akzente, Pixel-Schrift |
| Battle-Layout | Arena-Ansicht wie Pokémon Showdown (Gegner oben rechts, eigene unten links, Log-Panel rechts, Command-Bar unten) |
| Animationen | Volle Ladung: HP-Tweens, Schadenszahlen, Hit-Flash/Shake, Faint-/Swap-Animationen, Typewriter-Log, sequenzielles Event-Playback |
| Sprache | UI-Texte bleiben Englisch |
| Umsetzungsansatz | UI-Kit + Control-basierte Arena (Ansatz 1) |

## Nicht-Ziele

- Keine Änderungen an Spiellogik: `battle/` (Engine, Events, State), `database/`, `save/`, `runtime/`, `utils/` bleiben unberührt. `ui/battle/battle_controller.gd` (reine Orchestrierung, UI-frei) bleibt unverändert.
- Kein Networking, kein Web-Export — der Zwei-Fenster-Mechanismus (ein Prozess, zwei OS-Fenster, geteilter `BattleController`) bleibt wie er ist.
- Keine neuen Gameplay-Features (Tactics bleibt deaktivierter Stub).
- Keine Übersetzung, keine neuen Monster-Assets.

## Design-System (`ui/theme/`)

**Farbwelt:**
- Hintergrund: tiefes Nachtblau, fast schwarz (`~#0a0c22`)
- Panels: dunkles Blauschwarz (`~#101230`) mit weißem Doppelrahmen — außen 2 px weiß, kleiner Abstand, innen 1 px weiß, leicht abgerundete Ecken (das ikonische DQ-Fenster)
- Akzent: Gold (`~#d9a441`) für Auswahl, Hover, `▶`-Cursor, wichtige Zahlen
- HP-Balken: Grün > 50 %, Amber > 20 %, Rot darunter (wie bisher), mit Rahmen und animierter Füllung; MP-Balken: Blau
- Log-Farbcodes: Schaden rot, Heilung grün, Status gelb, K.O. grau

**Typografie:** Frei lizenzierte Pixel-Schrift (OFL, wird ins Projekt gelegt) für Titel, Buttons, Monsternamen; gut lesbare Standardschrift für Log-Fließtext.

**Wiederverwendbare Komponenten (`ui/components/`, je Szene + Skript):**
- `DQPanel` — Doppelrahmen-Fenster (per Theme-StyleBox, nutzbar auf jedem PanelContainer)
- `DQButton` — Button mit `▶`-Cursor bei Hover/Fokus
- `HPBar` / `MPBar` — animierte Balken mit Zahlenanzeige, tweenen zum neuen Wert
- `MonsterBattleSprite` — großes Sprite + schwebendes Namensschild (Name, Slot-Badge, HP, bei eigenen auch MP); Animations-API: `play_hit()`, `play_faint()`, `play_enter()`, `show_damage_number()`, Targeting-Highlight
- `BattleLogPanel` — RichTextLabel mit Typewriter-Effekt, Farbcodes, Auto-Scroll
- `TeamSlotCard` — Monsterkachel (Sprite, Name, Slot-Badge) für Team-Builder und Battle-Setup

## Screen-Flow & Lobby (`ui/lobby/`)

```
Lobby (neue Hauptszene, ersetzt team_builder als main_scene)
 ├─ "BATTLE!"     → Battle-Setup
 ├─ "Teambuilder" → Team-Builder
 └─ "Quit"
```

- Lobby: Titelbildschirm mit Spieltitel als großem Text-Logo, darunter DQ-Menüfenster mit den drei Optionen und `▶`-Cursor.
- Battle-Setup: beide Teams als Sprite-Vorschau-Reihen („Team A vs Team B") statt nackter Dropdowns; Team-Auswahl weiterhin über Auswahlliste, Start-Button erst aktiv, wenn beide Teams gültig (bestehende Validierungslogik unverändert). Zurück-Button zur Lobby.
- Zweites Battle-Fenster wird mit 1280×720 gespawnt (gleiches Layout wie Hauptfenster).

## Kampfbildschirm (`ui/battle/`)

```
┌────────────────────────────────────────────┬──────────────────┐
│  ARENA (~70 %)                             │  BATTLE LOG      │
│      [Nameplate HP]   [Nameplate HP]       │  (~30 %,         │
│         Gegner-Sprites oben rechts         │  Typewriter,     │
│   Eigene Sprites unten links               │  farbcodiert,    │
│  [Nameplate HP MP]  [Nameplate HP MP]      │  Auto-Scroll)    │
├────────────────────────────────────────────┴──────────────────┤
│ ▶ Commanding: <Name>        [ FIGHT ] [ ORDERS ] [ TACTICS ]  │
└───────────────────────────────────────────────────────────────┘
```

- **Arena:** dunkler Boden mit Verlauf/Vignette. Sprites ~140–180 px; Multi-Slot-Monster (species.slots 1–4) proportional größer/breiter mit Slot-Badge (z. B. „◆◆"). Dedupe pro `instance_id` wie bisher. Leere Slots: dezente Boden-Markierung. Das aktuell kommandierte eigene Monster erhält goldenen Rahmen/Glanz.
- **Command-Bar:** „Commanding: <Name>" mit `▶`-Cursor; FIGHT öffnet Skill-Liste im selben Bereich (Name + MP-Kosten, ausgegraut ohne MP, Back-Button), ORDERS zeigt Bank mit Mini-Sprites, TACTICS bleibt deaktiviert. Waiting-Zustand: „Waiting for the other side…".
- **Targeting:** Einzelziel-Skill schaltet Arena in Zielwahl — lebende Gegner pulsieren gold und sind klickbar, Hinweistext „Choose a target", Abbruch über Back.
- **Ende:** Vollbild-Overlay (abgedunkelt) mit DQ-Fenster „You Win!" / „You Lose!" + „Back to Lobby".

**Animationssystem:** Die von `turn_resolved` gelieferten Events werden nicht mehr auf einmal angewendet, sondern über eine kleine Playback-Queue sequenziell abgespielt (~0,5 s pro Event, Log-Zeile synchron zur Animation):
- `DamageAppliedEvent`: HP-Tween + rote Schadenszahl + Hit-Flash/Shake
- `HealingAppliedEvent`: HP-Tween + grüne Zahl
- `StatusAppliedEvent`: gelbe Log-Zeile + kurzes Icon-/Farb-Feedback
- `MonsterFaintedEvent`: Sprite kippt/verblasst
- `MonsterEnteredEvent`: Sprite gleitet von der Seite ein
- Eingaben (Command-Bar) sind während des Playbacks gesperrt; danach normale Slot-Weiterschaltung wie bisher.

Wichtig: Das Playback ist reine Darstellung — der `BattleController` löst den Turn weiterhin synchron auf; die View spielt die bereits feststehenden Events nur zeitversetzt ab.

## Team-Builder & Dialoge (`ui/team_builder/`)

- **Links:** Team-Liste als DQ-Panel — Teamname + Mini-Sprite-Reihe der Mitglieder, „New Team" unten.
- **Rechts:** Editor — Teamname groß, Mitglieder als `TeamSlotCard`-Zeilen (großes Sprite, Name, Slot-Badge, Skill-Chips, Hoch/Runter/Entfernen), Validierungsbanner rot im DQ-Stil. Funktionalität 1:1 (Auto-Save, Signale, `TeamRosterManager`-Aufrufe unverändert).
- **Monster-Picker:** durchsuchbares Sprite-Grid (Suchfeld, Kacheln mit Sprite/Name/Slot-Badge, Klick wählt).
- **Skill-Punkte-Dialog:** gleiche Funktion im DQ-Fenster-Stil.
- Top-Bar erhält zusätzlich „Back to Lobby".

## Dateistruktur (neu/geändert, alles unter `game/`)

```
ui/theme/        NEU: dq_theme.tres, Fonts, ggf. generierte StyleBox-Texturen
ui/components/   NEU: dq_button, hp_bar, mp_bar, monster_battle_sprite,
                      battle_log_panel, team_slot_card (+ .tscn je Komponente)
ui/lobby/        NEU: lobby_screen.tscn/.gd
ui/battle/       battle_setup_screen.* und battle_side_view.* neu aufgebaut;
                 battle_controller.gd UNVERÄNDERT; NEU: event_playback.gd
ui/team_builder/ alle Szenen/Skripte neu aufgebaut, gleiche Signal-Schnittstellen
project.godot    main_scene → Lobby, Theme → dq_theme.tres
```

## Fehlerbehandlung & Tests

- Fehlerpfade bleiben wie bisher (fehlende Teams/Species → Fehlertext im Setup-Screen, jetzt im DQ-Banner-Stil).
- Sprite-Ladefehler (fehlende Datei): Platzhalter-Silhouette statt Absturz.
- Bestehende Tests in `game/tests/` müssen unverändert grün bleiben (keine Logik-Änderung).
- Manuelle Verifikation: Godot-Editor-Start, kompletter Durchstich Lobby → Teambuilder → Setup → Kampf (beide Fenster) → Ende → zurück zur Lobby.
