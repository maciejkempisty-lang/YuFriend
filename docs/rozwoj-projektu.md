# Rozwój projektu YuFriend

[Mapa dokumentacji](README.md)

## Punkt wyjścia

Podstawowa pętla opieki, nauki i zapisu działa w lokalnym prototypie. 14 listopada 2026 wybrano pixel art i podłączono dostarczone 22 klipy / 142 klatki pakietu A+B. Następny krok to ocena gry w kilku krótkich sesjach i pierwszy eksport na telefon.

Odświeżony interfejs i dotykanie przedmiotów są wdrożone. Sprawdzono układy pionowe i szeroki panel boczny na komputerze z nowym psem. Pokój ma tło pixel art, stały świat 1440 × 480, sześć stacji, kamerę śledzącą i przesuwanie palcem. Głaskanie i trening przybliżają widok, a pies przechodzi przed i za przedmiotami. Nadal potrzebne są test na telefonie oraz ocena czytelności przy rzeczywistym skalowaniu. W dostawie pozostają drobne różnice proporcji między niezależnie narysowanymi klipami.

## Kolejność prac

| Priorytet | Zakres | Warunek ukończenia |
|---|---|---|
| P0 | Ocena dostarczonego pakietu A+B w grze | Komplet jest podłączony; dopracować proporcje na styku klipów i fazy chodu |
| Gotowe | Szeroki pokój i kamera | Jeden świat na około 2–3 ekrany, sześć stacji, ręczne przesuwanie, zbliżenia i płytka głębia |
| Gotowe | Opieka w przestrzeni pokoju | Dojście do miski i legowiska, pościg za piłką, sygnalizowanie potrzeb i automatyczne budzenie |
| P1 | Balans i czytelność | W kilku sesjach gracz rozumie potrzeby, odmowę próby, moment nagrody i różnicę po nauczeniu komendy |
| P1 | Pierwszy eksport mobilny | Można zagrać na wybranym fizycznym telefonie, wznowić aplikację i zachować stan po restarcie |
| P2 | Gesty, dźwięki i wibracje | Głaskanie przesunięciem palca, rzut piłki gestem, efekty przy animacjach i nagrodzie; weryfikacja na telefonie |
| P2 | Głębszy trening i więź | Ocena momentu nagrody, stopniowe ograniczanie pomocy, sekwencje, „zostań” i odblokowania więzi |
| P2 | Pierwsza sesja i powrót | Rytuał poznania i nadania imienia, zapowiedź nawyków, pora dnia w oknie; dopiero potem dobrowolne powiadomienia |
| P2 | Opcjonalne AI | Polecenia spoza słownika są mapowane na dozwolone działania, a brak sieci nie blokuje podstawowej gry |
| P3 | Dorastanie | Ten sam pies zmienia etap i wygląd, zachowując identyfikator, cechy, więź, wspomnienia i komendy |

Priorytety określają kolejność prac, nie terminy ani obietnicę gotowego wydania. Pierwotne szacunki programowania znajdują się w [planie implementacji](plan-implementacji.md); po podpięciu rzeczywistych materiałów można oszacować pozostały zakres ponownie.

## Integracja animacji — wykonane i dalsze poprawki

Pakiet dostarczony według [briefu](lista-spriteow-szczeniaka.md) działa w grze. Przy aktualizacji kolejnych arkuszy:

1. Sprawdzamy wspólne płótno, punkt podparcia, skalę i kierunek.
2. Importujemy tylko dostępne klipy zgodnie z [instrukcją](integracja-spriteow.md).
3. Dopasowujemy tempo przesunięcia do cyklu chodu i oglądamy przejścia między pozycjami.
4. Sprawdzamy komendy z naprowadzaniem i bez niego, czas nagrody oraz przerwanie próby.
5. Oglądamy również wejście/wyjście jedzenia, zasypianie i wybudzenie; zgodna liczba klatek nie gwarantuje zgodnych proporcji.

Jedzenie i zabawa mają 2 sekundy po dojściu do przedmiotu; animator kończy bieżące przejście przed następnym. Głaskanie reaguje na ponowne dotknięcie od razu, z ograniczeniem jedynie przyrostów. Sen zaczyna się w legowisku i kończy automatycznie przy energii 85. Przerwanie dojścia nie przyznaje efektów. `bark_stand` to powitanie po nieobecności, a `treat_take_stand` pokazuje przyjęcie nagrody na stojąco.

## Rozbudowa bez utraty postępu

Każda nowa potrzeba, komenda lub zmiana struktury danych wymaga zgodności ze starszym zapisem. Przejście z wersji 1 na 2 ma migrator, kopię wcześniejszego pliku i test odczytu starszego psa; kolejne zmiany schematu powinny dopisywać następny krok w ten sam sposób.

Warto zachować podział: `PetState` przechowuje dane, systemy obliczają efekty, sesja organizuje czynności, a widok prezentuje wynik. Nowy klip nie powinien sam przyznawać umiejętności. Rozbudowę kolejnych scen w edytorze można przeprowadzić stopniowo, zachowując te granice.

## Planowane AI

Obecna gra nie ma klienta AI ani backendu. Lokalna [osobowość i nawyki](osobowosc.md) mają już przygotowane miejsce na model: raz na dobę może on zastąpić lokalne reguły propozycją zmian cech i nawyków, którą gra sprawdza i ogranicza. Drugim możliwym zastosowaniem jest rozpoznawanie swobodnego polecenia i wybór krótkiej reakcji zgodnej z cechami psa. Decyzja o wykonaniu, postępie i nagrodzie pozostaje po stronie istniejącej logiki.

Docelowy przepływ:

```mermaid
flowchart LR
    Text["Polecenie gracza"] --> Local["Lokalny słownik"]
    Local -->|"znana komenda"| Session["GameSession i reguły gry"]
    Local -->|"nierozpoznany zwrot"| Backend["Planowany backend AI"]
    Backend --> Intent["Dozwolona intencja i propozycja reakcji"]
    Intent --> Session
```

Backend powinien przechowywać klucz dostawcy, kontrolować limity i zwracać ograniczony zestaw intencji. Gra potrzebuje ograniczenia czasu oczekiwania oraz powiązania odpowiedzi z aktualnym żądaniem, żeby spóźniona odpowiedź nie zmieniała nowej sytuacji. Kontekst może zawierać cechy i wybrane zapisane zdarzenia; model nie dopisuje do dziennika nieodbytych treningów.

Wybór dostawcy, modelu i hostingu jest otwarty. Obecny prototyp nie wykonuje płatnych wywołań. Przed integracją należy ustalić maksymalną liczbę zapytań na gracza i zmierzyć średni rozmiar kontekstu. Budżet techniczny będzie obejmował tokeny wejściowe i wyjściowe według wybranego cennika oraz utrzymanie backendu. Koszt będzie można oszacować po wyborze dostawcy i określeniu przewidywanego użycia.

## Dorastanie

Docelowe etapy to szczeniak, młody pies, dorosły pies i senior. Obecnie istnieje pole `life_stage`, ale nie ma automatycznej zmiany wieku, odrębnych zestawów grafik ani reguł tempa dorastania.

Przed implementacją trzeba ustalić, co wyzwala zmianę etapu: wspólnie spędzony czas, osiągnięcia czy decyzja gracza. Każdy etap potrzebuje własnych proporcji i zgodnych klipów. Zmiana grafiki zachowuje tożsamość psa i całą jego historię.

## Decyzje do podjęcia

| Decyzja | Kiedy będzie potrzebna |
|---|---|
| Docelowa siatka i paleta pixel art | Przed finalnym ręcznym dopracowaniem dostarczonych dużych arkuszy |
| Pierwsza platforma mobilna | Przed konfiguracją eksportu i testem na urządzeniu |
| Tempo potrzeb, regeneracji i nauki | Po kilku sesjach gry z czytelnymi animacjami |
| Zakres AI i limit kosztów | Przed przygotowaniem backendu i dostępu do dostawcy |
| Zasady dorastania | Przed zamówieniem kolejnych etapów grafiki i zmianą danych |

Konta, synchronizacja, wiele zwierząt, rozbudowa domu, sterowanie głosem i monetyzacja pozostają poza obecnym prototypem. Wymagają osobnej decyzji o zakresie. W tej iteracji nie dodano jeszcze gestów przesuwania, dźwięku, wibracji, nowych zasad treningu ani powiadomień. Ich kolejność warto potwierdzić po krótkich sesjach z testerami.
