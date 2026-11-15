# YuFriend

Grywalny prototyp opieki nad szczeniakiem golden retrievera w Godocie. Jeden pokój, temperament kształtowany przez wspólne rytuały i nauka trzech komend. Działa lokalnie, bez konta, internetu i klucza API.

Pokój wypełnia wysokość ekranu, a interfejs pływa nad nim. W widoku 390 × 844 około 75% wysokości znajduje się nad panelem opieki. Jeden rząd pięciu przycisków łączy akcję, obwódkę potrzeby i widoczny procent. U góry są imię otwierające kartę psa, pasek więzi i osobne ustawienia. Stała nawigacja **Dom / Trening / Album** pozostaje przy dolnej krawędzi bezpiecznego obszaru; szerokie okno ma sterowanie z boku.

<p>
  <img src="docs/images/interfejs-dom.png" width="260" alt="YuFriend — pokój i opieka nad pieskiem">
  <img src="docs/images/interfejs-trening.png" width="260" alt="YuFriend — trening i okno nagrody">
</p>

Zrzuty z wersji komputerowej, wykonane na syntetycznym zapisie testowym.

## Dokumentacja

[Mapa dokumentacji projektu](docs/README.md) prowadzi przez opis gry, architekturę, mechaniki, model danych, testy i plan rozwoju. Szybkie uruchomienie jest poniżej, a materiały dla grafika znajdują się w [liście sprite’ów](docs/lista-spriteow-szczeniaka.md) oraz [instrukcji integracji](docs/integracja-spriteow.md).

## Uruchomienie

Projekt sprawdzono w Godot **4.7.2**, renderer **Compatibility**, na macOS. Otwórz `project.godot` w Godocie i wybierz **Uruchom projekt (F5)**. Możesz też uruchomić grę bez edytora:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --path '/Volumes/Samsung SSD/YuFriend'
```

## Co można zrobić

- Przesuń pokój palcem lub przeciągnij myszą, aby obejrzeć jego dalszą część. „Do pieska” przywraca śledzenie; głaskanie i trening przybliżają kamerę.
- Dotknij pieska, aby go pogłaskać. Pies podchodzi do miski przed jedzeniem, do legowiska przed snem i goni toczącą się piłkę. Dotknięcie wolnej podłogi wskazuje cel spaceru.
- Pies sam pokazuje głód i nudę, a zmęczony idzie spać. Budzi się po odzyskaniu energii, także podczas przeliczania nieobecności. Kolejne głaskanie reaguje od razu; tylko przyrosty potrzeb i więzi mają 4 sekundy przerwy.
- W zakładce **Dom** te same czynności oraz czesanie są dostępne jako podpisane ikony. Potrzeby mają trzy kolory: poniżej 30%, 30–59% i od 60%. Niska potrzeba zmienia też podpis, np. na „Głodny”. Czas oczekiwania pokazują ubywające wypełnienie i sekundy; dotknięcie nadal wyjaśnia sytuację.
- W **Treningu** wybierz „Siad” i tryb „Z podpowiedzią” lub „Bez podpowiedzi”. Ikony prowadzą przez gest/komendę, czekanie i nagrodę. Po wykonaniu ruchu nagródź psa, zanim zniknie obwódka nagród. Ulubiona nagroda jest wyróżniona dopiero po odkryciu jej podczas udanej próby.
- Po osiągnięciu **25% siadu** odblokuje się „Podaj łapę”. „Przyjdź” jest dostępne od początku. Zmęczenie, głód i odpoczynek wpływają na gotowość do ćwiczeń.
- Ikona **klawiatury** w treningu pozwala wpisać polski zwrot, np. „usiądź” i „daj łapę”. To lokalny słownik komend.
- Dotknięcie **imienia** otwiera kartę psa z paskami cech, odznakami nawyków i zmianą imienia. **Zębatka** otwiera osobne ustawienia muzyki i efektów; zmiany zapisują się od razu. **Album** jest pełnoekranową kartą z różnymi ikonami zdarzeń.
- Po opiece pojawia się faktyczny przyrost, np. „+22 Sytość”. Dymek podąża za psem i znika po kilku sekundach. Przedmioty mają większe pola dotyku i krótko podskakują; wskazówka przesuwania znika po pierwszym przeciągnięciu, również po ponownym uruchomieniu.

Ciekawość wpływa na spontaniczne spacery, cierpliwość na czas reakcji i nagrody, towarzyskość na potrzebę kontaktu, a wrażliwość na rozproszenie podczas zmęczenia. Zdarzenia z ukończonych dni powodują niewielki dryf cech i powstawanie nawyków, widocznych w Profilu i zachowaniu psa. Powrót po nieobecności nie usuwa nawyków. Dane są zachowywane po ponownym uruchomieniu; preferowana nagroda pozostaje stała. Reguły i ograniczenia opisuje [osobowość i nawyki](docs/osobowosc.md).

## Własne życie psa

Pies ma dwa albo trzy stałe dziwactwa z puli dwunastu, odkrywane podczas wspólnych chwil i w opowieściach po powrocie. Karta psa pokazuje odkrycia oraz jeszcze nieznane cechy. Pięć nastrojów dnia wpływa na tempo chodzenia i spontaniczne zachowania; nowy nastrój wynika rano z temperamentu i wczorajszych działań.

Po co najmniej 30 minutach nieobecności pojawia się krótka relacja „Kiedy Cię nie było”, zachowana także w Albumie. Powitanie odróżnia godzinę od trzech dni. Nowy system nie obniża więzi ani umiejętności za nieobecność. To lokalna symulacja tekstowa na obecnych animacjach; [zasady, progi i ograniczenia](docs/osobowosc.md#własne-życie--etap-1-15-listopada-2026).

## Inicjatywa i zabawy dotykiem

Gloria sama zaprasza do piłki, liny, szukania smakołyka albo bliskości. Możesz odpowiedzieć, wybrać „Później” lub zająć się czymś innym. Zapamiętuje reakcje i częściej proponuje lubiane aktywności; karta psa pokazuje **Wasz rytm**. Odmowa nie zmniejsza więzi.

Wybierz **Pobaw się**: przeciągnij piłkę i puść, pociągaj węzeł liny naprzemiennie w obie strony albo śledź smakołyk pod mieszanymi kubkami. Działa dotyk i mysz. [Sterowanie i zasady nagród](docs/mechaniki-gry.md#zabawy-dotykiem).

## Grafika i sprite’y

Gra korzysta z dostarczonego pakietu **22 klipów / 142 klatek** w stylu pixel art. Pies mruga, chodzi, siada, podaje łapę, macha ogonem, reaguje na głaskanie, je i śpi. Arkusze są podłączone z zachowaniem ich kolejności i czasów; kalibracja wyrównuje rozmiar sylwetki i linię podparcia. Wybrane poprawki `sleep` i `eat_loop` są uwzględnione.

Pixel art obowiązuje również dla starszych zapisów z `skin: simple`, bez zmiany tożsamości ani postępów. Usunięto przełącznik stylu, metodę `change_skin` i nieużywaną skórkę ilustracyjną. Pole `skin` pozostaje wyłącznie dla zgodności istniejących zapisów; produkcyjna skórka nie odwołuje się już do dawnych obrazów zastępczych. Duże arkusze nadal mają drobne różnice proporcji i nie są równą siatką 64 × 64. [Opis dostawy i uwagi jakościowe](assets/sprites/puppy/pixel/README.md) wskazuje pozostałe poprawki.

Gotowa obsługa `AnimatedSprite2D` obejmuje 22 nazwy klipów, przejścia między pozycjami, odbicie lewo/prawo i indywidualny czas klatek. Nagroda czeka na zakończenie sztuczki lub dotarcie do celu. Można dostarczać animacje partiami.

- [Lista wymaganych sprite’ów](docs/lista-spriteow-szczeniaka.md)
- [Instrukcja wgrania sprite’ów i format manifestu](docs/integracja-spriteow.md)
- PNG i manifest produkcyjny: `assets/sprites/puppy/pixel/`
- [Tło pokoju i prompt](assets/art/environments/README.md)

## Dźwięk

Muzyka z dostarczonego `video2.mp4` gra cicho w pętli. Pakiet 22 efektów ElevenLabs obejmuje szczeknięcia, kroki, jedzenie, głaskanie z piskiem radości, czesanie, piłkę i trening. 19 nagrań jest używanych teraz; trzy odbicia czekają na odpowiednią animację. Muzykę i efekty wyciszysz osobno w Ustawieniach pod zębatką. Odtwarzanie jest lokalne, bez API. [Źródła, przygotowanie i zakres weryfikacji audio](assets/audio/sfx/README.md).

## Szeroki pokój

Jeden świat 1440 × 360 ma dwa ręcznie wybierane kadry: widok pośredni śledzący psa i „Cały pokój”, pokazujący wszystkie stacje. Dotknięcie panoramy przybliża wybrane miejsce, a „Do pieska” przywraca śledzenie. Domyślny kadr pośredni dopasowuje skalę do szerokości: na sprawdzonych ekranach telefonu pokazuje 480–648 jednostek z 1440, czyli około ⅓–½ pokoju. Przy początkowej pozycji psa widać także miskę i piłkę. Ma sześć stacji: legowisko, miskę, piłkę, kosz z zabawkami, okno i drzwi. Pies porusza się w płytkim pasie podłogi; przedmioty mogą zasłaniać go od przodu, a interfejs pozostaje nieruchomy. Po ręcznym przesunięciu kamera czeka na „Do pieska” lub nową czynność. Pokój zachowuje siatkę 3 jednostek świata na piksel logiczny, a podłoga jest przedłużona za pływającymi panelami. Dodatkowe zbliżenie 2× działa tylko wtedy, gdy szerokość i wysokość mieszczą całego psa; wynik jest powiększany wyłącznie całkowitą liczbę razy, niezależnie od skalowania UI.

![Cały pokój — podgląd świata bez interfejsu](docs/images/pokoj-panorama.png)

## Zapis

Stan trafia do `user://pet.json`, a poprzedni poprawny zapis do `user://pet.json.bak`. Na macOS standardowy katalog Godota dla tego projektu to `~/Library/Application Support/Godot/app_userdata/YuFriend/`. Można go otworzyć przez **Projekt → Otwórz folder danych użytkownika** w edytorze.

Format zapisu ma wersję 4. Wersja 3 otrzymuje pustą pamięć reakcji i liczniki zabaw, zachowując psa, postęp oraz `life`; oryginał zostaje w `pet.json.v3`. Wersja 2 otrzymuje deterministyczne dziwactwa, stan odkryć, nastrój i relację z nieobecności; oryginał zostaje w `pet.json.v2`. Odczyt wersji 1 zachowuje psa i postęp, uzupełnia nowe pola osobowości i zabezpiecza oryginał w `pet.json.v1`. Dotyczy to również odzyskiwania ze starszej kopii `.bak`. Jeżeli `.v1` jest cudzym lub nieprawidłowym zapisem, gra zachowuje go i tworzy własną kopię `.v1.<SHA-256 źródła>`; ten konflikt nie blokuje gry. Rzeczywisty błąd utworzenia lub sprawdzenia kopii nadal chroni oryginał przed nadpisaniem.

Zapis następuje po istotnych działaniach, okresowo i przy zamykaniu/wstrzymaniu. Uszkodzony główny plik jest odzyskiwany z poprawnej kopii. Nierozpoznanej nowszej wersji ani dwóch uszkodzonych plików gra nie nadpisuje: pokazuje komunikat i blokuje dalsze zmiany. Nieobecność jest liczona maksymalnie jako 8 godzin, potrzeby mają łagodną dolną granicę, a wyuczone komendy pozostają zachowane.

Nie uruchamiaj równolegle dwóch zwykłych instancji na tym samym zapisie. Do podglądu z osobnym stanem służy parametr `-- --qa`; testy używają własnych katalogów i usuwają swoje dane po zakończeniu.

## Struktura

| Miejsce | Odpowiedzialność |
|---|---|
| `scenes/Main.tscn`, `scripts/ui/` | Interfejs, rysowany pokój i ruch po scenie |
| `scripts/model/pet_state.gd` | Tożsamość, cechy, potrzeby, komendy, wspomnienia i walidacja danych |
| `scripts/systems/` | Opieka, trening, zapis i przebieg sesji |
| `scripts/pet/` | Wygląd, przejścia animacji i import klatek |
| `scripts/services/local_commands.gd` | Lokalne rozpoznawanie poleceń tekstowych |
| `data/skins/`, `data/animations/` | Konfiguracja pixel art i kompletny pakiet animacji; dawna ilustracja zachowana jako materiał referencyjny |
| `assets/art/reference/` | Dotychczasowe wzorce szczeniaka i prompty |
| `tests/` | Testy logiki, sprite’ów i interfejsu |

## Sprawdzenie projektu

Korekta kadru i albumu, 15 listopada 2026: **531/531 sprawdzeń** (113 logiki/zapisu, 46 życia, 61 zabaw, 38 animacji, 33 audio, 214 UI, 26 UI zabaw). Domyślny widok jest szerszy, a album zachowuje 10 ostatnich relacji obok trwałych wspomnień, również po wczytaniu starego v4. Wersję **0.1.0 (7)** zbudowano, podpisano, zainstalowano i uruchomiono na iPhonie 15 Pro Max. [Zrzut z urządzenia](docs/images/interfejs-dom.png) potwierdza widoczność psa, miski i piłki; porównanie zapisów potwierdza zachowanie Glorii i postępów. Ocena wygody gestów pozostaje próbą użytkownika.

Poprawki po audycie, 15 listopada 2026: **524/524 sprawdzenia** w siedmiu zestawach (112 logiki/zapisu, 46 życia psa, 61 inicjatywy/zabaw, 38 animacji, 33 audio, 208 UI i 26 UI zabaw). Album chroni trwałe wspomnienia, nieobecność nie odkrywa dziwactw, zaproszenia są rzadsze i neutralnie reagują na inną opiekę, teksty pasują też do suczki, a senność ma równą wagę temperamentu. [Widok całego pokoju](docs/images/pokoj-caly.png) sprawdzono w 390 × 844, 320 × 640 i 1080 × 2340; dotknięcie miejsca i powrót do psa są objęte testami. Fizycznego iPhone’a nie użyto do weryfikacji tych poprawek. Wspomnienia usunięte przez wcześniejszą wersję nie są automatycznie odtwarzane.

Wcześniejsza weryfikacja 15 listopada 2026: **467 sprawdzeń zakończonych powodzeniem** — 111 logiki, osobowości i zapisu, 38 importu i animacji, 42 życia psa, 58 inicjatywy i zabaw, 192 dotychczasowego interfejsu oraz 26 nowych zabaw w UI. Nowe testy obejmują pamięć reakcji, migrację v3, anulowanie gestów, pościg za rzuconą piłką, linę i śledzenie kubków. Zestawy obejmują również naliczanie faktycznych przyrostów, odkrycie ulubionej nagrody, jednorazową wskazówkę, oddzielne ustawienia, pełny album, dotyk w pokoju, powroty i różne rozmiary ekranu. Obejrzano zrzuty z układu pionowego, wąskiego i poziomego. Bezpieczne marginesy sprawdzono również z symulowanym wycięciem, paskiem gestów i ułamkowym skalowaniem 1080 × 2340. Ten przebudowany interfejs wymaga jeszcze sprawdzenia na fizycznym iPhonie.

Przy pierwszym otwarciu lub po dodaniu PNG poczekaj, aż Godot zaimportuje zasoby. Import można wykonać także bez okna:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path '/Volumes/Samsung SSD/YuFriend' --editor --quit
```

Testy uruchamiane z katalogu projektu:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_runner.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_sprites.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_life.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_play.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --path . --script res://tests/ui_smoke.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --path . --script res://tests/ui_play.gd
```

Dwa ostatnie testy otwierają okno i zapisują zrzuty do `test-results/`. Obejmuje układy 360 × 800, 390 × 844 i 540 × 960 oraz rzeczywiste skalowanie okien 320 × 640, 1100 × 720 i 1080 × 2340. To test pulpitu; obsługa dotyku i cykl życia na fizycznym telefonie wymagają osobnego sprawdzenia po eksporcie.

## Kolejne etapy

1. Test użyteczności i balansu kilku krótkich sesji; eksport oraz sprawdzenie na telefonie.
2. Dopracowanie proporcji na styku klipów oraz docelowej siatki pixel art.
3. Dopasowanie pyska do miski, przedmioty opieki i odsłuch balansu dźwięków.
4. Opcjonalny backend AI, bogatsze zachowania i kolejne etapy wieku.

Obecna gra nie korzysta z płatnego API i nie generuje kosztów wywołań modeli. Pole `life_stage` jest przygotowane, ale dorastanie jeszcze nie działa. Szczegółowy zakres późniejszych prac opisuje [plan implementacji](docs/plan-implementacji.md).

Pierwsza instalacja na fizycznym iPhonie: 15 listopada 2026, testowy pies **Gloria**. [Instrukcja i zakres weryfikacji iOS](docs/test-ios.md).
