# YuFriend

Grywalny prototyp opieki nad szczeniakiem golden retrievera w Godocie. Dom, podwórko, kąpiel, temperament kształtowany przez wspólne rytuały i dziewięć sztuczek. Działa lokalnie, bez konta, internetu i klucza API.

Pokój wypełnia wysokość ekranu, a interfejs pływa nad nim. W widoku 390 × 844 około 75% wysokości znajduje się nad panelem opieki. Jeden rząd pięciu przycisków łączy akcję, obwódkę potrzeby i widoczny procent. U góry są imię otwierające kartę psa, pasek więzi i osobne ustawienia. Stała nawigacja **Dom / Trening / Album** pozostaje przy dolnej krawędzi bezpiecznego obszaru; szerokie okno ma sterowanie z boku.

<p>
  <img src="docs/images/interfejs-dom.png" width="260" alt="YuFriend — pokój i opieka nad pieskiem">
  <img src="docs/images/interfejs-trening.png" width="260" alt="YuFriend — trening i okno nagrody">
</p>

Zrzuty z wersji komputerowej, wykonane na syntetycznym zapisie testowym.

## Aktualny stan — 17 listopada 2026

W buildzie **28**, zainstalowanym i uruchomionym na iPhonie, dodano [odpoczynek na podwórku](docs/odpoczynek-na-podworku.md): legowisko w cieniu, wodę z animacją picia i samodzielne przerwy po zabawie. Bez wskaźnika pragnienia, bez zmiany schematu v15. Pełne 29 zestawów logiki i 23 interfejsu przechodzą; kopia zapisu Glorii zachowuje 29/29 pól. Po uruchomieniu na telefonie zmieniły się tylko potrzeby i czas zapisu; postępy Glorii zachowano.

Build **27** z [małym torem przeszkód](docs/tor-przeszkod.md), animacją skoku i „Zostań” na podeście zainstalowano i uruchomiono na iPhonie. Pochwała zalicza istniejący trening, a pierwsza meta zostawia pamiątkę. Schemat nadal v15; odczyt telefonu potwierdził zachowanie postępów Glorii.

Projekt przeniesiono na `/Volumes/KINGSTON/YuFriend` z historią Git, lokalnymi zmianami i kopiami zapisów.

Lokalne rozszerzenie żywego podwórka dodaje ślimaka i wiewiórkę: razem cztery gatunki tła, najwyżej dwa zwierzęta naraz, plus ptak za oknem w pokoju. Wiewiórka przebiega po niższej belce płotu, poniżej przycisków miejsc; ślimak pełznie przy brzegu trawy. Zwierzęta ustępują działaniu gracza bez blokady i bez zapisu postępów. Sprawdzono 318 warunków w pięciu zestawach testów oraz zrzuty 320/390 px. Rozszerzenie jest również zawarte w zainstalowanym buildzie 28.

Build **26** z [pogodą i zaproszeniami na podwórku](docs/pogoda-i-zaproszenia.md) zainstalowano i uruchomiono na iPhonie: słońce, deszcz i dzień po deszczu, podlewanie przez deszcz oraz opcjonalne propozycje wody, aportu i chowanego. Schemat nadal v15; odczyt telefonu potwierdził zachowanie postępów Glorii.

Kod po buildzie 24 dodaje małe zdarzenia tła: motyla nad grządką, wróbla na trawie i ptaka za oknem. Zwierzęta ustępują zabawie, nie dodają zadań, liczników ani wpisów w Albumie. Pakiet zainstalowano na iPhonie jako 0.1.0 (25), zachowując wszystkie 28 plików danych Glorii bez zmian. Uruchomienie potwierdzono: zachowano 26 z 29 pól pieska dokładnie; zmieniły się tylko potrzeby, czas oraz historia jednej wizyty.

Build 24 zainstalowany na iPhonie: wspólny panel **Dziś** z 2–3 opcjonalnymi pomysłami, bez dziennych liczników i widocznej serii. Wejście jest na górnym pasku oraz w Treningu, Albumie i menu zabaw; zdjęcie nadal można zrobić z Albumu. Goście ustępują pierwszej wybranej zabawie lub opiece i odwiedzają podwórko najwyżej dwa razy podczas jednego pobytu. Ogródek można podlać raz na lokalny dzień kalendarzowy, również rano po wieczornym podlewaniu. Zainstalowano i uruchomiono aktualizację 0.1.0 (24), zachowując postępy Glorii. Szczegóły: [spokojniejszy dzień](docs/mechaniki-gry.md#spokojniejszy-dzień--17-listopada-2026).

Wcześniejszy build 23 / v15 dodał przygody dnia do gry z pamięcią gości i ilustrowanym Albumem, zachowując postępy Glorii. Aktualna wersja zawiera opcjonalne przygody dnia łączące ogródek, sztuczki i szukanie skarbów. Dwie czynności dają pamiątkę do Albumu, bez dodatkowej więzi, serii i kar za pominięcie. Przygody są dostępne w Albumie oraz menu „Pobaw się”.

Aktualny schemat w kodzie: **v15**; migracja v1–v14 zachowuje wcześniejsze dane i wersjonowane kopie. Widget odczytuje v4 i nowsze, jeśli wymagane pola są poprawne. Pakiet przygód zainstalowano i uruchomiono na iPhonie; migracja zachowała dotychczasowy postęp oraz archiwum v14. Pakiet animacji ma 28 klipów / 172 klatki. Opisy wcześniejszych wydań poniżej zachowują historię prototypu.

Obowiązują [aktualne mechaniki](docs/mechaniki-gry.md) i [plan stabilizacji oraz tygodnia testów](docs/rozwoj-projektu.md). Decyzją użytkownika ogródek i wyjście na potrzebę rozwijamy równolegle z próbą 5–10 osób. Bieżący status instalacji i dowody zachowania postępów są w [testach iOS](docs/test-ios.md).

Pakiet po buildzie 19 łączy „Przyjdź” w aporcie i „Zostań” w chowanym z formą oraz tą samą listą treningu dnia. Stokrotka, mak i lawenda odblokowują własne dekoracje. Ten pakiet wprowadził v14 (nowe identyfikatory dekoracji), widget odczytuje v4–v14; build 20 / v14 został zainstalowany na telefonie z zachowaniem postępów Glorii.

Kod po buildzie 20 dodaje ptaka, motyla i kota sąsiada przy płocie. Gloria reaguje według temperamentu; gracz może ją uspokoić lub przywołać. Wizyty czekają na przerwę między zajęciami, nie dają dodatkowej więzi i nie zmieniają schematu v14. Pakiet zainstalowano na iPhonie jako build 21; schemat zapisu pozostaje v14.

Kod po buildzie 21 dodaje pamięć gości, oswajanie przez trzy spokojne dni i ilustrowaną sekcję znajomości w Albumie. Zachowuje schemat v14 i dotychczasowe postępy. Ten pakiet zainstalowano i uruchomiono na iPhonie jako build 22, z zachowaniem postępów Glorii.

## Dokumentacja

[Mapa dokumentacji projektu](docs/README.md) prowadzi przez opis gry, architekturę, mechaniki, model danych, testy i plan rozwoju. Szybkie uruchomienie jest poniżej, a materiały dla grafika znajdują się w [liście sprite’ów](docs/lista-spriteow-szczeniaka.md) oraz [instrukcji integracji](docs/integracja-spriteow.md).

## Uruchomienie

Projekt sprawdzono w Godot **4.7.2**, renderer **Compatibility**, na macOS. Otwórz `project.godot` w Godocie i wybierz **Uruchom projekt (F5)**. Możesz też uruchomić grę bez edytora:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --path '/Volumes/KINGSTON/YuFriend'
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

Wybierz **Pobaw się**: przeciągnij piłkę i puść, pociągnij węzeł liny i puść, żeby pies odpowiedział własnym pociągnięciem, albo schowaj smakołyk pod kubkiem i daj pieskowi komendę „Szukaj!”. Działa dotyk i mysz. [Sterowanie i zasady nagród](docs/mechaniki-gry.md#zabawy-dotykiem).

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

Na ścianie obok portretu pieska wisi pixelartowy zegar w drewnianej ramce. Pokazuje lokalny czas urządzenia i odświeża się także po powrocie do aplikacji oraz zmianie godziny systemowej. Roślina przy portrecie stoi przed ramą i listwą, a światło okna pada na podłogę i dywan bez powtarzania plam w całym pokoju.

Jeden świat 1440 × 360 ma dwa ręcznie wybierane kadry: widok pośredni śledzący psa i „Cały pokój”, pokazujący wszystkie stacje. Dotknięcie panoramy przybliża wybrane miejsce, a „Do pieska” przywraca śledzenie. Domyślny kadr pośredni dopasowuje skalę do szerokości: na sprawdzonych ekranach telefonu pokazuje 480–585 jednostek z 1440, czyli około ⅓–⅖ pokoju. Scena jest przesunięta wyżej, dzięki czemu nad dekoracjami pozostaje mniej pustej ściany. Przy początkowej pozycji psa widać całą jego sylwetkę, miskę i piłkę. Ma sześć stacji: legowisko, miskę, piłkę, kosz z zabawkami, okno i drzwi. Pies porusza się w płytkim pasie podłogi; przedmioty mogą zasłaniać go od przodu, a interfejs pozostaje nieruchomy. Po ręcznym przesunięciu kamera czeka na „Do pieska” lub nową czynność. Pokój zachowuje siatkę 3 jednostek świata na piksel logiczny, a podłoga jest przedłużona za pływającymi panelami. Dodatkowe zbliżenie 2× działa tylko wtedy, gdy szerokość i wysokość mieszczą całego psa; wynik jest powiększany wyłącznie całkowitą liczbę razy, niezależnie od skalowania UI.

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
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path '/Volumes/KINGSTON/YuFriend' --editor --quit
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

## Widget na iPhone

Dodano natywny widget: mały z najpilniejszą potrzebą, średni z pięcioma potrzebami i nastrojem oraz prostokątny na ekran blokady. Pokazuje psa z bieżącego zapisu, uwzględnia sen i upływ czasu. Eksport z widgetem: `sh tools/export_ios.sh`. [Instrukcja dodania, synchronizacja i zakres testów](docs/widget-ios.md).

W ustawieniach gry na iPhonie można włączyć **Przypomnienia od pieska**: najwyżej dwa dziennie, w godzinach 09:00–21:00, na podstawie prognozy potrzeb. Powrót do gry anuluje oczekujące komunikaty. Domyślnie wyłączone; wymagają zgody systemowej. [Reguły, trwałość limitu i weryfikacja](docs/powiadomienia-ios.md).

## Kolejne etapy

1. Ulubione miejsca i zabawy oraz spokojne chwile razem: pamięć preferencji, dobrowolne zaproszenia, głaskanie na leżąco i przeciąganie po drzemce.
2. Pory roku, zaczynając od jesiennych liści i sezonowych znalezisk.
3. Krótki spacer za furtką z wykorzystaniem istniejących sztuczek.
4. Album wspólnych chwil: opcjonalne zdjęcia wydarzeń, podpisy i udostępnianie.

To plan dalszej rozbudowy. Testy z graczami i ocena balansu na telefonie mają odbywać się równolegle z rozbudową. Zakres, warunki akceptacji i ochrona danych Glorii: [aktualny plan rozwoju](docs/rozwoj-projektu.md#dalsze-kroki-po-buildzie-28--17-listopada-2026).

Obecna gra nie korzysta z płatnego API i nie generuje kosztów wywołań modeli. Pole `life_stage` jest przygotowane, ale dorastanie jeszcze nie działa. Szczegółowy zakres późniejszych prac opisuje [plan implementacji](docs/plan-implementacji.md).

Pierwsza instalacja na fizycznym iPhonie: 15 listopada 2026, testowy pies **Gloria**. [Instrukcja i zakres weryfikacji iOS](docs/test-ios.md).
