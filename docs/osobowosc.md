# Osobowość i nawyki YuFriend

[Mapa dokumentacji](README.md) · [Mechaniki gry](mechaniki-gry.md) · [Model danych](model-danych-i-zapis.md)

Stan z 15 listopada 2026. Pies zaczyna z cechami wylosowanymi z ziarna, a potem zmienia się pod wpływem tego, jak i kiedy gracz się nim zajmuje. Całość działa lokalnie, bez AI. Źródłem jest [PersonalitySystem](../scripts/systems/personality_system.gd).

## Trzy kroki

| Krok | Funkcja | Co robi |
|---|---|---|
| 1. Fakty | `record()` | Dopisuje zdarzenie do dziennego koszyka w `pet.history` |
| 2. Propozycja | `propose()` | Z zamkniętych dni wylicza zmiany cech, nawyki i wpisy do wspomnień |
| 3. Zatwierdzenie | `apply()` | Sprawdza i ogranicza propozycję, dopiero potem zmienia psa |

`reflect()` łączy kroki 2 i 3. Sesja wywołuje je przy starcie, wznowieniu i okresowym zapisie. Bieżący dzień nie jest przetwarzany, więc zmiany pojawiają się następnego dnia, a każdy dzień liczy się tylko raz.

## Zdarzenia

Dzień i pora wynikają z czasu lokalnego urządzenia. Pory: rano 5–11, po południu 11–17, wieczorem 17–22, noc 22–5.

| Zdarzenie | Kiedy powstaje |
|---|---|
| `visit` | Nowy pies albo powrót po ponad 5 minutach |
| `feed`, `pet`, `play`, `clean` | Zaakceptowana czynność opieki |
| `rest` | Gracz kładzie psa do odpoczynku; samodzielna drzemka się nie liczy |
| `train_guided`, `train_free` | Rozpoczęta próba z gestem lub samodzielna |
| `train_tired` | Próba rozpoczęta przy zmęczeniu co najmniej 50 |
| `reward_treat`, `reward_praise`, `reward_play` | Nagroda przyznana na czas |
| `reward_missed` | Okno nagrody minęło bez nagrody |
| `miss` | Pies nie wykonał samodzielnej próby |

Historia obejmuje najwyżej 14 dni z aktywnością. `miss`, `reward_missed` i `train_tired` nie zwiększają licznika pory dnia. Cofnięcie zegara dopisuje do ostatniego dnia.

## Dryf cech

Dzień bez opieki i treningu niczego nie zmienia. W pozostałe dni:

| Cecha | Rośnie o 0,02 | Maleje |
|---|---|---|
| Towarzyskość | Głaskanie i pochwały łącznie co najmniej 3 | O 0,01, gdy nie było żadnego |
| Cierpliwość | Co najmniej 80% okazji nagrodzonych na czas | O 0,02, gdy poniżej 50% |
| Ciekawość | Zabawa i samodzielne próby łącznie co najmniej 3 | O 0,01, gdy nie było zabawy ani treningu |
| Wrażliwość | Co najmniej 2 próby przy zmęczeniu | O 0,01, gdy był odpoczynek i żadnej próby przy zmęczeniu |

Cierpliwość jest oceniana przy co najmniej dwóch okazjach do nagrody. Jedno zatwierdzenie zmienia cechę najwyżej o 0,06. Cecha nie odejdzie dalej niż 0,25 od wartości urodzeniowej, którą `PetState.base_traits()` odtwarza z ziarna, i pozostaje w zakresie 0,05–0,95. Wspomnienia zawierają jednorazowe wyjaśnienia zmian w danym kierunku; nie są pełnym rejestrem każdego przesunięcia liczby.

## Nawyki

Nawyki są liczone z zamkniętych dni z aktywnością w oknie 7 dni kalendarzowych. Okno kończy się na ostatnim nieprzetworzonym dniu aktywności. Brak nowych dni nie przesuwa okna i nie usuwa nawyków; po późnym powrocie oczekujące zdarzenia są oceniane tak, jak następnego dnia po ich wystąpieniu. Przy mniej niż dwóch dniach z aktywnością nic się nie zmienia. Nawyk może wygasnąć dopiero po kolejnej aktywności, gdy wzorzec nie osiąga progu utrzymania.

| Nawyk | Nazwa | Warunek nabycia | Zachowanie |
|---|---|---|---|
| `time_morning`, `time_afternoon`, `time_evening`, `time_night` | Ranny ptaszek, Popołudniowy towarzysz, Wieczorny towarzysz, Nocny marek | Co najmniej 16 działań, 60% w jednej porze i aktywność o tej porze w co najmniej 2 dniach | O tej porze chętniej spaceruje, częściej pokazuje inne nawyki i wita inaczej |
| `cuddler` | Przytulas | Co najmniej 8 głaskań w co najmniej 2 dniach | Macha ogonem i czeka na głaskanie, gdy bliskość jest poniżej 80 |
| `playful` | Łobuziak | Co najmniej 6 zabaw w co najmniej 2 dniach | Sam robi ukłon do zabawy, gdy zabawa jest poniżej 80 |
| `student` | Pilny uczeń | Co najmniej 10 prób w co najmniej 2 dniach | Sam siada i czeka na komendę, gdy trening jest możliwy |

Katalog ma siedem typów nawyków, a pies może mieć równocześnie najwyżej cztery: jeden dotyczący pory dnia oraz Ochotę na pieszczoty, Małe psoty i Radość z nauki. Nabyty nawyk utrzymuje się przy połowie progu; nawyk pory przy 8 działaniach i 40% udziału. Propozycja pierwszego nabycia zawiera jednorazowy wpis do wspomnień, a lista nawyków jest widoczna w Profilu. Utrata i ponowne nabycie nie tworzą kolejnego wpisu o tym samym kluczu.

Zachowanie z nawyku wybiera ta sama decyzja co samodzielny spacer. Szansa wynosi 35%, a w ulubionej porze 60%; ulubiona pora dodaje też 0,15 do szansy spaceru. Zachowanie trwa 1,5 s i nie blokuje gracza, więc można od razu odpowiedzieć głaskaniem, zabawą lub treningiem.

## Własne życie — etap 1 (15 listopada 2026)

[LifeSystem](../scripts/systems/life_system.gd) uzupełnia historię i nawyki o stałe dziwactwa, nastrój dnia oraz krótkie opowieści po powrocie. Imię jest pobierane z zapisu; istniejąca Gloria zachowuje tożsamość i postępy. System działa lokalnie i korzysta z obecnych animacji.

### Odkrywane dziwactwa

Pies otrzymuje dwa albo trzy różne dziwactwa z puli dwunastu. Osobny generator korzysta z `personality_seed`, dlatego migracja starszego psa daje zawsze ten sam zestaw i nie zmienia cech ani ulubionej nagrody. Karta psa pokazuje każdą niepoznaną pozycję jako „Jeszcze nieznane”.

| Dziwactwo | Sytuacja prowadząca do odkrycia |
|---|---|
| Kolekcja skarpetek, Piłka pod łapą, Zabawki po swojemu | Ukończona zabawa lub wizyta przy zabawkach |
| Patrol przy oknie | Dotarcie do okna |
| Czujne uszy | Dotarcie do drzwi |
| Kółko przed snem, Łowca ciepła, Bieg przez sen | Rozpoczęcie odpoczynku w legowisku |
| Radość całym ciałem | Głaskanie z zaakceptowanym przyrostem |
| Jeszcze jeden ruch | Zaakceptowane czesanie |
| Najpierw obwąchać | Posiłek po dojściu do miski |
| Głowa na bok | Rozpoczęta próba z gestem |

Trzy pasujące sytuacje ujawniają dziwactwo i tworzą jeden wpis w Albumie. Przerwane dojście oraz głaskanie w czasie blokady przyrostów nie liczą się ponownie. Opowieść o nieobecności nie zwiększa liczników obserwacji ani nie odkrywa dziwactw. Samodzielne wizyty przy oknie, drzwiach i zabawkach oraz drzemki nie dopisują fikcyjnej opieki gracza do `history`.

### Nastrój dnia

Nowy dzień nastroju zaczyna się o **05:00 czasu lokalnego**. Pierwszy start, powrót lub aktywne odświeżenie po tej godzinie wylicza nastrój z cech i zapisanych działań poprzedniego dnia kalendarzowego. Dzisiejsze działania wpłyną na kolejny dzień. Cofnięcie zegara i restart nie losują ponownie już rozpoczętego dnia.

Pięć nastrojów to **Spokojny dzień, Ochota na psoty, Blisko Ciebie, Senny dzień i Czas na odkrycia**. Zabawa sprzyja psotom, głaskanie i pochwały bliskości, trening przy zmęczeniu spokojniejszemu tempu, samodzielne próby odkrywaniu, a odpoczynek spokojowi. Ograniczone liczniki i niewielka deterministyczna zmienność uzupełniają temperament. Wszystkie pięć wyników używa wagi cechy równej 2, również senność. Przy braku wczorajszych działań pozostaje temperament; nieobecność nie jest karą.

Nastrój zmienia tempo chodu i klipu `walk` w zakresie 0,85–1,12 oraz wybór spontanicznych zaproszeń, gdy nie ma pasującego nawyku. Spokojny lub senny pies przysiada, towarzyski zaprasza do głaskania, rozbrykany idzie do zabawek, a ciekawski do okna. Potrzeby nadal mają pierwszeństwo. Nastrój nie obniża umiejętności ani więzi i nie blokuje działań gracza.

### Kiedy Cię nie było

Nieobecność trwająca co najmniej **30 minut** tworzy dwa krótkie zdarzenia; od czterech godzin powstają trzy. Są to lokalnie symulowane drobne zachowania wynikające z dziwactw, cech i snu. Nie są zapisem pracy gry w tle. Nie przyznają jedzenia, więzi, nagród ani wyuczonych komend. W tej iteracji ślady, np. skarpetka przy legowisku, występują wyłącznie w tekście — nie dodano ich do grafiki pokoju.

Relacja pojawia się w oknie powrotu i pozostaje w Albumie. Ten sam ani nakładający się przedział czasu nie tworzy drugiej relacji. Album zachowuje wszystkie wpisy osiągnięć (maksymalnie 200) oraz 40 najnowszych wpisów powtarzalnych. Relacje nie wypierają pierwszych wspólnych chwil. W zapisanym stanie pozostaje też ostatnia relacja.

Powitanie odróżnia krótki powrót, godzinę i trzy dni: podniesienie głowy, merdanie ogonem albo spokojne obwąchanie. Śpiący pies nadal odpoczywa. Długość nieobecności na potrzeby powitania jest rzeczywista; dotychczasowa symulacja potrzeb pozostaje ograniczona do ośmiu godzin. Nie dodano kary za długą nieobecność.

## Własna inicjatywa i pamięć reakcji — etap 2

[InitiativeSystem](../scripts/systems/initiative_system.gd) wybiera zaproszenie do piłki, przeciągania liny, kubków ze smakołykiem albo bliskości. Pies podchodzi do piłki lub kosza z zabawkami; przy bliskości wyciąga łapę. Karta nad pokojem pozwala odpowiedzieć lub wybrać „Później”. Te same zabawy można samodzielnie rozpocząć przez przycisk „Pobaw się”.

Pierwsze zaproszenie może nastąpić po 90 sekundach dostępnej uwagi, podczas kolejnej decyzji bezczynnego psa. Następne czeka co najmniej 300 sekund; czas ostatniej propozycji przetrwa restart. Opieka, trening, sen i pilne potrzeby mają pierwszeństwo. Energia poniżej 35 lub zmęczenie od 80 wykluczają propozycje aktywnych zabaw.

Każda propozycja ma 30 sekund widocznej uwagi. Otwarty dialog, inna zakładka lub utrata fokusu zatrzymują licznik. Wstrzymanie aplikacji usuwa zaproszenie bez przypisywania odpowiedzi. Przyjęcie, „Później” i pozostawienie bez odpowiedzi są zapisywane oddzielnie. Wybór innej zaakceptowanej czynności neutralnie zamyka zaproszenie: nie zapisuje odpowiedzi i nie zmienia zainteresowania. Odrzucona czynność pozostawia zaproszenie bez zmian.

Każda aktywność ma własne zainteresowanie, początkowo 0,5. Przyjęcie dodaje 0,12, „Później” odejmuje 0,08, a brak odpowiedzi 0,04; zakres wynosi 0,15–0,95. Waga losowania to `0,3 + 2 × zainteresowanie`, uzupełniona temperamentem, nastrojem i pasującymi dziwactwami. Gloria częściej proponuje lubiane wspólne chwile, lecz nadal może zaskoczyć inną propozycją. Reakcje nie obniżają więzi, cech ani potrzeb.

Karta psa pokazuje sekcję **Wasz rytm** z preferowaną propozycją i trzema ostatnimi reakcjami. Stan zachowuje dwanaście ostatnich reakcji oraz łączne liczniki każdego rodzaju. Trzecie przyjęte zaproszenie danego typu dodaje jednorazowe wspomnienie „Nasz mały rytuał”. Jest to pamięć wspólnych aktywności; preferencje miejsca snu i smaku nadal pozostają przyszłym rozszerzeniem.

## Miejsce na AI

Model językowy może zastąpić wyłącznie krok 2. `summary()` przygotowuje kontekst: cechy bieżące i urodzeniowe, nawyki, ulubioną nagrodę, więź, opanowanie komend, koszyki z ostatnich dni oraz listę dozwolonych nawyków. Kontekst nie zawiera imienia ani identyfikatora psa.

Odpowiedź musi mieć kształt wyniku `propose()`:

```json
{
  "trait_deltas": {"patience": 0.02},
  "habits": ["time_evening", "cuddler"],
  "notes": [{"key": "habit_cuddler", "title": "Przytulas", "detail": "Często go głaszczesz…"}]
}
```

`apply()` traktuje ją jako niezaufaną: przycina zmiany cech, pomija nieznane nawyki i drugi nawyk pory dnia, odrzuca błędne wpisy i przyjmuje najwyżej 4 wpisy po 200 znaków, z uwzględnieniem limitu 200 zapisanych identyfikatorów wspomnień. Powtórzenie propozycji dla już przetworzonego dnia nie zmienia psa. To walidacja formatu i granic; nie dowodzi prawdziwości swobodnego tekstu modelu. Klient sieciowy, backend i limity kosztów nie istnieją; przed ich dodaniem trzeba także powiązać odpowiedź z aktualnym stanem i zweryfikować treść wpisów.

## Czego jeszcze nie ma

- Cechy nadal wpływają na zachowanie tylko tak, jak opisują [mechaniki](mechaniki-gry.md); dryf zmienia więc głównie liczby, a widoczna jest warstwa nawyków.
- Nawyki korzystają z klipów `tail_wag_stand`, `play_bow` i `sit_down`. Korzystają już z dostarczonych animacji pixel art oraz komunikatu.
- Progi i tempo dryfu nie były sprawdzane w kilkudniowej rozgrywce.
- Pogoda, lokalizacja i inne dane spoza gry nie są używane.
