# Lokalne przypomnienia od pieska

W ustawieniach gry włącz **Przypomnienia od pieska** i zaakceptuj zgodę iOS. Domyślnie są wyłączone. Po odmowie aplikacja wskazuje Ustawienia iPhone’a; nie ponawia automatycznie pytania. Wyłączenie przełącznika usuwa zaplanowane przypomnienia. Na pozostałych platformach opcja jest nieaktywna.

Od buildu 11 ustawienia są panelem wewnątrz gry, mieszczącym się w bezpiecznym obszarze ekranu. „Zamknij” u góry oraz „Wróć do pokoju” u dołu pozostają dostępne podczas przewijania opcji. Poprawka odpowiada na zgłoszenie zasłaniania ustawień przez Dynamic Island i braku dostępnego wyjścia na telefonie.

Powiadomienie ma imię psa w tytule i krótkie zaproszenie w pierwszej osobie, np. „Burczy mi w brzuchu. Zjemy coś?”. Dotknięcie otwiera grę. Nie wymaga internetu, konta ani serwera.

## Reguły

- Prognoza korzysta z tego samego `PetSnapshot.projected` co widget, zgodnego z `NeedsSystem` Godota.
- Przypomnienia są planowane w tle po zapisie gry, dla potrzeby **poniżej 30%**, co najmniej **30 minut** po opuszczeniu gry. Kandydaci są sprawdzani co 15 minut.
- Najwyżej **dwa na dzień lokalny**, dodatkowo najwyżej dwa w ruchomym oknie 24 godzin. Między nimi są co najmniej **cztery godziny**. Podczas jednej nieobecności ta sama potrzeba nie jest powtarzana.
- Cisza nocna **21:00–09:00** według lokalnego czasu. Następnego dnia po zapisie możliwe jest **jedno poranne przypomnienie, od 09:00 do przed 12:00**, w ramach tych samych limitów i odstępów. Wykorzystany limit może przesunąć poranny termin albo całkowicie go wykluczyć.
- Horyzont planowania kończy się **o 12:00 następnego lokalnego dnia po zapisie**; ponowne przeliczenie tego samego zapisu go nie przedłuża. Spadek potrzeb nadal zatrzymuje się po **8 godzinach** — poranny komunikat korzysta z zamrożonego stanu. Nie ma bezterminowych ani codziennie powtarzanych alarmów. Pies zaspokojony albo zapis z przyszłości nie wywołują przypomnień. Podczas snu energia nie jest powodem do alarmu.
- Powrót do gry usuwa oczekujące przypomnienia; kolejne wyjście przelicza je na podstawie nowego stanu. Błędny zapis również anuluje wcześniejszy plan.

iOS może opóźnić lub ukryć prezentację z powodu ustawień systemowych, Trybu skupienia lub podsumowania powiadomień. Limity dotyczą planowanych terminów. Upłynięty termin zużywa limit również wtedy, gdy system nie pokazał komunikatu — aplikacja nie ponawia go jako „niedostarczonego”.

## Integracja i trwałość

`scripts/services/local_reminders.gd` atomowo zapisuje wyłącznie preferencję i identyfikator jawnej zmiany w `Documents/reminders.json`. Natywny `PetWidgetBridge` obserwuje katalog i przekazuje bieżący zapis oraz stan aplikacji do `PetReminderController`. `reminders-status.json` zwraca wynik do panelu ustawień. Tryb QA i testy używają osobnych katalogów.

Planista `PetReminderPlan.swift` jest niezależny od interfejsu. Kontroler serializuje operacje `UNUserNotificationCenter`; spóźnione ukończenie planowania nie przywróci powiadomień po wyłączeniu opcji lub powrocie do gry. Zgoda systemowa jest sprawdzana ponownie przy wznowieniu. Obsługa istotnej zmiany czasu przelicza plan w działającej aplikacji; już zarejestrowane terminy pozostają ustalone, jeśli aplikacja nie działa podczas zmiany strefy.

`Documents/reminder-ledger.json` przechowuje rezerwacje i wykorzystane terminy poza zapisem gry. Przyszłe terminy są zwalniane przy anulowaniu; minione zostają w limicie. Rezerwacje są zapisane przed rejestracją w iOS, więc awaria może zachowawczo zużyć limit, ale nie zresetuje go. Uszkodzony licznik blokuje planowanie i pozostaje zachowany; cofnięcie zegara również nie odnawia limitu. Żaden plik natywny nie zmienia `pet.json` ani schematu 4.

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

Atrapa centrum w testach nie potwierdza dostarczenia komunikatu przez iOS. Ręczna próba: włącz opcję, zaakceptuj zgodę, pozostaw niską potrzebę i wyjdź z gry. Pierwszy możliwy termin jest po 30 minutach, między 09:00 a 21:00. Sprawdź otwarcie gry po dotknięciu komunikatu, anulowanie po powrocie oraz wyłączenie opcji. Nie zmieniaj ręcznie zapisu Glorii na potrzeby tego testu.
