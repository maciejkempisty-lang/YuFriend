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
