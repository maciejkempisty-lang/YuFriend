# Mechaniki gry YuFriend

[Mapa dokumentacji](README.md)

Wartości poniżej opisują prototyp z 10 listopada 2026. Są parametrami do dalszego sprawdzenia w rozgrywce. Ich źródłami są [NeedsSystem](../scripts/systems/needs_system.gd), [TrainingSystem](../scripts/systems/training_system.gd), [GameSession](../scripts/systems/game_session.gd) i [PetState](../scripts/model/pet_state.gd).

## Potrzeby

Wysoki wskaźnik oznacza zaspokojoną potrzebę. Zmiany zachodzą proporcjonalnie do czasu `delta`, a nie liczby klatek.

| Potrzeba | Klucz danych | Wartość początkowa | Pasywny spadek na godzinę |
|---|---|---:|---:|
| Sytość | `fullness` | 78 | 7 |
| Energia | `energy` | 76 | 5 |
| Czystość | `hygiene` | 85 | 3 |
| Zabawa | `play` | 58 | 7 |
| Bliskość | `contact` | 65 | `5 × (0,7 + 0,6 × sociability)` |

Pasywna aktualizacja ogranicza potrzeby do 15–100. Jednorazowe efekty czynności są ograniczane do 0–100, więc dolna granica pasywnej aktualizacji nie jest globalną walidacją każdej zmiany. Gra nie usuwa psa ani umiejętności przy niskich potrzebach.

Podczas nieobecności symulowane jest najwyżej 8 godzin. Zasady czasu i wznowienia opisuje [zapis danych](model-danych-i-zapis.md).

## Działania opiekuna

Efekty opieki są naliczane przy zaakceptowaniu działania. Zwykła czynność blokuje kolejną przez 2 sekundy, a jej osobny czas ponownego użycia biegnie od rozpoczęcia. Obecny czas opieki jest stały; pełne dopasowanie do ruchów pyska i przedmiotów nastąpi przy integracji sprite’ów.

Ikony w zakładce Dom i dotknięcia psa, miski, piłki lub legowiska wywołują te same działania sesji. Korzystają z tych samych blokad i czasów ponownego użycia.

| Działanie | Klucz | Efekt | Ponowne użycie |
|---|---|---|---:|
| Jedzenie | `feed` | Sytość +22 | 10 s |
| Głaskanie | `pet` | Bliskość +18, zabawa +3, więź +0,6 | 4 s |
| Zabawa | `play` | Zabawa +24, bliskość +8, energia −5, czystość −3 | 8 s |
| Czesanie | `clean` | Czystość +25, bliskość +5 | 12 s |
| Odpoczynek / budzenie | `rest` | Przełącza trwałe pole `resting` | Bez osobnego czasu ponownego użycia |

W odpoczynku przyrost energii wynosi 0,8 punktu na sekundę aktywnej gry lub 18 punktów na godzinę nieobecności. W tym samym czasie działa zwykły pasywny ubytek energii. Pies pozostaje w odpoczynku do wybudzenia przez gracza, także po osiągnięciu pełnej energii.

Sesja odmawia czynności, gdy trwa trening, ruch lub inna aktywność. Śpiącego psa trzeba obudzić przed opieką i treningiem. Przy problemie z odczytem zapisu zmiany stanu są zablokowane.

## Temperament i zachowania samodzielne

Przy tworzeniu psa każda cecha jest losowana w zakresie 0,25–0,85 na podstawie zapisanego ziarna. Wczytanie korzysta z zapisanych wartości, zamiast losować je ponownie.

| Cecha | Wpływ |
|---|---|
| `curiosity` — ciekawość | Szansa rozpoczęcia spaceru podczas decyzji o samodzielnej aktywności |
| `patience` — cierpliwość | Czas reakcji podczas ćwiczenia oraz długość okna nagrody |
| `sociability` — towarzyskość | Tempo spadku zaspokojenia potrzeby bliskości |
| `sensitivity` — wrażliwość | Siła rozproszenia powodowanego zmęczeniem przy samodzielnej próbie |

Osobno losowana jest ulubiona nagroda: `treat`, `praise` albo `play`. Preferencja nie zmienia się w obecnej wersji.

Pierwsza decyzja o samodzielnej aktywności następuje po 8 sekundach bezczynności, kolejne co 9–15 sekund bezczynności. Gdy energia jest poniżej 28, pies rozpoczyna odpoczynek. W przeciwnym razie może wybrać spacer zależnie od ciekawości. Te decyzje nie przerywają opieki ani treningu.

## Warunki rozpoczęcia treningu

Trening wymaga obudzonego psa, energii co najmniej 25, sytości co najmniej 25 i zmęczenia poniżej 75. Nie może jednocześnie trwać inna próba ani czynność. Podanie łapy wymaga dodatkowo opanowania siadu na poziomie co najmniej 25%.

| Komenda | Identyfikator | Prezentacja udanej próby |
|---|---|---|
| Przyjdź | `come` | Chód do logicznego celu `0,62`; widok mapuje go na pokój z marginesem na sylwetkę psa |
| Siad | `sit` | Przejście do siadu |
| Podaj łapę | `paw` | Przejście do siadu, jeśli potrzebne, i `give_paw` |

Każda zaakceptowana próba zwiększa `attempts`, dodaje 12 punktów zmęczenia i odejmuje 2 punkty energii. Dotyczy to także próby później nieudanej lub przerwanej. Samo rozpoczęcie nie zwiększa opanowania.

## Wynik i czas próby

Naprowadzanie gestem gwarantuje poprawne wykonanie po spełnieniu warunków rozpoczęcia. Samodzielna próba jest losowa. Szansa jest wyliczana ze stanu sprzed doliczenia kosztu bieżącej próby:

```text
rozproszenie = fatigue × (0.0008 + sensitivity × 0.0012)
szansa = clamp(0.16 + mastery × 0.007 + bond × 0.001 − rozproszenie, 0.12, 0.96)
```

`mastery`, `bond` i `fatigue` mają skalę 0–100, a `sensitivity` 0–1. Przykład: opanowanie 50, więź 20, zmęczenie 20 i wrażliwość 0,5 dają szansę 50,2%. Nawet 100% opanowania nie oznacza wykonania przy każdej samodzielnej próbie.

Minimalny czas reakcji wynosi `2 + (1 − patience) × 0,4` sekundy; dla łapy bazą jest 2,8 zamiast 2. Gra czeka także na zakończenie animacji, a przy przywołaniu na dotarcie do celu. Dłuższa animacja nie zużywa wcześniej okna nagrody.

Fazy treningu to `idle` → `attempt` → `reward` → `idle`. Niewykonanie komendy wraca bezpośrednio z `attempt` do `idle`. Nieudana próba pokazuje zaciekawienie zamiast właściwej sztuczki. Wstrzymanie aplikacji anuluje bieżącą próbę.

## Nagrody i postęp

Po udanej próbie okno nagrody trwa `2,7 + patience × 0,7` sekundy. Można nagrodzić tylko raz, w fazie `reward`. Zbyt wczesne, późne lub powtórzone kliknięcie nie nalicza postępu. Niewykorzystana okazja wygasa bez zmiany opanowania.

| Sposób próby | Zwykła nagroda | Ulubiona nagroda |
|---|---:|---:|
| Z naprowadzaniem | Opanowanie +8, więź +1 | Opanowanie +10, więź +1,5 |
| Samodzielnie | Opanowanie +12, więź +1 | Opanowanie +14, więź +1,5 |

Smakołyk dodatkowo zwiększa sytość o 2, pochwała bliskość o 4, a zabawa potrzebę zabawy o 4. Opanowanie i więź są ograniczone do 100. Udana nagroda zwiększa licznik `successes`; jest to licznik **nagrodzonych prób**, nie wszystkich poprawnych ruchów psa.

Interfejs opisuje opanowanie jako „Poznaje gest” poniżej 25%, „Ćwiczy z Tobą” od 25% do wartości poniżej 75% oraz „Coraz pewniej” od 75%. Pierwsza nagrodzona próba i przekroczenie 75% dodają jednorazowe wspomnienia.

## Zmęczenie i więź

Zmęczenie rozpoczyna się od 0 i spada o 0,08 punktu na sekundę, a podczas odpoczynku o 0,35. Przy przeliczaniu nieobecności używane są te same stawki na sekundę, z ograniczeniem czasu do 8 godzin. Wskaźnik „Skupienie” w interfejsie wynosi `100 − fatigue`.

Więź zaczyna się od 12. Rosną ją głaskanie i nagrody; obecna wersja nie zmniejsza więzi za nieobecność. Zmęczenie nie usuwa zdobytych umiejętności.

## Polecenia tekstowe i wspomnienia

[LocalCommands](../scripts/services/local_commands.gd) ignoruje wielkość liter, usuwa zewnętrzne białe znaki, polskie znaki diakrytyczne oraz znaki `! ? . ,`. Potem porównuje cały zwrot ze słownikiem:

| Komenda | Rozpoznawane zwroty |
|---|---|
| Przyjdź | przyjdź, do mnie, chodź, chodź tutaj |
| Siad | siad, usiądź, siadaj |
| Podaj łapę | łapa, daj łapę, podaj łapę |

Wpisanie zwrotu uruchamia samodzielną próbę z tymi samymi warunkami co przycisk. Dłuższa swobodna wypowiedź, np. „proszę, usiądź obok mnie”, nie jest obecnie interpretowana.

Dziennik obejmuje powitanie, pierwsze czynności opieki, pierwsze nagrodzone próby i osiągnięcia 75%. Przechowuje maksymalnie 40 wpisów, od najnowszego. Identyfikatory osiągnięć w `milestones` zapobiegają powtórzeniu wpisu nawet po usunięciu go z krótszego dziennika.
