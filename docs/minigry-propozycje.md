# Minigierki z Glorią — propozycje

[Mapa dokumentacji](README.md)

Status: **propozycja z 22 listopada 2026. Wdrożono lokalny prototyp [Liny 2.0](lina-2.md); 25 listopada dodano lokalne [pierwsze wersje berka, Kubków 2.0 i Frisbee](minigry-2026-11-25.md). Pozostałe propozycje i rozszerzenia tych rund czekają.** Dokument zbiera pomysły na zabawy, które wymagają od gracza uwagi, refleksu i decyzji. Opiera się na obecnym kodzie: [zabawach dotykiem](mechaniki-gry.md#zabawy-dotykiem), [aporcie](mechaniki-gry.md#stałe-miejsca-i-aport-z-zamachem--17-listopada-2026), [chowanym](mechaniki-gry.md#chowany-na-podwórku--17-listopada-2026), [torze przeszkód](tor-przeszkod.md) i [znaczniku „Siad”](mechaniki-gry.md#prototyp-znacznika-i-siad--build-32).

## Dlaczego obecna zabawa nudzi

| Zabawa | Co robi gracz | Problem |
|---|---|---|
| Piłka w domu | Przeciąga i puszcza | Pies zawsze dobiega. Rzut niczego nie zmienia poza miejscem. |
| Lina | Trzy razy ciągnie w prawo | Nie da się przegrać ani zagrać lepiej. To przewijanie, nie gra. |
| Kubki | Wybiera kubek, potem „Brawo!” | Gracz tylko patrzy. Pies szuka w losowej kolejności. |
| Aport na podwórku | Zamach i dotknięcie w oknie 0,85 s | Najlepsza zabawa: ma siłę rzutu, rekord i okno premii. Okno jest jednak jedno i zawsze takie samo. |
| Chowany | Wybór krzaka albo szukanie ogona | Trzy krzaki, brak presji czasu, błąd bez konsekwencji. |
| Tor przeszkód | Skacz → Zostań → Pochwal | Stała kolejność. Ten sam tor za każdym razem. |

Wspólne przyczyny:

1. **Wynik jest przesądzony.** Gracz nie może przegrać, więc wygrana nic nie znaczy.
2. **Nagroda nie zależy od gry.** Odstęp 30 s nagradza za sam fakt rozpoczęcia. Świetna i słaba runda dają to samo.
3. **Pies reaguje jak automat.** Ta sama reakcja na sukces, brak „charakteru” w zabawie, żadnych niespodzianek.
4. **Brak eskalacji.** Kolejna runda nie jest trudniejsza ani inna. Nie ma serii, kombinacji ani rekordu dnia (poza aportem).
5. **Trening i zabawa są rozłączne.** Wyuczone sztuczki prawie nie zmieniają tego, w co można się bawić.

Najmocniejszy element gry to **znacznik „Siad”**: liczy się moment, jest ocena Idealnie / Dobrze / Pudło i widać własną poprawę. Ten wzorzec warto przenieść do zabaw.

## Zasady projektowe dla nowych zabaw

- **Umiejętność gracza zmienia wynik.** Każda runda ma ocenę (np. 0–3 gwiazdki) i da się zagrać źle — bez kary, ale z mniejszą nagrodą.
- **Pies daje sygnały, które trzeba czytać.** Ukłon (`play_bow`), przechylenie głowy (`head_tilt_stand`), merdanie i szczeknięcie zapowiadają, co Gloria zaraz zrobi. Gracz uczy się jej mowy ciała — to też buduje więź.
- **Temperament zmienia zabawę.** Cierpliwość, ciekawość i wrażliwość już istnieją w `PersonalitySystem`. Niech wpływają na tempo, zmyłki i trudność.
- **Krótkie rundy, szybki restart.** 20–60 sekund, przycisk „Jeszcze raz” od razu, bez odliczania.
- **Nagroda zależna od wyniku, malejąca z powtórzeniami.** Zamiast twardego odstępu 30 s: pełna nagroda za pierwsze rundy dnia, potem coraz mniejsza (np. ×1, ×0,6, ×0,3, minimum 0,1). Rekordy i gwiazdki liczą się zawsze, więc granie dalej ma sens.
- **Soczysta informacja zwrotna.** Ocena przy psie, krótki dźwięk, drgnięcie kamery przy „Idealnie”, a przy serii coraz większa radość: merdanie → obrót (`spin`) → turlanie (`roll`).
- **Niespodzianki.** Co kilka rund mały zwrot: złota piłka, pies ucieka z zabawką, podmuch wiatru, gość przy płocie rozprasza psa.

## Propozycje

Każda pozycja podaje: rozgrywkę, element umiejętności, wpływ charakteru psa, użyte animacje i szacowany nakład. Wszystkie propozycje 1–5 korzystają wyłącznie z istniejących 28 klipów i skoku `PuppyJump`.

### 1. Berek z zabawką (nowa) ★ priorytet

Gloria łapie zabawkę i ucieka po podwórku. Gracz ma ją „złapać”, dotykając psa — ale tylko wtedy, gdy zwolni.

- **Rozgrywka:** pies biega zygzakiem (`run`), co chwilę zatrzymuje się w ukłonie (`play_bow`) i zachęca. Dotknięcie w trakcie ukłonu = złapanie. Dotknięcie w biegu = Gloria robi unik i odbiega w drugą stronę.
- **Zmyłki:** czasem pies zaczyna ukłon i z niego „wyskakuje” (pierwsze klatki `play_bow`, potem `run`). Uważny gracz widzi różnicę: prawdziwy ukłon kończy się merdaniem.
- **Umiejętność:** czytanie sygnałów i wyczucie momentu. Trzy złapania w 45 s = wygrana; ocena za czas.
- **Narożniki:** gracz może przeciągnięciem postawić „ścianę” (rozłożone ręce) i zagonić psa do płotu — wtedy ukłon jest dłuższy.
- **Charakter:** niska cierpliwość = krótsze ukłony; wysoka ciekawość = więcej zmyłek; wysoka wrażliwość = pies szybciej się męczy i łatwiej go złapać pod koniec.
- **Animacje:** `run`, `play_bow`, `tail_wag_stand`, `spin` po złapaniu.
- **Nakład:** średni. Nowy `YardTagSystem` na wzór `YardHide`, ruch na istniejącej nawigacji podwórka.

### 2. Lina 2.0 — siła i odpuszczanie (przebudowa) ★ priorytet

Zamiast trzech pociągnięć: pasek napięcia, w którym trzeba wyczuć psa.

- **Rozgrywka:** linę trzyma się palcem. Gloria ciągnie falami: spokojnie → mocne szarpnięcie. Gracz przeciąga w swoją stronę, gdy pies odpuszcza, i **luzuje**, gdy szarpie.
- **Zapowiedź:** przed szarpnięciem pies na chwilę się pochyla i warczy zabawowo (krótki dźwięk + przykucnięcie z `play_bow`). To sygnał do odpuszczenia.
- **Błąd:** ciągnięcie w trakcie szarpnięcia → lina wysuwa się z ręki i pies na chwilę wygrywa. Bez kary, ale przegrana runda.
- **Decyzja:** gdy wygrywasz, możesz „pozwolić Glorii wygrać”. Prawdziwe psy lubią czasem wygrywać — więź rośnie bardziej, ale bez gwiazdek. Ciekawy wybór między wynikiem a relacją.
- **Charakter:** siła i rytm szarpnięć zależą od temperamentu; z rosnącą więzią Gloria jest silniejsza, więc gra nie robi się łatwiejsza.
- **Animacje:** obecne klatki liny, `play_bow`, `shake` (potrząsanie liną po wygranej psa), `tail_wag_stand`.
- **Nakład:** mały–średni. Rozbudowa fazy `tug` w `TouchPlaySystem` i `TouchPlayView`.

### 3. Psi freestyle — taniec ze sztuczkami (nowa) ★ priorytet

Psi taniec to prawdziwy sport kynologiczny. Gra rytmiczna łączy zabawę z treningiem.

- **Rozgrywka:** gra muzyka (istniejący `BackgroundMusic`), po ścieżce przesuwają się ikony komend: Siad, Łapa, Obrót, Turlaj, Leżeć, Ukłon. Dotknięcie w rytmie = Gloria wykonuje sztuczkę.
- **Ocena:** jak znacznik Siad — Idealnie / Dobrze / Pudło. Seria idealnych daje kombinację i coraz bardziej efektowne przejścia.
- **Związek z treningiem:** w układzie pojawiają się tylko sztuczki, które Gloria zna. Opanowanie poniżej 50% = pies czasem się myli (`head_tilt_stand`) mimo dobrego trafienia. Trening ma więc widoczny cel: lepszy taniec.
- **Postęp:** układy od 20 s / 4 komend do 60 s / wszystkich sztuczek; rekord każdego układu; pierwszy pełny układ trafia do Albumu.
- **Animacje:** `sit_down`, `give_paw`, `spin`, `roll`, `lie_down`, `play_bow`, `bark_stand`.
- **Nakład:** średni–duży. Potrzebna ścieżka rytmu zsynchronizowana z muzyką i krótsze wersje przejść między pozami.

### 4. Frisbee — chwyt w locie (rozbudowa aportu)

- **Rozgrywka:** zamach jak w aporcie, ale dysk leci łukiem, a pies biegnie pod niego. Gdy dysk jest nad psem, gracz dotyka „Skacz!” — Gloria wyskakuje (`PuppyJump`).
- **Ocena:** odległość dysku od pyska w szczycie skoku. Idealnie = chwyt w locie z obrotem; Dobrze = chwyt; Pudło = pies łapie dysk z ziemi.
- **Wiatr:** `YardWeather` dodaje wiatr widoczny na chorągiewkach polany. Rzut trzeba korygować.
- **Seria:** pięć rzutów na rundę, kombinacja chwytów w locie, rekord dnia.
- **Animacje:** `run`, `PuppyJump`, `spin`, `tail_wag_stand`. Nowa grafika: tylko dysk, rysowany w kodzie.
- **Nakład:** średni. Większość fizyki istnieje w `YardFetch`.

### 5. Trzy kubki i nos Glorii (przebudowa kubków)

- **Rozgrywka:** smakołyk trafia pod kubek, kubki się tasują — coraz szybciej i dłużej. Gracz śledzi kubek, ale może też zapytać Glorię.
- **Nos Glorii:** pies obwąchuje (`sniff`) i merda mocniej przy właściwym kubku. Wskazówka bywa myląca przy niskiej ciekawości lub dużym zmęczeniu. Gracz decyduje: ufam sobie czy psu?
- **Ocena:** trafienie bez pytania psa = 3 gwiazdki, z pytaniem = 2, pudło = 0. Poziom tasowania rośnie przy kolejnych trafieniach.
- **Animacje:** `sniff`, `tail_wag_stand`, `head_tilt_stand`, `treat_take_stand`.
- **Nakład:** mały. Rozszerzenie fazy `cups`.

### 6. Bańki mydlane (już wspomniane w planach podwórka)

- **Rozgrywka:** przytrzymanie palca nadmuchuje bańkę (dłużej = większa i wolniejsza), przeciągnięcie ją wypuszcza. Pies goni i przebija bańki skokiem. Gracz kieruje bańki tak, żeby Gloria zdążyła je złapać, zanim odlecą.
- **Seria:** złote bańki są szybsze i wyżej; czasem bańka pęka sama.
- **Charakter:** nadaje się na spokojniejszy wieczór, gdy tor i berek są niedostępne.
- **Animacje:** `run`, `PuppyJump`, `bark_stand`, `shake`. Bańki rysowane w kodzie.
- **Nakład:** średni.

### 7. Agility na czas (rozbudowa toru)

- **Rozgrywka:** pies biegnie sam, a gracz w odpowiednim momencie podaje komendę przy przeszkodzie: Skacz, Slalom, Stój. Za wcześnie lub za późno = pies się zatrzymuje (`head_tilt_stand`) i traci czas.
- **Zmienny tor:** układ przeszkód losowany według daty; rekord dnia i rekord wszech czasów.
- **Nakład:** średni. Wymaga przeróbki `YardCourse` z sekwencji kroków na bieg z oknami czasowymi.

## Wspólne elementy (raz, dla wszystkich zabaw)

| Element | Co daje | Gdzie |
|---|---|---|
| `PlayScore` — ocena rundy | 0–3 gwiazdki, Idealnie / Dobrze / Pudło, rekordy | Nowy moduł obok `FetchRewards` |
| Nagroda malejąca w ciągu dnia | Zastępuje twardy odstęp 30 s; wynik ma znaczenie | `TouchPlaySystem`, `YardActivities` |
| Reakcja zależna od serii | Merdanie → obrót → turlanie | Nowa metoda przy animatorze psa |
| Efekty „Idealnie” | Dźwięk, napis przy psie, lekkie drgnięcie kamery | `SoundEffects`, `RoomView` |
| Tablica rekordów | Najlepsze wyniki i gwiazdki w karcie psa | `ProgressionPanels` |
| Wspomnienia | Pierwsze 3 gwiazdki w każdej zabawie → Album | `KeepsakeSystem` |

Zmiana formatu zapisu: jedno nowe pole `play_records` (rekordy i licznik rund dnia). Pozostałe dane bez zmian, migracja jak przy poprzednich wersjach.

## Proponowana kolejność

1. **`PlayScore` + Lina 2.0** — mała zmiana, od razu pokazuje, czy ocena i ryzyko porażki poprawiają odczucia. Dobra do szybkiego testu na iPhonie.
2. **Berek z zabawką** — najbardziej „psia” i najprostsza do zrozumienia nowa zabawa.
3. **Trzy kubki z nosem Glorii** — mały koszt, przerabia najbardziej bierną zabawę.
4. **Frisbee** — rozbudowa najlepiej przyjętej zabawy.
5. **Psi freestyle** — największa, ale daje treningowi długoterminowy cel.
6. Bańki i agility na czas — później, jako odmiana.

Po każdym kroku: test na telefonie z pytaniem „czy chcesz zagrać jeszcze raz?”. Jeśli po pierwszym kroku odpowiedź brzmi „nie”, problemem nie jest liczba zabaw, tylko informacja zwrotna — wtedy dopracowujemy efekty, zanim dodamy kolejne gry.

## Otwarte pytania

- Czy dopuszczamy wyraźną przegraną (np. „Gloria wygrała linę”)? Propozycja zakłada, że tak, bez utraty punktów.
- Czy zabawy mają mieć dzienny limit nagród, czy tylko malejące nagrody?
- Czy freestyle ma używać obecnej muzyki, czy osobnych krótkich utworów o stałym tempie?
