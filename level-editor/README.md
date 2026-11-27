# YuFriend Studio · Edytor poziomów

Lekki edytor WWW (przeglądarka + lokalny serwer Pythona) do budowania poziomów
dla gry YuFriend. Gra i edytor czytają ten sam kontrakt danych — jeden plik
JSON na projekt, jeden folder PNG-ów, jeden rejestr skryptów.

## Uruchomienie

Otwórz `level-editor/index.html` w Chrome lub Edge — bez serwera, bez zależności.
Edytor przy starcie pyta o folder YuFriend (wskaż katalog, w którym znajduje się
`level-editor/`). Przeglądarka poprosi o zgodę na odczyt i zapis. Folder jest
pamiętany między uruchomieniami (IndexedDB) — kolejne otwarcie HTML od razu
wczytuje projekt startowy.

Edytor używa [File System Access API](https://developer.chrome.com/docs/capabilities/web-apis/file-system-access),
więc Safari i Firefox nie obsłużą zapisu w folderze projects/. W tych
przeglądarkach używaj „Otwórz → Wybierz plik JSON" i „Pobierz JSON".

## Struktura folderu

```
level-editor/
  assets/                # ← PNG do biblioteki. Dropnij tu plik, klik ↻ w panelu
    bed.png              # „Biblioteka grafik" i gotowe.
    home-background.png
    kategoria/
      obiekt.png         # id = "kategoria-obiekt"
  projects/
    starter.json         # wzorzec (chroniony przed nadpisaniem)
    moj-projekt.json     # Twoje zapisy
  scripts.json           # rejestr skryptów (patrz niżej)
  registry.js            # ten sam rejestr dla przeglądarki
  index.html             # otwórz w Chrome/Edge — zero serwera
  app.js, model.js, fs.js # kod edytora (klasyczne skrypty)
```

Dodatkowo edytor widzi też grafikę z folderu gry: `assets/art/yard/sprites/*.png`,
`assets/art/home/sprites/*.png`, `assets/art/environments/*.png`, `assets/sprites/puppy/pixel/*.png`.

## Konwencja nazwowa grafik

- Nazwa pliku → `id` grafiki. `bed.png` → id `bed`, `home/bed.png` → id `home-bed`
- Tylko `[a-zA-Z0-9_-]`, max 64 znaki, musi zaczynać się literą
- Max 4096 × 4096 px, nagłówek PNG weryfikowany po bajtach
- Subfoldery służą jako grupowanie (prefiks id)

## Struktura projektu

```json
{
  "format": "yufriend-levels",
  "version": 1,
  "name": "YuFriend · Dom i ogród",
  "startLevel": "home",
  "assets": [
    {"id": "bed", "name": "Legowisko",
     "source": "res://level-editor/assets/bed.png",
     "width": 60, "height": 24}
  ],
  "levels": [
    {
      "id": "home", "name": "Dom",
      "width": 1440, "height": 360,
      "spawn": {"x": 670, "y": 322},
      "walk": {"x": 95, "y": 286, "width": 1250, "height": 42},
      "walkSpeed": 70, "runSpeed": 160,
      "elements": [
        {
          "id": "bed", "name": "Legowisko", "asset": "bed",
          "layer": "background",
          "x": 205, "y": 322, "width": 180, "height": 72,
          "pivot": {"x": 30, "y": 18},
          "visible": true, "locked": false, "static": true,
          "script": "rest",
          "params": {"energy": 15, "message": "Pora odpocząć.",
                     "clip": "sleep"}
        }
      ]
    }
  ]
}
```

- `project.assets` to lista grafik używanych w projekcie. Grafika z dysku, której
  jeszcze tu nie ma, pojawia się w bibliotece z przerywaną ramką i plakietką
  „+ dodaj". Klik dodaje ją do `project.assets` i tworzy element.
- Element ma zawsze `script` + `params`. Walidacja wymaga, żeby `params` zgadzał
  się ze schemą z `scripts.json`.
- `walkSpeed` (px/s chodu) i `runSpeed` (bieg po piłkę) to pola poziomu, nie magiczne
  liczby w kodzie.

## Rejestr skryptów (`scripts.json`)

Każdy skrypt opisuje: `id`, `label`, opcjonalnie `icon`, `static` (wymusza
element statyczny/dynamiczny) i `params` (schema parametrów). Schema jest
mapą `nazwa → {type, label, default, min, max}`. Typy:

- `number` — liczba z opcjonalnym `min`/`max`
- `text` — pole wieloliniowe (dla komunikatów, myśli)
- `string` — pojedyncza linia
- `bool` — checkbox
- `level` — dropdown z ID istniejących poziomów (np. dla portalu)
- `clip` — nazwa klipu animacji psa (datalist z `scripts.json.clips`)

Dodanie nowego skryptu = dopisanie wpisu w `scripts.json`. Edytor
automatycznie wygeneruje pola w inspektorze, a runtime gry zdispatchuje po
`id` — o ile dodasz obsługę w [scripts/levels/level_preview.gd](../scripts/levels/level_preview.gd).

Wbudowane skrypty: `none`, `message`, `thought` (chmurka myśli psa),
`portal`, `feed`, `pet`, `clean`, `rest`, `ball`, `bark`, `greet`, `play_clip`,
`walk_to`.

## Obsługa plików

Edytor sam skanuje `level-editor/assets/` oraz `assets/art/{yard,home}/sprites/`,
`assets/art/environments/` i `assets/sprites/puppy/pixel/`. Po wrzuceniu nowego
PNG kliknij ↻ w panelu „Biblioteka grafik". Nowe projekty zapisują się jako
`level-editor/projects/*.json` (atomowo); `starter.json` chroniony przed
nadpisaniem. Fallback: „Pobierz JSON" generuje plik do pobrania.

**Rejestr skryptów jest w dwóch miejscach:** `scripts.json` (czyta Godot) i
`registry.js` (czyta przeglądarka). Node test (`model.test.mjs`) wymusza parytet
— zmieniając jedno, zmień i drugie.

## Jak gra czyta projekt

```sh
godot --path . --script res://scripts/levels/preview.gd -- \
  --project=res://level-editor/projects/moj-projekt.json --level=home
```

Runtime ([scripts/levels/level_project.gd](../scripts/levels/level_project.gd)) używa tej samej
walidacji co edytor i tego samego `scripts.json`. Zapis Glorii nigdy nie jest
dotykany — pies testowy w podglądzie ma własny stan.

## Testy

- JS: `node --test level-editor/tests/model.test.mjs` (weryfikuje też parytet `registry.js` ↔ `scripts.json`)
- Godot: `godot --headless --script res://tests/test_level_project.gd`
         `godot --headless --script res://tests/ui_level_editor.gd`
