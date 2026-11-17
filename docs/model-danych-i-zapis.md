# Model danych i zapis YuFriend

[Mapa dokumentacji](README.md)

## Format danych

Stan jednego psa jest przechowywany jako JSON o `schema_version: 5`. Plik zawiera dwa główne pola: numer schematu oraz obiekt `pet`. Syntetyczne przykłady poprzednich formatów to [zapis-v2.json](przyklady/zapis-v2.json) i [zapis-v1.json](przyklady/zapis-v1.json); nie są kopiami danych gracza. Testy sprawdzają ich migrację do bieżącego formatu.

Źródłem formatu jest [PetState.to_dict() i from_dict()](../scripts/model/pet_state.gd). Wersję i obsługę plików określa [SaveSystem](../scripts/systems/save_system.gd).

| Pole w `pet` | Znaczenie i format |
|---|---|
| `pet_id` | Stały, niepusty identyfikator tekstowy; maksymalnie 100 znaków |
| `pet_name` | Imię do 24 znaków; nie może składać się wyłącznie z białych znaków |
| `life_stage` | `puppy`, `young`, `adult` albo `senior`; gra tworzy i prezentuje obecnie szczeniaka |
| `skin` | `simple` albo `pixel`; nowe psy mają `pixel`. Pole starszego zapisu zostaje zachowane, ale obecny widok zawsze używa pixel art |
| `personality_seed` | Ziarno losowania od 1 do 2147483646 |
| `traits` | Liczby dla `curiosity`, `patience`, `sociability`, `sensitivity`, wczytywane do zakresu 0–1 |
| `favorite_reward` | `treat`, `praise` albo `play` |
| `needs` | Liczby dla `fullness`, `energy`, `hygiene`, `play`, `contact`, wczytywane do zakresu 0–100 |
| `skills` | Obiekty `come`, `sit`, `paw`, każdy z `mastery`, `attempts`, `successes` |
| `bond`, `fatigue` | Więź i zmęczenie, wczytywane do zakresu 0–100 |
| `resting` | Wartość logiczna regeneracji podczas odpoczynku; widoczny sen nocny może trwać po jej zakończeniu |
| `rhythm` | Przesunięcie godzin snu, dzień ostatniej korekty i ograniczenia automatycznych drzemek |
| `last_seen_at` | Nieujemny czas Unix w sekundach, używany do przeliczenia nieobecności |
| `journal` | Tablica do 210 wydarzeń (do 200 trwałych osiągnięć i 10 bieżących wpisów): `key`, `title`, `detail`, `at` |
| `milestones` | Tablica do 200 identyfikatorów zdarzeń, które już wystąpiły |
| `history` | Tablica do 14 dziennych koszyków: `day`, liczniki `events` i liczniki pór dnia `parts` |
| `habits` | Tablica identyfikatorów nawyków z katalogu `PetState.HABIT_KEYS` |
| `reflected_day` | Nieujemny numer ostatniego dnia przetworzonego przez osobowość |
| `life` | Dziwactwa, odkrycia, nastrój dnia i ostatnia relacja z nieobecności (opis poniżej) |
| `social` | Pamięć reakcji na zaproszenia, zainteresowania, liczniki zabaw i trwałe czasy propozycji/nagrody |

`day` to numer dnia w czasie lokalnym. W koszyku zapisywane są tylko znane klucze zdarzeń i pór; liczniki muszą być nieujemne. Nieznany nawyk powoduje odrzucenie stanu. Znaczenie pól opisuje [osobowość i nawyki](osobowosc.md).

Opanowanie `mastery` ma zakres 0–100. Liczniki prób muszą być nieujemne; odczyt konwertuje je do liczb całkowitych i ogranicza do miliona. `successes` rośnie po zaakceptowanej nagrodzie. Nie ma oddzielnego licznika poprawnych wykonań bez nagrody ani podziału liczników na naprowadzanie i samodzielność.

Wpis dziennika używa znaczników czasu Unix. `key`, `title` i `detail` mają limit 500 znaków każde, a identyfikator w `milestones` — 100. Dodawanie nowych typów osiągnięć musi uwzględniać limit 200; `remember()` odmawia dodania nowego osiągnięcia po osiągnięciu limitu. Powtarzalne relacje z nieobecności trafiają przez `add_journal_entry()` tylko do ograniczonego Albumu.

## Walidacja i zgodność wersji

Odczyt wymaga poprawnego obiektu JSON i wszystkich pól wymaganych przez `from_dict()`. Nieprawidłowe typy, nieznane identyfikatory stylu lub etapu oraz wartości nieskończone i `NaN` powodują odrzucenie stanu. Prawidłowe liczby potrzeb, cech, więzi, zmęczenia i opanowania są ograniczane do odpowiednich zakresów.

Limit pliku wynosi **1 MiB**. Gra czyta wersje `1`, `2`, `3` i `4`. Każda inna wartość `schema_version`, również brak tego pola w obiekcie JSON, daje status `unsupported`.

Zapis w wersji 1 jest uzupełniany przez `SaveSystem.migrate()` o pustą historię, pustą listę nawyków i `reflected_day: 0`; pozostałe pola nie są zmieniane. Oryginał jest kopiowany do pliku tymczasowego, sprawdzany i zatwierdzany jako `pet.json.v1`. Dotyczy to także odzyskiwania wersji 1 z `.bak`; późniejsze rotacje kopii nie usuwają `.v1`. Poprawna kopia tej wersji i tego samego psa jest ponownie używana. Jeśli istniejąca `.v1` dotyczy innego psa lub jest niepoprawna, pozostaje nietknięta, a własna kopia trafia do `.v1.<pełny SHA-256 źródła>`. Ponowienie używa tego samego pliku po sprawdzeniu wersji, identyfikatora i skrótu zawartości. Błąd systemu plików lub walidacji kopii nadal wstrzymuje zapis bez utraty oryginału.

Jeśli zabezpieczenie oryginału się nie powiedzie, `load_pet()` zwraca `migration_failed` z wczytanym psem i `writable: false`. Również bezpośrednie `save_pet()` odmawia zastąpienia starszego zapisu bez poprawnej kopii. Po udanym zabezpieczeniu najbliższy zapis tworzy wersję 5. Kolejna zmiana struktury wymaga dopisania następnego kroku w `migrate()` i testu odczytu starszego psa.

Akceptacja wartości `young`, `adult` i `senior` przez walidator nie uruchamia dorastania ani innych grafik. Zmiana wieku wymaga osobnego rozszerzenia logiki i wyboru zasobów.

Wersja 2 jest uzupełniana o `life` wyliczone deterministycznie z istniejącego ziarna. Wersja 1 przechodzi oba kroki. Oryginał wersji 2 jest zachowywany w `.v2`, także przy odzyskiwaniu ze starszej `.bak`; obowiązują te same zasady konfliktów i kontroli kopii co dla `.v1`. Stan wersji 3 z brakującym lub niepoprawnym `life` jest odrzucany, a nie ponownie losowany.

`life` zawiera:

- `quirks`: dwa lub trzy różne identyfikatory z `PetState.QUIRK_KEYS`.
- `discovered`: unikalny podzbiór przypisanych dziwactw; `observations`: liczniki całkowite 0–3 wyłącznie dla tego zestawu.
- `mood`: identyfikator z `PetState.MOOD_KEYS`; `mood_day`: całkowity znacznik dnia (początkowo −1); `mood_reason`: opis do 200 znaków.
- `away_report`: pusty obiekt albo `{from, until, events}`. Czasy Unix muszą być skończone i rosnące; tablica ma dwa lub trzy niepuste teksty po maksymalnie 140 znaków.

Wersje 1–3 otrzymują pustą pamięć `social`. Oryginał wersji 3 pozostaje w `.v3`, z taką samą kontrolą kopii i konfliktów jak wcześniejsze migracje. Migracja v3 zachowuje istniejące `life`; jego brak lub uszkodzenie nie powoduje ponownego losowania psa. W bieżącym schemacie brak `social` jest błędem odczytu.

`social` zawiera:

- `responses`: dla `ball`, `tug`, `cups`, `cuddle` liczniki `accepted`, `declined`, `ignored` oraz `interest` w zakresie 0,15–0,95.
- `recent`: do 12 wpisów `{kind, response, at}`, od najnowszego, wyłącznie ze znanymi kluczami i nieujemnym skończonym czasem Unix.
- `games`: liczniki ukończonych rund `ball`, `tug`, `cups`; nietrafiona odpowiedź przy kubkach też kończy rundę.
- `last_offer_at`, `last_reward_at`: nieujemne skończone czasy Unix, zachowujące odstępy między propozycjami i przyrostami zabawy po restarcie.

Liczniki `social` muszą być całkowite i mieścić się w 0–100000. Aktywne zaproszenie, odliczanie, przeciągany węzeł, układ kubków i lot piłki są tymczasowe. Wstrzymanie anuluje niedokończoną rundę bez przyznawania nagrody.

## Rytm dnia — migracja 4 → 5

Wersje 1–4 otrzymują `rhythm: {offset_minutes: 0, updated_day: -1, nap_day: -1, nap_at: 0.0}`. Oryginał v4 jest zabezpieczany w `.v4` przed zapisem nowej wersji, także przy odzyskiwaniu z kopii. W schemacie v5 brak lub niepoprawny `rhythm` jest błędem odczytu.

`offset_minutes` jest liczbą całkowitą od −30 do 180. `updated_day` i `nap_day` są całkowitymi lokalnymi numerami dni (początkowo −1); `nap_at` jest nieujemnym, skończonym czasem lokalnym w tej samej reprezentacji co historia osobowości. Jeden zaobserwowany nowy dzień zmienia przesunięcie najwyżej o 30 minut. Cofnięty zegar ani restart tego samego dnia nie wykonują kolejnego kroku. Dłuższa nieobecność nie nadrabia wielu kroków naraz.

Sen nocny, senność po obudzeniu, pamięć trzech zachowań i kolejka scenki są stanem sesji. Noc wynika z lokalnego zegara i zapisanego przesunięcia. Przy otwarciu w nocy pies wita gracza na jawie; krótkie przejście w tło zachowuje trwający sen lub czuwanie. [Pełne reguły cyklu](cykl-zachowan.md).

## Co jest trwałe

Zapis obejmuje imię, tożsamość, wygląd, cechy, potrzeby, relację, komendy, odpoczynek, wspomnienia, historię zdarzeń, nawyki, pamięć reakcji, liczniki zabaw i czas. Ziarno służy do pierwotnego losowania; podczas odczytu cechy są pobierane z pliku.

Pozycja w pokoju, kierunek patrzenia, aktualny klip, kolejka animacji, zakładka interfejsu, czasy ponownego użycia i rozpoczęta próba treningowa są tymczasowe. Tymczasowe są także cel opieki i token dojścia; przerwane dojście nie daje efektu po wznowieniu. Współrzędne świata i ręczne ustawienie kamery nie są zapisywane. Po restarcie pies zaczyna w środkowej części pokoju (670, 322). Jeśli zapisany odpoczynek umieścił go w legowisku, nocne powitanie budzi go w tym miejscu. Wczytany odpoczynek ustawia psa w legowisku i odtwarza pozycję snu, o ile przeliczenie nieobecności nie zakończyło już drzemki; niezakończony trening nie daje oczekującej nagrody.

## Lokalizacja i momenty zapisu

| Tryb | Ścieżka Godota |
|---|---|
| Zwykła gra | `user://pet.json` |
| Ręczny podgląd `--qa` | `user://qa-ui/pet.json` |
| Testy | Własne katalogi `user://qa-domain-*`, `user://qa-integration-*` lub plik `qa-sprites-*.res` |

Standardowy katalog projektu na macOS to `~/Library/Application Support/Godot/app_userdata/YuFriend/`. Dane są poza katalogiem kodu. Rzeczywistą ścieżkę określa `ProjectSettings.globalize_path("user://")`.

`GameSession.flush()` zapisuje po ważnych akcjach: opiece, rozpoczęciu treningu, nagrodzie, zmianie imienia, a także przy starcie, wstrzymaniu, wznowieniu, utracie fokusu i zamknięciu okna. Dodatkowo zapis następuje po 25 sekundach bez kolejnego `flush()`. Sam ruch po pokoju nie wymaga osobnego zapisu pozycji.

## Zatwierdzanie pliku

1. Stan przechodzi walidację przez `PetState.from_dict()`.
2. Nowy JSON trafia do `pet.json.tmp`; plik jest opróżniany do systemu plików, zamykany i ponownie odczytywany przez walidator.
3. Jeśli obecny główny plik ma nieobsługiwany schemat, zapis zostaje przerwany.
4. Przed zastąpieniem pliku lub rotacją kopii starszy poprawny zapis z pliku głównego lub `.bak` musi mieć zabezpieczony oryginał `.v1`/`.v2`/`.v3` lub właściwą dodatkową kopię ze skrótem źródła.
5. Jeśli obecny główny plik jest poprawny, jest kopiowany do `pet.json.bak.tmp`, a następnie zatwierdzany jako `pet.json.bak`.
6. Plik tymczasowy zastępuje główny przez zmianę nazwy w tym samym katalogu.

Kopia zawiera **poprzedni poprawny zapis**. Pierwsze zapisanie nowego psa tworzy główny plik; kopia pojawia się przy kolejnym zapisie. Uszkodzony główny plik nie jest kopiowany na poprawną kopię odzyskiwania.

Niepowodzenie zwraca `false` i ustawia `SaveSystem.last_error`. Interfejs pokazuje, że postęp czeka na zapis; stan w pamięci nie jest cofany i kolejny zapis może ponowić próbę. Prototyp nie ma blokady pliku dla wielu procesów, dlatego dwie instancje nie powinny korzystać z tej samej ścieżki.

## Odczyt i odzyskiwanie

| Plik główny | Kopia | Wynik `load_pet()` |
|---|---|---|
| Poprawny | Dowolna | `loaded`, wczytany pies, zapis włączony |
| Nieobsługiwany schemat | Dowolna | `unsupported`, zapis zablokowany; bez cofania do kopii |
| Brak lub błędny | Poprawna | `recovered`, pies z kopii, zapis włączony |
| Wersja 1 lub 2 w wybranym źródle, błąd zabezpieczenia oryginału | Dowolna | `migration_failed`, wczytany pies, zapis zablokowany |
| Brak | Brak | `new`, nowy pies, zapis włączony |
| Pozostałe przypadki | Niepoprawna lub brak | `invalid`, zapis zablokowany |

Przy błędnym lub nieobsługiwanym zapisie interfejs otrzymuje tymczasowy stan nowego psa do wyświetlenia; przy błędzie zabezpieczenia migracji pokazuje poprawnie odczytanego psa. Żaden z tych stanów nie jest zapisywany na dotychczasowe pliki. Komunikat informuje o problemie, a działania zmieniające stan są blokowane. Udane odzyskanie z kopii pozwala natomiast sesji zapisać odzyskany stan jako nowy główny plik już przy starcie.

Przy ręcznym diagnozowaniu zamknij grę i zachowaj kopię całego katalogu danych. Sprawdź JSON i numer wersji w kopiach plików. Nie zmieniaj samego numeru schematu, żeby wymusić odczyt innego formatu; potrzebna jest zgodna wersja gry lub jawna migracja. Prototyp nie ma jeszcze osobnego ekranu importu i odzyskiwania danych.

## Czas i nieobecność

W aktywnej sesji potrzeby korzystają z `delta`. Przy starcie i wznowieniu wyliczana jest różnica `now − last_seen_at`, ograniczona do 0–28800 sekund. Po przeliczeniu `last_seen_at` jest ustawiany na większą z wartości poprzedniej i bieżącego czasu. Zapis także nie cofa tego znacznika.

Cofnięcie zegara nie daje ujemnej nieobecności. Przesunięcie zegara w przód może wywołać przeliczenie, lecz tylko do limitu ośmiu godzin. Gra nie pobiera czasu z serwera. To łagodne zasady lokalnej symulacji, bez sieciowego rozliczania czasu.

Sen po nieobecności jest liczony do progu 85 energii (netto +13/h), a pozostały czas jako czuwanie (−5/h). W aktywnej grze wybudzeniem zarządza sesja, z minimum 6 sekundami drzemki. To zmiana zachowania, bez nowej wersji schematu. Pole `skin` nadal przechodzi przez odczyt i zapis, ale nie wybiera już wyglądu gry.

Nastrój ma osobny znacznik dnia zaczynającego się o 05:00. Relacje i powitania używają pełnego czasu nieobecności, bez rozszerzania ośmiogodzinnego limitu potrzeb. Szczegóły opisuje [własne życie psa](osobowosc.md#własne-życie--etap-1-15-listopada-2026).

Limit albumu stosuje się oddzielnie do wpisów oznaczonych w `milestones` oraz do pozostałych. Sama korekta albumu nie zmieniała struktury v4; obecny schemat v5 dodaje opisany wyżej rytm. Dotychczasowe zapisy v1–4 nadal są odczytywane. Wspomnień już usuniętych przez starszą wersję nie odtwarzamy z wymyśloną datą ani treścią. Do odzyskania potrzebna byłaby kopia zawierająca te wpisy.

Czytnik nadal przyjmuje wcześniejsze albumy v4 do 240 wpisów. Po walidacji zachowuje kamienie milowe i 10 najnowszych pozostałych wpisów; pełny stary album nie powoduje odrzucenia zapisu ani utraty psa.

## v15 — opcjonalne przygody dnia

Pole `adventure`: `day` (całkowity lokalny dzień lub −1), `done` (0–2 unikalne identyfikatory z dzisiejszego zestawu: garden/trick/treasure), `rewarded` (true dokładnie po obu zadaniach). Zestaw wyznacza dzień modulo 3. Nie zapisujemy osobnej serii ani zaległości. Widok planu nie zmienia danych; ukończona czynność zatwierdza nowy dzień, zadanie i ewentualną nagrodę razem ze swoim zapisem. Dzień nie cofa się. Nagrody wykorzystują dotychczasowy journal/milestones (trzy stałe pamiątki i jeden wpis ostatniej powtórki).

Migracja wcześniejszych wersji dodaje wyłącznie pusty `adventure`. Wersja bieżąca wymaga poprawnego pola; niepoprawne zadania, powtórzenia i niespójna flaga nagrody są odrzucane. Starszy zapis jest archiwizowany przed aktualizacją. Widget i przypomnienia używają wspólnego czytnika obsługującego v15.


### Zgodne rozszerzenie v15 — podlewanie kalendarzowe

`yard_routines.watered_day` jest opcjonalnym numerem lokalnego dnia (`-1` przed pierwszym podlewaniem). Jeśli występuje, musi być liczbą całkowitą nie mniejszą od `-1`. Brak pola w istniejących zapisach nie jest błędem i nie wymaga nowej wersji schematu. `YardRoutines.watering_day()` odczytuje wtedy dawny czas podlewania z `water_until - 86400`, z bieżącym przesunięciem lokalnego zegara. Pierwsza udana czynność ogródka zapisuje pole; błąd zapisu przywraca cały wcześniejszy stan. Nowa data musi być większa od zapisanej, a zegar czasu wzrostu nie może cofać się przed `checked_at`.

`TodayPlan` jest tylko widokiem istniejących danych. Nie dodaje osobnej listy zadań, liczników ani migracji. Usunięcie widocznej serii i ułamków nie usuwa danych postępu ani wspomnień.
