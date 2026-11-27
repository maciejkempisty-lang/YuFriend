# Zestaw graficzny domu i ogrodu

Gotowy projekt edytora: `level-editor/projects/art-kit.json` (dom i ogród).
Otwórz go z listy projektów w YuFriend Studio. Biblioteka automatycznie skanuje
ten katalog i jego podfoldery. Scena ma 1440 × 360 jednostek; tła mają
480 × 120 pikseli, więc jeden piksel grafiki odpowiada 3 jednostkom sceny.

## Dom

- `background.png` — ściana i podłoga bez wbudowanych mebli ani okien.
- `window-view-day.png`, `window-view-night.png`, `window-frame.png` —
  niezależny widok za głównym oknem i rama z firankami.
- `kitchen-window-view-day.png`, `kitchen-window-view-night.png`,
  `kitchen-window-frame.png` — analogiczny zestaw dla kuchni.
- `floor-lamp-off.png`, `floor-lamp-on.png`, `pendant-lamp-off.png`,
  `pendant-lamp-on.png` — dwa rodzaje lampek w obu stanach.
- `door.png`, `rug.png`, `plant.png`, `chest.png`, `kitchen.png`,
  `gramophone.png`, `shelf.png`, `guitar.png`, `portrait.png`, `clock.png` —
  osobne elementy wystroju.

## Ogród

- `background.png` — trawa, płot, drzewa i fragment domu z wnęką drzwiową.
- `door.png` — taki sam wzór drzwi jak w domu; ustawiony we wnęce.
- `canopy.png`, `bed.png`, `water-bowl.png` — osobne elementy miejsca odpoczynku.
- Pozostałe stacje ogrodu korzystają z istniejących grafik
  `assets/art/yard/sprites/`, dostępnych także w bibliotece edytora.

W projekcie startowo widoczne są dzienne widoki okien i wyłączone lampki.
Wersje nocne i włączone lampki są umieszczone w tych samych pozycjach jako
niewidoczne elementy; stan można zmienić przełącznikiem widoczności.
Wszystkie grafiki są PNG w rozdzielczości natywnej; elementy mają przezroczyste tło.

Pliki można odtworzyć poleceniem `python3 tools/build_level_editor_art.py`.
Podglądy kompozycji znajdują się w `docs/images/level-art-*.png`.
