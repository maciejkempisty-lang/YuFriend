# Picie w domu i przyjaźnie — 25 listopada 2026

Pakiet powstał **po instalacji buildu 39**. Nie jest jeszcze częścią aplikacji zainstalowanej na MagicPhone.

## Miska z wodą

Dotknięcie prawej miski, obok jedzenia, rozpoczyna dojście i picie. Lewa miska zachowuje karmienie. Gloria dochodzi od prawej strony, zwraca się do wody i korzysta z istniejących animacji wejścia, picia oraz zakończenia. Samo picie trwa 4,2 sekundy po dotarciu; ponowne dotknięcie miski przerywa czynność. Dojście ma limit 60 sekund.

Sen, zajęta aktywność, brak zapisu, pobyt na podwórku i tło blokują rozpoczęcie. Przejście w tło albo inna czynność bezpiecznie anuluje bieżące picie. Pierwsze ukończenie zapisuje wspomnienie „Świeża woda w domu”. Powtarzanie nie duplikuje wpisu ani nie przyznaje punktów więzi. Tak jak picie na podwórku jest to spokojny rytuał — bez nowego wskaźnika pragnienia i obowiązku pojenia podczas nieobecności.

## Goście i interakcje

Dotknięcie pojawiającego się ptaka, motyla lub kota sąsiada otwiera menu. Ten sam dostęp zapewnia przycisk **Gość**, obok dotychczasowych **Spokojnie** i **Przyjdź**.

- **Przywitaj się spokojnie:** trzysekundowe, łagodne powitanie. Ostrożny pies nadal zachowuje dystans.
- **Pobądźcie razem:** sześć sekund wspólnej chwili; dostępne po pierwszym ukończonym spokojnym spotkaniu.
- Gość, który odszedł podczas czytania menu, nie może otrzymać spóźnionej akcji. Menu zamyka się po zakończeniu wizyty. Trwającej odpowiedzi nie da się uruchomić drugi raz.

Goście nadal korzystają z dotychczasowej rotacji, limitów odwiedzin oraz warunków pory dnia, energii i dostępności psa. Nie dodano kolejnego generatora NPC.

## Rozwój przyjaźni

Wykorzystujemy `VisitorMemory`: maksymalnie jeden spokojny dzień dla danego gościa, trzy różne dni do poziomu **Przyjaciel**. Powitanie, wspólna chwila, dotychczasowe uspokojenie i udane przywołanie rozwijają tę samą pamięć. Wcześniejsze spotkania są uznawane; nie zaczynamy relacji od zera. Po ukończeniu spokojnej interakcji na trzecim poziomie pojawia się jednorazowe wspomnienie „Nowa przyjaźń”. Stan znajomości jest widoczny w menu NPC i istniejącej sekcji gości w Albumie.

Brak odpowiedzi, przerwanie, nieobecność ani cofnięcie zegara nie odbierają przyjaźni. Powtórzenia tego samego dnia nie przyspieszają rozwoju. Nieudany zapis przywraca poprzedni stan pamięci. Schemat psa nadal v17; używamy istniejących osiągnięć i Albumu, bez dodatkowego pliku relacji.

## Weryfikacja

Testy `test_home_friends.gd` i `ui_home_friends.gd` obejmują dojście i picie, ukończenie oraz przerwanie, sen, osobne miski, restart zapisu, powitania, trzy różne dni przyjaźni, brak wielokrotnych nagród i menu na 320/390 px. Testy wykonano na odseparowanych zapisach. Fizyczna próba nowych funkcji pozostaje do następnego buildu.


Wyniki: **41/41 zestawów logiki**. Pełny przebieg UI 36/37; test starego zaproszenia do piłki wymagał jawnego przywrócenia fokusu fixture po zamknięciu natywnego profilu. Końcowa powtórka: **46/46** sprawdzeń dotychczasowych zabaw oraz **24/24** nowego UI. Łącznie wszystkie **37 zestawów UI** zaliczone z powtórką. Obejrzano picie i menu NPC przy szerokościach 320 i 390 px. Logi oraz zrzuty: `exports/home-friends-2026-11-25/`.
