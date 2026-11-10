# Lista spriteów i animacji szczeniaka YuFriend

[Mapa dokumentacji](README.md) · [Podpinanie gotowych klatek](integracja-spriteow.md)

Brief produkcyjny z 10 listopada 2026 dla golden retrievera wzorowanego na zdjęciu psa użytkownika. Lista jest wspólna dla prostej ilustracji 2D i pixel art. Pełny zestaw klatek przygotowujemy po wyborze jednego stylu. Obecne obrazy są wzorcami wyglądu i pozy; nie są jeszcze wyrównanymi klatkami animacji.

Pierwszy kompletny zestaw obejmuje 22 klipy i orientacyjnie 142 klatki dla głównego widoku bocznego. Najpierw powstaje 8 klipów ruchu i treningu, następnie 14 klipów opieki i reakcji. Liczby klatek są punktem wyjścia i można je zmienić po obejrzeniu ruchu. Lista rozszerza wcześniejszy szkic 13 klipów i jest aktualnym briefem animacji do [planu implementacji](plan-implementacji.md).

## Pozycje bazowe

Najpierw ustalamy neutralne pozycje, do których wracają animacje. Każdy wzorzec ma zachować krótki tułów, krótkie łapy, większą głowę, ciemniejsze opadające uszy, grzywkę, czarny nos i jasne końce łap.

| Pozycja | Widok | Stan materiałów |
|---|---|---|
| Stoi na czterech łapach | Bok, pysk w prawo | Wzorzec jest gotowy w obu stylach |
| Stoi na czterech łapach | Od tyłu | Wzorzec jest gotowy w obu stylach |
| Stoi na czterech łapach | Przód lub delikatne 3/4 | Dodatkowy wzorzec do przygotowania, jeśli użyjemy tego widoku w interakcjach |
| Siedzi, przednie łapy na podłodze | Przód lub delikatne 3/4 | Wzorzec jest gotowy w obu stylach |
| Siedzi, przednie łapy na podłodze | Bok, pysk w prawo | Do przygotowania; musi pasować do bocznego stania |
| Leży na brzuchu, głowa uniesiona | Bok, pysk w prawo | Do przygotowania; neutralna poza odpoczynku |
| Leży na brzuchu, głowa oparta, oczy zamknięte | Bok, pysk w prawo | Do przygotowania; neutralna poza snu |

Wariant leżący na boku lub zwinięty w kłębek można dodać później jako alternatywny sen. Podanie łapy wymaga dodatkowej kluczowej pozy siedzącej z uniesioną przednią łapą, zawartej w klipie `give_paw`.

## Kierunki i zakres ujęć

- Główny zestaw ruchu, opieki i sztuczek: widok boczny skierowany w prawo. Lewo powstaje przez odbicie grafiki wraz z punktami przyczepienia przedmiotów.
- Przód i 3/4: portret, obserwowanie gracza i ewentualny osobny tryb bliskich interakcji. Każda animacja w tym ujęciu jest dodatkowym klipem.
- Tył: wzorzec do zachowania spójności, przyszłych obrotów i poruszania się w głąb pokoju. Sam wzorzec stojący wystarczy na tym etapie.
- Nie mnożymy wszystkich 22 klipów przez wszystkie kierunki. Ruch w głąb pokoju będzie osobnym rozszerzeniem.

## Pakiet A Ruch i trening

Ten pakiet wystarcza do spacerowania po pokoju i prototypu komend „przyjdź”, „siad” oraz „podaj łapę”. Radość jest dopasowana do aktualnej pozycji ciała.

| Klip | Co ma robić pies | Pozycja początkowa i końcowa | Odtwarzanie | Klatki |
|---|---|---|---|---:|
| `idle` | Spokojny oddech i pojedyncze mrugnięcie | Stanie → stanie | Pętla około 2 s | 6 |
| `walk` | Spokojny krok z pracą czterech łap i lekkim ruchem uszu | Chód w miejscu | Pętla około 0,8 s | 8 |
| `sit_down` | Ugięcie tylnych łap i opuszczenie zadu | Stanie → siad | Jednorazowo około 0,6 s | 6 |
| `sit_idle` | Oddech i spokojne oczekiwanie w siadzie | Siad → siad | Pętla około 1,6 s | 4 |
| `stand_up` | Podniesienie zadu i wyprostowanie łap | Siad → stanie | Jednorazowo około 0,6 s | 6 |
| `tail_wag_stand` | Machanie ogonem, delikatna praca zadu, radosny wyraz pyska | Stanie → stanie | Pętla około 0,8 s | 6 |
| `tail_wag_sit` | Machanie ogonem podczas siedzenia | Siad → siad | Pętla około 0,8 s | 6 |
| `give_paw` | Uniesienie przedniej łapy, krótkie przytrzymanie i opuszczenie | Siad → siad | Jednorazowo około 1,5 s | 12 |

Razem: 8 klipów i 54 klatki. Zmienna długość wyświetlania klatki umożliwia pauzę przy podanej łapie bez mnożenia identycznych obrazów. W pierwszym treningu nagroda w siadzie może być pokazana efektem interfejsu, dźwiękiem i `tail_wag_sit`.

## Pakiet B Opieka i reakcje

| Klip | Co ma robić pies | Pozycja początkowa i końcowa | Odtwarzanie | Klatki |
|---|---|---|---|---:|
| `bark_stand` | Krótkie szczeknięcie: otwarcie pyska, ruch głowy i tułowia, zamknięcie pyska | Stanie → stanie | Jednorazowo około 0,5 s | 6 |
| `head_tilt_stand` | Przechylenie głowy z zaciekawieniem i powrót | Stanie → stanie | Jednorazowo około 1 s | 6 |
| `petted_stand` | Przymknięcie oczu, rozluźnienie uszu i lekkie nachylenie głowy do dłoni | Stanie → stanie | Jednorazowo około 1 s | 6 |
| `lie_down` | Ugięcie przednich łap, opuszczenie tułowia, położenie się | Stanie → leżenie z głową uniesioną | Jednorazowo około 0,8 s | 8 |
| `idle_lie` | Spokojny oddech podczas odpoczynku, oczy otwarte | Leżenie → leżenie | Pętla około 2 s | 4 |
| `fall_asleep` | Oparcie głowy i powolne zamknięcie oczu | Leżenie → sen | Jednorazowo około 1 s | 4 |
| `sleep` | Subtelne unoszenie klatki piersiowej, oczy zamknięte | Sen → sen | Pętla około 3 s | 6 |
| `wake_up` | Otwarcie oczu i podniesienie głowy | Sen → leżenie z głową uniesioną | Jednorazowo około 0,8 s | 6 |
| `get_up` | Podparcie na łapach i podniesienie całego tułowia | Leżenie → stanie | Jednorazowo około 0,8 s | 8 |
| `eat_enter` | Pochylenie głowy do miski | Stanie → pozycja jedzenia | Jednorazowo około 0,6 s | 6 |
| `eat_loop` | Małe ruchy pyska, żuchwy i szyi podczas jedzenia | Pozycja jedzenia → pozycja jedzenia | Pętla około 0,8 s | 6 |
| `eat_exit` | Uniesienie głowy po jedzeniu | Pozycja jedzenia → stanie | Jednorazowo około 0,6 s | 6 |
| `treat_take_stand` | Sięgnięcie pyskiem po smakołyk, krótkie przeżucie i powrót | Stanie → stanie | Jednorazowo około 1 s | 8 |
| `play_bow` | Przednie łapy i klatka nisko, zad w górze, powrót do stania | Stanie → ukłon do zabawy → stanie | Jednorazowo około 1 s | 8 |

Razem: 14 klipów i 88 klatek. Pakiety A i B łącznie: 22 klipy i 142 klatki. Dźwięk szczeknięcia, położenie smakołyka i miska są osobnymi zasobami. Przyjęcie smakołyka w siadzie wymaga osobnego klipu z kolejnego pakietu; nie uruchamiamy klipu stojącego na siedzącym psie.

## Pakiet C Dodatki po uruchomieniu podstawowej gry

| Animacja lub wariant | Potrzebne ruchy | Uwaga produkcyjna |
|---|---|---|
| Bieg | Szybszy cykl pracy łap, uszu i ogona | Osobny cykl 8 klatek, zsynchronizowany z prędkością ruchu |
| Węszenie | Pochylenie nosa, krótka pętla obwąchiwania, powrót | Osobne wejście, pętla i wyjście |
| Szczekanie w siadzie | Praca pyska i głowy przy stabilnym zadzie | Osobny klip około 6 klatek |
| Głaskanie w siadzie | Przymknięte oczy i ruch głowy w siadzie | Osobny klip około 6 klatek |
| Smakołyk w siadzie | Przyjęcie i przeżucie nagrody bez wstawania | Osobny klip około 8 klatek |
| Zaciekawienie w siadzie | Przechylenie głowy podczas siedzenia | Osobny klip około 6 klatek |
| Ziewanie | Otwarcie pyska, lekkie uniesienie głowy, zamknięcie | Około 6–8 klatek; ustalamy jedną pozycję ciała |
| Przeciąganie | Wyciągnięcie łap i tułowia, powrót | Około 8–12 klatek |
| Drapanie za uchem | Siad, rytmiczny ruch tylnej łapy, powrót | Nie dodajemy przypadkowych dodatkowych kończyn |
| Otrzepywanie sierści | Krótka praca całego tułowia i uszu | Krople wody jako osobny efekt |
| Picie | Pochylenie głowy, ruch języka, uniesienie głowy | Może współdzielić wejście i wyjście z jedzenia po dopasowaniu pozy |
| Niepewność | Obniżenie głowy lub uszu, spokojny powrót | Subtelna reakcja w określonej pozycji; czytelna także bez ikony |
| Zaskoczenie | Krótkie cofnięcie głowy i zastygnięcie | Około 4–6 klatek |
| Drzemka na boku | Ułożenie się, osobna pętla snu, pobudka | Dodatkowe pozycje bazowe i przejścia |
| Zabawa piłką | Podejście, podniesienie, stanie i chód z zajętym pyskiem, odłożenie | Piłka osobno, punkt mocowania przy pysku; sprawdzić warianty ruchu |
| Obrót | Pełny obrót z bokiem, przodem i tyłem po drodze | Około 12–16 klatek; same trzy nieruchome widoki nie wystarczą |
| Turlanie | Położenie się, obrót przez plecy, bezpieczny powrót do pozy bazowej | Późniejsza, bardziej pracochłonna sztuczka |

Komenda „zostań” wykorzystuje `idle` lub `sit_idle`. „Przyjdź” wykorzystuje `walk`. Machanie ogonem może mieć różną długość i umiarkowanie zmienną szybkość bez tworzenia nowego kompletu klatek, jeśli ruch nadal wygląda naturalnie.

## Kluczowe fazy wybranych animacji

- Machanie ogonem: stała nasada ogona, wychylenie w obie strony, płynny powrót do początku cyklu. Tułów może delikatnie reagować, ale łapy pozostają oparte. Osobna wersja dla stania i siadu.
- Szczekanie: zamknięty pysk, przygotowanie, otwarcie z krótkim ruchem ciała, zamknięcie, neutralna pozycja. Moment dźwięku przypisujemy do odpowiedniej klatki. Końcowa poza ma pasować do `idle`.
- Podawanie łapy: siad, przeniesienie ciężaru, uniesienie jednej przedniej łapy, czytelna pauza, opuszczenie i powrót do tego samego siadu.
- Sen: `lie_down` → `idle_lie` → `fall_asleep` → `sleep` → `wake_up` → `idle_lie` → `get_up` → `idle`. Można pominąć czas oczekiwania w neutralnym leżeniu, zachowując zgodne klatki przejścia.
- Jedzenie: `eat_enter` → `eat_loop` → `eat_exit`. Pozycja miski i pyska musi się zgadzać we wszystkich klatkach.

## Osobne obiekty i efekty

Miska z jedzeniem, miska z wodą, smakołyk, piłka, szczotka, legowisko oraz cień pod psem są osobnymi grafikami. Serduszka, znak zapytania, symbol snu, drobinki nagrody i krople wody pozostają oddzielnymi efektami, dzięki czemu można ich używać przy różnych animacjach.

Brud na łapkach lub mokrą sierść warto najpierw rozważyć jako dodatkową warstwę albo wariant kolorów. Wymaga to sprawdzenia dopasowania do ruchu; nie zlecamy od razu pełnych kopii wszystkich animacji dla każdego stanu czystości.

## Wymagania dla klatek

- Każdy klip dostarczamy jako numerowane PNG RGBA albo osobny arkusz z jawną liczbą klatek. Przykładowo `puppy_side_tail_wag_stand_00.png`.
- Jedna animacja = ta sama kamera, skala, proporcje, paleta, linia podłoża i punkt odniesienia we wszystkich klatkach. Nie przycinamy osobno przezroczystych marginesów.
- Dla gładkiej ilustracji proponowane płótno to 512 × 512 px. Dla pixel art ustalamy rzeczywistą małą siatkę, np. 64 × 64 px, oraz ograniczoną paletę. Dotychczasowe duże przykłady pixel art są wzorcami stylu.
- Pies musi mieścić się na płótnie także przy wyciągniętej łapie, otwartym pysku i skrajnym wychyleniu ogona. Pozostawiamy marginesy.
- Pętle łączą się płynnie; identycznej pierwszej klatki nie trzeba kopiować na końcu. Przejścia jednorazowe kończą się w zdefiniowanej pozycji bazowej.
- Chód i bieg powstają w miejscu. Przesunięcie psa po scenie wykonuje gra, z prędkością dopasowaną do cyklu łap.
- Czas wyświetlania klatek może się różnić. Wolny oddech, pauza z podaną łapą i szybkie szczeknięcie nie muszą mieć wspólnego tempa.
- Kontrola jakości obejmuje cztery kończyny, brak zmiany długości uszu i pyska, brak migotania kolorów, stabilne łapy, czyste krawędzie i czytelność w docelowym małym rozmiarze.

## Wzorce już dostępne

| Ujęcie | Prosta ilustracja 2D | Pixel art |
|---|---|---|
| Siad, przód lub 3/4 | [PNG](../assets/art/reference/golden-puppy-simple-v1.png) | [PNG](../assets/art/reference/golden-puppy-pixel-v1.png) |
| Stanie, bok | [PNG](../assets/art/reference/golden-puppy-simple-side-v1.png) | [PNG](../assets/art/reference/golden-puppy-pixel-side-v1.png) |
| Stanie, tył | [PNG](../assets/art/reference/golden-puppy-simple-rear-v1.png) | [PNG](../assets/art/reference/golden-puppy-pixel-rear-v1.png) |

Pierwsza partia produkcyjna: wyrównać stojącego szczeniaka z boku, przygotować zgodny siad z boku, następnie wykonać 8 klipów pakietu A. Po obejrzeniu ich w ruchu przechodzimy do opieki, szczekania i pozostałych reakcji.
