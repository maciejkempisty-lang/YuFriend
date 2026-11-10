# Dokumentacja projektu YuFriend

YuFriend to gra o opiece nad szczeniakiem golden retrievera, budowaniu więzi i uczeniu komend. Ten zestaw opisuje działający prototyp Godot oraz kolejne kroki jego rozwoju. Stan dokumentacji: **10 listopada 2026**.

Pierwsza wersja działa lokalnie na Macu. Ma potrzeby, temperament, trening, wspomnienia i zapis. Użytkownik przygotowuje klatki animacji; obecnie pies korzysta z ilustracji zastępczych. AI, dorastanie i wydanie na telefon należą do dalszego zakresu.

## Mapa dokumentacji

| Dokument | Co w nim znajdziesz |
|---|---|
| [Opis projektu](opis-projektu.md) | Cel gry, zakres prototypu, ekrany i sposób rozgrywki |
| [Architektura](architektura.md) | Moduły, przepływ zdarzeń i połączenie logiki z animacjami |
| [Mechaniki gry](mechaniki-gry.md) | Potrzeby, temperament, trening, nagrody i aktualne parametry balansu |
| [Model danych i zapis](model-danych-i-zapis.md) | Format JSON, walidacja, kopie, odzyskiwanie i upływ czasu |
| [Uruchomienie i testy](uruchomienie-i-testy.md) | Praca z projektem, oddzielny zapis testowy, testy i diagnoza problemów |
| [Rozwój projektu](rozwoj-projektu.md) | Priorytety, kryteria ukończenia, decyzje otwarte i planowane AI |
| [Lista sprite’ów szczeniaka](lista-spriteow-szczeniaka.md) | Brief 22 animacji, pozy, kierunki i kolejność produkcji |
| [Integracja sprite’ów](integracja-spriteow.md) | Foldery PNG, manifest, importer i podpinanie częściowych zestawów |
| [Pierwotny plan implementacji](plan-implementacji.md) | Szersza koncepcja oraz początkowe szacunki zakresu i czasu pracy |

## Od czego zacząć

- Aby zagrać: [szybkie uruchomienie](../README.md), potem opis treningu w [mechanikach](mechaniki-gry.md).
- Aby przygotować grafikę: [brief sprite’ów](lista-spriteow-szczeniaka.md), potem [integracja](integracja-spriteow.md).
- Aby rozwijać kod: [architektura](architektura.md), [dane](model-danych-i-zapis.md) i [testy](uruchomienie-i-testy.md).
- Aby ustalić następny zakres: [rozwój projektu](rozwoj-projektu.md).

## Utrzymywanie dokumentacji

Opisy architektury, mechanik i danych dotyczą obecnej implementacji. W dokumencie rozwoju oraz pierwotnym planie funkcje przyszłe są oznaczone jako planowane. Przy zmianie zachowania gry aktualizujemy odpowiedni opis razem z kodem.

Parametry mechanik są zebrane w jednym dokumencie; format PNG i manifestu opisuje instrukcja integracji. Nie zmieniamy nazw komend, klipów ani pól zapisu tylko w dokumentacji — muszą pozostać zgodne z kodem i dostarczanymi materiałami. Wyniki testów zawsze odnosimy do daty uruchomienia.
