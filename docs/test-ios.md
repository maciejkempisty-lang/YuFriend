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

Po commicie `f1b86d4` zainstalowano i uruchomiono build 15 na MagicPhone jako aktualizację tego samego bundle ID. Odczyt urządzenia potwierdza wersję 0.1.0 (15) i App Group. Kontrola podpisu aplikacji z widgetem przeszła, źródła natywne odpowiadają repozytorium, a pakiet gry w aplikacji jest identyczny ze sprawdzonym eksportem.

Kopia zapisu po instalacji jest w `exports/iphone-backups/2026-11-15-after-v15/`. Format wynosi 5; identyfikator Glorii, imię, ziarno, cechy, umiejętności, więź, nawyki i osiągnięcia zostały zachowane. Pamięć reakcji zawiera jedno nowe zignorowane zaproszenie do bliskości podczas działania gry; licznik wzrósł o jeden i ograniczona historia przesunęła się o jeden wpis. Nie traktujemy jej jako identycznej bajtowo ani jako resetu postępu. Szczegóły zapisano w `state-verification.json`.

Obejrzano zrzut fizycznego iPhone’a `exports/ios-rhythm-v15/iphone-rhythm.png` (1290 × 2796): Gloria, potrzeby, pokój i nawigacja są widoczne. Noc o 22:30 i powtórzenia treningu sprawdzono z wstrzykniętym zegarem na macOS; nie przestawiano zegara telefonu. Rzeczywiste doręczenie przypomnienia, zachowanie widgetu po aktualizacji i tygodniowy test z ludźmi nadal wymagają obserwacji na urządzeniu.


## Aktualizacja 0.1.0 (16) — etapy 1–5, 17 listopada 2026

Zbudowano, podpisano i zainstalowano aktualizację na tym samym iPhonie, pod tym samym identyfikatorem aplikacji. Użytkownik potwierdził działanie zmian. Kopia `Documents` bezpośrednio sprzed instalacji jest w `exports/iphone-backups/2026-11-17-before-v16-final/`, a po zakończonym uruchomieniu w `exports/iphone-backups/2026-11-17-after-v16-ready/`. Pierwszy, zbyt wczesny odczyt `after-v16` nadal zawierał v5; miarodajny odczyt `after-v16-ready` potwierdził migrację do v8. Porównanie potwierdziło zachowanie tożsamości Glorii, imienia, cech, więzi, nawyków, dotychczasowych sztuczek i osiągnięć. Oryginał v5 pozostał w kopii wersjonowanej. Raport: `exports/ios-stage5-v16/state-verification.json`.

Historycznie, przed buildem 17: poprawki po przeglądzie (forma sztuczek i lista dnia, pełny test powrotów oraz nocny powrót z podwórka) są obecnie lokalne i używają schematu v9. Nie instalowano ich ponownie na telefonie. Test kopii zapisu Glorii v8 → v9 zachował wszystkie wcześniejsze pola; raport w `exports/ios-stage5-v16/migration-v9-review.json`. Kolejna instalacja wymaga świeżej kopii Documents, aby zachować także postępy zdobyte od builda 16.


## Aktualizacja 0.1.0 (17) — stabilizacja, 17 listopada 2026

Kod i zasoby: commit `3ea71cc`. Eksport, podpisana kompilacja aplikacji z widgetem, kontrola podpisu, instalacja i uruchomienie na MagicPhone zakończyły się powodzeniem. Odczyt urządzenia potwierdza build 17. Zachowano bundle ID i zespół; aplikacji nie odinstalowywano.

Świeża kopia całego Documents przed instalacją: `exports/iphone-backups/2026-11-17-before-v17/Documents`; odczyt po uruchomieniu: `exports/iphone-backups/2026-11-17-after-v17/Documents`. Migracja v8 → v11 zachowała identyfikator, imię, umiejętności, osobowość, cechy, więź, nawyki, zdjęcia, dekoracje i osiągnięcia Glorii. Z wcześniejszych pól zmieniły się tylko potrzeby i czas ostatniej wizyty, zgodnie z upływem czasu. Oryginał v8 jest identyczny bajtowo z archiwum `.v8.8621c49249fb592972051f0ea21a370d9bc48f16934cd148d6b229bda419c515`; zwykła `.v8` przechowuje wcześniejszą zawartość i nie została nadpisana. Raport oraz potwierdzenia urządzenia: `exports/ios-stabilization-v17/`.

Zmiany: powrót zmęczonego psa do legowiska po zakończeniu zabawy, usuwanie zdjęcia z potwierdzeniem, kąpiel przy energii co najmniej 35, sytości 30 i higienie poniżej 80 (efekt +45 higieny, −5 energii, −2 sytości), czytelne podpisy opieki i pełniejszy kadr podwórka przy szerokości 320 px. Usunięcie wpisu Albumu nie kasuje PNG używanego przez starsze kopie.

Weryfikacja lokalna: 17 zestawów logiki i 11 UI bez błędów; widget 1526 sprawdzeń, przypomnienia 1067 planisty i 18 kontrolera. Obejrzano komputerowe zrzuty wąskiego układu. Te wyniki nie są potwierdzeniem gestów na fizycznym ekranie 320 px ani rzeczywistego doręczenia przypomnienia. Status przypomnień po uruchomieniu: włączone, zero oczekujących; nie dowodzi to doręczenia. Bieżąca obserwacja widgetu, powiadomienia i siedem dni z 5–10 testerami pozostają otwarte.

Duże produkty poza SSD projektu: `/tmp/yufriend-stabilization-v17` oraz `/tmp/yufriend-stabilization-v17-build`; log kompilacji `/tmp/yufriend-stabilization-v17-build.log`.

## Kod po buildzie 17 — ogródek i wyjście na potrzebę

Wdrożone lokalnie, jeszcze bez nowej instalacji telefonu. Schemat v12; widget akceptuje v4–v12. Test roboczej kopii Glorii z `2026-11-17-after-v17/Documents/pet.json` zachował wszystkie 26 istniejących pól, archiwum v11 i poprawny odczyt po ponownym zapisie. Nie modyfikowano oryginału ani danych na telefonie. Przed kolejną instalacją nadal należy pobrać świeże Documents.

Regresja: 18 zestawów logiki, w tym 49 sprawdzeń ogródka/wyjścia; 12 zestawów UI, w tym sadzenie i podlewanie przy 320 px oraz wejście i pochwała w nowym miejscu. Po korekcie deklaracji WeakRef ponowiono testy kąpieli i dymków; oba przechodzą. Ponowiona kontrola rytmu nie zgłosiła ostrzeżenia zasobów przy zamknięciu. Widget: 1526 sprawdzeń / 252 prognozy zgodne z Godotem. Zrzuty lokalne: `/tmp/yuf-garden-ui.png`, `/tmp/yuf-garden-overview.png`. Są to próby komputerowe, nie potwierdzenie nowej wersji na fizycznym iPhonie.


## Buildy 18 i 19 — ogródek, więź i kopanie, 17 listopada 2026

Build 18 zainstalowano i uruchomiono na MagicPhone z zachowaniem identyfikatora aplikacji oraz zespołu podpisującego. Kopie Documents: `exports/iphone-backups/2026-11-17-before-v18/` i `after-v18/`. Przejście v11 → v12 zachowało dotychczasowy postęp; w odczycie po uruchomieniu zmieniły się potrzeby i czas wizyty. Archiwa `.v11` pochodzą z ostatnich zapisów uruchomionej aplikacji i różnią się od wcześniejszej kopii komputera tylko tymi dwoma polami; nie są identyczne bajtowo z tą kopią.

Build 19 dodaje poziomy więzi, pięć dekoracji, spokojny rytuał oraz piaskownicę z nowym klipem i kolekcją 12 skarbów. Kopia sprzed instalacji: `exports/iphone-backups/2026-11-17-before-v19/`. Migracja roboczej kopii v12 → v13 zachowała wszystkie 27 wcześniejszych pól, archiwum i odczyt po ponownym zapisie. Eksport, podpisana kompilacja, instalacja oraz uruchomienie zakończyły się powodzeniem.

Odczyt `after-v19` potwierdził zachowanie tożsamości, imienia, sztuczek, więzi, cech, zdjęć, dekoracji, osiągnięć i ogródka. Poza potrzebami i czasem zmieniło się `social`: jedno zignorowane zaproszenie do liny podczas działania aplikacji, związany licznik i przesunięcie ograniczonej historii. To normalny zapis zdarzenia, nie reset. Dowody: `exports/ios-exploration-v19/`. Końcowa kompilacja tego samego wydania uwzględnia poprawkę omijania paska i miejsc podwórka przez dymki.

Weryfikacja: 19 zestawów logiki, 13 UI, widget 1526 sprawdzeń / 252 prognozy oraz przypomnienia 1067 + 18. W zestawach sprite’ów, Albumu i UI zaktualizowano oczekiwane liczby klipów (28) i dekoracji (5), po czym odpowiednie zestawy powtórzono z powodzeniem. Nowy test kopania i więzi ma 64 sprawdzenia. Zrzuty 320 px obejmują animację, kolekcję, poziomy oraz dekoracje. Próby komputerowe nie potwierdzają dotyku na iPhonie ani faktycznego doręczenia przypomnienia; te obserwacje pozostają otwarte. Nie przestawiano zegara ani nie zmieniano ręcznie potrzeb Glorii.

Końcową kompilację buildu 19 z poprawką dymka ponownie zainstalowano i uruchomiono. Dodatkowe kopie: `before-v19-final` i `after-v19-final`. Porównanie potwierdza schemat 13 i zachowanie tożsamości, imienia, ziarna, sztuczek, więzi, cech, zdjęć, dekoracji, osiągnięć, ogródka oraz kolekcji. Raport: `exports/ios-exploration-v19/verification-final.json`.


## Pakiet po buildzie 19 — komendy w zabawach i kwiaty

Implementacja lokalna, bez nowej instalacji na iPhonie. Kopia Glorii `2026-11-17-after-v19-final/Documents/pet.json` przeszła migrację v13 → v14, ponowny zapis i odczyt; wszystkie 28 dotychczasowych pól zostało zachowanych. Oryginał i dane telefonu nie zostały zmienione.

Nowy zestaw logiki: 60 sprawdzeń komend, wspólnego treningu dnia, zapisu, przerwania, cofnięcia nagrody przy błędzie zapisu oraz dekoracji. Próba UI przechodzi przez przyciski na 320 px i faktyczny powrót pieska do punktu rzutu. Widget: 1526 sprawdzeń / 252 prognozy. Zrzuty: `/tmp/yuf-outdoor-recall.png`, `/tmp/yuf-outdoor-stay.png`, `/tmp/yuf-outdoor-flowers-room.png`, `/tmp/yuf-outdoor-flowers-menu.png`. Przed kolejną instalacją trzeba pobrać świeże Documents z telefonu; wcześniejsza kopia jest dowodem migracji, nie aktualną kopią bezpieczeństwa.

Końcowa regresja pakietu: 20 zestawów logiki i 14 interfejsu bez błędów. Po dodaniu anulowania oferty przy zakończeniu zabawy ponowiono 60 sprawdzeń komend z powodzeniem.


## Aktualizacja 0.1.0 (20) — animacja przejścia i komendy w zabawach

17 listopada 2026 zbudowano, podpisano, zainstalowano i uruchomiono build 20 na MagicPhone. Odczyt urządzenia potwierdza 0.1.0 (20). Zachowano bundle ID `com.maciejkempisty.yufriend.playtest` i zespół; nie odinstalowywano aplikacji. Pakiet zawiera wcześniejsze komendy i kwiatowe dekoracje oraz animację podejścia do drzwi/furtki, otwarcia, przyciemnienia i wyjścia po drugiej stronie.

Bezpośrednia kopia sprzed instalacji: `exports/iphone-backups/2026-11-17-before-v20-final/Documents`; po uruchomieniu: `exports/iphone-backups/2026-11-17-after-v20/Documents`. Migracja roboczej kopii v13 → v14 zachowała wszystkie 28 wcześniejszych pól, ponowny zapis i odczyt. Na telefonie archiwum `.v13` jest identyczne bajtowo z kopią sprzed instalacji. Porównanie po uruchomieniu potwierdziło zachowanie tożsamości, sztuczek, cech, osiągnięć, treningu dnia, ogródka, kolekcji i dekoracji. Więź wzrosła z 96,55 do 96,90 wraz z jedną dodatkową zabawą piłką (`games.ball` i historia zabawy +1); zmiany potrzeb i czasu są zgodne z działaniem gry. Nie traktujemy tych pól jako identycznych. Dowody: `exports/ios-commands-v20/verification.json` i potwierdzenia instalacji.

Przechodzi 20 zestawów logiki i 15 interfejsu po powtórzeniu dwóch poprawionych prób: dymki 786 sprawdzeń, animacja 14. Nowy zestaw sprawdza oba kierunki, ruch, otwarcie drzwi, moment zmiany sceny, anulowanie, brak podwójnego uruchomienia, tło aplikacji i noc przy przekroczeniu progu. Sprawdzono podpis aplikacji z widgetem; obejrzano komputerowe zrzuty na 320 px. Nie jest to potwierdzenie jakości gestów na fizycznym telefonie ani doręczenia powiadomienia.

Eksport i kompilacja poza SSD projektu: `/tmp/yufriend-commands-v20` oraz `/tmp/yufriend-commands-v20-build`. Zrzuty animacji: `/tmp/yuf-transition-approach.png`, `/tmp/yuf-transition-door-open.png`, `/tmp/yuf-transition-enter-yard.png`, `/tmp/yuf-transition-home.png`.


## Goście przy płocie — weryfikacja lokalna po buildzie 20 (17.11.2026)

- Logika: 21 zestawów przechodzi, w tym 52 sprawdzenia gości i 135 rytmu dnia.
- Interfejs: 16 zestawów przechodzi, w tym 24 sprawdzenia gości przy 320 × 680 oraz 14 przejść przez drzwi. Jednorazowe ostrzeżenie o zasobach przy zamykaniu testu ogródka nie powtórzyło się w osobnym przebiegu z logowaniem szczegółowym; jego asercje przeszły w obu przebiegach.
- Wizualnie sprawdzono wszystkie trzy postacie i przyciski na 320 px. Znaczniki miejsc są ukryte podczas spotkania. Nadal potrzebna ocena na fizycznym telefonie.
- Kopia `exports/iphone-backups/2026-11-17-after-v20/Documents/pet.json` przeszła odczyt, trzy spotkania z przywołaniem i ponowny zapis w osobnym katalogu `/tmp`: wszystkie 28 pól pieska identyczne, schema_version nadal 14. Oryginalna kopia i dane telefonu nie były modyfikowane.
- Pakiet gości nie jest jeszcze zainstalowany na iPhonie; ostatnia instalacja pozostaje buildem 20. Przy następnej instalacji wykonać świeżą kopię Documents oraz sprawdzić wizyty, uspokojenie, faktyczne dojście po przywołaniu i powrót po zmęczeniu/nocą.

## Aktualizacja 0.1.0 (21) — goście przy płocie, 17 listopada 2026

Build 21 z kodem gości (`5c6d4a5`) wyeksportowano, podpisano, zainstalowano i uruchomiono na MagicPhone. Urządzenie potwierdza 0.1.0 (21). Bundle ID, zespół P665WUWCN4 i App Group pozostały bez zmian; nie odinstalowywano gry. Podpis aplikacji z widgetem zweryfikowano, obydwa pakiety mają numer 21, a PCK w aplikacji jest identyczny z eksportem. Pierwsze uruchomienie zablokował ekran blokady; po odblokowaniu przez użytkownika uruchomienie i obecność procesu potwierdzono.

Kopie Documents: `exports/iphone-backups/2026-11-17-before-v21/`, bezpośrednio przed instalacją `before-v21-final/`, po samej instalacji `after-v21-install/`, po uruchomieniu `after-v21/`. Kopia robocza świeżego zapisu przeszła odczyt, wizyty i ponowny zapis bez zmiany żadnego z 28 pól. Po samej instalacji wszystkie pola pozostały identyczne. Po uruchomieniu zachowano 25 pól, w tym tożsamość, więź, sztuczki, formę, temperament, zdjęcia, dekoracje, ogródek i kolekcję. Zmieniły się potrzeby i czas ostatniej wizyty oraz historia: jedna nowa wizyta wieczorem. Schemat nadal v14, bez migracji.

Potwierdzenia i porównanie: `exports/ios-visitors-v21/verification.json` oraz pliki instalacji, uruchomienia i listy aplikacji. Duże produkty są w `/tmp/yufriend-visitors-v21` i `/tmp/yufriend-visitors-v21-build`. Weryfikacja wizualna samych gości dotyczy wcześniejszych prób komputerowych; nie przeprowadzano ręcznego spotkania z gościem na telefonie ani nie zmieniano potrzeb lub zegara Glorii.

## Pamięć gości — pakiet lokalny po buildzie 21

Wdrożono trwałe rozpoznawanie gości, trzy spokojne dni oswajania i ilustrowaną sekcję Albumu. Format pozostaje v14. Test na roboczej kopii `2026-11-17-after-v21/Documents/pet.json` zachował wszystkie wcześniejsze pola poza świadomie dopisanymi pamiątkami i czasem zapisu; wszystkie stare wpisy i osiągnięcia pozostały obecne. Nowy spokojny dzień przetrwał ponowny odczyt. Oryginału i danych telefonu nie zmieniano.

Przechodzą 22 zestawy logiki i 17 interfejsu, w tym 56 nowych sprawdzeń pamięci gości i 6 sprawdzeń Albumu/rozpoznawania. Test UI po poprawieniu scenariusza ponownie wychodzi na podwórko po zamknięciu Albumu. Jednorazowe ostrzeżenie o zasobach w teście komend nie powtórzyło się w osobnym przebiegu szczegółowym. Obejrzano ilustrację i zrzut Albumu 320 × 680 (`/tmp/yuf-memory-album.png`). Kod oczekuje na kolejną instalację; na telefonie nadal build 21 bez tego pakietu.

## Aktualizacja 0.1.0 (22) — pamięć gości i nowy Album, 17 listopada 2026

Kod pakietu `ae04c61` wyeksportowano, podpisano, zainstalowano i uruchomiono na MagicPhone jako build 22. Odczyt aplikacji i procesów potwierdza nową wersję oraz działającą grę. Aplikacja i widget mają numer 22, dotychczasowy bundle ID, zespół P665WUWCN4 i App Group. Podpis z rozszerzeniem przeszedł kontrolę; PCK wewnątrz aplikacji jest identyczny z eksportem. Nie odinstalowywano gry.

Świeże kopie Documents: `exports/iphone-backups/2026-11-17-before-v22/`, bezpośrednio przed instalacją `before-v22-final/`, po instalacji `after-v22-install/`, po uruchomieniu `after-v22/`. Próba pamięci gości na roboczej kopii świeżego zapisu zachowała wcześniejszy postęp oraz wpisy, a nowa pamiątka przetrwała odczyt. Porównanie końcowego zapisu telefonu zachowuje 26 z 28 pól dokładnie, w tym tożsamość, osobowość, więź, sztuczki, formę, historię, pamiątki, zdjęcia, dekoracje, ogródek i kolekcję. Zmieniły się jedynie potrzeby i czas ostatniej wizyty zgodnie z działaniem gry. Format nadal v14, bez migracji.

Dowody instalacji, uruchomienia i porównania: `exports/ios-memory-v22/verification.json` oraz sąsiednie raporty urządzenia. Eksport i kompilacja: `/tmp/yufriend-memory-v22`, `/tmp/yufriend-memory-v22-build`. Ocena wizualna Albumu pochodzi z wcześniejszego testu komputerowego 320 px; nie wymuszano spotkań, zmiany daty ani potrzeb Glorii na telefonie.

## Małe przygody dnia — pakiet lokalny po buildzie 22

Przechodzą 23 zestawy logiki oraz 18 interfejsu, w tym 65 sprawdzeń przygód i 11 UI. Dwa stare zestawy logiki otrzymały rzeczywisty tymczasowy SaveSystem, ponieważ nagroda treningowa jest teraz zatwierdzana dopiero po udanym zapisie. Pojedyncza nieudana próba dotyku zaproszenia w `ui_play` przeszła po osobnym powtórzeniu (30/30); pozostałe zestawy UI przeszły od razu. Obejrzano plan i Album przy 320 × 680: `/tmp/yuf-adventure-plan.png`, `/tmp/yuf-adventure-album.png`.

Widget: 1526 sprawdzeń, 252 prognozy zgodne z Godotem, odczyt v15. Przypomnienia: 1067 planisty i 18 kontrolera. Migracja roboczej kopii `2026-11-17-after-v22/Documents/pet.json` v14 → v15 zachowała wszystkie 28 wcześniejszych pól dokładnie, dodała pustą przygodę, pozostawiła identyczne bajtowo archiwum `.v14` i przeszła ponowny odczyt. Oryginał i dane telefonu nie były zmieniane.

Pakiet nie jest zainstalowany na iPhonie; ostatnia instalacja to build 22 / v14. Przed instalacją kolejnego wydania pobrać świeże Documents i sprawdzić migrację najnowszego zapisu. Po przejściu na v15 build 22 nie odczyta nowego zapisu.

## Aktualizacja 0.1.0 (23) — małe przygody dnia, 17 listopada 2026

Pakiet `2ddc949` wyeksportowano, podpisano, zainstalowano i uruchomiono na MagicPhone jako build 23. Odczyt aplikacji i procesów potwierdza nową wersję oraz działającą grę. Aplikacja i widget mają numer 23, dotychczasowy bundle ID, zespół P665WUWCN4 i App Group. Kontrola podpisu z rozszerzeniem przeszła, PCK aplikacji jest identyczny z eksportem. Gry nie odinstalowywano.

Kopie Documents: `exports/iphone-backups/2026-11-17-before-v23/`, bezpośrednio przed instalacją `before-v23-final/` i po uruchomieniu `after-v23/`. Migrację świeżej kopii sprawdzono przed instalacją: wszystkie 28 dotychczasowych pól bez zmian, pusty plan, dokładne archiwum v14 i poprawny ponowny odczyt. Telefon po uruchomieniu potwierdza v15 oraz nowe `adventure` bez zaliczonych zadań. W porównaniu końcowym 26 wcześniejszych pól pozostało identycznych, w tym sztuczki, więź, cechy, historia, pamiątki, ogródek, kolekcja, zdjęcia i dekoracje. Zmieniły się tylko potrzeby i czas ostatniej wizyty, zgodnie z działaniem gry.

Oryginał bezpośredniej kopii sprzed instalacji zachowano dokładnie w `pet.json.v14.85217380b708e4489b80141472fe37ce1b24f7aa8f1ed71b004de78401fcea40`. Zwykła kopia `.v14` zawiera wcześniejszy stan różniący się tylko potrzebami i czasem; nie została nadpisana. Dowody: `exports/ios-adventures-v23/verification.json` oraz raporty instalacji i uruchomienia. Duże produkty są w `/tmp/yufriend-adventures-v23` i `/tmp/yufriend-adventures-v23-build`.

Nie wykonywano zadań ani nie zmieniano zegara lub potrzeb Glorii na telefonie. Obsługę przygód i układ 320 px sprawdzono wcześniej na komputerze. Build 22 nie odczyta nowego zapisu v15; poprzedni zapis jest zabezpieczony w kopiach.


## Aktualizacja 0.1.0 (24) — spokojniejszy dzień i zabawa w wodzie, 17 listopada 2026

Build 24 został wyeksportowany, podpisany, zainstalowany i uruchomiony na MagicPhone. Lista aplikacji potwierdza 0.1.0 (24), a lista procesów działającą grę. Aplikacja i widget mają build 24, dotychczasowy bundle ID, zespół P665WUWCN4 oraz App Group. Podpis z rozszerzeniem przeszedł weryfikację, a pakiet PCK w aplikacji jest identyczny z eksportem. Aktualizacja obejmuje panel Dziś, nieblokujących gości, kalendarzowe podlewanie, czytnik widgetu v4+ i istniejące lokalne zmiany zabawy w wodzie. Nie odinstalowywano gry.

Kopia robocza świeżego zapisu przeszła odczyt, zapis i ponowny odczyt z zachowaniem wszystkich 29 pól. Przed instalacją ponowiono kopię Documents. Po samej instalacji wszystkie 28 plików Documents pozostało identycznych bajtowo. Po uruchomieniu nadal istnieją wszystkie pliki, a 26 z 29 pól pieska jest identycznych: zachowane są tożsamość Glorii, więź, sztuczki, temperament, forma, osiągnięcia, fotografie, dekoracje, ogródek, kolekcje i przygody. Zmieniły się potrzeby i czas ostatniej wizyty; historia dostała dokładnie jedną wizytę wieczorem. Schemat nadal v15. Nie wykonywano czynności ani nie edytowano danych Glorii na telefonie.

Trwałe kopie całego Documents: `exports/iphone-backups/2026-11-17-before-v24.zip` i `2026-11-17-after-v24.zip`. Zweryfikowano zawartość pet.json w obu archiwach. Raport: `exports/ios-calm-v24/verification.json`. Potwierdzenia urządzenia, log kompilacji, eksportu i testów: `exports/ios-calm-v24/evidence.zip`. Ze względu na małą ilość miejsca na SSD eksport i produkty kompilacji są na dysku wewnętrznym: `/tmp/yufriend-calm-v24`, `/tmp/yufriend-calm-v24-build`; robocze dane w `/tmp/yufriend-calm-v24-evidence`.

`ui_water` kończy teraz pracę po zatrzymaniu audio, zwolnieniu sceny oraz sprawdzeniu słabych referencji do widoku i nagrań. Trzy przebiegi (w tym ze szczegółowym logowaniem) dały 105/105 bez ostrzeżeń zasobów. Wcześniejsze ostrzeżenie było nieregularne; nie przypisujemy go potwierdzonemu wyciekowi produkcyjnej logiki wody. Przed tym buildem przeszły 25 zestawów logiki i 19 interfejsu, 1546 sprawdzeń widgetu i 1085 przypomnień. Instalacja nie zastępuje ręcznej oceny nowych zachowań, widgetu i doręczenia przypomnienia na telefonie.


## Aktualizacja 0.1.0 (25) — żywe otoczenie, 17 listopada 2026

Build 25 wyeksportowano z projektu na Kingstonie, skompilowano, podpisano i zainstalowano na MagicPhone. Odczyt listy aplikacji potwierdza 0.1.0 (25). Pakiet zawiera motyla nad grządką, wróbla na trawie i ptaka za oknem, bez zadań, liczników ani blokowania czynności. Aplikacja i widget mają build 25 oraz dotychczasowy bundle ID, zespół P665WUWCN4 i App Group. Podpis z rozszerzeniem jest poprawny, PCK w aplikacji jest identyczny z eksportem, a log eksportu potwierdza obecność trzech nowych skryptów otoczenia. Nie odinstalowywano gry.

Świeża kopia Glorii przeszła odczyt, zapis i ponowny odczyt z zachowaniem wszystkich 29 pól. Bezpośrednio przed instalacją ponowiono kopię Documents. Po samej instalacji wszystkie 28 plików pozostało identycznych bajtowo. Zachowany jest schemat v15, bez migracji. Kopia bezpieczeństwa: `exports/iphone-backups/2026-11-17-before-v25.zip`; integralność archiwum i zawartość pet.json zweryfikowano. Raport i dowody: `exports/ios-ambient-v25/verification.json` oraz `evidence.zip`.

Po odblokowaniu telefonu przez użytkownika uruchomiono grę i potwierdzono działający proces buildu 25. Porównanie z kopią bezpośrednio sprzed instalacji zachowuje 26 z 29 pól pieska dokładnie, w tym tożsamość, więź, sztuczki, temperament, formę, osiągnięcia, fotografie, dekoracje, ogródek, kolekcje i przygody. Zmieniły się jedynie potrzeby i czas ostatniej wizyty oraz historia: dokładnie jedna dodatkowa wizyta wieczorem. Wszystkie wcześniejsze pliki Documents pozostają obecne. Kopia po uruchomieniu: `exports/iphone-backups/2026-11-17-after-v25.zip`, z potwierdzoną integralnością i zawartością pet.json. Raport i archiwum dowodów uzupełniono. Nie wykonywano czynności ani nie edytowano danych Glorii; nie oceniano wizualnie animacji na telefonie. Wcześniejsze testy komputerowe: 26 sprawdzeń logiki otoczenia, 25 integracji, 152 spokojnego dnia i siedem zestawów UI.

Eksport: `/tmp/yufriend-ambient-v25`; kompilacja: `/tmp/yufriend-ambient-v25-build`; robocze kopie i raporty: `/tmp/yufriend-ambient-v25-evidence`. Eksport zgłosił ostrzeżenia o automatycznym skalowaniu ikony, brakującym ustawieniu pełnoekranowego splashu i odczycie źródłowych PNG przez lokalny generator grafik widgetu; kompilacja i weryfikacja podpisu zakończyły się powodzeniem.


## Aktualizacja 0.1.0 (26) — pogoda i zaproszenia Glorii, 17 listopada 2026

Wyeksportowano aktualny projekt z KINGSTON, skompilowano, podpisano, zainstalowano i uruchomiono build 26 na MagicPhone. Lista aplikacji i procesów potwierdza wersję 26 i działającą grę. Aplikacja i widget mają ten sam numer, dotychczasowy bundle ID, zespół P665WUWCN4 i App Group. Kontrola podpisu przeszła; PCK w aplikacji jest identyczny z eksportem i zawiera pogodę, zaproszenia oraz nową grafikę. Źródła nie zmieniły się podczas kompilacji; manifest sum jest w archiwum dowodów.

Świeża kopia Glorii przeszła odczyt, zapis i ponowny odczyt bez zmiany żadnego z 29 pól. Przed instalacją ponowiono kopię Documents. Trwałe archiwa: `exports/iphone-backups/2026-11-17-before-v26.zip`, `before-v26-final.zip` (z pełnym prefiksem daty) i `2026-11-17-after-v26.zip`; integralność ZIP oraz zapis pet.json sprawdzono. Ostatni odczyt po uruchomieniu zachowuje 27 z 29 pól dokładnie. Zmieniły się tylko potrzeby i czas zapisu; tożsamość, więź, umiejętności, forma, temperament, historia, pamiątki, zdjęcia, dekoracje, ogródek, kolekcje, przygody i preferencje pozostały bez zmian. Schemat nadal v15, bez migracji. Wszystkie 28 wcześniejszych plików Documents pozostają obecne. Gry nie odinstalowywano.

Podczas przygotowania aktualizacji działająca wcześniejsza gra zapisała jeszcze potrzeby i czas oraz pliki planisty przypomnień; nie deklarujemy identyczności bajtowej wszystkich plików po samej instalacji. Raport porównania: `exports/ios-weather-v26/verification.json`, szczegółowe dowody: `evidence.zip`. Eksport i kompilacja są w `/tmp/yufriend-weather-v26` i `/tmp/yufriend-weather-v26-build`.

Przed wydaniem przeszło 27 zestawów logiki i 21 interfejsu; nowy pakiet ma 99 sprawdzeń logiki i 19 UI. Test fauny dostosowano do słonecznej pogody. Sporadyczne ostrzeżenie zasobów przy zamknięciu testu rytmu nie wystąpiło w osobnym powtórzeniu. Eksport powtórzył znane komunikaty generatora grafik widgetu; kompilacja, podpis i kontrola paczki zakończyły się powodzeniem. Nie przestawiano czasu ani potrzeb Glorii i nie wymuszano deszczu na telefonie. Ocena grafiki, gestów, widgetu oraz doręczenia powiadomień na fizycznym urządzeniu pozostaje osobną próbą.


## Aktualizacja 0.1.0 (27) — tor przeszkód i skok, 17 listopada 2026

Aktualny projekt wyeksportowano, skompilowano, podpisano, zainstalowano i uruchomiono na MagicPhone jako build 27. Odczyt aplikacji i procesu potwierdza 0.1.0 (27). Aplikacja i widget mają numer 27, dotychczasowy bundle ID, zespół P665WUWCN4 i App Group. Kontrola podpisu przeszła; PCK jest identyczny z eksportem oraz zawiera `yard_course`, `puppy_jump` i grafikę toru. Manifest sum źródeł potwierdza brak zmian podczas budowania. Nie odinstalowywano aplikacji.

Świeża kopia Glorii przeszła odczyt, zapis i ponowny odczyt z zachowaniem wszystkich 29 pól. Przed instalacją ponowiono pobranie Documents. Kopie z potwierdzoną integralnością: `exports/iphone-backups/2026-11-17-before-v27.zip`, `2026-11-17-before-v27-final.zip` i `2026-11-17-after-v27.zip`.

Po uruchomieniu 26 z 29 pól pozostaje identycznych, w tym identyfikator, imię, sztuczki, forma, więź, temperament, historia, pamiątki, zdjęcia, dekoracje, ogródek, kolekcje, przygody oraz preferencje. Zmieniły się potrzeby, czas ostatniego zapisu i `resting`: kopia miała odpoczynek oraz 100 energii, więc istniejąca reguła progu 85 obudziła Glorię przy uruchomieniu. Nie jest to reset. Schemat pozostaje v15, a wszystkie 28 wcześniejszych plików Documents są obecne. Działająca wcześniejsza gra zapisała jeszcze potrzeby, czas i plik planisty podczas przygotowania instalacji; nie deklarujemy identyczności bajtowej wszystkich plików po instalacji.

Raport: `exports/ios-course-v27/verification.json`; szczegółowe dowody: `evidence.zip`. Eksport i kompilacja: `/tmp/yufriend-course-v27` i `/tmp/yufriend-course-v27-build`. Eksport powtórzył znane komunikaty generatora grafik widgetu; podpis i kompilacja zakończyły się poprawnie.

Przed wydaniem przechodziło 28 zestawów logiki i 22 UI po powtórzeniu zestawu fauny tła. Nowy tor ma 42 sprawdzenia logiki i 133 interfejsu. Układ 320 px, animację skoku, podest i przerwanie w tle sprawdzono na komputerze. Na telefonie potwierdzono instalację, uruchomienie i zapis; nie wykonywano rundy toru, nie zmieniano ręcznie potrzeb ani zegara Glorii. Ocena dotyku i wyglądu pozostaje próbą użytkownika.


## Odpoczynek na podwórku — build 28 (17.11.2026)

Zbudowano, podpisano, zainstalowano i uruchomiono build 28 na MagicPhone. Aplikacja i widget zachowują dotychczasowy bundle ID, zespół P665WUWCN4 i App Group. Kontrola podpisu, identyczności PCK oraz manifestu źródeł przeszła. Pakiet zawiera zacienione legowisko, miskę z animacją picia i samodzielne przerwy po zabawie.

Świeża kopia zapisu zachowała 29/29 pól w próbie odczytu i zapisu. Po samej instalacji zapis pozostał identyczny. Po uruchomieniu zachowano 27/29 pól dokładnie; zmieniły się jedynie potrzeby i czas zapisu. Wszystkie wcześniejsze pliki Documents pozostają obecne. Schemat nadal v15. Nie odinstalowywano gry.

Archiwa: `exports/iphone-backups/2026-11-17-before-v28.zip`, `2026-11-17-before-v28-final.zip`, `2026-11-17-after-v28.zip`. Raport i dowody: `exports/ios-rest-v28/verification.json`, `evidence.zip`. Eksport i kompilacja: `/tmp/yufriend-rest-v28` i `/tmp/yufriend-rest-v28-build`. Przeszły wcześniejsze 29 zestawów logiki oraz 23 interfejsu. Animację i układ 320 px oceniono na komputerze; instalacja i uruchomienie nie zastępują ręcznej oceny nowej zabawy na telefonie.


## Aktualizacja 0.1.0 (29) — 18 listopada 2026

Zbudowano, podpisano, zainstalowano bez odinstalowania i uruchomiono build 29 na MagicPhone. Aplikacja i widget zachowują bundle ID, zespół P665WUWCN4 i App Group; oba mają numer 29. Podpis i zgodność PCK z eksportem zweryfikowano. Pierwsza instalacja przekroczyła czas połączenia; ponowienie zakończyło się sukcesem. Potwierdzono działające procesy aplikacji i widgetu.

Świeży zapis przeszedł odczyt i ponowny zapis bez zmiany 29 pól. Po instalacji wszystkie 29 plików Documents pozostało identycznych. Po uruchomieniu 23/29 pól bez zmian, w tym tożsamość, więź, sztuczki, forma, cechy, osiągnięcia, zdjęcia i kolekcje. Zmieniły się potrzeby, czas, odpoczynek, historia wizyty, raport nieobecności i dziennik. Nowy raport zastąpił jeden najstarszy nietrwały raport away_1794853541 zgodnie z istniejącym limitem dziennika; trwałe wspomnienia zachowano. Wszystkie wcześniejsze pliki są obecne, fotografie identyczne bajtowo. Schemat v15 bez migracji.

Kopie: exports/iphone-backups/2026-11-18-before-v29.zip, 2026-11-18-before-v29-final.zip, 2026-11-18-after-v29.zip. Raport i dowody: exports/ios-stage1-v29/verification.json oraz evidence.zip. Nie wykonywano aktywności ani nie edytowano danych gracza. Ręczna ocena dotyku i wyglądu pozostaje osobną próbą.


## Aktualizacja 0.1.0 (30) — 18 listopada 2026

Zbudowano, podpisano, zainstalowano jako aktualizację i uruchomiono build 30 na MagicPhone. Aplikacja i widget mają numer 30, dotychczasowy bundle ID, zespół P665WUWCN4 i App Group. Podpis, zgodność PCK z eksportem i niezmienność źródeł podczas budowania zweryfikowano. Lista aplikacji potwierdza build 30; działają procesy gry i widgetu. Wersja zawiera drugi etap: pierwsze spotkanie nowych psów, kadr, priorytety komunikatów i akcje podwórka.

Świeża kopia Glorii przeszła odczyt i zapis bez zmiany wszystkich 29 pól. Bezpośrednio przed instalacją ponowiono kopię. Po samej instalacji wszystkie 29 plików Documents było identycznych bajtowo. Po uruchomieniu 26/29 pól pozostało identycznych: zmieniły się wyłącznie potrzeby, czas ostatniej wizyty i historia (dodana jedna nocna wizyta, wszystkie wcześniejsze wpisy zachowane). Cały trwały postęp, imię, tożsamość, więź, umiejętności, wspomnienia i kolekcje zachowano. Wszystkie wcześniejsze pliki są obecne; fotografie i ui.cfg są identyczne. Schemat nadal v15. Nie usuwano aplikacji ani nie edytowano danych gracza.

Zweryfikowane kopie ZIP: `exports/iphone-backups/2026-11-18-before-v30.zip`, `2026-11-18-before-v30-final.zip`, `2026-11-18-after-v30.zip`. Raport i dowody: `exports/ios-stage2-v30/verification.json`, `evidence.zip`. Eksport i kompilacja w `/private/tmp/yufriend-v30-export` oraz `/private/tmp/yufriend-v30-build`. Przed wydaniem przeszło 30 zestawów logiki i 24 UI (część powtórzona). Na urządzeniu potwierdzono instalację, uruchomienie i zachowanie danych; ręczna ocena dotyku i klawiatury pierwszego spotkania pozostaje osobną próbą.


## Aktualizacja 0.1.0 (31) — 19 listopada 2026

Build 31 zbudowano, podpisano i zainstalowano jako aktualizację na MagicPhone. Lista aplikacji potwierdza numer 31. Aplikacja i widget zachowują bundle ID, zespół P665WUWCN4 i App Group; oba mają numer 31. PCK odpowiada eksportowi, a manifest 647 plików potwierdza zgodność źródeł roboczych z eksportowaną kopią.

Wydanie obejmuje zachowane zmiany Etapów 1–2, poprawki po przeglądzie, mechanikę wyjścia i sprzątania oraz uporządkowany dom, większego psa, jedno wejście Dziś i karty imienia, zabaw oraz sztuczek. Zestawy logiki 31/31 i UI 25/25 przeszły w końcowych przebiegach; testy natywne oraz kompilacja i podpis również przeszły.

Przed instalacją pobrano świeżą kopię Documents, sprawdzono odczyt i ponowny zapis wszystkich 29 pól Glorii bez zmian oraz ponowiono backup tuż przed aktualizacją. Po instalacji wszystkie 29 plików Documents jest identycznych bajtowo. Kopie: `exports/iphone-backups/2026-11-19-before-v31.zip` i `2026-11-19-before-v31-final.zip`. Raport: `exports/ios-ux-v31/verification.json`. Pierwsza próba uruchomienia została odrzucona przez iOS z powodu blokady telefonu; kontrola zapisu po uruchomieniu czeka na odblokowanie.

Układ i symulowaną klawiaturę sprawdzono na komputerze. Rzeczywista klawiatura pierwszego spotkania oraz doręczenie powiadomienia o potrzebie wyjścia wymagają odrębnej próby na urządzeniu; nie resetowano Glorii w celu wywołania powitania.
