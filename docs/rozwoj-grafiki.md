# Dalszy rozwój grafiki — 24 listopada 2026

Adaptacja audytu i materiałów z `codex/garden-sprites-kitchen-2026-11-23` (`30636e7`) do obecnego projektu. Makiety są referencjami; pokazują także propozycje, których nie wdrożono. Podstawą zleceń animacji jest bieżący [manifest](../assets/sprites/puppy/pixel/manifest.json), nie liczby w dawnych opisach.

## Stan obecny

Manifest zawiera 28 klipów, 169 wpisów klatek i 24 używane arkusze. Ogród ma panoramę oraz 14 przezroczystych sprite’ów (12 miejsc, dodatkowe stany furtki i kałuży). Rośliny, pogoda, woda i tor korzystają z warstw aktualizowanych podczas gry. Kuchnia jest rysowana w kodzie. Stan i reguły rozgrywki pozostają oddzielone od grafiki.

## Kolejność prac

| Priorytet | Zadanie | Kryterium odbioru |
|---|---|---|
| 1 | Wspólny wzorzec psa; próbka `idle`, `walk`, `sit_down` | Jedna paleta i sylwetka, stabilne łapy, spójna wielkość pikseli; ogląd w ruchu przy 320/390 px. Zachować źródła i aktualny pakiet do porównania. |
| 1 | Przejścia leżenia, snu i jedzenia | Sprawdzić styki `idle_lie → get_up`, `sleep → wake_up`, `eat_loop → eat_exit`; bez skoków skali i oderwania pyska od miski. |
| 2 | Dedykowany skok i picie | Obecnie ruchy składają się z innych klipów. Nowe animacje muszą zachować momenty kontaktu i zdarzenia mechaniki. |
| 2 | Spójność ogrodu, domu i kąpieli | Porównać paletę i kontury na telefonie; zachować czytelność obiektów dotykowych, wzrost roślin i efekty pogody. |
| 3 | Bardziej ikonowy interfejs | Makieta służy do prototypu. Zachować nazwy dostępności, cel minimum 44 pkt i rozpoznawalność bez samego koloru; nie usuwać podpisów bez próby z użytkownikiem. |
| Później | Animacje nowych rytuałów i kolejnych aktywności | Zamawiać po ustaleniu mechaniki; nie traktować listy pomysłów jako już wdrożonych funkcji. |

To plan kontroli i produkcji, a nie nowy audyt wszystkich klatek. Przed wymianą pakietu trzeba obejrzeć aktualne animacje i porównać je z próbą.

## Zachowane referencje

- Kuchnia: [wariant przytulny](images/kuchnia-makieta-a-przytulna.png), [wariant jasny](images/kuchnia-makieta-b-jasna.png), [prompty](images/kuchnia-makiety-prompts.md).
- Ogród: [słoneczny](images/ogrod-makieta-a-sloneczny.png), [po deszczu](images/ogrod-makieta-b-po-deszczu.png), [prompty](images/ogrod-makiety-prompts.md).
- Interfejs: [makieta ikon](images/makieta-interfejs-ikony.png), [prompt i korekta](images/makieta-interfejs-ikony.prompt.txt).

Makiety pochodzą ze wskazanej gałęzi i nie są zrzutami obecnego buildu. Eksporter rzeczywistych obiektów ogrodu: [instrukcja sprite’ów](../assets/art/yard/README.md).

## Zaadaptowane menu obiektów

`YardActionMenu` pokazuje wybór przy krzakach, kałuży i zraszaczu oraz przy aporcie, gdy dostępna jest komenda. Wybór pojawia się od razu w panelu opieki. Dopiero czynność uruchamia istniejącą mechanikę dojścia. Na małym ekranie menu zastępuje przyciski opieki i pozostaje w panelu pod sceną; powrót do domu i wymagane akcje nie znikają.

Mapa ogrodu i trwające aktywności zachowują dotychczasowe sterowanie. Menu zamyka się po zmianie sceny, ekranu, wejściu w aktywność, otwarciu dialogu, sprzątaniu, utracie zapisu albo przejściu aplikacji w tło. Przyciski ponownie sprawdzają dostępność przy wykonaniu. Nie nadpisujemy zegara autonomicznego chodzenia, nie zmieniamy nagród ani schematu zapisu.

Weryfikacja menu i instalacji: [raport buildu 38](test-ios.md).

## Trzymanie piłki — 25 listopada 2026

Po chwycie Gloria przez 2,4 s trzyma piłkę przy pyszczku i merda ogonem,
a następnie puszcza ją z wysokości pyska; działa dotychczasowa fizyka odbić.
Pozycja piłki śledzi bieżącą klatkę i odbicie lustrzane psa. Przerwanie
aktywności usuwa fazę trzymania i odkłada piłkę na ziemię. Powrót z aportem
zachowuje własny stan niesienia piłki.

Animacja składa się z istniejących klipów chwytu i merdania oraz ruchu
rekwizytu; nie dodaje nowego arkusza sprite’ów ani danych do zapisu.
`ui_catch_motion.gd`: 16 sprawdzeń, w tym trzymanie w obu kierunkach,
upuszczenie, przerwanie i chwyt frisbee. Obejrzano zrzut fazy trzymania.
Weryfikacja na fizycznym telefonie pozostaje do wykonania.

## Korekta chwytu i ciągłości przy misce — 25 listopada 2026

Poprawka przygotowana do buildu 42: piłka korzysta z ręcznie dobranych punktów
chwytu dla każdej klatki stania, merdania, chwytu, chodu i biegu. Pyszczek
zasłania górną/wewnętrzną część piłki, znika jej cień podłogowy podczas
trzymania. Pozycja jest aktualizowana przed renderowaniem, także po zmianie
klatki i kierunku. Przy puszczeniu wracają zwykła warstwa i fizyka odbić.
Pozostałe rekwizyty zachowują dotychczasowe punkty kontaktu.

Jedzenie i picie używają jednej spójnej sekwencji: schylanie z eat_enter,
pętla na jego dwóch ostatnich pozach i odwrócona sekwencja przy podnoszeniu.
Pierwsza i ostatnia klatka pętli są identyczne z końcem schylania i początkiem
podnoszenia — ten sam sprite, skala i zakotwiczenie łap. Zachowano czasy
klipów 0,6 / 0,8 / 0,6 s, grafiki źródłowe i logikę rytuałów. Manifest oraz
wygenerowany puppy_pixel.res są zgodne. Nie modyfikowano plików PNG.

Weryfikacja: porównanie wizualne pozycji, 76 sprawdzeń punktów chwytu i
ciągłości przejść w obu kierunkach, 16 sprawdzeń chwytu/odbicia i 24 UI
picia/przyjaźni. Korekta wchodzi do buildu 42; ocena palcem na telefonie pozostaje do wykonania.
