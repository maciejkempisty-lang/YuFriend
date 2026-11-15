# Cykl zachowań YuFriend

Wdrożenie z 15 listopada 2026. Logika: `DailyRhythm`, `BehaviorSystem` i `GameSession`. Rytm wpływa na inicjatywę psa; wieczór i noc nie blokują zabawy ani treningu rozpoczętego przez gracza. Dotychczasowe wymagania energii i zmęczenia nadal obowiązują.

## Pory i wybór

| Pora bez przesunięcia | Aktywne | Spokojne | Drzemka |
|---|---:|---:|---:|
| 6–9 | 60 | 35 | 5 |
| 9–13 | 70 | 25 | 5 |
| 13–15 | 15 | 35 | 50 |
| 15–19 | 60 | 35 | 5 |
| 19–22 | 15 | 60 | 25 |

To początkowe wagi grup przy wyborze, a nie procent czasu spędzonego w danym stanie. Nastrój koryguje grupy, a cechy, nawyki i dziwactwa — wybór wewnątrz grupy. Wieczorem waga drzemki stopniowo rośnie. Trzy ostatnie zachowania mają mnożnik 0,08; to samo miejsce dodatkowo 0,12. Pozostaje możliwość wyboru przy małej puli. Cała scenka stanowi jedną decyzję, więc dwukrotne zajrzenie do kosza jest dozwolone wewnątrz sekwencji.

Pilny głód i niska energia mają pierwszeństwo przed losowaniem. Nuda wieczorem i nocą nie uruchamia zaczepki z piłką. Wieczorne i nocne zaproszenia dotyczą wyłącznie bliskości. W dzień zaproszenia zachowują dotychczasowy odstęp i pamięć reakcji.

Automatyczna drzemka trwa co najmniej 60 sekund, kończy się po osiągnięciu 85 energii lub po 180 sekundach. Kolejna może się rozpocząć po co najmniej 30 minutach od poprzedniego zaśnięcia; w sjeście najwyżej jedna na lokalny dzień. Ręczny odpoczynek i pilna potrzeba energii pozostają dostępne niezależnie od limitu. Dotknięcie psa lub przycisku Obudź kończy odpoczynek.

## Noc i budzenie

Domyślnie noc trwa 22–6. Nocny sen nie jest losowany. Otwarcie aplikacji w nocy budzi psa na powitanie, również przy pierwszym uruchomieniu i zanim powstaną nawyki. Powrót po co najmniej minucie w tle również uruchamia powitanie; krótkie przełączenie aplikacji zachowuje trwający sen. Powitanie nie zmienia potrzeb ani więzi i rozpoczyna nowe trzy minuty do automatycznego snu. Podczas otwartej gry pies idzie spać po 180 sekundach bez opieki/akcji; 20 sekund wcześniej pokazuje zapowiedź z przyciskiem głaskania. Zabawa, otwarta runda z wynikiem, trening, karmienie, czesanie i głaskanie chronią przed zaśnięciem. Odliczanie bezczynności jest wstrzymane, gdy widok opieki nie jest dostępny (np. dialog, przegląd pokoju).

Zapowiedź „Chce mi się spać” i komunikat „Jeszcze chwila na rozbudzenie” są neutralne i pasują także do Glorii. Dotyk budzi bez zmiany więzi i bez natychmiastowej zmiany potrzeb. Pierwszy dotyk służy obudzeniu, kolejny głaskaniu. Przez trzy minuty pies chodzi wolniej, ale może się bawić i ćwiczyć. Po obudzeniu nocny powrót do legowiska następuje po 120 sekundach bezczynności. Zapowiedź również pojawia się 20 sekund wcześniej. Rano pies budzi się według harmonogramu. Przerwana droga do legowiska nie może później uśpić psa przez spóźniony sygnał dojścia.

`night_sleep` opisuje widoczny sen, a zapisane `resting` — regenerację. W otwartej grze regeneracja nocna kończy się przy 85 energii, ale sen trwa do pobudki. Potem energia może znowu maleć pomimo śpiącej animacji. To świadome zachowanie zachowujące dotychczasowe obliczenia `NeedsSystem`, projekcje widgetu i planisty przypomnień. Poza aplikacją nie symulujemy nowego harmonogramu regeneracji. Widget czyta zapisy v4/v5 i nadal przedstawia odpoczynek wynikający z projekcji potrzeb; nie dodano osobnej nocnej prezentacji widgetu.

## Dopasowanie do gracza

Na podstawie istniejących nawyków docelowy harmonogram wynosi:

- poranny: 21:30–5:30;
- domyślny: 22–6;
- wieczorny: 23:30–7:30;
- nocny: 1–9.

Przesunięcie całego harmonogramu zmienia się najwyżej o 30 minut na nowy zaobserwowany dzień. Jest zapisane wraz ze znacznikiem dnia; restart, cofnięty zegar i dłuższa nieobecność nie powodują skoku. Aktualne godziny widać w profilu. Historia nadal zawiera cztery szerokie pory dnia: nie przewidujemy dokładnej godziny przyjścia gracza. Odpowiedni nawyk zwiększa szansę czekania przy drzwiach w danej porze.

## Widoczne zachowania

Katalog obejmuje patrol, okno, drzwi, kosz, piłkę, oglądanie miski, dywan, czekanie pośrodku, podejście po kontakt i drzemkę. Sekwencje wykorzystują istniejące animacje i ruch w świecie. Można je przerwać opieką, zabawą lub treningiem. Przejście w tło usuwa niedokończoną kolejkę.

„Patrol przy oknie” dodaje pojedyncze szczeknięcie w dzień; „Zabawki po swojemu” dodają ponowne podejście do kosza; „Kółko przed snem” dodaje obejście legowiska przed automatycznym snem; „W poszukiwaniu ciepła” przenosi automatyczną drzemkę pod okno. Pozostałe preferencje wpływają na wagi istniejących zachowań. Automatyczne scenki nie zapisują działań gracza ani nie przyznają efektów opieki.

Po minucie bezczynności, gdy skończy się bieżąca scenka, pies może usiąść i zwrócić uwagę na gracza. Po jedzeniu i zakończonej animacji zabawy wybiera odpoczynek na dywanie. Nagroda treningowa kończy się pozostaniem w bieżącej pozycji; otwarta zakładka treningu wstrzymuje samodzielne spacery i scenki także między próbami. Po wyjściu do pokoju samodzielne zachowania wracają. Po przesunięciu pokoju może po trzech sekundach podejść w oglądaną stronę; nowa akcja i przycisk powrotu do psa anulują oczekujące podążanie. Przesunięcie nie budzi śpiącego psa.

Pełne osobne scenki pozostałych dziwactw, dokładna godzina oczekiwania na gracza, picie, nowe animacje i nocna prezentacja widgetu pozostają kolejnymi rozszerzeniami.

## Weryfikacja

`tests/test_rhythm.gd` wstrzykuje lokalny zegar i sprawdza granice pór, adaptację, losowanie, blokady drzemek, noc, budzenie, przerywanie sekwencji, odczyt starego zapisu i trwałość nowego. `tests/ui_rhythm.gd` sprawdza rzeczywiste połączenia widoku, ruchu i animatora oraz generuje obrazy `test-results/rhythm-*.png`. Dodatkowo uruchamiane są dotychczasowe zestawy logiki, interfejsu oraz zgodność Swift/Godot.
