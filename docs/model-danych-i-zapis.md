# Model danych i zapis YuFriend

[Mapa dokumentacji](README.md)

## Format danych

Stan jednego psa jest przechowywany jako JSON o `schema_version: 1`. Plik zawiera dwa główne pola: numer schematu oraz obiekt `pet`. Kompletny syntetyczny przykład znajduje się w [zapis-v1.json](przyklady/zapis-v1.json); nie jest kopią danych gracza.

Źródłem formatu jest [PetState.to_dict() i from_dict()](../scripts/model/pet_state.gd). Wersję i obsługę plików określa [SaveSystem](../scripts/systems/save_system.gd).

| Pole w `pet` | Znaczenie i format |
|---|---|
| `pet_id` | Stały, niepusty identyfikator tekstowy; maksymalnie 100 znaków |
| `pet_name` | Imię do 24 znaków; nie może składać się wyłącznie z białych znaków |
| `life_stage` | `puppy`, `young`, `adult` albo `senior`; gra tworzy i prezentuje obecnie szczeniaka |
| `skin` | `simple` albo `pixel` |
| `personality_seed` | Ziarno losowania od 1 do 2147483646 |
| `traits` | Liczby dla `curiosity`, `patience`, `sociability`, `sensitivity`, wczytywane do zakresu 0–1 |
| `favorite_reward` | `treat`, `praise` albo `play` |
| `needs` | Liczby dla `fullness`, `energy`, `hygiene`, `play`, `contact`, wczytywane do zakresu 0–100 |
| `skills` | Obiekty `come`, `sit`, `paw`, każdy z `mastery`, `attempts`, `successes` |
| `bond`, `fatigue` | Więź i zmęczenie, wczytywane do zakresu 0–100 |
| `resting` | Wartość logiczna informująca o odpoczynku |
| `last_seen_at` | Nieujemny czas Unix w sekundach, używany do przeliczenia nieobecności |
| `journal` | Tablica do 40 wydarzeń: `key`, `title`, `detail`, `at` |
| `milestones` | Tablica do 200 identyfikatorów zdarzeń, które już wystąpiły |

Opanowanie `mastery` ma zakres 0–100. Liczniki prób muszą być nieujemne; odczyt konwertuje je do liczb całkowitych i ogranicza do miliona. `successes` rośnie po zaakceptowanej nagrodzie. Nie ma oddzielnego licznika poprawnych wykonań bez nagrody ani podziału liczników na naprowadzanie i samodzielność.

Wpis dziennika używa znaczników czasu Unix. `key`, `title` i `detail` mają limit 500 znaków każde, a identyfikator w `milestones` — 100. Dodawanie nowych typów osiągnięć musi uwzględniać limit 200; `remember()` nie przycina automatycznie listy `milestones`.

## Walidacja i zgodność wersji

Odczyt wymaga poprawnego obiektu JSON i wszystkich pól wymaganych przez `from_dict()`. Nieprawidłowe typy, nieznane identyfikatory stylu lub etapu oraz wartości nieskończone i `NaN` powodują odrzucenie stanu. Prawidłowe liczby potrzeb, cech, więzi, zmęczenia i opanowania są ograniczane do odpowiednich zakresów.

Limit pliku wynosi **1 MiB**. Każda wartość `schema_version` inna niż `1`, również brak tego pola w obiekcie JSON, daje status `unsupported`. Nie ma jeszcze migracji starszych formatów. Przed zmianą struktury trzeba zaprojektować migrację i dopiero wtedy zwiększyć numer wersji.

Akceptacja wartości `young`, `adult` i `senior` przez walidator nie uruchamia dorastania ani innych grafik. Zmiana wieku wymaga osobnego rozszerzenia logiki i wyboru zasobów.

## Co jest trwałe

Zapis obejmuje imię, tożsamość, wygląd, cechy, potrzeby, relację, komendy, odpoczynek, wspomnienia i czas. Ziarno służy do pierwotnego losowania; podczas odczytu cechy są pobierane z pliku.

Pozycja w pokoju, kierunek patrzenia, aktualny klip, kolejka animacji, zakładka interfejsu, czasy ponownego użycia i rozpoczęta próba treningowa są tymczasowe. Po restarcie pies zaczyna w środkowej części pokoju. Wczytany odpoczynek odtwarza pozycję snu; niezakończony trening nie daje oczekującej nagrody.

## Lokalizacja i momenty zapisu

| Tryb | Ścieżka Godota |
|---|---|
| Zwykła gra | `user://pet.json` |
| Ręczny podgląd `--qa` | `user://qa-ui/pet.json` |
| Testy | Własne katalogi `user://qa-domain-*`, `user://qa-integration-*` lub plik `qa-sprites-*.res` |

Standardowy katalog projektu na macOS to `~/Library/Application Support/Godot/app_userdata/YuFriend/`. Dane są poza katalogiem kodu. Rzeczywistą ścieżkę określa `ProjectSettings.globalize_path("user://")`.

`GameSession.flush()` zapisuje po ważnych akcjach: opiece, rozpoczęciu treningu, nagrodzie, zmianie imienia i stylu, a także przy starcie, wstrzymaniu, wznowieniu, utracie fokusu i zamknięciu okna. Dodatkowo zapis następuje po 25 sekundach bez kolejnego `flush()`. Sam ruch po pokoju nie wymaga osobnego zapisu pozycji.

## Zatwierdzanie pliku

1. Stan przechodzi walidację przez `PetState.from_dict()`.
2. Nowy JSON trafia do `pet.json.tmp`; plik jest opróżniany do systemu plików, zamykany i ponownie odczytywany przez walidator.
3. Jeśli obecny główny plik ma nieobsługiwany schemat, zapis zostaje przerwany.
4. Jeśli obecny główny plik jest poprawny, jest kopiowany do `pet.json.bak.tmp`, a następnie zatwierdzany jako `pet.json.bak`.
5. Plik tymczasowy zastępuje główny przez zmianę nazwy w tym samym katalogu.

Kopia zawiera **poprzedni poprawny zapis**. Pierwsze zapisanie nowego psa tworzy główny plik; kopia pojawia się przy kolejnym zapisie. Uszkodzony główny plik nie jest kopiowany na poprawną kopię odzyskiwania.

Niepowodzenie zwraca `false` i ustawia `SaveSystem.last_error`. Interfejs pokazuje, że postęp czeka na zapis; stan w pamięci nie jest cofany i kolejny zapis może ponowić próbę. Prototyp nie ma blokady pliku dla wielu procesów, dlatego dwie instancje nie powinny korzystać z tej samej ścieżki.

## Odczyt i odzyskiwanie

| Plik główny | Kopia | Wynik `load_pet()` |
|---|---|---|
| Poprawny | Dowolna | `loaded`, wczytany pies, zapis włączony |
| Nieobsługiwany schemat | Dowolna | `unsupported`, zapis zablokowany; bez cofania do kopii |
| Brak lub błędny | Poprawna | `recovered`, pies z kopii, zapis włączony |
| Brak | Brak | `new`, nowy pies, zapis włączony |
| Pozostałe przypadki | Niepoprawna lub brak | `invalid`, zapis zablokowany |

W trybie zablokowanym interfejs otrzymuje tymczasowy stan nowego psa do wyświetlenia; nie jest on zapisywany na dotychczasowe pliki. Komunikat informuje o problemie, a działania zmieniające stan są blokowane. Udane odzyskanie z kopii pozwala natomiast sesji zapisać odzyskany stan jako nowy główny plik już przy starcie.

Przy ręcznym diagnozowaniu zamknij grę i zachowaj kopię całego katalogu danych. Sprawdź JSON i numer wersji w kopiach plików. Nie zmieniaj samego numeru schematu, żeby wymusić odczyt innego formatu; potrzebna jest zgodna wersja gry lub jawna migracja. Prototyp nie ma jeszcze osobnego ekranu importu i odzyskiwania danych.

## Czas i nieobecność

W aktywnej sesji potrzeby korzystają z `delta`. Przy starcie i wznowieniu wyliczana jest różnica `now − last_seen_at`, ograniczona do 0–28800 sekund. Po przeliczeniu `last_seen_at` jest ustawiany na większą z wartości poprzedniej i bieżącego czasu. Zapis także nie cofa tego znacznika.

Cofnięcie zegara nie daje ujemnej nieobecności. Przesunięcie zegara w przód może wywołać przeliczenie, lecz tylko do limitu ośmiu godzin. Gra nie pobiera czasu z serwera. To łagodne zasady lokalnej symulacji, bez sieciowego rozliczania czasu.
