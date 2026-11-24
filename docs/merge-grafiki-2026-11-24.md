# Selektywny merge grafiki — 24 listopada 2026

Źródło: `codex/garden-sprites-kitchen-2026-11-23`, commit `30636e7419f1a7595ddd8bd6be6126b5b0a24880`.
Baza lokalnego `main`: `b8678be69a5971b4c93cf5510699922701e579bc` oraz istniejące niezacommitowane zmiany.

## Zakres

Przeniesiono panoramę ogrodu, 14 przezroczystych PNG dwunastu stacji, obrysy obiektów, kuchnię z dwiema miskami, zegar i przyciemnienie pogody. Zachowano dynamiczne rośliny, otwieranie furtki, mokrą/suchą kałużę, wodę i elementy toru. Nowe warstwy respektują dotychczasowe odkrywanie miejsc oraz widoczność obiektów podczas toru. Grafikę misek przesunięto tak, by miska z jedzeniem nadal odpowiadała obecnemu miejscu karmienia.

Nie przenoszono starszej obsługi kliknięć i dymków akcji, zmian `RoomLayout`, ustawień eksportu Androida ani historycznej dokumentacji i makiet z tej gałęzi. Zachowano dekorację serca obecną na lokalnym `main`.

Scalenie ma dwóch rodziców. Strategia `ours` zachowała aktualną bazę, po czym nałożono sprawdzony zakres graficzny z gałęzi źródłowej. Pozostałe zmiany źródła świadomie pominięto; przyszły zwykły merge tej samej gałęzi nie przywróci pominiętych fragmentów.

## Zachowanie lokalnej wersji

Wszystkie 21 plików wcześniejszych niezacommitowanych zmian pozostało identycznych bajt w bajt. Nie włączono ich do commita graficznego. Zachowano m.in. samopoczucie, przytulanie, sterowanie dotykiem, wyjścia na potrzebę, automatyczny sen, NPC, trening i aktualną konfigurację iOS.

Żaden istniejący plik `scripts/systems/`, `scripts/model/room_layout.gd`, `scripts/ui/main.gd` ani żaden istniejący test nie został zmieniony przez ten merge. Zmienione istniejące pliki to siedem widoków graficznych; dodano zasoby, ich układ, eksport oraz test integracji.

Kopia wcześniejszych zmian, manifest SHA-256, wyniki i podglądy: `exports/graphics-merge-2026-11-24/`. Testy używały osobnych zapisów. Nie wykonywano operacji na zapisie Glorii ani instalacji na telefonie.

## Sprawdzenie

- Import Godota 4.7.2 zakończony bez błędów skryptów i zasobów.
- `python3 tools/run_game_tests.py`: **36/36** zestawów logiki.
- `python3 tools/run_game_tests.py --ui`: **32/32** zestawów interfejsu.
- Nowy `tests/ui_yard_sprites.gd` sprawdza integrację stanu roślin, furtki i kałuży, odkrywanie miejsc, widoczność podczas toru/powrotu do domu oraz brak zmian postępu podczas aktualizacji warstw.
- Obejrzano panoramę kuchni oraz podglądy kuchni/ogrodu 390 px, ogrodu 320 px i mapy ogrodu.
- Próba fizycznego dotyku i wydajności na telefonie pozostaje poza zakresem tego scalenia.
