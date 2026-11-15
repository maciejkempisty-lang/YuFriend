# Uruchomienie i testy YuFriend

[Mapa dokumentacji](README.md)

## Środowisko

Projekt był uruchamiany w **Godot 4.7.2 na macOS**, z rendererem Compatibility. Logika jest napisana w GDScripcie. Do lokalnej gry nie są potrzebne konto, backend, klucz API ani instalacja pakietów innych języków.

Katalog roboczy: `/Volumes/Samsung SSD/YuFriend`. Punkt wejścia to [project.godot](../project.godot). Otwórz ten plik w menedżerze projektów Godota, poczekaj na import zasobów i wybierz **Uruchom projekt (F5)**.

Wszystkie poniższe polecenia zakładają terminal otwarty w katalogu projektu. Ścieżka programu odpowiada instalacji na tym Macu; na innym komputerze należy wskazać własny plik wykonywalny Godota.

## Pierwszy import i uruchomienie

Import bez okna edytora:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --editor --quit
```

Uruchomienie gry:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --path .
```

Uruchomienie z oddzielnym zapisem do ręcznego sprawdzania:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --path . -- --qa
```

`--qa` zapisuje stan do `user://qa-ui/pet.json`. Ten stan pozostaje między uruchomieniami i nie jest za każdym razem losowany od nowa. Nie uruchamiaj kilku okien na tym samym zapisie. Zwykłą grę i podgląd `--qa` rozdzielają różne ścieżki danych.

## Testy automatyczne

Testy używają prostych skryptów `SceneTree` i nie wymagają zewnętrznego frameworka. Sukces daje kod zakończenia 0, a niespełnione sprawdzenie — 1. Gdy pojawia się błąd parsowania lub zasobu, najpierw sprawdź import projektu.

| Skrypt | Zakres | Ostatni odnotowany wynik |
|---|---|---:|
| [test_runner.gd](../tests/test_runner.gd) | Temperament, dane, upływ czasu, trening, nagrody, zapis, kopia, słownik komend, osobowość, nawyki i migracja zapisu | 104 poprawne sprawdzenia |
| [test_sprites.gd](../tests/test_sprites.gd) | Manifest, nieregularne regiony, podparcie, skalowanie, kompletny pakiet 22/142, zasób `.res`, przejścia i ukończenie prezentacji | 38 poprawnych sprawdzeń |
| [ui_smoke.gd](../tests/ui_smoke.gd) | Opieka i trening, kliknięcia i dotyk w pokoju, zapis, wznowienie, nawyki, dialogi i układy ekranu | 132 poprawne sprawdzenia |

Wynik **274/274** pochodzi z weryfikacji prototypu 15 listopada 2026 w Godot 4.7.2 na macOS. Obejrzano także zrzuty ekranu, w tym trening, profil z nawykami oraz układy pionowy i poziomy. Regresje obejmują krótszą i dłuższą nieobecność, powtórzenie propozycji, limit wspomnień, zachowanie `.v1` po rotacji kopii i zablokowanie migracji przy błędzie zabezpieczenia oryginału. Nowe regresje obejmują obcą kopię `.v1`, wybudzanie także offline, dojście przed naliczeniem opieki, anulowanie dojścia, reakcję na kolejne głaskanie, sygnalizowanie potrzeb oraz brak przebudowy statycznego tła podczas ruchu. Audyt zachowania obejmuje też przerwanie spaceru opieką, zmianę celu, reakcję na potrzeby 100/99,9 i dotyk podczas jedzenia, bez naruszenia treningu. Przebudowa świata dodaje próby przesuwania kamery, rozróżnienia gestu i tapnięcia, granic, zbliżeń, przechodzenia za przedmiotami, sześciu stacji i niezmienności współrzędnych przy zmianie rozmiaru okna.

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_runner.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_sprites.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --path . --script res://tests/ui_smoke.gd
```

Dwa pierwsze skrypty działają bez okna. Trzeci potrzebuje sesji graficznej, otwiera okno i zapisuje obrazy w `test-results/`. Sprawdza układy 390 × 844, 540 × 960 i 360 × 800 oraz skalowanie bazowego widoku w oknach 320 × 640, 1100 × 720 i 1080 × 2340. Steruje sygnałami przycisków, zdarzeniami myszy i dotyku (także przeciągnięciem) oraz kontrolowanym upływem czasu. Zapisuje też lewy i prawy koniec pokoju, zbliżenie, obie głębokości przy koszu i pełną panoramę świata w `19-panorama.png`. Dodatkowo mierzy rzeczywiste bloki koloru na zrzutach, a nie tylko parametry kamery: powiększenie pozostaje całkowite po uwzględnieniu transformacji całego okna. Fizyczny dotyk, klawiatura ekranowa i cykl życia telefonu wymagają osobnych prób na urządzeniu.

Testy używają własnych tymczasowych danych i sprzątają je po normalnym zakończeniu. Nie nadpisują `user://pet.json` ani ręcznego zapisu `--qa`. Katalog `test-results/` jest pomijany przez Git i skaner zasobów Godota.

## Krótka próba ręczna

Uruchom grę z `--qa`. Wykonaj poniższe czynności również po większej zmianie grafiki lub interfejsu.

| Czynność | Oczekiwany rezultat |
|---|---|
| Otwórz Profil, zmień imię, zapisz | Zmiany pojawiają się w grze; przyciski dialogu mieszczą się w oknie |
| Kliknij lewą i prawą stronę pokoju | Pies zmienia kierunek i dochodzi do celu; po siadzie najpierw wstaje |
| Nakarm, pogłaszcz, pobaw się i wyczesz | Pies idzie do miski, goni piłkę i odpowiada na kolejne dotknięcia; efekty i wspomnienia naliczają się tylko raz |
| Włącz odpoczynek i poczekaj | Pies idzie do legowiska, energia rośnie i przy 85 pies sam wstaje; ręczne budzenie nadal działa |
| Ćwicz siad z gestem i nagradzaj na czas | Opanowanie rośnie; po 25% dostępna staje się łapa |
| Nagródź przed wykonaniem, po czasie i dwa razy | Żadna z tych dodatkowych prób nie przyznaje postępu |
| Wpisz „usiądź”, a następnie nierozpoznawany zwrot | Pierwszy uruchamia samodzielną próbę, drugi daje wyjaśnienie |
| Zamknij grę i uruchom ten sam tryb ponownie | Imię, cechy, wygląd, umiejętności i wspomnienia są zachowane |
| Zmniejsz okno i otwórz wszystkie zakładki | Akcje i nawigacja pozostają dostępne; przewija się tylko album |

Jakość rzeczywistych sprite’ów oceniamy osobno: stabilne łapy, zgodne pozycje na styku klipów, czyste pętle, właściwy kierunek i brak zmiany skali. Test importera nie zastępuje oglądania animacji.

## Gdzie wprowadzać zmiany

| Zmiana | Miejsce i sprawdzenie |
|---|---|
| Tempo potrzeb lub odpoczynku | `NeedsSystem`; zaktualizuj mechaniki i sprawdź testy logiki |
| Efekt opieki i czas ponownego użycia | `GameSession.act()`; sprawdź reguły oraz przepływ UI |
| Szansa wykonania i nagrody | `TrainingSystem`; sprawdź wczesne, podwójne i wygasłe nagrody |
| Układ, napisy i dialogi | `scripts/ui/main.gd`; sprawdź układy pionowe i szeroki panel boczny |
| Wygląd pokoju i ruch | `RoomView` i `RoomArtwork`; sprawdź cel, kierunek, dojście do przedmiotów i przejście z siadu do chodu |
| Nowy klip | `PetAnimator.CLIPS`, ewentualnie graf przejść, manifest i sytuacja uruchamiająca klip |
| Nowa komenda lub potrzeba | Model, odpowiedni system, sesja, UI i migracja istniejącego zapisu |

Dodanie klucza do `PetState.TRICK_KEYS` lub `NEED_KEYS` zmienia wymagania odczytu. Bez migracji wcześniejszy zapis będzie niekompletny. Nowa komenda wymaga też mapowania na animację w sesji oraz, jeśli ma działać tekstowo, wpisu w `LocalCommands`.

Po zmianie uruchamiaj zestawy powiązane z danym obszarem. Aktualizacja samego opisu wymaga sprawdzenia treści, przykładów i linków; nie zmienia zachowania gry.

## Typowe problemy

| Objaw | Co sprawdzić |
|---|---|
| Nowy PNG nie jest znajdowany | Poczekaj na import Godota; sprawdź nazwę i ścieżkę `res://assets/` |
| Importer zgłasza brak plików z przykładu | `manifest.example.json` pokazuje przyszłe nazwy; w `manifest.json` pozostaw dostarczone klipy |
| Pakiet już istnieje | Użyj `--replace` przy świadomej przebudowie całego pakietu |
| Nowe klatki nie pojawiają się w grze | Uruchom grę ponownie i sprawdź `puppy_pixel.res` oraz czy ręczne `frames` nie ma pierwszeństwa |
| Pies nie porusza łapami | Dla brakującego klipu nadal działa zastępcza ilustracja |
| Łapa lub trening są niedostępne | Sprawdź opanowanie siadu, sytość, energię, zmęczenie i bieżącą czynność |
| Postęp czeka na zapis | Sprawdź dostęp i wolne miejsce w katalogu `user://`; szczegół jest w `SaveSystem.last_error` |
| Zapis wymaga odzyskania | Zastosuj opis diagnostyki w [modelu danych](model-danych-i-zapis.md), zachowując oryginalne pliki |

## Wydanie na telefon

Projekt nie ma jeszcze skonfigurowanego zestawu eksportowego ani potwierdzonego działania na fizycznym telefonie. Następny etap obejmuje wybór platformy, konfigurację eksportu, pakowanie zasobów, podpisanie aplikacji tam, gdzie jest wymagane, oraz test dotyku, bezpiecznych marginesów ekranu, klawiatury, wstrzymania i wznowienia. Kryteria opisuje [plan rozwoju](rozwoj-projektu.md).

Wydzielony zakres audio przed publikacją sprawdzono osobno na bazie `c23df29`: **274/274** (104 logiki, 38 animacji, 132 UI). Obejmuje komplet 20 nagrań, kroki tylko podczas ruchu, limit 160 ms, brak dźwięku po odrzuconej opiece, zatrzymanie efektów w tle oraz niezależne wyciszenie. Te testy nie stanowią oceny naturalności nagrań.
