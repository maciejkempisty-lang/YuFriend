# Uruchomienie i testy YuFriend


## Naprawa regresji UI — 26 listopada 2026

Zachowano obecny nagłówek, pasek samopoczucia i wiadomości, chmurki reakcji, podpisy i procenty przy ikonach oraz dolną nawigację. Poprawiono bezpieczne marginesy zawartości paneli (tła nadal dochodzą do krawędzi), przeliczanie miejsca po ukryciu wiadomości i otwarciu mapy oraz dopasowanie skali/zbliżenia psa do rzeczywistej wysokości między HUD-em a panelem. Na szerokich i krótkich ekranach pies nie znika za nagłówkiem.

Testy dziewięciu wcześniej nieudanych zestawów dostosowano do aktualnego interfejsu: sprawdzają widoczny `companion_notice`, samopoczucie w pasku statusu, podpisane przyciski, przylegające panele i bezpieczne prostokąty kontrolek zamiast pełnoekranowych teł. Test wody otwiera mapę przez tę samą metodę co przycisk Mapa. Zachowano kontrole dotyku, braku kolizji wiadomości z psem i pełnej widoczności postaci.

Weryfikacja końcowa: **44/44 zestawy logiki** oraz **43/43 zestawy UI po ponowieniu ostatniego testu**. Pełen przebieg UI dał 42/43; pozostał warunek kadru względem dawnego, ukrytego paska kamery. Po odniesieniu go do widocznego statusu, bez zmiany kodu gry, `ui_smoke` przeszedł **242/242** sprawdzenia. Pozostałe 42 zestawy nie wymagały ponowienia. `ui_bubbles`: 1104/1104, `ui_companion`: 36/36, `ui_hud_navigation`: 34/34, `ui_play`: 46/46, `ui_rhythm`: 20/20, `ui_stage2`: 0 błędów, `ui_water`: 148/148, `ui_wellbeing`: 17/17.

Obejrzano kadr treningu na wysokiej rozdzielczości i ogród. Kontrolny zrzut pokoju 390 × 844 pozostał identyczny piksel po pikselu; w ogrodzie różnice porównywanych zrzutów obejmują zmienną pogodę. Sprawdzenie na macOS, bez nowego eksportu i instalacji na telefonie.


## Warstwy pokoju i ogrodu — 26 listopada 2026

Przed zmianą zapisano i wypchnięto `codex/old-version-backup-2026-11-26`, commit `ebdba63`. Implementacja warstw znajduje się na `codex/scene-layers`.

- Regresja logiki: **44/44 zestawy**.
- Pełna regresja UI: **34/43 zestawy**. Dziewięć nieudanych zestawów (`ui_bubbles`, `ui_companion`, `ui_hud_navigation`, `ui_play`, `ui_rhythm`, `ui_smoke`, `ui_stage2`, `ui_water`, `ui_wellbeing`) uruchomiono także na odizolowanej kopii `ebdba63`: odtwarzają wcześniejsze błędy dymków, nagłówka, układu treningu i widoczności celu zraszacza. Nie stanowią potwierdzenia pełnej poprawności istniejącego HUD-u.
- Końcowe testy po zachowaniu kolorystyki pogody: **151/151** warstw, **19/19** sprite'ów ogrodu, **19/19** pogody, **156/156** toru i **153/153** odpoczynku.
- Nowy `tests/ui_scene_layers.gd` sprawdza kolejność rzeczywiście wyrenderowanych pikseli, wspólne sortowanie postaci/przedmiotów, położenie grafik po zmianie pivotów, przełączanie lokacji, brak zmian danych psa, przeszkody i kolory pogody.
- Obejrzano zrzuty pokoju i ogrodu. Kontrolny zrzut pokoju 390 × 844 jest identyczny piksel po pikselu ze zrzutem sprzed zmian; ogród zachowuje geometrię i kadrowanie. Kolejność zasłaniania przestrzennych obiektów wynika teraz z ich podstaw.

Testy wykonano na macOS; nie eksportowano ani nie instalowano tej zmiany na telefonie. Zasady tworzenia nowych grafik: [wytyczne](wytyczne-grafik.md).

[Mapa dokumentacji](README.md)

## Środowisko

Projekt był uruchamiany w **Godot 4.7.2 na macOS**, z rendererem Compatibility. Logika jest napisana w GDScripcie. Do lokalnej gry nie są potrzebne konto, backend, klucz API ani instalacja pakietów innych języków.

Katalog roboczy: `/Volumes/KINGSTON/YuFriend` (przeniesiony 17 listopada 2026 z dysku Samsung SSD). Punkt wejścia to [project.godot](../project.godot). Otwórz ten plik w menedżerze projektów Godota, poczekaj na import zasobów i wybierz **Uruchom projekt (F5)**.

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

Testy interfejsu ustawiają `app.room.ambient_life.life.autoplay = false`, żeby losowo pojawiające się postacie tła nie trafiały do porównywanych zrzutów. `ui_ambient` nadal uruchamia postacie jawnie przez `start()`. Nowy zestaw interfejsu musi dodać tę samą linię zaraz po `save_path_override`.

Sporadyczna porażka `ui_smoke` („rendered background translates by exactly one physical pixel”) miała inną przyczynę. Porównywany fragment 40 × 40 px leżał w całości na psie. Pies w spoczynku zmienia klatkę co około 3,3 s i czasem trafiał na moment między zrzutami. Sprawdzenie bierze teraz fragment tła obok psa, pomija obrys psa i wymaga co najmniej 400 porównanych pikseli w co najmniej 3 kolorach (obecnie 1600 px, 16 kolorów). Zrzuty wymuszają renderowanie przez `RenderingServer.force_draw()` zamiast czekać na `frame_post_draw`, bo bez animacji w kadrze Godot nie rysuje nowej klatki.

`tools/test_ios_widget.sh` i `tools/test_ios_reminders.sh` trzymają pamięć podręczną modułów Swift w katalogu z kluczem zależnym od ścieżki projektu. Po przeniesieniu repozytorium na inny dysk skrypt zakłada nową pamięć zamiast używać nieaktualnej. Stare katalogi `swift-cache*` w `test-results/` można usunąć ręcznie.

17 listopada 2026 — rozszerzenie tła o ślimaka i wiewiórkę: **318/318 sprawdzeń** w pięciu zestawach: `test_ambient` 43, `ui_ambient` 42, `test_calm_day` 152, `test_visitors` 52, `ui_visitors` 29. Sprawdzono pełzanie, przebieg i postój na belce, limit dwóch postaci przy czterech gatunkach, ich automatyczne pojawianie się, przerwanie przy kopaniu, brak zapisów i blokad, łagodne wycofanie przy przerwaniu pojawiania oraz widoczność pod przyciskami w 320/390 px. Obejrzano oba zrzuty nowych postaci. Regresja gości obejmuje pierwsze użycie piłki, chowanego i piaskownicy oraz dziesięć aktywności w czterech fazach wizyty. Zrzuty i logi: `test-results/ambient-extension/`. Testy bez okna w sandboxie zgłosiły systemowy błąd odczytu certyfikatów macOS (`get_system_ca_certificates`), ale wszystkie asercje przeszły i procesy zakończyły się kodem 0; testy graficzne poza sandboxem zakończyły się bez tych komunikatów. Brak instalacji tego rozszerzenia i próby na fizycznym telefonie.

17 listopada 2026 — żywe otoczenie, kod po buildzie 24: **26/26** sprawdzeń logiki (`test_ambient`) i **25/25** integracji (`ui_ambient`). Sprawdzono ruch, lądowanie na roślinie, pustą grządkę, odlot przy psie i zabawie, brak zmian zapisu, brak blokad, priorytet prawdziwych gości oraz zatrzymanie po zmianie sceny, nocy, otwarciu Albumu/Dziś i przejściu aplikacji w tło. Obejrzano sceny w szerokościach 390 i 320 px. Regresja: `test_calm_day` 152/152 oraz siedem zestawów UI — `ui_ambient`, `ui_smoke` (241/241), `ui_visitors`, `ui_yard`, `ui_water` (105/105), `ui_adventures`, `ui_yard_transition` — bez nieudanych sprawdzeń i ostrzeżeń. W `ui_smoke` naprawiono oczekiwanie na zrzut statycznego panelu: po dwóch klatkach układu test jawnie renderuje obraz, zamiast czekać bez końca na `frame_post_draw`. Pakiet otoczenia zainstalowano następnie jako build 25; uruchomienie i zachowanie postępów Glorii potwierdzono, szczegóły w [testach iOS](test-ios.md). Zrzuty i logi są lokalnie w `test-results/ambient/`.

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_ambient.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --path . --script res://tests/ui_ambient.gd
```

17 listopada 2026 — spokojniejszy dzień: **25 zestawów logiki i 19 interfejsu — wszystkie sprawdzenia zaliczone** po poprawkach. `ui_water` po poprawce sprzątania przechodzi 105/105: zatrzymuje audio, zwalnia scenę i przed zakończeniem silnika sprawdza słabe referencje do widoku oraz nagrań. Trzy kolejne przebiegi, w tym szczegółowy, nie zgłosiły ostrzeżeń. Nowy `test_calm_day.gd`: **152 sprawdzenia**, obejmujące przerwanie każdej fazy wizyty przez dziesięć aktywności, limit dwóch gości na pobyt, podlewanie przed upływem 24 godzin następnego dnia, restart, cofnięcie daty, 23-/25-godzinną dobę, starszy zapis i cofnięcie nieudanego zapisu. `ui_visitors`: **29 sprawdzeń**, w tym pierwsze użycie piłki, chowanego i piaskownicy podczas wizyty. `ui_adventures` sprawdza teraz wspólny panel Dziś: **25 sprawdzeń**, trzy szerokości, zmianę dnia i nocy, wejścia z Domu/Albumu i brak liczników. `ui_yard_routines` sprawdza również następny dzień bez czekania 24 godzin. Obejrzano zrzuty Dziś 320 px i gościa 320 px. Widget: **1546** sprawdzeń / **252** zgodne projekcje; przypomnienia: **1067 + 18** i kontrola typów iOS. Ten pakiet zainstalowano następnie jako build 24, z zachowaniem postępów Glorii; szczegóły w [testach iOS](test-ios.md).

Dodatkowy test logiki:

```sh
YUFRIEND_TEST_ROOT=/tmp '/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_calm_day.gd
```


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


## Zbiorcze uruchamianie regresji

Po imporcie projektu: `python3 tools/run_game_tests.py` uruchamia logikę, a `python3 tools/run_game_tests.py --ui` uruchamia testy okien w sesji graficznej. Opcjonalnie ustaw `GODOT_BIN`. Uruchamiaj oba polecenia kolejno. Runner wymusza katalog tymczasowy dla testów obsługujących `YUFRIEND_TEST_ROOT`; pozostałe testy używają własnych ścieżek `/tmp`. Nie używa zapisu gracza. Błąd skryptu lub parsowania oznacza porażkę również przy kodzie wyjścia Godota równym zero. Limit procesu wynosi 120 sekund; testy mogą mieć własne krótsze limity.

`test_stage1.gd` sprawdza dzienny limit głaskania, odczyt istniejącego modelu, cofnięcie zegara, rejestrowanie treningu podwórkowego oraz uwagę i przyciemnienie przy panelach. Testy kąpieli, zdjęć i gestów mają stały dzienny zegar.


`ui_stage2.gd` sprawdza pierwsze spotkanie i wznowienie po przerwaniu, odrzucenie pustego imienia, trwałość imienia i tożsamości po restarcie, brak ponownego powitania, układ podwórka przy 320 punktach szerokości, czytelność odmowy oraz akcję zaproszenia i powrót do domu. `ui_bubbles.gd` sprawdza pierwszeństwo odpowiedzi przed myślą i powrót myśli po jej wygaśnięciu.

Etap 2 sprawdzono na odizolowanej kopii projektu. Odczyt i zapis kopii Glorii pobranej po uruchomieniu builda 29 zachował identyczne wszystkie 29 pól `pet` (schemat 15). Nie modyfikowano danych na telefonie. Zmiany etapu 2 wymagają jeszcze nowego eksportu i sprawdzenia na iPhonie, w szczególności klawiatury podczas nadawania imienia.

Weryfikacja etapu 2: 30/30 zestawów logiki i 24/24 zestawów UI przeszło (trzy testy UI ponowiono po przekroczeniu czasu renderowania; test kadru ponowiono po poprawce marginesu). Runner UI uruchamia okno na wierzchu, bez VSync, z limitem 60 FPS; zmniejsza to zależność oczekiwania na klatkę od zasłonięcia okna na macOS.


Mechanika wyjścia i sprzątania: `test_potty.gd` sprawdza cały cykl, zachowanie kupy po odczycie zapisu, ograniczenie dzienne, cofnięcie daty, przerwanie, dwukrotne dotknięcie i rollback przy błędzie zapisu. `ui_potty.gd` sprawdza przycisk wyjścia, animację, klikalną kupę i woreczek przy szerokości 320 punktów. Planista iOS jest objęty `tools/test_ios_reminders.sh`, zgodność widgetu przez `tools/test_ios_widget.sh`.

Weryfikacja wyjścia i sprzątania: 31 zestawów logiki oraz 25 UI przeszło po poprawkach i powtórzeniu testów dotkniętych zmianami. Planista: 1078 sprawdzeń, kontroler: 18, widget: 1546 (252 prognozy zgodne z Godotem); natywny kod przeszedł typecheck iOS. Kopia Glorii z buildu 30 zachowała wszystkie 29 pól w próbie odczytu i ponownego zapisu. Raporty i obrazy: `exports/potty-verification/`. Mechanika nie została jeszcze zainstalowana na iPhonie; rzeczywiste doręczenie jej powiadomienia pozostaje do sprawdzenia.


Build 31: końcowe uruchomienia całych pakietów dały 31/31 zestawów logiki i 25/25 UI. Planista przypomnień: 1078 sprawdzeń; kontroler: 18; widget: 1546, w tym 252 prognozy zgodne z Godotem. Kompilacja iOS i kontrola podpisu przeszły. Testy UI obejmują jedyny przycisk Dziś, karty okien, miejsce nad symulowaną klawiaturą, większego psa, powrót z podwórka i pełną widoczność akcji domu. Rzeczywistej klawiatury pierwszego spotkania ani doręczenia powiadomienia o wyjściu nie potwierdzono na fizycznym urządzeniu.
