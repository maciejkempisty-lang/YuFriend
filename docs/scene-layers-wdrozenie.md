# Scene layers — wdrożenie handoff

27 listopada 2026, gałąź `codex/scene-layers`. Punktem wyjścia był `TODO.md`.

## Projekt uruchamiany przez grę

`level-editor/projects/ver2.json` rozszerza `ver1.json` o skrypty mechanik i brakujące elementy z istniejącej biblioteki grafik. Oryginalny `ver1.json` pozostaje bez zmian. Gra wybiera najwyższy numer `verN.json`; można nadal wskazać konkretny projekt przez `--project=`. W edytorze należy otworzyć **ver2**.

Dom ma aktywne legowisko, jedzenie i wodę, głaskanie, przytulanie, czesanie, kąpiel, trening, zabawy dotykowe i zręcznościowe oraz kontrolery zaproszeń i dekoracji. Ogród ma wodę i odpoczynek, tor i tor na czas, węszenie i chowanego, kopanie, grządkę, wyjście/sprzątanie, komendy, gości, zabawy zręcznościowe, bańki, zaproszenia i pogodę. Wykorzystano istniejące grafiki; to konfiguracja funkcjonalna, którą można dalej komponować w edytorze.

## Pozycje i ruch — sekcja 4.3 handoff

`RoomLayoutLoader` ustawia pozycję, bounds i stand zarówno domu, jak i ogrodu. Dokładne ID stacji ma pierwszeństwo przed aliasem skryptu. Niewidoczne elementy nie nadpisują stacji. Przy każdym udanym odczycie wracają bazowe wartości, dzięki czemu kolejne wczytanie nie kumuluje przesunięcia punktu dojścia. Niepełny odczyt (np. brak tekstury) zachowuje ostatni poprawny projekt.

Picie, odpoczynek, woda, tor, goście, kopanie, wyjście oraz węszenie/chowany korzystają z aktualnych stacji. Punkty dojścia są ograniczane pasem ruchu danego poziomu. Domyślne współrzędne odpowiadają światu 1440×540. Tor ma trasę względną do stacji `course`; `landing` i `podium` mogą być osobnymi elementami. Bez nich dziedziczą przesunięcie toru. `safe_spot` analogicznie dziedziczy przesunięcie miejsca gościa.

Stare proceduralne dekoracje i znaczniki nie wracają po przejściu między lokacjami. Efekty trwających czynności (pluski, picie, przeszkody rozkładanego toru) korzystają z nowych pozycji. Zmieniono także pozycję ogona w chowanego i miejsca sprzątania.

`AmbientLife` jest wyłączony w scenach edytora. **Bańki pozostają w swoim lokalnym świecie 640×400**, ponieważ jest to układ osobnego okna minigry, a nie współrzędne pokoju. Element `bubble_play` decyduje o dostępności i uruchomieniu tej gry.

## Dostępność — sekcja 4.2 handoff

`has_script(id, level, params)` wymaga widocznego elementu w odpowiednim poziomie; opcjonalny filtr rozróżnia np. kałużę i zraszacz. `allows` zachowuje historyczny tryb bez projektu dla samodzielnych systemów i testów. **Wczytany pusty poziom nie włącza trybu historycznego.**

Sprawdzenia są w UI, dispatcherze i punktach wejścia systemów, również dla zachowań autonomicznych. Ukrycie przycisku nie jest jedyną ochroną. Nieistniejący element ani podstawiony skrypt przekazany do handlera nie uruchomią mechaniki. Stare prostokąty klikania nie tworzą niewidocznych stacji. Ruchoma piłka jest trafiana w aktualnej pozycji.

Chowany wybiera tylko dostępne krzaki; usunięty krzak nie trafia do losowania. Zaproszenia nie proponują brakującej zabawy, automatyczne picie/odpoczynek i goście wymagają elementu. Kontrolery treningu, zabaw oraz opieki znikają lub blokują uruchomienie zgodnie z projektem. Dalsze sterowanie rozpoczętą czynnością (gest, pochwała, przerwanie) pozostaje w istniejącym UI.

Smakołyki, samopoczucie, plan dnia, album/zdjęcia i ustawienia pozostają globalne. Budzenie śpiącego psa pozostaje dostępne. Wygląd i ułożenie świata edytuje się w projekcie, nie w tych panelach.

## Rejestr i uruchamianie — sekcja 4.1 handoff

Dodano `training`, `touch_play`, `skill_play`, `bubble_play`, `outdoor_commands`, `potty`, `initiative`, `dig`, `garden`, `decor`, `yard_weather`. Rejestry JSON i JS zachowują parytet. `LevelActions` jest wspólnym dispatcherem używanym przez Main, skróty UI i LevelRoom. Parametry treningu obejmują sztuczkę i prowadzenie gestem; zabawy wybiera `kind` (lub `all`, aby udostępnić kategorię). `yard_weather.mode` przyjmuje `auto`, `sun`, `rain`, `after_rain`.

Podgląd Godota i test w przeglądarce reagują również na nowe skrypty; pełne mechaniki i ich dotykowe panele działają w głównej scenie gry. LevelRoom korzysta ze wspólnej kontroli i przekazuje dojście psa do sesji, zamiast przyznawać równocześnie efekt z podglądu. Nie zastępuje głównego UI.

Dekoracja z pustym `key` otwiera menu; element z konkretnym `key` jest jej edytowalnym przedstawieniem. Menu oferuje tylko warianty obecne w projekcie, a widoczność tych grafik odpowiada wyborom z istniejącego zapisu. W ver2 przygotowano `rug` i `shelf`; pozostałe zachowane odblokowania i wybory można wykorzystać, dodając kolejne elementy `decor`. Niewidoczna wyłączona dekoracja nie zostawia obszaru kliknięcia.

## Weryfikacja

- `node --test level-editor/tests/model.test.mjs`: **22/22** testy.
- `python3 tools/run_game_tests.py`: **47/47** zestawów logiki, w tym **42** sprawdzenia nowego `test_scene_authority.gd` i **8** loadera.
- Wymagane przez handoff: `test_level_project`, `test_room_layout_loader`, `ui_level_editor`, `ui_level_room` — przechodzą.
- Zrewidowany `ui_editor_art_quality` przechodzi: sprawdza rzeczywiście zapisane tekstury i granice elementów w obu poziomach, bez założenia dawnego automatycznego podmieniania grafik.
- Łącznie **9/9 wybranych zestawów UI**: `ui_level_editor`, `ui_level_room`, `ui_editor_art_quality`, `ui_scene_authority`, `ui_course`, `ui_timed_course`, `ui_water`, `ui_yard_rest`, `ui_home_friends`.
- Sześć ostatnich zestawów uruchomiono również z oknem macOS. Obejrzano zrzuty domu i ogrodu. Testy toru, wody i odpoczynku zostały przeniesione ze starych przycisków mapy na elementy edytora.

Testy używają odizolowanych zapisów. Poprawiono również dawny `ui_level_room`, który usuwał ustawienia muzyki/efektów z głównego `user://`.

Nie zmieniano `project.godot`, animatora, manifestu sprite’ów ani metod odczytu/zapisu GameSession. Dane Glorii i instalacja na iPhonie nie były modyfikowane. Fizyczny dotyk i nowy eksport iOS pozostają do sprawdzenia na urządzeniu; nie są potwierdzone testami macOS.
