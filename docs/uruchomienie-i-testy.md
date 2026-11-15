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

Poprawki cyklu przed buildem 15, 15 listopada 2026: **1636/1636 sprawdzeń w 14 zestawach**. `test_rhythm` ma teraz **122**, a `ui_rhythm` **17** sprawdzeń: pierwsze otwarcie o 22:30, nocne powitanie istniejącego psa i powrót po nieobecności, trzy rodzaje nagród treningowych, pozostawanie w miejscu w zakładce treningu, powrót autonomii oraz neutralne teksty. Zrzuty `rhythm-night-greeting-390.png` i `rhythm-training-stay-390.png` pokazują nowe zachowanie. Ponowiono również **1526** sprawdzeń widgetu i **1067+18** przypomnień. Migracja kopii rzeczywistego zapisu Glorii v4→v5 zachowuje wszystkie istniejące pola i oryginał v4.

Cykl zachowań, 15 listopada 2026: **94/94** sprawdzenia logiki (`test_rhythm.gd`) i **11/11** integracji widoku (`ui_rhythm.gd`). Sprawdzono granice pór, nocne budzenie i zabawę, adaptację po restarcie, migrację v4→v5 oraz przerywanie sekwencji. Dotychczasowe zestawy: 113 logiki/zapisu, 46 życia, 94 zabaw, 23 towarzysza, 38 animacji, 33 audio, 10 ustawień przypomnień oraz 238+30+34+52 UI — wszystkie bez błędów. Natywnie: **1526** sprawdzeń widgetu (252 projekcje zgodne z Godotem), **1067** planisty i **18** kontrolera przypomnień. Obejrzano zrzuty nocy, ostrzeżenia przed snem i wieczornego odpoczynku. Testy graficzne na macOS; tego pakietu nie instalowano na iPhonie. [Reguły i zakres](cykl-zachowan.md).

Chmurki nad Glorią, 15 listopada 2026: `tests/ui_bubbles.gd` — **786/786** sprawdzeń na pięciu rozmiarach ekranu, w zwykłym kadrze i zbliżeniu, przy staniu, siadzie, ukłonie i śnie oraz po obu stronach pokoju. Test mierzy rzeczywisty obrys klatki animacji, odstęp od komunikatów, bezpieczny obszar i wzajemne kolizje paneli. Krótka reakcja na opiekę ma pierwszeństwo przed myślą, jeśli mały ekran nie mieści obu; przy braku miejsca opcjonalny komunikat czeka poza widokiem. Obejrzano zrzuty normalnego kadru i zbliżenia. `ui_companion.gd`: **34/34**. Ogólny `ui_smoke.gd` w równolegle zmienianym katalogu zgłaszał błędy przeciągania/śledzenia psa; nie jest to pełne potwierdzenie regresji całej gry. Poprawka chmurek nie została jeszcze zainstalowana na telefonie.

Poprawka ustawień iPhone’a (build 11), 15 listopada 2026: **52/52** sprawdzenia `ui_reminders.gd`. Test obejmuje sześć układów, w tym skalowanie 2×/3×, symulowane marginesy Dynamic Island i dolnego gestu, przewijanie oraz zamykanie obu przycisków zdarzeniami dotyku. **302/302** dotychczasowych sprawdzeń UI (`ui_smoke`, `ui_play`, `ui_companion`) również przechodzą. Obejrzano zrzuty pionowe i poziome. Ta regresja zastępuje wcześniejsze 13 sprawdzeń panelu, które nie obejmowały marginesów i skalowania iPhone’a.

Lokalne przypomnienia iOS, 15 listopada 2026: `sh tools/test_ios_reminders.sh` — **365** sprawdzeń planisty, **15** kontrolera z atrapą centrum powiadomień i kontrola typów iOS. `tests/test_reminders.gd` — **10**, `tests/ui_reminders.gd` — **13**. Razem nowy zakres: **403**. Dotychczasowe **649** sprawdzeń gry i **1525** widgetu przechodzą; zestawy UI powtórzono po zmianie ustawień. [Reguły, ograniczenia i próba na telefonie](powiadomienia-ios.md).

Testy używają prostych skryptów `SceneTree` i nie wymagają zewnętrznego frameworka. Sukces daje kod zakończenia 0, a niespełnione sprawdzenie — 1. Gdy pojawia się błąd parsowania lub zasobu, najpierw sprawdź import projektu.

| Skrypt | Zakres | Ostatni odnotowany wynik |
|---|---|---:|
| [test_runner.gd](../tests/test_runner.gd) | Temperament, dane, upływ czasu, trening, nagrody, zapis, kopia, słownik komend, osobowość, nawyki i migracja zapisu | 113 poprawnych sprawdzeń |
| [test_life.gd](../tests/test_life.gd) | Dziwactwa, odkrywanie, nastrój o 05:00, cofnięcie zegara, relacje, powitania, migracja v2 i powrót do sesji | 46 poprawnych sprawdzeń |
| [test_play.gd](../tests/test_play.gd) | Autonomiczne zaproszenia, pamięć reakcji, gesty, ograniczenie nagród, przerwania, trwałość i migracja v3 | 94 poprawne sprawdzenia |
| [ui_play.gd](../tests/ui_play.gd) | Karta zaproszenia, dotyk przycisku, rzut i pościg, lina, kubki, wznowienie oraz mały i szeroki ekran | 30 poprawnych sprawdzeń |
| [test_companion.gd](../tests/test_companion.gd) | Priorytety potrzeb, zmęczenie, potwierdzone wspomnienia, stabilność myśli, czas oczekiwania i blokady akcji | 23 poprawne sprawdzenia |
| [ui_companion.gd](../tests/ui_companion.gd) | Dymek i dotyk akcji, cztery rozmiary ekranu, bezpieczne marginesy, niezmieniony kadr i widoczność psa/miski/piłki | 34 poprawne sprawdzenia |
| [test_sprites.gd](../tests/test_sprites.gd) | Manifest, nieregularne regiony, podparcie, skalowanie, kompletny pakiet 22/142, zasób `.res`, przejścia i ukończenie prezentacji | 38 poprawnych sprawdzeń |
| [ui_smoke.gd](../tests/ui_smoke.gd) | Opieka i trening, kliknięcia i dotyk w pokoju, zapis, wznowienie, nawyki, dialogi i układy ekranu | 238 poprawnych sprawdzeń |

Dymek potrzeb, myśli i wspomnień, 15 listopada 2026: **419/419 sprawdzeń** w pięciu zestawach (`test_companion`, `ui_companion`, `test_play`, `ui_play`, `ui_smoke`). Nowe zrzuty `test-results/companion-*.png` obejmują 390 × 844, 320 × 640, 860 × 1864 z symulowanymi marginesami urządzenia oraz 1100 × 720. Obejrzano spokojną myśl, potrzebę, wspomnienie i zaproszenie. Test mierzy niezmienność kamery, skali i pozycji psa po zmianie treści, brak zasłaniania psa/miski/piłki i faktyczne dotknięcia przycisków. Sprawdzono na pulpicie, bez instalacji tej zmiany na fizycznym iPhonie.

Audyt ról w zabawach, 15 listopada 2026: **450/450 sprawdzeń** w czterech zestawach — 93 zabaw, 30 UI zabaw, 113 logiki i 214 UI opieki/treningu. Kubki sprawdzają chowanie przez gracza, samodzielne szukanie psa i pochwałę; lina sprawdza pociągnięcie gracza, puszczenie i odpowiedź psa. Obejrzano zrzuty kubków i liny oraz dostępność przycisków bez przewijania na małym ekranie. Te zmiany nie zostały jeszcze sprawdzone na fizycznym iPhonie.

Korekta kadru pośredniego i limitu albumu: **531/531** w siedmiu zestawach. Nowe regresje mierzą szerokość domyślnego kadru i obecność miski/piłki w 390 × 844, 320 × 640 i 1080 × 2340 oraz wczytują stary album v4 z 200 osiągnięciami i 40 relacjami, zachowując wszystkie osiągnięcia i 10 ostatnich relacji. Zrzuty `room-medium-*.png` pokazują nowy kadr. Build 7 uruchomiono również na fizycznym iPhonie; szczegóły i zakres kontroli opisuje [test iOS](test-ios.md).

Dalsza korekta pionowego kadru (mniej pustej ściany nad sceną): **238/238 sprawdzeń UI**. Regresje obejmują 390 × 844, 320 × 640, 1080 × 2340 i 860 × 1864, także z symulowanymi bezpiecznymi marginesami. Kontrolują pełną widoczność psa, miski i piłki pomiędzy paskiem narzędzi a panelem opieki, odstęp nad oknem do 110 punktów UI, niezmienność pozycji świata oraz ostre, równe piksele. Zrzuty: `test-results/phone-framing-*.png`. Tę późniejszą korektę sprawdzono na pulpicie; nie jest jeszcze częścią instalacji build 7 na iPhonie.

Poprawki po audycie, 15 listopada 2026: **524/524** w siedmiu zestawach, w tym dodatkowe **33 sprawdzenia `test_audio.gd`**. Regresje obejmują 60 powrotów z zachowaniem pierwszego dnia i siadu po ponownym odczycie, osobne limity 200+40 wpisów, brak obserwacji dziwactw offline, rozkład 400 nowych psów (95 sennych), karmienie podczas zaproszenia do bliskości oraz pięciominutowy odstęp zaproszeń. UI sprawdza neutralny tekst dla Glorii oraz widok całego pokoju, wybór miejsca i powrót do psa w trzech pionowych rozdzielczościach. Zrzuty: `room-overview-390.png`, `room-overview-320.png`, `room-overview-1080.png`. Obejrzano widok 1080 × 2340 i zbliżenie; fizyczny iPhone nadal wymaga próby tych zmian.

Etap 2, 15 listopada 2026: **467/467 sprawdzeń** w sześciu zestawach. Nowe testy korzystają z syntetycznej Glorii i osobnych zapisów, a zrzuty `30-invitation.png`–`40-play-1100.png` w `test-results/` pokazują nowe przepływy. Obejrzano zaproszenie, podgląd rzutu, linę, kubki, pamięć odpowiedzi i dialogi w oknach 320 × 640 oraz 1100 × 720. Test UI steruje ramkami i symuluje aktywny fokus, aby inne okna testowe nie wygaszały zaproszenia. Dotyk jest syntetyczny; fizyczny telefon wymaga osobnej próby.

Poprawka widoczności treningu z 15 listopada 2026: **192/192 sprawdzenia UI**. Nowe regresje mierzą widoczną sylwetkę psa w fazach przygotowania, próby i nagrody w oknach 390 × 844, 360 × 800, 320 × 640 oraz 1080 × 2340 z symulowanymi marginesami urządzenia. Sprawdzają również komunikaty wewnątrz panelu i brak powracającego dymka po wyjściu z treningu. Obejrzano zrzuty z tych układów.

Wcześniejszy wynik pełnego zestawu **355/355** pochodzi z weryfikacji 15 listopada 2026 w Godot 4.7.2 na macOS: 111 logiki i zapisu, 38 sprite’ów, 42 życia psa oraz 164 interfejsu. Nowe regresje sprawdzają przyrost po dojściu i ograniczeniu do 100%, odkrywanie ulubionej nagrody, jeden rząd potrzeb/akcji, wygasanie dymka, czas oczekiwania, rozdzielenie profilu i ustawień, pełny album, zapamiętanie pierwszego gestu oraz marginesy urządzenia przy zwykłym i ułamkowym skalowaniu. Obejrzano również zrzuty z opieki, treningu, profilu, ustawień, albumu i raportu powrotu. Fizycznego iPhone’a nie użyto do weryfikacji tej przebudowy.

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_runner.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_sprites.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_life.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_play.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_companion.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --path . --script res://tests/ui_companion.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --path . --script res://tests/ui_smoke.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --path . --script res://tests/ui_play.gd
```

Cztery pierwsze skrypty działają bez okna. Dwa ostatnie potrzebują sesji graficznej, otwierają okno i zapisują obrazy w `test-results/`. Sprawdza układy 390 × 844, 540 × 960 i 360 × 800 oraz skalowanie bazowego widoku w oknach 320 × 640, 1100 × 720 i 1080 × 2340. Steruje sygnałami przycisków, zdarzeniami myszy i dotyku (także przeciągnięciem) oraz kontrolowanym upływem czasu. Zapisuje też lewy i prawy koniec pokoju, zbliżenie, obie głębokości przy koszu i pełną panoramę świata w `19-panorama.png`. Dodatkowo mierzy rzeczywiste bloki koloru na zrzutach, a nie tylko parametry kamery: powiększenie pozostaje całkowite po uwzględnieniu transformacji całego okna. Fizyczny dotyk, klawiatura ekranowa i cykl życia telefonu wymagają osobnych prób na urządzeniu.

Zmiennej `YUFRIEND_TEST_ROOT` można nadać istniejący katalog tymczasowy, np. `/tmp`, aby zapisy testowe powstały poza `user://`. Bez niej ścieżki pozostają dotychczasowe.

Testy używają własnych tymczasowych danych i sprzątają je po normalnym zakończeniu. Nie nadpisują `user://pet.json` ani ręcznego zapisu `--qa`. Katalog `test-results/` jest pomijany przez Git i skaner zasobów Godota.

## Krótka próba ręczna

Uruchom grę z `--qa`. Wykonaj poniższe czynności również po większej zmianie grafiki lub interfejsu.

| Czynność | Oczekiwany rezultat |
|---|---|
| Dotknij imienia, zmień je w karcie psa, wybierz „Zapisz imię” | Zmiany pojawiają się w grze; przyciski dialogu mieszczą się w oknie |
| Kliknij lewą i prawą stronę pokoju | Pies zmienia kierunek i dochodzi do celu; po siadzie najpierw wstaje |
| Nakarm, pogłaszcz, pobaw się i wyczesz | Pies idzie do miski, goni piłkę i odpowiada na kolejne dotknięcia; efekty i wspomnienia naliczają się tylko raz |
| Poczekaj na zaproszenie, odpowiedz lub wybierz „Później” | Karta psa pokazuje reakcję w „Waszym rytmie”; ponowne uruchomienie zachowuje pamięć |
| Otwórz „Pobaw się” i ukończ piłkę, linę oraz kubki | Gesty odpowiadają wskazówkom, wynik nalicza się raz; przy kubkach Ty chowasz smakołyk i chwalisz, a pies go szuka; przy linie pies sam odpowiada pociągnięciem |
| Przerwij przeciąganie lub wyślij aplikację w tło podczas rundy | Nie ma dodatkowego rzutu, wyboru kubka ani nagrody po wznowieniu |
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
| Własna inicjatywa i zabawy dotykiem | `InitiativeSystem`, `TouchPlaySystem`, sesja i widoki; uruchom `test_play.gd` oraz `ui_play.gd` |
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

Projekt ma konfigurację iOS i wcześniejszą instalację testową opisaną w [teście iOS](test-ios.md). Przebudowany interfejs wymaga jeszcze eksportu i sprawdzenia na urządzeniu: dotyku, bezpiecznych marginesów, klawiatury, wstrzymania i wznowienia. Kryteria opisuje [plan rozwoju](rozwoj-projektu.md).

Kontrola audio obejmuje 22 rzeczywiste nagrania, brak pętli efektów, wyzwalanie po przyjęciu czynności, ograniczenie jednoczesnego odtwarzania, zatrzymanie w tle i niezależne preferencje muzyki/efektów. `tests/test_audio.gd` działa bez okna i sprawdza szczekanie przy drzwiach/misce oraz pisk przy głaskaniu, jego odstępy, odmowy i wyciszenie. Odsłuch i balans na telefonie pozostają do oceny użytkownika.

Wydzielony zakres audio przed publikacją sprawdzono osobno na bazie `c23df29`: **274/274** (104 logiki, 38 animacji, 132 UI). Obejmuje komplet 20 nagrań, kroki tylko podczas ruchu, limit 160 ms, brak dźwięku po odrzuconej opiece, zatrzymanie efektów w tle oraz niezależne wyciszenie. Te testy nie stanowią oceny naturalności nagrań.
