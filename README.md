# YuFriend

Grywalny prototyp opieki nad szczeniakiem golden retrievera w Godocie. Pionowy interfejs, jeden pokój, trwały temperament i nauka trzech komend. Działa lokalnie, bez konta, internetu i klucza API.

## Dokumentacja

[Mapa dokumentacji projektu](docs/README.md) prowadzi przez opis gry, architekturę, mechaniki, model danych, testy i plan rozwoju. Szybkie uruchomienie jest poniżej, a materiały dla grafika znajdują się w [liście sprite’ów](docs/lista-spriteow-szczeniaka.md) oraz [instrukcji integracji](docs/integracja-spriteow.md).

## Uruchomienie

Projekt sprawdzono w Godot **4.7.2**, renderer **Compatibility**, na macOS. Otwórz `project.godot` w Godocie i wybierz **Uruchom projekt (F5)**. Możesz też uruchomić grę bez edytora:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --path '/Volumes/Samsung SSD/YuFriend'
```

## Co można zrobić

- Kliknij podłogę, aby pies podszedł w wybrane miejsce. Sam również czasem spaceruje.
- W **Opiece** nakarm, pogłaszcz, pobaw się, wyczesz lub połóż pieska do odpoczynku.
- W **Treningu** wybierz „Siad”, użyj „Pokaż gest”, zaczekaj na wykonanie i wybierz nagrodę, gdy pojawi się odliczanie. Nagroda zwiększa opanowanie komendy i więź. „Poproś samodzielnie” sprawdza, czy pies już pamięta.
- Po osiągnięciu **25% siadu** odblokuje się „Podaj łapę”. „Przyjdź” jest dostępne od początku. Zmęczenie, głód i odpoczynek wpływają na gotowość do ćwiczeń.
- Przycisk **Wpisz komendę** rozpoznaje kilka polskich zwrotów, np. „usiądź” i „daj łapę”. To lokalny słownik komend.
- W **Profilu** zmienisz imię i przełączysz prostą ilustrację / pixel art. **Wspomnienia** pokazują zdarzenia, które faktycznie zaszły w grze.

Ciekawość wpływa na spontaniczne spacery, cierpliwość na czas reakcji i nagrody, towarzyskość na potrzebę kontaktu, a wrażliwość na rozproszenie podczas zmęczenia. Każdy pies ma zapisaną preferowaną nagrodę. Temperament pozostaje ten sam po ponownym uruchomieniu.

## Grafika i sprite’y

Na razie używamy istniejących ilustracji jako zastępników. Oddech i kołysanie są prostymi ruchami całego obrazka; podawanie łapy, machanie ogonem, jedzenie i sen czekają na właściwe klatki. Siedzenie korzysta jeszcze z referencji od przodu, a stanie z boku.

Gotowa obsługa `AnimatedSprite2D` obejmuje 22 nazwy klipów, przejścia między pozycjami, odbicie lewo/prawo i indywidualny czas klatek. Nagroda czeka na zakończenie sztuczki lub dotarcie do celu. Można dostarczać animacje partiami.

- [Lista wymaganych sprite’ów](docs/lista-spriteow-szczeniaka.md)
- [Instrukcja wgrania sprite’ów i format manifestu](docs/integracja-spriteow.md)
- Foldery PNG: `assets/sprites/puppy/simple/` i `assets/sprites/puppy/pixel/`

## Zapis

Stan trafia do `user://pet.json`, a poprzedni poprawny zapis do `user://pet.json.bak`. Na macOS standardowy katalog Godota dla tego projektu to `~/Library/Application Support/Godot/app_userdata/YuFriend/`. Można go otworzyć przez **Projekt → Otwórz folder danych użytkownika** w edytorze.

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
| `data/skins/` | Konfiguracja ilustracji i pixel art |
| `assets/art/reference/` | Dotychczasowe wzorce szczeniaka i prompty |
| `tests/` | Testy logiki, sprite’ów i interfejsu |

## Sprawdzenie projektu

Weryfikacja 10 listopada 2026: **87 sprawdzeń zakończonych powodzeniem** — 44 logiki i zapisu, 26 importu i animacji oraz 17 przepływu przez interfejs. Zrzuty ekranu obejrzano także wizualnie, w tym profil, trening i układ na wąskim ekranie.

Przy pierwszym otwarciu lub po dodaniu PNG poczekaj, aż Godot zaimportuje zasoby. Import można wykonać także bez okna:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path '/Volumes/Samsung SSD/YuFriend' --editor --quit
```

Testy uruchamiane z katalogu projektu:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_runner.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tests/test_sprites.gd
'/Applications/Godot.app/Contents/MacOS/Godot' --path . --script res://tests/ui_smoke.gd
```

Ostatni test otwiera okno, sprawdza przepływ opieki i treningu oraz zapisuje zrzuty do `test-results/`. Obejmuje szerokości 360, 390 i 540 punktów. To test pulpitu; obsługa dotyku i cykl życia na fizycznym telefonie wymagają osobnego sprawdzenia po eksporcie.

## Kolejne etapy

1. Podpięcie pakietu A klatek i dopasowanie prędkości chodu, skali oraz punktu podparcia do grafiki.
2. Pakiet B, dopasowanie pyska do miski, przedmioty opieki i dźwięki.
3. Test użyteczności i balansu kilku krótkich sesji; eksport oraz sprawdzenie na telefonie.
4. Opcjonalny backend AI, bogatsze zachowania i kolejne etapy wieku.

Obecna gra nie korzysta z płatnego API i nie generuje kosztów wywołań modeli. Pole `life_stage` jest przygotowane, ale dorastanie jeszcze nie działa. Szczegółowy zakres późniejszych prac opisuje [plan implementacji](docs/plan-implementacji.md).
