# Lokalne przypomnienia od pieska

W ustawieniach gry włącz **Przypomnienia od pieska** i zaakceptuj zgodę iOS. Domyślnie są wyłączone. Po odmowie aplikacja wskazuje Ustawienia iPhone’a; nie ponawia automatycznie pytania. Wyłączenie przełącznika usuwa zaplanowane przypomnienia. Na pozostałych platformach opcja jest nieaktywna.

Od buildu 11 ustawienia są panelem wewnątrz gry, mieszczącym się w bezpiecznym obszarze ekranu. „Zamknij” u góry oraz „Wróć do pokoju” u dołu pozostają dostępne podczas przewijania opcji. Poprawka odpowiada na zgłoszenie zasłaniania ustawień przez Dynamic Island i braku dostępnego wyjścia na telefonie.

Powiadomienie ma imię psa w tytule i krótkie zaproszenie w pierwszej osobie, np. „Burczy mi w brzuchu. Zjemy coś?”. Dotknięcie otwiera grę. Nie wymaga internetu, konta ani serwera.

## Reguły — automatyczny sen, 22 listopada 2026

- Prognoza korzysta z `PetSnapshot.projected`, zgodnego z rytmem i potrzebami Godota.
- Dla zapisów v17 wiadomości „Już nie śpię!” są planowane na najbliższe pobudki według harmonogramu psa, co najmniej minutę po wyjściu z gry. Zawierają aktualną prośbę o wyjście albo najniższą potrzebę poniżej 60 punktów. Nie proszą o ręczne usypianie.
- Najwyżej **cztery na lokalny dzień i ruchome 24 godziny**, z odstępem co najmniej dwóch godzin. Niezaspokojona potrzeba może wrócić przy kolejnej pobudce.
- Cisza nocna **21:00–09:00**. Domyślnie wiadomości mogą pojawić się o 09, 12, 15 i 18; nawyki przesuwają te terminy razem z rytmem psa. Nie ma komunikatów podczas snu.
- Od buildu 36 plan obejmuje **7 dni od ostatniego zapisu wizyty**, najwyżej 28 oczekujących terminów. iOS otrzymuje całą kolejkę przy wyjściu do tła; kolejne dni nie wymagają działania gry. Ponowne otwarcie i wyjście odświeża plan zgodnie z nowym stanem Glorii. Stary snapshot nie przesuwa końca tego okna. Potrzeby zamrażają się po ośmiu godzinach. Nie ma bezterminowych alarmów; zaspokojone potrzeby i wykonane wyjście nie tworzą wymyślonych próśb.
- Powrót do gry i wyłączenie opcji anulują oczekujące terminy. Wykorzystany limit przetrwa restart.
- Starsze snapshoty bez rytmu zachowują zgodność z poprzednią regułą dwóch próśb dziennie, progu 30 punktów i minimum 30 minut.

iOS może opóźnić lub ukryć prezentację z powodu ustawień systemowych, Trybu skupienia lub podsumowania powiadomień. Limity dotyczą planowanych terminów. Upłynięty termin zużywa limit również wtedy, gdy system nie pokazał komunikatu — aplikacja nie ponawia go jako „niedostarczonego”.

## Integracja i trwałość

`scripts/services/local_reminders.gd` atomowo zapisuje wyłącznie preferencję i identyfikator jawnej zmiany w `Documents/reminders.json`. Natywny `PetWidgetBridge` obserwuje katalog i przekazuje bieżący zapis oraz stan aplikacji do `PetReminderController`. `reminders-status.json` zwraca wynik do panelu ustawień. Tryb QA i testy używają osobnych katalogów.

Planista `PetReminderPlan.swift` jest niezależny od interfejsu. Kontroler serializuje operacje `UNUserNotificationCenter`; spóźnione ukończenie planowania nie przywróci powiadomień po wyłączeniu opcji lub powrocie do gry. Zgoda systemowa jest sprawdzana ponownie przy wznowieniu. Obsługa istotnej zmiany czasu przelicza plan w działającej aplikacji; już zarejestrowane terminy pozostają ustalone, jeśli aplikacja nie działa podczas zmiany strefy.

`Documents/reminder-ledger.json` przechowuje rezerwacje i wykorzystane terminy poza zapisem gry. Przyszłe terminy są zwalniane przy anulowaniu; minione zostają w limicie. Rezerwacje są zapisane przed rejestracją w iOS, więc awaria może zachowawczo zużyć limit, ale nie zresetuje go. Uszkodzony licznik blokuje planowanie i pozostaje zachowany; cofnięcie zegara również nie odnawia limitu. Żaden plik natywny nie zmienia `pet.json`.

Eksport: `sh tools/export_ios.sh`, domyślnie do `exports/ios-reminders-v10/`. Instalator dodaje źródła przypomnień do targetu aplikacji; rozszerzenie widgetu nie planuje powiadomień. Wygenerowane eksporty i wyniki testów są wykluczone z paczki gry. Po zmianach Godota nadal trzeba sprawdzić punkt inicjalizacji i instalator.

API: [zgoda na powiadomienia](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) i [planowanie lokalne](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).

## Weryfikacja — 15 listopada 2026

Poprawka wieczornego wyjścia: **1067 sprawdzeń planisty i 18 kontrolera** oraz kontrola typów iOS z ostrzeżeniami jako błędami przechodzą. Testy obejmują wyjścia o 08:00, 13:00, 17:00, 19:00, 20:00 i 22:00, jedno zaproszenie następnego ranka, zamrożenie potrzeb po 8 godzinach, zwalnianie limitu 24 godzin, odstępy i koniec okna w południe. Sprawdzają też wieczór przed obiema zmianami czasu, rejestrację porannego terminu w kontrolerze, trwałą rezerwację i anulowanie po powrocie. Ponownie przechodzi **1525 sprawdzeń widgetu**, w tym 252 porównania prognozy z Godotem. Poprawkę zainstalowano na iPhonie; próby ujawniły dodatkowy problem przekazania stanu tła do kontrolera. Build 14 zawiera korektę tej integracji. Harmonogram po wyjściu z tej wersji i rzeczywiste doręczenie wymagają potwierdzenia. [Przebieg i dowody prób](test-ios.md#aktualizacja-010-14--poranne-przypomnienie-i-przejście-w-tło).

Wcześniejsza weryfikacja pierwszej implementacji:

- `sh tools/test_ios_reminders.sh`: **365** sprawdzeń planisty (m.in. progi, sen, cisza nocna, zmiany czasu i trwałość limitu), **15** sprawdzeń kontrolera z atrapą centrum powiadomień (zgoda, odmowa, wznowienie, restart, anulowanie w trakcie zapisu do iOS, uszkodzenie licznika i błąd planowania). Kod natywny przechodzi też sprawdzenie typów dla iOS z ostrzeżeniami traktowanymi jako błędy.
- `tests/test_reminders.gd`: **10** sprawdzeń preferencji, błędów zapisu i izolacji od pliku gry.
- `tests/ui_reminders.gd`: **13** sprawdzeń panelu w 390 × 844, 320 × 640 i 1100 × 720; obejrzano zrzut wąskiego ekranu z odmową uprawnienia.
- Istniejące **649** sprawdzeń gry oraz **1525** widgetu przechodzą; testy UI powtórzono po dodaniu przełącznika.

Build **0.1.0 (10)** zbudowano, podpisano, zainstalowano i uruchomiono na iPhonie 15 Pro Max. Użytkownik potwierdził włączenie opcji oraz zaakceptowanie zgody iOS. Odczyt natywnego `reminders-status.json` z urządzenia potwierdził `enabled: true`, `status: on`; harmonogram był wówczas pusty (`pending: 0`). Nie potwierdzono jeszcze doręczenia prawdziwego powiadomienia. [Dowody i zachowanie zapisu Glorii](test-ios.md#aktualizacja-010-10--lokalne-przypomnienia).

Atrapa centrum w testach nie potwierdza dostarczenia komunikatu przez iOS. Ręczna próba: włącz opcję, zaakceptuj zgodę, pozostaw niską potrzebę i wyjdź z gry. W nowej wersji pierwszym możliwym terminem jest kolejna dzienna pobudka, między 09:00 a 21:00, co najmniej minutę po opuszczeniu gry. Sprawdź otwarcie gry po dotknięciu komunikatu, anulowanie po powrocie oraz wyłączenie opcji. Nie zmieniaj ręcznie zapisu Glorii na potrzeby tego testu.


## Prośba o wyjście na potrzebę

Planista odczytuje istniejący `yard_routines.outday` i opcjonalne `mess`. Jeśli dzisiaj nie było jeszcze wyjścia, pies nie śpi i nie czeka wcześniejsza kupa, pierwszeństwo ma wiadomość „Chcę wyjść się załatwić. Pójdziemy na podwórko?”. Jest to lokalne powiadomienie iOS, bez serwera. Korzysta z obecnej zgody i przełącznika „Przypomnienia od pieska”. Nie tworzy dodatkowej puli powiadomień: korzysta ze wspólnych limitów i godzin opisanych powyżej. W v17 niezrealizowana prośba może wrócić przy kolejnej dziennej pobudce.

Dotknięcie otwiera grę. W domu opis podpowiada wyjście, a na podwórku przycisk „Na potrzebę” rozpoczyna czynność. Po wykonaniu i zapisaniu wyjścia nie powstaje ponowna prośba na ten sam dzień. Niezebrana kupa blokuje prośbę o nowe wyjście także kolejnego dnia. Wznowienie gry i wyłączenie przypomnień nadal anulują oczekujące terminy. Stare snapshoty widgetu bez pól wyjścia nadal się odczytują; widget zachowuje dotychczasowe pięć wskaźników.

Testy planisty obejmują termin, ciszę nocną, wspólny limit, brak powtórzeń, zapisany bałagan, odczyt danych gry i roundtrip formatu widgetu. Testy nie potwierdzają rzeczywistego doręczenia przez iOS — wymaga to próby na telefonie po zainstalowaniu tej wersji.

## Weryfikacja automatycznego snu

Planista: 1150 sprawdzeń; kontroler: 22 sprawdzenia. Kontrola typów dla iOS traktuje ostrzeżenia jako błędy. Widget: 4234 sprawdzenia i 700 projekcji zgodnych z Godotem. Nie potwierdza to doręczenia na fizycznym telefonie.

## Weryfikacja planowania na siedem dni — build 36

`PetReminderPlan` planuje do 28 terminów w ciągu siedmiu lokalnych dni od
ostatniego zapisu. Kolejka jest rejestrowana od razu przy przejściu do tła;
nie wymaga codziennego uruchamiania gry ani pracy procesu w tle. Wykorzystane
limity, cisza nocna, progi potrzeb i zamrożenie ich spadku po ośmiu godzinach
pozostają zachowane. Starsza czteroelementowa kolejka jest nadal odczytywana.
Powrót do gry, wyłączenie opcji i błędy rejestracji usuwają całą tygodniową
kolejkę. Zadanie tła UIKit kończy się dopiero po zakończeniu asynchronicznych
operacji kontrolera; wcześniejszy callback sceny nie kończy nowszego zadania.

Testy: **3422 sprawdzenia planisty, 30 kontrolera, 10 ustawień Godota i 52 UI**.
Obejmują ostatni dzień bez ponownego otwarcia, wygaśnięcie starego snapshotu,
limity dzienne i ruchome 24 godziny, odstępy, obie zmiany czasu, przesunięcia
rytmu, zachowanie czteroelementowego licznika, restart po trzech dniach,
anulowanie 28 terminów oraz błąd po częściowym zapisaniu dłuższej kolejki.
Kontrola typów dla iOS z ostrzeżeniami jako błędami, eksport, kompilacja
aplikacji i widgetu oraz kontrola podpisu przechodzą. Dłuższy opis ustawień
sprawdzono także wizualnie na ekranie 320 px.
