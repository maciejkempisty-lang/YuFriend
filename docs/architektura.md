# Architektura YuFriend

[Mapa dokumentacji](README.md)

## Punkt wejścia i organizacja

[project.godot](../project.godot) uruchamia [Main.tscn](../scenes/Main.tscn). Scena zawiera główny `Control` ze skryptem [main.gd](../scripts/ui/main.gd). Interfejs, pokój, dialogi i obiekt sesji powstają w GDScripcie podczas uruchomienia; nie są osobnymi scenami do edycji w drzewie `Main.tscn`.

Projekt używa renderera Compatibility i bazowego obszaru 390 × 844. Okno pulpitu ma domyślnie 430 × 930. Skalowanie to `canvas_items` z aspektem `expand`. Nie ma autoloadów, bazy danych, backendu ani dodatkowego frameworka aplikacji.

`Main._fit_room()` układa pokój, nagłówek, wskaźniki potrzeb, aktywny panel i nawigację. Cały ekran nie przewija się; przewijany jest album. Szeroki układ przenosi sterowanie obok pokoju. `GameIcons` współdzieli własne ikony, `IconActionButton` rysuje akcje i nawigację, a `NeedIndicator` pokazuje poziomy potrzeb. Font Nunito jest dołączony wraz z licencją w `assets/fonts/`.

Pokój jest osobnym światem 2D w `SubViewport`, wyświetlanym przez `Sprite2D` pod HUD-em. `Camera2D` przesuwa tylko świat; zbliżenie realizuje całkowite powiększenie tekstury pokoju, a potrzeby, panele i komunikat pozostają w interfejsie. [RoomLayout](../scripts/model/room_layout.gd) określa wymiary 1440 × 360, płytki pas chodzenia oraz sześć stacji. Ich pozycje nie zmieniają się wraz z wielkością okna.

`RoomArtwork` składa panoramę z fragmentów istniejącego tła pixel art i osobnych przedmiotów. Tło ma zachowaną listę rysowania, przedmioty są oddzielnymi węzłami, a `actors.y_sort_enabled` ustawia kolejność psa i kosza/miski/piłki według głębokości. Legowisko i drzwi są nad tłem, lecz za postacią. [Opis zasobów](../assets/art/environments/README.md) wskazuje sposób składania grafiki.

```mermaid
flowchart TD
    Main["Main — interfejs i połączenia sygnałów"] --> Session["GameSession — przebieg sesji"]
    Main --> Room["RoomView — pokój i ruch"]
    Session --> State["PetState — trwałe dane psa"]
    Session --> Needs["NeedsSystem — potrzeby i czas"]
    Session --> Training["TrainingSystem — próby i nagrody"]
    Session --> Personality["PersonalitySystem — historia, dryf i nawyki"]
    Session --> Save["SaveSystem — zapis i odzyskiwanie"]
    Main --> Commands["LocalCommands — rozpoznawanie zwrotów"]
    Room --> Artwork["RoomArtwork — statyczne tło i osobne przedmioty"]
    Room --> Layout["RoomLayout — świat i stacje"]
    Room --> Camera["SubViewport + Camera2D — widok świata"]
    Room --> Animator["PetAnimator — pozycje i klipy"]
    Animator --> Skin["PetSkin / PetAnimationSet — grafika i klatki"]
    Session -. "żądanie ruchu lub animacji" .-> Room
    Room -. "dotarcie lub zakończenie próby" .-> Session
```

## Odpowiedzialności modułów

| Moduł | Rola |
|---|---|
| [PetState](../scripts/model/pet_state.gd) | Tożsamość, cechy, potrzeby, komendy, relacja, dziennik oraz serializacja i walidacja |
| [GameSession](../scripts/systems/game_session.gd) | Łączy systemy; przyjmuje działania gracza, blokuje nakładające się czynności, steruje zegarami i zapisem |
| [NeedsSystem](../scripts/systems/needs_system.gd) | Zmiany potrzeb i zmęczenia w czasie oraz jednorazowe efekty działań |
| [TrainingSystem](../scripts/systems/training_system.gd) | Warunki rozpoczęcia, wynik próby, czas nagrody i naliczanie postępu |
| [PersonalitySystem](../scripts/systems/personality_system.gd) | Dziennik zdarzeń, dryf cech, nawyki i sprawdzanie propozycji zmian osobowości |
| [SaveSystem](../scripts/systems/save_system.gd) | Odczyt, walidowany zapis do pliku tymczasowego i odzyskiwanie kopii |
| [LocalCommands](../scripts/services/local_commands.gd) | Normalizuje wpisany tekst i zwraca identyfikator istniejącej komendy |
| [RoomView](../scripts/ui/room_view.gd) | Tworzy świat i kamerę, odróżnia tapnięcie od przesuwania, przelicza ekran/świat, prowadzi ruch i zbliżenia |
| [RoomLayout](../scripts/model/room_layout.gd) | Stałe współrzędne, granice ruchu i definicje stacji: miejsce, punkt dojścia, klip, potrzeba oraz efekty |
| [RoomArtwork](../scripts/ui/room_artwork.gd) | Zachowuje statyczne listy rysowania tła i przedmiotów; osobne instancje obsługują cień i piłkę |
| [PetAnimator](../scripts/pet/pet_animator.gd) | Dobiera przejścia między pozycjami i odtwarza klipy lub zastępcze ilustracje |
| [PetSkin](../scripts/pet/pet_skin.gd), [PetAnimationSet](../scripts/pet/pet_animation_set.gd) | Zasoby wyglądu, klatek, skali i punktu podparcia |
| [SpriteImporter](../scripts/pet/sprite_importer.gd) | Waliduje manifest i buduje zasób z PNG lub fragmentów arkusza |

`PetState`, systemy potrzeb, treningu i zapisu są obiektami `RefCounted`. Nie potrzebują interfejsu do sprawdzenia reguł. `GameSession` jest węzłem aktualizowanym przez `_process(delta)`, `RoomView` to `Control`, a `PetAnimator` to `Node2D` z `AnimatedSprite2D`.

## Przebieg uruchomienia

1. `Main` buduje interfejs i łączy sygnały sesji z pokojem.
2. Wybiera ścieżkę zapisu: normalną, `--qa` lub nadpisaną przez test.
3. `GameSession.start()` wczytuje psa i ustala, czy zapis jest dostępny do modyfikacji.
4. `NeedsSystem.catch_up()` przelicza nieobecność.
5. Jeśli pies nadal odpoczywa po przeliczeniu nieobecności, sesja umieszcza go w legowisku i zleca sen.
6. Sesja próbuje zapisać stan i odświeża interfejs; `RoomView` używa jednego produkcyjnego pakietu pixel art również dla dawnych zapisów.

Zegary czynności, animacji i próby treningowej nie są wczytywane z dysku. Po restarcie wraca stan psa, a nowa próba musi zostać rozpoczęta od początku.

## Umowa między sesją i widokiem

Połączenia są tworzone w `Main._ready()`.

| Sygnał | Odbiorca i znaczenie |
|---|---|
| `GameSession.changed` | `Main._refresh()` odświeża dane i dostępność przycisków |
| `feedback(text)` | Aktualizuje komunikat dla gracza |
| `save_status(ok)` | Odświeża informację o zapisie |
| `clip_requested(clip)` | `RoomView.play_clip()` uruchamia zwykłą reakcję lub pozycję |
| `destination_requested(world_position)` | `RoomView.move_to()` ustawia cel `Vector2` we współrzędnych świata |
| `approach_requested(action, token)` | Widok ustawia drogę do miski, legowiska lub piłki; nie przyznaje efektów |
| `RoomView.station_reached(token)` | Sesja przyjmuje tylko aktualne dojście i jednorazowo wykonuje opiekę lub sygnalizuje potrzebę |
| `attention_requested(close_up)` | Przywraca śledzenie psa, opcjonalnie z krótkim zbliżeniem |
| `activity_cancelled` | Widok zatrzymuje ruch i usuwa poprzedni cel |
| `place_requested(action)` | Odtworzenie położenia w legowisku po wczytaniu / wznowieniu |
| `performance_requested(clip, trial_id)` | `RoomView.play_performance()` rozpoczyna prezentację konkretnej próby |
| `RoomView.floor_tapped(world_position)` | `GameSession.move_to()` sprawdza możliwość ruchu |
| `RoomView.care_requested(action)` | Akcja opieki po dotknięciu psa, miski, piłki lub legowiska; nadal podlega regułom `GameSession.act()` |
| `destination_reached` | Kończy zwykłe chodzenie w sesji |
| `performance_finished(trial_id)` | Zgłasza ukończenie prezentacji próby do sesji |

Cele ruchu to `Vector2` we współrzędnych świata. `RoomLayout.clamp_walk()` ogranicza je do prostokąta od (95, 286) do (1345, 328). Podstawowy chód ma 38,4 jednostki świata na sekundę (12,8 piksela logicznego). Klip gra w oryginalnym tempie 1×, także przy podążaniu za piłką. Szybszy pościg wymaga osobnego klipu biegu i pomiaru długości kroku. Ruch zaczyna się dopiero po przejściu animatora do `walk`. Dla „przyjdź” widok wyznacza cel około 150 jednostek od obecnego położenia, zamiast dawnego ułamka szerokości ekranu.

## Synchronizacja treningu

`TrainingSystem` ustala wynik i minimalny czas reakcji. `GameSession` rozpoczyna próbę z `performance_done = false`. Pokój potwierdza zakończenie sztuczki; dla „przyjdź” czeka również na dotarcie do celu. Dopiero potwierdzenie i upływ czasu reakcji pozwalają otworzyć okno nagrody.

Każda próba ma `trial_id`. `performance_finished()` uznaje tylko aktualny identyfikator, fazę `attempt` i aktywną sesję. Anulowanie zmienia identyfikator, więc spóźnione potwierdzenie poprzedniej próby nie przyznaje nagrody.

```mermaid
sequenceDiagram
    participant UI as Main
    participant S as GameSession
    participant T as TrainingSystem
    participant R as RoomView i PetAnimator
    UI->>S: begin_training(key, guided)
    S->>T: begin(pet, key, guided)
    T-->>S: akceptacja lub powód odmowy
    S->>R: performance_requested(clip, trial_id)
    R-->>S: performance_finished(trial_id)
    S->>T: advance(delta, performance_done)
    T-->>S: ready po spełnieniu warunków
    S-->>UI: changed i komunikat o nagrodzie
    UI->>S: give_reward(kind)
    S->>T: reward(pet, kind)
    S->>S: zapis i reakcja radości
```

Schemat pokazuje udaną próbę. Odmowa lub niewykonanie komendy kończą się komunikatem bez przejścia do nagrody. Reguły faz i obliczeń opisują [mechaniki gry](mechaniki-gry.md).

## Animacje i stan wizualny

Animator rozróżnia pozycje `stand`, `sit`, `lie`, `sleep` i `eat`. Każdy z 22 klipów ma jawną pozycję początkową i końcową. Przykładowo podanie łapy w staniu wymaga najpierw `sit_down`; przejście ze snu do chodu wymaga `wake_up` i `get_up`.

W danym momencie oczekuje jedno żądanie klipu. Kolejne żądanie zastępuje oczekujące, a trwający klip jednorazowy kończy się przed zmianą. Dla klipu jednorazowego `request_completed(id)` oznacza zakończenie; dla pętli — wejście do niej po przejściach. Pokój dodaje osobny warunek dotarcia przy przywołaniu.

Czas dostarczonego klipu jednorazowego to suma mnożników czasu klatek podzielona przez FPS. Brak klipu uruchamia grafikę zastępczą z czasem z `PetAnimator.CLIPS`. Ręczne `PetSkin.frames` ma pierwszeństwo przed pakietem wskazanym przez `animation_pack_path`. `PetAnimationSet.clip_layouts` przenosi skalę klipów i punkty podparcia poszczególnych klatek. Regiony `AtlasTexture` pozwalają użyć dostarczonych nierównych pól bez przerysowania PNG. Filtr alfa w skórce działa wyłącznie podczas renderowania. [Integracja sprite’ów](integracja-spriteow.md) opisuje format wejściowy.

`GameSession.pose` opisuje pozycję oczekiwaną przez rozgrywkę. `PetAnimator.pose` opisuje pozycję osiągniętą po zakończeniu przejścia. Nie należy traktować ich jako zawsze identycznych w trakcie animacji.

## Cykl życia aplikacji

Zamknięcie okna wywołuje zapis, a następnie kończy grę. Utrata fokusu na pulpicie wywołuje zapis, lecz sama nie wstrzymuje symulacji. Powiadomienie o wstrzymaniu aplikacji anuluje próbę i token niedokończonego dojścia, zatrzymuje ruch oraz aktualizację sesji, a następnie zapisuje stan. Wznowienie przelicza nieobecność i odtwarza pozycję odpoczynku lub stania.

Przy rozbudowie reguły opieki i treningu powinny pozostać w systemach, a interfejs powinien wywoływać metody sesji. Zmiana grafiki nie powinna bezpośrednio zwiększać umiejętności ani przepisywać danych psa.

## Opieka w pokoju i kamera

Sesja zleca dojście z tokenem. `RoomView` odczytuje punkt stacji z `RoomLayout`; dojście uruchamia efekt opieki w sesji. Pozycja piłki jest zmienna, pozostałe stacje mają stałe współrzędne. Przy podmianie grafiki można zachować ich kontrakt z logiką.

Obszar wyświetlania zaczyna się 16 jednostek poniżej wiersza potrzeb (w szerokim układzie HUD jest obok). Pokój kończy się nad dymkiem i panelem. Świat ma 480 × 120 pikseli logicznych (1 piksel = 3 jednostki świata). Kamera łagodnie śledzi psa, a jej początek widoku jest przyciągany do siatki. `Camera2D.zoom` pozostaje 1; zbliżenie 2× zwiększa całkowite powiększenie gotowej tekstury i zmniejsza widoczny fragment świata. Przy za małej wysokości pozostaje widok podstawowy, aby nie uciąć psa. Rozmiar i pozycja `Sprite2D` uwzględniają transformację końcową viewportu oraz `canvas_items`, dzięki czemu piksele nie stają się nierówne po zmianie rozmiaru okna. `Sprite2D` omija zaokrąglanie pozycji kontrolek przed skalowaniem UI. Transformacja korzysta z [metod Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-get-final-transform). Pozostałe miejsce wypełnia kolor ściany. Głaskanie utrzymuje zbliżenie przez 3,5 sekundy; trening przez próbę, okno nagrody i reakcję na nią. Granice kamery zapobiegają odsłanianiu pustki poza pokojem.

Dotknięcie jest rozpoznawane po puszczeniu palca. Ruch o co najmniej 9 jednostek uruchamia przesuwanie widoku i wyklucza akcję dotknięcia. Ręcznie ustawiona kamera pozostaje na miejscu do użycia „Do pieska” lub rozpoczęcia nowej czynności. `world_to_screen()` i `screen_to_world()` obsługują wszystkie strefy kliknięcia po panoramowaniu i zoomie. Maski alfa psa powstają dopiero przy dotknięciu danej klatki; na pierwszym planie pierwszeństwo mają piłka i przedmioty zasłaniające psa.

Zmiana rozmiaru okna przelicza wyłącznie widok i kamerę — nie pozycje psa i przedmiotów. `RoomArtwork.draw_count` sprawdza, że chód nie przebudowuje tła. Zmiana rozmiaru viewportu może jednorazowo odświeżyć listę. To kontrola listy rysowania na CPU, a nie pomiar baterii lub wydajności GPU na telefonie.
