# Test YuFriend na iPhonie

15 listopada 2026 zainstalowano wersję 0.1.0 (1) na fizycznym iPhonie 15 Pro Max z iOS 27.2. Użytkownik zatwierdził zaufanie do dewelopera i potwierdził działanie gry. Odczyt kontenera aplikacji potwierdził `pet.pet_name: Gloria` i `schema_version: 2`.

- Preset: `iOS Gloria Playtest` w [export_presets.cfg](../export_presets.cfg).
- Bundle ID: `com.maciejkempisty.yufriend.playtest`, osobisty zespół `P665WUWCN4`.
- Cecha eksportu `gloria_playtest` nadaje imię wyłącznie nowemu psu. Istniejące zapisy zachowują imię i postępy.
- [Ikona](../assets/art/app/yufriend-icon-v1.png) powstała we wbudowanym ImageGen; [prompt](../assets/art/app/yufriend-icon-v1-prompt.txt) zachowano obok. Oryginał ma 1254 × 1254 px; eksporter Godota generuje wymagane rozmiary ikon, w tym 1024 × 1024.
- Szablon iOS pochodzi z oficjalnego pakietu Godot 4.7.2. Suma SHA-256 całego pobranego pakietu: `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`.

Eksport wymaga `textures/vram_compression/import_etc2_astc=true`. Projekt używa [oficjalnego eksportera iOS](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --editor --quit
mkdir -p exports/ios
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --export-debug 'iOS Gloria Playtest' exports/ios/YuFriend.zip
```

Otwórz `exports/ios/YuFriend.xcodeproj`, wybierz swój telefon, podpisywanie automatyczne i Run. Preset eksportuje projekt Xcode; nie tworzy sam podpisanego IPA. Do aktualizacji używaj tego samego bundle ID i zespołu, bez odinstalowywania gry. Przed ponownym eksportem zachowaj ewentualne ręczne zmiany projektu Xcode; źródłem ustawień jest preset Godota.

Bieżący profil deweloperski wygasa 22 listopada 2026 o 13:24 czasu warszawskiego. W razie potrzeby ponownie podpisz i zainstaluj aplikację jako aktualizację. Eksport zgłosił automatyczną zmianę rozmiaru ikony oraz ostrzeżenie o brakującym ustawieniu `application/boot_splash/fullsize`; kompilacja Xcode i kontrola podpisu zakończyły się powodzeniem.

Weryfikacja obejmuje instalację, uruchomienie potwierdzone przez użytkownika i odczyt zapisu Glorii, a także 104 testy logiki na Macu po zmianie. Pełny test gestów, przerw w działaniu aplikacji, powrotu następnego dnia i wyglądu na telefonie pozostaje do wykonania.

## Aktualizacja 0.1.0 (2) — płynne przesuwanie

Poprawka usuwa przesuwanie kamery co cały powiększony piksel grafiki. `RoomView` renderuje dodatkowy piksel marginesu z każdej strony, a `room_scroll.gdshader` przesuwa próbkowanie gotowego obrazu o pojedyncze piksele ekranu. Zachowane są ostre krawędzie, całkowite powiększenie i zgodność dotyku z widocznymi przedmiotami. Margines nie powiększa widocznego świata ani nie wymaga ponownego rysowania tła co klatkę.

Test pulpitu przy 1080 × 2340 obejmuje wolny gest, brak skoku po puszczeniu palca, porównanie przesunięcia tła o jeden piksel między wyrenderowanymi klatkami oraz równe bloki kolorów przy przesuniętej kamerze. Wynik: 109 sprawdzeń UI i 38 importu/animacji. Subiektywna płynność na iPhonie wymaga potwierdzenia użytkownika po aktualizacji. Przed aktualizacją wykonano kopię zapisu Glorii.

Aktualizacja (2) została zainstalowana i uruchomiona na iPhonie. Odczyt zapisu po aktualizacji potwierdził ten sam identyfikator Glorii.

## Aktualizacja 0.1.0 (3) — muzyka

Dodano ścieżkę z `video2.mp4`, ciche odtwarzanie w pętli, pauzę po zawieszeniu aplikacji i zapamiętywany przełącznik w Profilu. Źródła opisuje [katalog muzyki](../assets/audio/music/README.md). 115 sprawdzeń UI obejmuje pełną długość nagrania, przejście przez punkt pętli, pauzę/wznowienie oraz zachowanie wyciszenia po ponownym uruchomieniu. Odsłuch na telefonie pozostaje do oceny użytkownika.

Wersja (3) została zainstalowana i uruchomiona na iPhonie; odczyt kontenera potwierdził zachowanie identyfikatora Glorii i jej umiejętności.

## Aktualizacja 0.1.0 (4) — efekty ElevenLabs

Dodano [20 krótkich nagrań](../assets/audio/sfx/README.md), wyzwalanie efektów przez faktyczne czynności i ruch oraz osobne wyciszenie efektów w Profilu. Trzy nagrania odbicia piłki są rezerwą; obecny ruch korzysta z odgłosu toczenia. W tle efekty zatrzymują się, a muzyka pozostaje niezależna. Gra nadal działa offline.

Eksport i kompilacja Xcode zakończyły się powodzeniem. Wersję (4) zainstalowano jako aktualizację i uruchomiono przez `devicectl`. Kopie kontenera przed i po potwierdziły imię Gloria, ten sam identyfikator, umiejętności i format zapisu 2. Testy na macOS: 104 domenowe, 38 sprite’ów i 131 UI. **Naturalność nagrań oraz balans efektów z muzyką na iPhonie wymagają odsłuchu użytkownika**; sama instalacja i testy tego nie potwierdzają.

## Aktualizacja 0.1.0 (5) — korekta treści efektów

Po zgłoszeniu szczekania podczas spaceru wymieniono 11 nagrań, w tym wszystkie cztery kroki. Przypisanie `step → paw_wood` było poprawne; błędna była treść części wygenerowanych próbek. Kroki mają teraz 160 ms i test ogranicza ich długość, aby nie nakładały się podczas marszu. Szczegóły i ograniczenia kontroli akustycznej opisuje [katalog efektów](../assets/audio/sfx/README.md).

164 sprawdzenia UI i efektów zakończyły się bez błędów. Sprawdzono też format i sumy źródeł/wyników wszystkich 20 nagrań. Eksport, kompilacja Xcode, instalacja wersji (5) i uruchomienie na iPhonie zakończyły się powodzeniem. Kopie kontenera przed i po aktualizacji potwierdziły tę samą Glorię i jej umiejętności. Instalacja nie zastępuje odsłuchu: nowe brzmienie spaceru, cicha pielęgnacja i toczenie piłki pozostają do oceny użytkownika na głośniku telefonu.

Wersja telefonu (5) zawierała również równoległe lokalne zmiany interfejsu i życia psa. Wynik 164 dotyczy tamtego pełnego katalogu; publikacja audio wydziela tylko obsługę i nagrania dźwięków. Zapis Glorii na telefonie ma po tych równoległych zmianach wersję 3, podczas gdy sam commit audio nie zmienia schematu zapisu. Nie instaluj starszego schematu na tej Glorii bez zgodnej obsługi migracji.

Wydzielony zakres audio przed publikacją sprawdzono osobno na bazie `c23df29`: **274/274** (104 logiki, 38 animacji, 132 UI). Obejmuje komplet 20 nagrań, kroki tylko podczas ruchu, limit 160 ms, brak dźwięku po odrzuconej opiece, zatrzymanie efektów w tle oraz niezależne wyciszenie. Te testy nie stanowią oceny naturalności nagrań.

## Aktualizacja 0.1.0 (6) — szczekanie i pisk przy głaskaniu

15 listopada 2026 zainstalowano i uruchomiono wersję (6) na iPhonie 15 Pro Max „MagicPhone”, jako aktualizację tego samego bundle ID i zespołu. Szczek jest związany z początkiem animacji `bark_stand`, również przy drzwiach. Przyjęte głaskanie odtwarza szelest sierści oraz jeden z dwóch nowych pisków ElevenLabs, z odstępem co najmniej 1,2 s. Wyciszenie efektów i zatrzymanie w tle nadal obowiązują.

Przed instalacją zachowano pełny kontener w `exports/iphone-backups/2026-11-15-before-v6/`. Odczyt `Documents` po uruchomieniu, w `exports/iphone-backups/2026-11-15-after-v6/`, potwierdził zachowanie identyfikatora, imienia Glorii, osobowości i wszystkich umiejętności. Aktualizacja zawiera bieżące lokalne zmiany gry, w tym migrację zapisu 3 → 4; oryginalny zapis pozostaje również na telefonie jako `pet.json.v3`. Migrację rzeczywistej kopii Glorii sprawdzono przed instalacją.

Eksport w `exports/ios-audio-v6/`, kompilacja Xcode i kontrola podpisu zakończyły się powodzeniem. Zainstalowana aplikacja zgłasza build 6 i pozostała uruchomiona po kontroli. Pakiet aplikacji ma tę samą sumę SHA-256 co sprawdzony eksport, zawierający komplet 22 efektów (trzy szczeki i dwa piski). Przeszły **282 sprawdzenia bez okna**: 111 logiki/zapisu, 42 życia psa, 58 zabaw, 38 animacji i 33 audio. Wyniki i potwierdzenia instalacji zapisano w `exports/ios-audio-v6/evidence/`. Odsłuch pisków, szczekania i ich balansu na głośniku telefonu pozostaje próbą użytkownika.

## Aktualizacja 0.1.0 (7) — kadr pośredni i krótsza historia relacji

15 listopada 2026 zainstalowano build 7 na iPhonie 15 Pro Max „MagicPhone” jako aktualizację tego samego bundle ID i zespołu. Eksport, kompilacja Xcode, weryfikacja podpisu i uruchomienie zakończyły się powodzeniem. Zrzut 1290 × 2796 z fizycznego urządzenia pokazuje Glorię, miskę i piłkę jednocześnie w domyślnym kadrze. Przegląd całego pokoju nadal służy jako mapa; głaskanie i trening zachowują dodatkowe zbliżenie.

Pełna kopia kontenera sprzed aktualizacji: `exports/iphone-backups/2026-11-15-before-v7/`. Kopia `Documents` po uruchomieniu: `exports/iphone-backups/2026-11-15-after-v7/`. Porównanie potwierdziło to samo imię, identyfikator, ziarno osobowości, cechy, umiejętności i kamienie milowe. Oryginalne pliki pozostają w kopii. Format nadal wynosi 4; starszy album do 240 wpisów jest odczytywany przed ograniczeniem bieżących relacji do 10.

Dowody eksportu, budowania, instalacji, uruchomienia, zrzut i porównanie danych: `exports/ios-room-v7/evidence/`. Testy pulpitu: **531/531**. Kontrola sprzętowa obejmowała instalację, uruchomienie, obraz domyślnego kadru oraz trwałość danych; nie zastępuje ręcznej oceny wygody gestów, całej ścieżki treningu ani odsłuchu.

## Aktualizacja 0.1.0 (8) — widget iPhone’a

15 listopada 2026 podpisano, zainstalowano i uruchomiono build 8 z natywnym rozszerzeniem WidgetKit: małym, średnim i prostokątnym na ekran blokady. Aplikacja i rozszerzenie mają wspólną App Group. [Źródła, eksport i instrukcja dodania](widget-ios.md).

Po zgodzie użytkownika zabezpieczono wyłącznie `Documents/pet.json` w `exports/iphone-backups/2026-11-15-before-v8/`. Plik po uruchomieniu w `exports/iphone-backups/2026-11-15-after-v8/` potwierdził tę samą Glorię, identyfikator, osobowość, cechy, umiejętności, więź i osiągnięcia. Format zapisu nadal wynosi 4. `exports/ios-widget-v8/state-verification.json` zawiera wyniki porównania; obok są potwierdzenia instalacji, uruchomienia i wersji 8 z właściwą grupą.

1525 sprawdzeń modelu Swift obejmuje 252 porównania prognozy z rzeczywistym `NeedsSystem` Godota. Cztery dodatkowe testy natywnego mostu na symulatorze sprawdziły aktualizacje pliku, uszkodzony zapis i późny zapis po wejściu w tło. Obejrzano natywne widoki mały, średni i śpiącego psa z długim imieniem. Pełny eksport gry nie zlinkował się dla symulatora arm64 z powodu architektury biblioteki Godota, dlatego podgląd uruchamiano niezależnie od silnika.

System iOS odmówił zewnętrznego odczytu `pet-widget.json` z głównego katalogu App Group przez `devicectl` (polityka kontenera, błąd 11007). Później, 15 listopada 2026, użytkownik ręcznie potwierdził poprawne imię Glorii i potrzeby po dodaniu widgetu, wykonaniu opieki i powrocie na ekran początkowy. Nie jest to odczyt grupowego pliku przez narzędzia ani sprawdzenie wszystkich rozmiarów widgetu.

## Aktualizacja 0.1.0 (9) — zegar ścienny

15 listopada 2026 zbudowano, podpisano, zainstalowano i uruchomiono build 9 na iPhonie 15 Pro Max „MagicPhone”. Aktualizacja zachowuje bundle ID, zespół i rozszerzenie WidgetKit (również build 9). Zegar obok portretu pieska pokazuje lokalny czas systemowy trzema wskazówkami. Zrzut z urządzenia potwierdził jego widoczność; testy interfejsu na komputerze zakończyły się wynikiem **238/238**.

Kopie wyłącznie `Documents/pet.json` przed i po instalacji znajdują się w `exports/iphone-backups/2026-11-15-before-v9/` i `exports/iphone-backups/2026-11-15-after-v9/`. Porównanie potwierdziło zachowanie Glorii, identyfikatora, ziarna osobowości, cech, umiejętności, osiągnięć, więzi i formatu zapisu 4. Eksport, log kompilacji, potwierdzenia instalacji i uruchomienia, odczyt wersji, wyniki porównania oraz zrzut `iphone-clock.png` zapisano w `exports/ios-clock-v9/`. Pakiet gry w aplikacji jest identyczny ze sprawdzonym eksportem zawierającym skrypt zegara. Nie zmieniano systemowej godziny telefonu w ramach tej kontroli.

## Aktualizacja 0.1.0 (10) — lokalne przypomnienia

15 listopada 2026 zbudowano, podpisano, zainstalowano i uruchomiono aktualizację z [dobrowolnymi przypomnieniami głosem psa](powiadomienia-ios.md). Użytkownik potwierdził włączenie opcji w grze i zgodę iOS. Natywny status z telefonu potwierdził `enabled: true`, `status: on`, `pending: 0`; nie jest to dowód doręczenia komunikatu. Domyślne wyłączenie przed zgodą również potwierdzono odczytem (`off`, zero oczekujących).

Kopie zapisu przed i po instalacji: `exports/iphone-backups/2026-11-15-before-v10/` oraz `exports/iphone-backups/2026-11-15-after-v10/`. Porównano istniejące pola identyfikatora, imienia, `personality_seed`, cech, umiejętności, osiągnięć i więzi; są zachowane, a format pozostał w wersji 4. Suma pakietu gry w aplikacji odpowiada eksportowi. Potwierdzenia i `state-verification.json` znajdują się w `exports/ios-reminders-v10/`, obok statusów przypomnień i kopii ich licznika.

Nowy zakres ma **403** sprawdzenia, istniejąca gra **649**, widget **1525**. Powtórzenie instalatora nie tworzy dodatkowych targetów, kopii źródeł ani wywołania startowego. Kontrola podpisu aplikacji i rozszerzenia przeszła. Kompilacja najpierw zatrzymała się z powodu braku miejsca na SSD; nieudany cache tej próby usunięto, a udany build powstał w `/tmp/yufriend-reminders-v10-build/`. Log sukcesu zachowano jako `exports/ios-reminders-v10/build-success.log`. Ostrzeżenia pełnego eksportu dotyczą generowanych przez Godota nagłówków i pustych opisów uprawnień kamery, mikrofonu i zdjęć; natywne źródła przypomnień przechodzą kontrolę typów z ostrzeżeniami jako błędami.

Pozostaje ręczna próba rzeczywistego doręczenia, otwarcia gry z komunikatu oraz zachowania przy Trybie skupienia. Nie skracano produkcyjnego minimum 30 minut ani nie zmieniano potrzeb Glorii w pliku, żeby wywołać alarm testowy.

## Aktualizacja 0.1.0 (11) — bezpieczny ekran ustawień

15 listopada 2026 po zgłoszeniu nachodzenia ustawień na Dynamic Island i braku dostępnego wyjścia zastąpiono osobne okno dialogowe panelem w obszarze gry. Panel korzysta ze współrzędnych i bezpiecznych marginesów głównego interfejsu. Nagłówek z przyciskiem „Zamknij” oraz dolny przycisk „Wróć do pokoju” są poza przewijaną treścią. Oba mają pola dotykowe o wysokości co najmniej 44 punktów.

**Użytkownik potwierdził na iPhonie**, że ustawienia mieszczą się pod Dynamic Island i da się z nich wyjść. Build 11 zbudowano, podpisano, zainstalowano i uruchomiono na tym samym urządzeniu. Testy: **52/52** sprawdzenia ustawień w sześciu układach z marginesami i skalowaniem 2×/3× oraz **302/302** dotychczasowe sprawdzenia UI. Obejrzano zrzuty pionowego i poziomego panelu.

Kopie `pet.json` przed i po aktualizacji znajdują się w `exports/iphone-backups/2026-11-15-before-v11/` i `exports/iphone-backups/2026-11-15-after-v11/`. Porównanie potwierdziło zachowanie identyfikatora, imienia, ziarna osobowości, cech, umiejętności, osiągnięć, więzi i schematu 4. Dowody instalacji, uruchomienia, testów i porównania: `exports/ios-settings-v11/`. Duży eksport i produkty kompilacji pozostawiono na dysku Maca w `/tmp/yufriend-settings-v11/` i `/tmp/yufriend-settings-v11-build/`, aby nie zapełniać zewnętrznego SSD.

## Aktualizacja 0.1.0 (14) — poranne przypomnienie i przejście w tło

15 listopada 2026 zbudowano, podpisano, zainstalowano i uruchomiono build 14 na MagicPhone. Aplikacja i rozszerzenie widgetu mają build 14, dotychczasowy bundle ID oraz zespół. Eksport i kompilacja są w `/tmp/yufriend-morning-v14/` oraz `/tmp/yufriend-morning-v14-build/`; logi i potwierdzenia w `exports/ios-morning-v14/`. Kontrola podpisu przeszła, źródła natywne odpowiadają repozytorium, a pakiet gry w aplikacji ma tę samą sumę co eksport.

Planista dopuszcza jedno przypomnienie następnego dnia między 09:00 a 12:00, zachowując limit spadku potrzeb do 8 godzin i dotychczasowe budżety. Ponownie przeszło **1067 sprawdzeń planisty, 18 kontrolera i sprawdzenie typów iOS**.

Próba buildu 12 ujawniła dodatkowy problem integracyjny: po rzeczywistym wyjściu z gry harmonogram pozostawał pusty, choć prognoza z pobranego zapisu wskazywała poranną potrzebę. Samo synchroniczne rozpoczęcie pracy w tle i dodanie obserwacji zdarzeń sceny w buildzie 13 nie wystarczyło. Build 14 dodatkowo przechowuje stan aktywności ze zdarzeń cyklu życia zamiast ponownie ustalać go przez `UIApplication.applicationState` przy każdym odczycie zapisu.

Użytkownik potwierdził poprawny widget z Glorią i potrzebami na ekranie początkowym podczas próby buildu 12. Kopia sprzed aktualizacji jest w `exports/iphone-backups/2026-11-15-before-v12/`; porównania po buildach 12, 13 i 14 potwierdziły zachowanie identyfikatora, imienia, ziarna osobowości, cech, umiejętności, osiągnięć, więzi i schematu 4. Kopia po najnowszej instalacji jest w `exports/iphone-backups/2026-11-15-after-v14/`, a wynik porównania w `exports/ios-morning-v14/state-verification.json`. Na tym etapie harmonogram po potwierdzonym wyjściu z buildu 14 oraz rzeczywiste doręczenie powiadomienia pozostają do sprawdzenia.

## Build 0.1.0 (15) — rytm i poprawki przed testem tygodniowym

Przygotowano pakiet obejmujący [rytm dnia](cykl-zachowan.md), wcześniejszą poprawkę porannego przypomnienia i przejścia w tło oraz poprawki rozmieszczania dymków. Nocne otwarcie gry wita gracza zamiast wymagać budzenia; po nagrodzie treningowej pies pozostaje na miejscu, a teksty senności pasują również do Glorii. Zakładka treningu wstrzymuje autonomiczne spacery między powtórzeniami.

Przeszło 1636 sprawdzeń gry w 14 zestawach, 1526 widgetu i 1085 przypomnień. Kopia `Documents/pet.json` sprzed aktualizacji jest w `exports/iphone-backups/2026-11-15-before-v15/`. Przed instalacją migracja jej roboczej kopii do v5 zachowała wszystkie dotychczasowe pola i oryginał v4. Eksport oraz podpisana kompilacja aplikacji i widgetu zakończyły się powodzeniem; duże produkty są w `/tmp/yufriend-rhythm-v15/` i `/tmp/yufriend-rhythm-v15-build/`. Dowody: `exports/ios-rhythm-v15/`.

Na etapie tego wpisu instalacja buildu 15 oczekuje na zakończenie commita. Rzeczywiste doręczenie przypomnienia, zachowanie widgetu po aktualizacji i tygodniowy test z ludźmi wymagają obserwacji na urządzeniu.
