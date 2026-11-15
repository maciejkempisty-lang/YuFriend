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
