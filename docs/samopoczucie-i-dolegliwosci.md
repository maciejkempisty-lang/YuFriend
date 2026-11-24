# Samopoczucie i dolegliwości — plan wdrożenia

[Mapa dokumentacji](README.md)

Stan: **ustalenia zaakceptowane 22 listopada 2026; etap 1 wdrożony lokalnie**. Samopoczucie i przytulanie opisano poniżej według implementacji; dolegliwości, widget i przypomnienia pozostają planem. Zapis psa pozostaje w schemacie **v17**. 23 listopada zainstalowano i uruchomiono build 37 na iPhonie z zachowaniem postępów Glorii — patrz [raport instalacji](test-ios.md#build-37--samopoczucie-i-przytulanie-2026-11-23).

## Przyjęte decyzje

- Buźka z podpisem w nagłówku, bez szóstego paska i bez procentu samopoczucia. Dotknięcie wyjaśnia, co może pomóc.
- Tylko łagodne dolegliwości. Ewentualna wizyta u weterynarza może być spokojną kontrolą; poważna choroba nie należy do uzgodnionego zakresu.
- Smutek nie obniża skuteczności treningu, nie blokuje komend i nie odejmuje postępów. Może zmieniać zachowanie i zaproszenia.
- Gloria mówi w pierwszej osobie, konkretnie i bez wyrzutów.
- Nieobecność oraz sen **nie pogarszają samopoczucia**, również po zakończeniu powitania. Nie wolno odkładać ich kosztu na później.
- Etap 1 bez migracji: emocja i bufor radości żyją w sesji. Ulubione miejsce deterministycznie wynika z `personality_seed`, a odkrycie korzysta z istniejących osiągnięć i albumu.
- Dolegliwości wygasają według czasu rzeczywistego również w tle i przy zamkniętej grze. Pilot kolca wymaga bezpiecznej alternatywy węszenia.


## 1. Punkt wyjścia przed etapem 1

- **Nastrój dnia** (`life.mood`) to jedna z pięciu etykiet: Spokojny dzień, Ochota na psoty, Blisko Ciebie, Senny dzień, Czas na odkrycia. Jest wybierany raz dziennie o 05:00 na podstawie cech i wczorajszych działań. Przez resztę dnia się nie zmienia, cokolwiek zrobi gracz. Widać go tylko w wierszu statusu („Spokojny dzień · dotknij, by zadbać”), w karcie psa i w średnim widgecie.
- **Pięć potrzeb** ma kolorowe obwódki z procentami. Pasywny spadek zatrzymuje się na 15%, a nieobecność liczy się najwyżej przez 8 godzin.
- **Nie ma osobnego paska nastroju.** Nie ma stanu „smutny” ani choroby. [Plan rozwoju](rozwoj-projektu.md) świadomie odłożył choroby i zapisał zasadę: bez zawstydzania za nieobecność, bez choroby i śmierci jako kary, bez obowiązków wymuszających codzienne wizyty.
- Pies śpi około 18 godzin na dobę i czuwa w godzinnych oknach ([cykl zachowań](cykl-zachowan.md)).

Wniosek: nastrój jest dziś **opisem charakteru dnia, a nie reakcją na gracza**. Dlatego nie daje poczucia, że pocieszenie czy opieka coś zmieniły. To ta sama przyczyna braku satysfakcji co w [propozycjach minigierek](minigry-propozycje.md): działanie gracza nie ma widocznego skutku emocjonalnego.

## 2. Rekomendacja w skrócie

1. **Nie dodawać szóstego paska ze spadającym procentem.** Kolejny wskaźnik spadający w czasie dubluje potrzeby, a przy 18 godzinach snu i limicie 8 godzin nieobecności mierzyłby głównie to, jak dawno gracz nie zaglądał. To kara za nieobecność w przebraniu.
2. **Dodać „Samopoczucie”: chwilową emocję, którą gracz zmienia od razu.** Jest wyliczana z potrzeb, ostatnich wspólnych chwil i ewentualnej dolegliwości. Pokazuje ją przede wszystkim **ciało psa** i mała ikona buźki w nagłówku, a nie kolejny procent.
3. **„Potrzebuje uwagi” to scena z rozwiązaniem, nie wyrzut.** Smutny pies prosi o konkretną rzecz. Gracz spełnia ją w krótkiej zabawie dotykiem, a efekt jest natychmiastowy i widoczny (merdanie, podskok, zmiana buźki).
4. **Choroby w łagodnej formie „dolegliwości”.** Wynikają z sytuacji w grze (krzaki, woda w deszczu, kopanie, nadmiar smakołyków, trening na zmęczeniu), **nigdy z samej nieobecności**. Każda ma widoczny objaw, zrozumiałą przyczynę, krótką minigrę leczenia i limit czasu, po którym mija sama. Nie pogarsza się i nie zabiera postępów.
5. **Kolejność:** najpierw samopoczucie i scena „Stęskniona”, potem jedna dolegliwość pilotażowa (kolec w łapie). Resztę dodajemy dopiero, gdy pilot sprawdzi się na iPhonie.

## 3. Zatwierdzone zasady projektowe

| Zasada | Konkretnie |
|---|---|
| Nieobecność nie jest winą | Powrót po długiej przerwie daje radość i tęsknotę („Stęskniona”), nigdy smutek ani chorobę. |
| Gracz zawsze może pomóc od razu | Każdy zły stan ma rozwiązanie w trakcie jednej wizyty, w mniej niż 3 minuty. |
| Brak spirali | Smutek ani dolegliwość nie obniżają więzi, cech, opanowania sztuczek ani ogródka. Dolegliwość nigdy nie przechodzi w cięższą. |
| Przyczyna jest czytelna | Pies „mówi”, skąd się wzięło („Chyba coś wbiło mi się w łapkę w krzakach”). Gracz uczy się zapobiegać. |
| Rzadkość | Najwyżej jedna dolegliwość naraz i co najmniej 3 dni przerwy między nimi. Żadnej w pierwszym tygodniu z psem. |
| Leczenie wymaga uwagi, nie zasobów | Brak sklepu i waluty: leczy się gestem, czasem i odpoczynkiem. |
| Powiadomienia łagodne | Najwyżej jedno o dolegliwości, w pierwszej osobie, bez tonu alarmu. Nic w nocy i nic o smutku. |

## 4. Etap 1 — Samopoczucie (emocja chwili)

### Model

Samopoczucie jest wyliczane w `WellbeingSystem`, bez zapisu w `PetState`. Liczba 0–100 jest wewnętrzna; gracz widzi tylko buźkę i nazwę emocji.

**Ochrona przed nieobecnością jest częścią modelu, nie tylko powitania.** System trzyma pięć emocjonalnych składników i obserwuje zmiany rzeczywistych potrzeb. Podczas aktywnego czuwania aktualizuje składniki o te zmiany, ale nie przenosi na nie strat z tła, snu ani czytania zasłaniającego grę okna. Korzyści z opieki są widoczne od razu. Rzeczywiste potrzeby nadal działają jak wcześniej.

- Przy uruchomieniu każdy składnik zaczyna od większej wartości: obecna potrzeba albo 80. Restart ma życzliwy początek, bez odtwarzania złej emocji.
- Po powrocie z tła składniki zachowują co najmniej wcześniejszą wartość i dostają minimum 80. Obserwacja potrzeb zaczyna się od ich stanu **po** rozliczeniu nieobecności. Nie ma wygasającej osłony ani późniejszego długu emocjonalnego.
- Podczas snu, braku aktywnego okna i nieobecności radość nie maleje. Zegar radości liczy tylko aktywne czuwanie; cofnięcie zegara urządzenia go nie zmienia.
- Emocja nie jest utrwalana między restartami. Przy ponownym uruchomieniu nadal jest „Radosna”, ale dokładna liczba i bufor radości zaczynają od nowa. To świadome ograniczenie etapu bez migracji; widget nie próbuje odtwarzać tej wartości ze starych danych.

```
podstawa = 0,30·bliskość + 0,25·zabawa + 0,20·sytość + 0,15·energia + 0,10·czystość
            (składniki emocjonalne chronione przed stratami spoza aktywnej wizyty)
radość = 0–20; połowa znika po 20 minutach aktywnego czuwania
samopoczucie = clamp(podstawa + radość, 0, 100)
```

| Próg | Stan | Co widać na psie |
|---|---|---|
| ≥ 75 | **Radosna** | Nieco szybszy chód, częstszy wybór piłki i zabawek; merdanie po udanej zabawie |
| 55–74 | **Zadowolona** | Obecne zachowanie bez zmian |
| 35–54 | **Markotna** | Wolniejszy chód, częstszy wybór odpoczynku na dywanie, rzadszy wybór zabawek |
| < 35 | **Smutna — potrzebuje uwagi** | Wolniejszy chód, częstszy wybór podejścia do gracza i odpoczynku; dymek prosi o konkretną pomoc. Nowe uszy i popiskiwanie pozostają do grafiki/dźwięku |

`radość` pozostaje w pamięci sesji. Udana lina korzysta z istniejącej oceny `tug_stars()` (4 punkty radości za gwiazdkę), piłka i kubki dają 10, ukończone przytulanie 12. Ta sama aktywność ma co najmniej 30 sekund aktywnego czuwania odstępu i malejące premie za powtarzanie; przerwa 20 minut resetuje licznik powtórzeń. Samo klikanie, nieudana runda i przerwane przytulanie nie dają premii. Dolegliwości nie uczestniczą jeszcze w obliczeniu.

**Nastrój dnia zostaje** jako „charakter dnia” i nadal wpływa na zaproszenia i tempo. Samopoczucie mówi, jak pies czuje się *teraz*. W interfejsie: buźka w nagłówku przy więzi, a pod spodem w karcie psa „Charakter dnia: Ochota na psoty”.

### Scena „potrzebuje uwagi”

Gdy samopoczucie spada poniżej 35 w czasie czuwania, pies wybiera **najniższy składnik** i prosi właśnie o niego. Prośba ma jeden przycisk w dymku, tak jak dzisiejsza pobudka:

| Najniższy składnik | Prośba | Rozwiązanie (minigra) |
|---|---|---|
| Bliskość | „Posiedzisz ze mną?” | **Rytuał przytulania** to osobny widok z istniejącym animowanym pieskiem. Otwiera go przycisk „Przytul” w opiece, prośba o bliskość lub przyjęte zaproszenie do głaskania. Zwykły dotyk pieska nadal daje krótkie głaski; w powitaniu uruchamia rytuał.

1. Około 16 sekund spokojnego przesuwania po grzbiecie. Ruch jest oceniany według prędkości i równomierności, niezależnie od liczby zdarzeń dotyku. Przytrzymanie, szybkie pocieranie i drugi palec nie naliczają spokoju. Za szybki ruch wywołuje łagodny komunikat i podniesienie głowy, bez odejmowania postępów.
2. Odkrycie jednego z dwóch miejsc: za uszkiem lub pod brodą. Dwie sekundy delikatnego ruchu w ulubionym miejscu kończą rytuał. Podpowiedź i reakcja psa pozwalają je znaleźć.
3. Pies merda, bliskość rośnie o maksymalnie 24, zabawa o 4, rośnie radość. Po ukończeniu samopoczucie ma co najmniej 58 („Zadowolona”), więc jeden rytuał rzeczywiście pociesza. Nie daje dodatkowych punktów więzi ani sztuczek.

Ulubione miejsce wynika z ziarna osobowości i jest stałe dla psa. Odkrycie zapisuje się raz jako `cuddle_favorite` w istniejących `milestones`/`journal`; widać je w karcie psa. W etapie 1 jest to techniczna reguła wyboru, nie nowa uczona preferencja.

Wyjście, tło i utrata aktywnego okna przerywają rytuał bez kary i bez nagrody. Pora snu również może go zakończyć. Przytulanie nie budzi śpiącego psa. Nieudany zapis końcowy przywraca wszystkie pola psa sprzed rozliczenia i nie przyznaje premii emocjonalnej.

### „Stęskniona” po powrocie

Nieobecność dłuższa niż 4 godziny uzbraja 60 sekund powitania, liczonych tylko w aktywnym czuwaniu. Śpiący pies śpi dalej; powitanie czeka do pobudki. Dymek mówi „Miło Cię znowu widzieć! Posiedzisz ze mną?”, a pierwszy dotyk może rozpocząć skrócone przytulanie (8 sekund grzbietu i 2 sekundy ulubionego miejsca). Ukończenie daje dodatkowe +10 radości w limicie 20 i zużywa premię raz. Zakończenie powitania **nie przywraca strat z nieobecności**. Nie ma osobnego biegu do drzwi w tej implementacji.

## 5. Etap 2 — Dolegliwości (łagodne „choroby”)

Każda dolegliwość ma: **wyzwalacz w grze**, **objaw**, **ograniczenie**, **leczenie przez minigrę** i **samoistne ustąpienie**. Szansa jest niska, a gracz może jej zapobiec.

| Dolegliwość | Skąd się bierze | Jak zapobiec | Objaw | Co ogranicza | Leczenie | Mija sama po |
|---|---|---|---|---|---|---|
| **Kolec w łapie** (pilot) | Węszenie w krzakach, około 4% za wizytę | Wybór bezpiecznego węszenia przy brzegu krzaków, bez ryzyka kolca | Utyka, unosi łapę w siadzie | Tor przeszkód, aport | **Wyciągnij kolec:** przybliżenie łapy, powolne, stałe przeciągnięcie; szarpnięcie = pies cofa łapę, próbujesz jeszcze raz | Do końca najbliższego okna czuwania według zegara, także offline |
| **Przemoczona i zziębnięta** | Trzecia runda wody w deszczu bez otrzepania | Wytarcie ręcznikiem po zabawie w wodzie | Kicha, drży, szuka legowiska | Woda, podwórko | **Wycieranie:** okrężne ruchy ręcznikiem po zaznaczonych mokrych plamach, potem kocyk przy oknie | Do końca drugiego okna czuwania według zegara, także offline |
| **Brzuszek** | Ponad 6 smakołyków w ciągu godziny albo zjedzone znalezisko z piaskownicy | Nagradzanie pochwałą lub zabawą | Leży z głową na łapach, odmawia smakołyka | Smakołyki jako nagroda (pochwała i zabawa działają) | Lekki posiłek + spokojne głaskanie brzuszka (wolne kółka) | Następna noc |
| **Kleszcz** | Spacer za furtką (gdy powstanie), wiosną i latem | Przeczesanie po spacerze | Drapie się | Nic, tylko swędzi | **Przegląd sierści:** czesanie partiami; kleszcz to mały ciemny piksel; precyzyjne chwycenie | 1 okno czuwania (znika „przy czesaniu”) |
| **Zakwasy** | Co najmniej 3 próby treningu przy zmęczeniu ≥ 75 tego samego dnia | Przerwa, odpoczynek | Sztywny chód, `stand_up` wolniej | Trening i tor | Odpoczynek i masaż łap (przytrzymanie palcem) | 1 noc |

Wspólne reguły:

- **Brak pogorszenia.** Nieleczona dolegliwość nie rośnie; po czasie z tabeli mija, a pies mówi „Już lepiej!”. Leczenie przyspiesza powrót do zdrowia i daje radość oraz wspomnienie. Zaniedbanie nie jest karane, tylko trwa dłużej.
- **Bez weterynarza i lekarstw w pierwszej wersji.** Ewentualna wizyta u weterynarza może później być spokojną kontrolą, bez poważnej choroby jako kary.
- **Album:** „Pierwszy kolec — dzielnie wytrzymała”. Więź za samą opiekę: +1 jednorazowo za każdy rodzaj, bez farmienia.
- **Sen ma pierwszeństwo.** Podczas snu nie losujemy dolegliwości i nie pokazujemy próśb. Już istniejąca dolegliwość nadal wygasa według `until`; nie budzi psa ani gracza.

### Dlaczego tak, a nie „pies choruje, gdy jest zaniedbany”

Choroba z zaniedbania działa w Tamagotchi, bo tam jest główną stawką. Tu kłóci się z trzema przyjętymi już decyzjami: brakiem kary za nieobecność, 18 godzinami snu (gracz realnie widzi psa kilka razy dziennie) i limitem 8 godzin. Gracz otwierający grę raz na dwa dni zastawałby chorego psa bez swojej winy. To zawstydzanie, które plan rozwoju wprost wyklucza. Dolegliwości z sytuacji w grze dają ten sam efekt opieki, a do tego **uczą** zapobiegania, co jest bardziej satysfakcjonujące.

## 6. Grafika i dźwięk

Dziś nie ma żadnego „smutnego” ani „chorego” klipu. Etap 1 i pilot da się zrobić na istniejących klipach plus małych nakładkach:

| Potrzebne | Tymczasowo | Docelowo (nowy klip do [briefu](lista-spriteow-szczeniaka.md)) |
|---|---|---|
| Smutek | `idle_lie` + wolniejsze tempo + ikonka chmurki | `sad_lie`: głowa na łapach, uszy płasko, 4 klatki |
| Prośba o uwagę | `sit_idle` + popiskiwanie | `whine_sit`: przestępowanie z łapy na łapę |
| Utykanie | `walk` z wolniejszym tempem i lekkim przechyłem sprite'a | `limp_walk`: 8 klatek |
| Kichanie | `bark_stand` bez dźwięku szczeknięcia + dźwięk kichnięcia | `sneeze`: 6 klatek |
| Radość po pocieszeniu | `tail_wag_stand`, `play_bow` | `belly_up`: przewrót na plecy |

Dźwięki: ciche popiskiwanie, kichnięcie, westchnienie ulgi. Wszystko w obecnym budżecie z [README dźwięku](../assets/audio/sfx/README.md).

## 7. Zakres techniczny

| Element | Etap 1 / dalszy plan |
|---|---|
| `WellbeingSystem` | Składniki emocjonalne, bezpieczny powrót, radość liczona czasem aktywnego czuwania, malejące premie, deterministyczne ulubione miejsce. Nie mutuje `PetState`. |
| `CuddleSystem`, `CuddleView` | Gest grzbietu, wyszukanie miejsca, ocena prędkości i płynności, przerwanie, pojedyncze rozliczenie. Istniejące animacje. |
| `GameSession`, `CompanionVoice`, UI | Buźka i opis, prośby, rytuał, powitanie, reakcje na ukończone zabawy, respektowanie snu i tła. Trening bez kary za emocję. |
| Zapis | Etap 1 zachowuje v17 i wszystkie dotychczasowe pola. Nowe odkrycie wykorzystuje istniejący album. Nie tworzymy `wellbeing`, `joy_at` ani osobnego pliku zapisu. |
| Dolegliwości — później | `AilmentSystem` i migracja do następnej wolnej wersji (obecnie planowane v18). Nowe pola tylko dla dolegliwości; trwałe samopoczucie wymaga osobnej specyfikacji ochrony czasu offline. |
| Widget i przypomnienia — później | Obecne zachowanie bez zmian. Nie można liczyć dokładnego samopoczucia samym surowym wzorem z potrzeb: widget nie ma sesyjnej kompensacji. Wspólny kontrakt snapshotu opracujemy w tym etapie. |
| Testy | Progi, opieka, sen, długa nieobecność, wznowienie i zimny start, koniec powitania, cofnięcie zegara, malejące premie, gesty, przerwania i błąd zapisu. Kopia zapisu Glorii bez zmian wszystkich pól. UI 390×844 i 320×640. |

Lina 2.0 i automatyczny sen są już zapisane w repozytorium; wcześniejsze ostrzeżenie o niezapisanych równoległych zmianach jest nieaktualne. Wdrożenie bazuje na main z buildem 36. Repozytorium znajduje się w `/Volumes/KINGSTON/YuFriend`.

## 8. Kolejność i szacunek

| Krok | Zakres | Gotowe, gdy |
|---|---|---|
| 1 | `WellbeingSystem` + buźka w nagłówku + zachowania „Radosna/Markotna/Smutna” na istniejących klipach | Samopoczucie zmienia się na oczach gracza po zabawie i reaguje na potrzeby podczas aktywnego czuwania; nieobecność i sen nie obniżają żadnego stanu, również po powitaniu |
| 2 | Rytuał przytulania + prośba „Posiedzisz ze mną?” + „Stęskniona” | Gracz z testu na iPhonie potrafi bez instrukcji pocieszyć psa i opisuje to jako przyjemne |
| 3 | Kolejna wolna wersja zapisu (plan v18), `AilmentSystem`, **tylko kolec w łapie** | Pilot działa na iPhonie; Gloria przechodzi migrację bez strat |
| 4 | Widget i jedno przypomnienie o dolegliwości | Widget pokazuje kolec; testy Swift zgodne z Godotem |
| 5 | Pozostałe dolegliwości po jednej, nowe klipy | Każda ma test zapobiegania i ustąpienia |

Kroki 1–2 to mniej więcej tyle pracy co jedna zabawa dotykiem (Lina 2.0). Krok 3 jest podobny, ale dochodzi migracja. Kroki 4–5 zależą od grafiki.

## 9. Status i weryfikacja

Cztery pytania projektowe rozstrzygnięto; decyzje są na początku dokumentu. Etap 1 wdrożono lokalnie i zweryfikowano na Macu. Dolegliwości, widget oraz fizyczna ocena przytulania na iPhonie pozostają do dalszych etapów. 23 listopada, na polecenie użytkownika, zainstalowano i uruchomiono build 37. Nie podmieniano zapisu Glorii kopią testową.


Weryfikacja 22 listopada 2026:

- **36/36 zestawów logiki** i **31/31 zestawów UI**. Po końcowym oddzieleniu okna objaśnienia i zwiększeniu celu dotyku buźki ponowiono `ui_wellbeing`, `ui_companion` i `ui_smoke`.
- **69 sprawdzeń samopoczucia, gestów i ochrony zapisu** na kopii Glorii, bez błędów; **16 sprawdzeń nowego UI**, w tym realne zdarzenia dotyku, drugi palec, prośba, poprawa emocji, album, przerwanie w tle i mały ekran.
- Kopia Glorii: `exports/ios-week-reminders-v36/after-unlocked/Documents/pet.json`, v17. Odczyt, zapis do osobnego katalogu i ponowny odczyt zachowały wartości **wszystkich 30 pól**. Nie nadpisywano źródła, archiwów ani danych na urządzeniu.
- Przejrzano zrzuty nagłówka, głaskania, wyboru ulubionego miejsca i wyniku. Logi i zrzuty tej zmiany: `test-results/wellbeing/` (lokalne, ignorowane przez Git).
- Do oceny na fizycznym iPhonie: wygoda prędkości głaskania, trafianie w ulubione miejsce i odbiór emocjonalny rytuału. Choroby i widget nie zostały wdrożone.
