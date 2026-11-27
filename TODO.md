# YuFriend · Handoff dla kolegi z zespołu

Cel dokumentu: wprowadzić Cię w aktualną architekturę gra ↔ edytor i pokazać luki,
które musimy pozamykać. Projekt jest w trakcie migracji z hardcoded Main.tscn
(Godot) do modelu **"editor jako jedyne źródło prawdy"** — poziomy, elementy,
pozycje i zachowania mają pochodzić z plików JSON zapisywanych przez
`level-editor/` (serverless, File System Access API). Gra tylko je czyta.

---

## 1. Nowa struktura: co już działa

### 1.1 Edytor (`level-editor/`)

- Czysta przeglądarka — `index.html` + `app.js` + `model.js` + `fs.js` +
  `registry.js`. Bez serwera, bez modułów ES. Chrome/Edge (File System Access).
- Edytor trzyma **jeden folder główny repo** (user wskazuje raz, handle w
  IndexedDB). Projekt = jeden JSON w `level-editor/projects/*.json`.
- Biblioteka grafik: skan płaskiego katalogu `level-editor/assets/`.
  Arkusze animacji z prefiksem `sprites-` są filtrowane.
- Zapis: `projects/verN.json` (konwencja, patrz niżej). Fallback: "Pobierz JSON".
- Rejestr skryptów: `scripts.json` (czyta Godot) **i** `registry.js` (edytor).
  Parytet jest wymuszany testem `node --test level-editor/tests/model.test.mjs`.
- Uchwyty rozmiaru (niedawno dodane): 4 narożne z zachowaniem proporcji,
  4 krawędziowe wolne. Działa z undo i snap do siatki 3 jednostek.

### 1.2 Gra (Godot 4.7.2)

- Scena startowa: `Main.tscn` → `scripts/ui/main.gd` (GameUI). Trzyma całe
  handcrafted UI: HUD z 5 potrzebami, zakładki Dom/Ogród, menu ustawień,
  dialogi onboardingu, treats, album, mapa, chat card. **To zostaje.**
- `GameUI` (`scripts/ui/main.gd`) wybiera na starcie najnowszy `verN.json`
  (regex `^ver(\d+)\.json$`) z `projects/`. `RoomLayoutLoader` następnie:
  - czyta projekt przez `LevelProject.read_project`,
  - patchuje `RoomLayout.STATIONS` (dom) — pozycje, bounds, stand point,
  - patchuje tylko `bounds` dla `RoomLayout.YARD_STATIONS`,
  - zapamiętuje wczytany projekt w `active_project` + `active_textures`
    (statyczne pola — czytane przez `RoomView`).
- `RoomView` (`scripts/ui/room_view.gd`): gdy `active_project` nie jest pusty,
  ukrywa procedural `RoomArtwork`/ball_art/clock/ambient_life i renderuje
  `Sprite2D` per element edytora z `layer`/`pivot`/`z_index`.
- `LevelPreview.activate()` (`scripts/levels/level_preview.gd`) jest punktem
  wejścia skryptów elementu edytora (`feed`, `pet`, `bath`, `cuddle` itd.).

### 1.3 Skala świata

- **1440 × 540 jednostek** (po migracji z 1440×360). `FLOOR_Y=440`,
  `WALK_AREA=(95, 466, 1250, 42)`, `START=(670, 502)`.
- Grafiki PNG wrzucane do edytora w natywnej rozdzielczości HD —
  edytor dopasowuje początkowy rozmiar na scenie na podstawie
  `art-kit-warm.json` (jeśli grafika jest w kicie) albo generycznego
  fitowania do sceny. Tło zawsze wypełnia poziom.

### 1.4 Konwencja wersjonowania

- Edytor zapisuje do `level-editor/projects/verN.json`.
- Gra automatycznie wybiera **najwyższy N**. Patrz `_latest_version_project()`
  w `scripts/ui/main.gd`.
- Stare projekty są w `projects/_backup/`. `art-kit-warm*.json` pozostają
  w `projects/` dla narzędzi generowania grafik i domyślnych rozmiarów edytora.

---

## 2. Zasady tworzenia grafik

- Format: PNG, do 4096×4096, do 2,8 MB per plik.
- Natywna rozdzielczość: HD — nie downscale'uj przed zapisem. Edytor sam
  dopasuje rozmiar na scenie. Reguła kciuka: tło domu/ogrodu ok. 2160×810
  (żeby 3× fitowało do 1440×540), rekwizyt proporcjonalnie do roli.
- Nazwa pliku = `id` grafiki (`[a-zA-Z0-9_-]{1,64}`, musi zaczynać się literą).
  Subfoldery służą jako prefiks (`home/bed.png` → id `home-bed`).
- Arkusze animacji psa (`sprites/` wszędzie) są celowo pomijane przez edytor.
- Pivot grafiki (w px PNG) steruje głębokością w warstwie `middle` (y-sort).
  Ustaw tam, gdzie element "stoi na podłodze".

---

## 3. Zasady tworzenia skryptów

- Każdy element edytora ma **`script` + `params`**. Rejestr skryptów to
  **dwa pliki w sync'u**: `level-editor/scripts.json` (Godot) i
  `level-editor/registry.js` (przeglądarka). Node test to pilnuje.
- Schemat `params`: mapa `nazwa → {type, label, default, min, max}`. Typy:
  `number`, `text`, `string`, `bool`, `level` (dropdown poziomów), `clip`
  (nazwa klipu animacji psa z `scripts.json.clips`).
- Pole `static`: `true/false/null`. Kiedy nie-null, wymusza static w edytorze.
- Runtime po stronie gry: **dispatcher w `level_preview.gd` → `activate()`**.
  Dodając nowy skrypt do rejestru, dodaj tam gałąź `match`.
- Interaktywność: skrypt z `isInteractive(e)` = `true` (patrz `model.js`)
  dostaje handler kliknięcia i wejście w `completeScript()`.
- **Lista aktualnie wspieranych skryptów:** `none, message, thought, portal,
  feed, pet, clean, rest, ball, bark, greet, play_clip, walk_to, bath,
  cuddle, drink, sniff, course, timed_course, water, hide, visitor`.

---

## 4. Luki do zamknięcia (co jeszcze NIE przepięte na editor)

### 4.1 Mechaniki wywoływane z UI, nie przez skrypt elementu

Te systemy mają kod w `scripts/systems/*` ale **nie są skryptem w rejestrze**.
UI (`main.gd`) woła je bezpośrednio przez `session.xxx()`. Trzeba dla każdej:
dopisać wpis w `scripts.json`+`registry.js`, dodać gałąź w `level_preview.activate()`,
usunąć bezpośrednie wywołanie z `main.gd`, dodać element w edytorze.

- **training/tricks** — `main.gd:1546, 1569, 1625, 1653, 1667`
- **touch_play** — `main.gd:1255, 1293`
- **bubble_play** — `scripts/systems/bubble_play.gd`
- **outdoor_commands** (come/stay/praise) — `main.gd:1815-1841`
- **yard_routines / potty / cleanup** — `main.gd:1914-1915`
- **initiative/invitations** — `main.gd:709, 864-865`
- **fetch / throw_ball** z canvasa — `main.gd:262-266`
- **keepsake/decor** — `main.gd:2545`
- **digging_system**, **skill_play**, **yard_weather** (shade/sun)
- **wellbeing dialog**, **today_plan**

### 4.2 Pies reaguje na elementy, których NIE MA w projekcie

Dispatcher w `scripts/levels/level_room.gd:186-201` odpala
`session.start_bath / start_cuddle / home_drink.start / start_sniff /
course.start / timed_course.start / water.start / start_hide /
visitors.start` tylko na podstawie klucza skryptu — **nie sprawdza,
czy `RoomLayoutLoader.active_project.levels[*].elements` zawiera element**.
Analogicznie: `main.gd:830-836, 1538-1539, 2388-2443`. RoomView gatekeepuje
tylko rysowanie, nie logikę.

**Minimalny fix:**

1. Dodać helper w `RoomLayoutLoader`:
   ```gdscript
   static func has_script(script_id: String, level_id := "") -> bool:
       for l in active_project.get("levels", []):
           if level_id != "" and l.id != level_id: continue
           for e in l.elements:
               if str(e.get("script", "none")) == script_id: return true
       return false
   ```
2. Każde miejsce w `main.gd`/`level_room.gd` które odpala `session.xxx()`
   po skrypcie: wrap w `if RoomLayoutLoader.has_script("bath", "home"): …`.
3. Przyciski `care_actions`, `yard_menu`, `water_splash_button`,
   `yard_rest_stop`, `course_action` itp. — `.visible = has_script(…)`.
4. Dla treats / wellbeing / today_plan: ustalić czy są "globalne"
   (zawsze dostępne) czy mają być w projekcie. Jeśli globalne, zostawić;
   jeśli nie — dodać do rejestru jako skrypty i gatekeepować.

### 4.3 Hardcoded koordynaty (nadal 1440×360!)

Te systemy mają własne `const Vector2` i **nie są patchowane przez loader**.
Y są w starej skali — po migracji 1440×540 renderują się za wysoko.

| Plik | Linia | Stałe |
|---|---|---|
| `scripts/systems/home_drink.gd` | 4-5 | `BOWL(536,303), STAND(588,319)` |
| `scripts/systems/yard_water.gd` | 4 | `puddle(420,315), sprinkler(1230,315)` |
| `scripts/systems/yard_rest.gd` | 4-6 | `BED(220,315), DRINK(276,319), BOWL(330,325)` |
| `scripts/systems/yard_course.gd` | 4-6 | `PATH y=287/325, LANDING(1160,315), PODIUM(1270,306)` |
| `scripts/systems/yard_visitors.gd` | 10-11 | `FENCE(1010,205), SAFE_SPOT(810,310)` |
| `scripts/systems/digging_system.gd` | 33 | `move_to(650,315)` |
| `scripts/systems/bubble_play.gd` | 4, 45 | `WORLD(640,400) + clamp (40,145)-(600,330)` |
| `scripts/systems/ambient_life.gd` | 6, 104-121 | ANCHORS, hop paths, snail y=344, squirrel y=252 |
| `scripts/model/room_layout.gd` | 15-26 | YARD_STATIONS defaults — `point` NIE patchowany przez loader |

**Fix:**

1. Każdy system `yard_*` / `home_*` musi czytać z
   `RoomLayout.YARD_STATIONS[key].point / .bounds / .stand` zamiast
   własnych stałych.
2. Rozszerzyć `RoomLayoutLoader._patch_bounds_only()` → pełny `_patch()`
   dla YARD_STATIONS z `point` + `stand`, nie tylko `bounds`.
3. Dołożyć brakujące klucze do `YARD_STATIONS` defaults (`drink`, `bed`,
   `landing`, `podium`, `fence`, `safe_spot`), żeby loader miał co patchować.
4. `ambient_life` i `bubble_play` — albo zmigrować na projekt (każda
   pszczoła/bąbel jako element edytora), albo zabić — stary artefakt
   procedural, nie wie o projekcie.

---

## 5. Czego szukać / jak diagnozować

- **"Pies robi coś czego nie powinien"**: szukaj wywołania `session.xxx`
  w `main.gd` / `level_room.gd` nie opakowanego w `RoomLayoutLoader.has_script`.
- **"Element nie jest tam gdzie powinien"**: najpierw sprawdź czy
  `verN.json` ma aktualną pozycję, potem czy `RoomLayout.STATIONS[id]`
  jest patchowany (loguj `active_project.levels[0].elements` vs
  `RoomLayout.STATIONS`). Dla `YARD_STATIONS` — pamiętaj że `.point`
  nie jest patchowany.
- **"Grafika wygląda inaczej niż w edytorze"**: loader ładuje
  tekstury 1:1 z projektu. Test `tests/ui_editor_art_quality.gd` sprawdza
  zachowanie rozmiarów elementów HD na scenie.
- **"Gra nie czyta najnowszego JSON"**: `_latest_version_project()`
  w `main.gd` — regex `^ver(\d+)\.json$`. Kolejność: `--project=` CLI
  → najwyższy `verN.json` → zapamiętany w `user://active_project.txt` →
  `ver1.json`.

---

## 6. Testy, które muszą pozostać zielone

```bash
# JS (parytet rejestru + model edytora)
node --test level-editor/tests/model.test.mjs

# Godot (headless)
godot --headless --script res://tests/test_level_project.gd
godot --headless --script res://tests/test_room_layout_loader.gd
godot --headless --script res://tests/ui_level_editor.gd
godot --headless --script res://tests/ui_level_room.gd
```

`tests/ui_editor_art_quality.gd` **fail** jest spodziewany — ten test
zakłada stary HD-swap. Do rewizji razem z sekcją 4.

---

## 7. Co NIE ruszać bez pytania

- `project.godot` — scena startowa, autoloady, settings renderera.
- `scripts/pet/pet_animator.gd`, `manifest.json` — tylko po konsultacji
  (sprites mają przeliczony `display_height` i `scale` per clip,
  łatwo coś rozjechać).
- `GameSession.save/load` — Save Gloria to święte, osobny system.
- Konwencja `verN.json` — gra o nią wie, nie wprowadzaj innej nazwy.

---

## 8. Sugerowana kolejność działań

1. **Sekcja 4.3** — fix hardcoded coords i migracja 1440×540. Najtańsze,
   najbardziej widoczne (teraz pies kuca pod pustym rogiem sceny).
2. **Sekcja 4.2** — `RoomLayoutLoader.has_script()` + gatekeeping UI.
   Jeden helper, kilkanaście `if`-ów, szybka wygrana.
3. **Sekcja 4.1** — refaktoryzacja na skrypty. Najdroższe, podziel po
   jednym systemie na PR. Zacznij od `training` i `touch_play`
   (najprostsze), zostaw `bubble_play`/`ambient_life` na koniec.
