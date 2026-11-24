# Dokumentacja projektu YuFriend

YuFriend to gra o opiece nad szczeniakiem golden retrievera, budowaniu więzi i uczeniu komend. Ten zestaw opisuje działający prototyp Godot oraz kolejne kroki jego rozwoju. Dalsze kroki po buildzie **28**, 17 listopada 2026: [preferencje Glorii, spokojne rytuały, pory roku, spacer i Album](rozwoj-projektu.md#dalsze-kroki-po-buildzie-28--17-listopada-2026). Najbliższy pakiet obejmuje preferencje i spokojne chwile razem; to plan, nie funkcje już wdrożone. Starsze etapy zachowano jako historię.

Pierwsza wersja działa lokalnie na Macu. Ma potrzeby, temperament, trening, wspomnienia i zapis. Dostarczony pakiet A+B obejmuje 22 klipy i 142 klatki; gra używa pixel art. Integrację i ograniczenia jakości opisuje [instrukcja sprite’ów](integracja-spriteow.md). Wersja testowa jest zainstalowana na iPhonie; AI, dorastanie i wydanie sklepowe należą do dalszego zakresu.

Aktualizacja interfejsu: pokój na całą wysokość, jeden rząd przycisków łączących opiekę z poziomami potrzeb, widoczna więź, znikające dymki i przyrosty, trening prowadzony ikonami, karta psa pod imieniem oraz osobne ustawienia pod zębatką. Album zajmuje pełny ekran. Sterowanie opisuje [opis projektu](opis-projektu.md#ekrany-i-sterowanie), a zakres weryfikacji — [uruchomienie i testy](uruchomienie-i-testy.md#testy-automatyczne).

Etap 2 dodaje zaproszenia Glorii, pamięć reakcji w karcie psa oraz trzy zabawy dotykiem: piłkę, linę i kubki. [Zasady zabaw](mechaniki-gry.md#zabawy-dotykiem) i [pamięć reakcji](osobowosc.md#własna-inicjatywa-i-pamięć-reakcji--etap-2) opisują bieżący zakres.

## Mapa dokumentacji

| Dokument | Co w nim znajdziesz |
|---|---|
| [Opis projektu](opis-projektu.md) | Cel gry, zakres prototypu, ekrany i sposób rozgrywki |
| [Architektura](architektura.md) | Moduły, przepływ zdarzeń i połączenie logiki z animacjami |
| [Mechaniki gry](mechaniki-gry.md) | Potrzeby, temperament, trening, nagrody i aktualne parametry balansu |
| [Odpoczynek na podwórku](odpoczynek-na-podworku.md) | Cień, miska z wodą, animacja picia i samodzielne przerwy |
| [Mały tor przeszkód](tor-przeszkod.md) | Slalom, skok, Zostań i wspólny trening |
| [Minigierki — propozycje](minigry-propozycje.md) | Plan: zabawy wymagające refleksu i uwagi, ocena rund, kolejność wdrażania (niewdrożone) |
| [Samopoczucie i dolegliwości](samopoczucie-i-dolegliwosci.md) | Samopoczucie i przytulanie: wdrożenie lokalne, ochrona przed pogorszeniem po nieobecności; dolegliwości pozostają planem |
| [Pogoda i zaproszenia](pogoda-i-zaproszenia.md) | Lokalny deszcz, podlewanie ogródka i samodzielne propozycje zabawy |
| [Kałuża i zraszacz](woda-na-podworku.md) | Pluskanie, brudzenie sierści, otrzepywanie, grafika i połączenie z kąpielą |
| [Cykl zachowań](cykl-zachowan.md) | Rytm dnia, noc, adaptacja, wybór ważony i sekwencje |
| [Osobowość i nawyki](osobowosc.md) | Dziennik zdarzeń, dryf cech, nawyki i miejsce na AI |
| [Model danych i zapis](model-danych-i-zapis.md) | Format JSON, walidacja, kopie, odzyskiwanie i upływ czasu |
| [Uruchomienie i testy](uruchomienie-i-testy.md) | Praca z projektem, oddzielny zapis testowy, testy i diagnoza problemów |
| [Rozwój projektu](rozwoj-projektu.md) | Priorytety, kryteria ukończenia, decyzje otwarte i planowane AI |
| [Lista sprite’ów szczeniaka](lista-spriteow-szczeniaka.md) | Brief 22 animacji, pozy, kierunki i kolejność produkcji |
| [Integracja sprite’ów](integracja-spriteow.md) | Foldery PNG, manifest, importer i podpinanie częściowych zestawów |
| [Dźwięk](../assets/audio/sfx/README.md) | Muzyka, efekty ElevenLabs, źródła i obróbka |
| [Test iOS](test-ios.md) | Instalacja i aktualizacje na fizycznym iPhonie |
| [Widget iOS](widget-ios.md) | Rozmiary widgetu, stan psa, App Groups, eksport i testy |
| [Powiadomienia iOS](powiadomienia-ios.md) | Dobrowolne przypomnienia, cisza nocna, limit dzienny i testy |
| [Pierwotny plan implementacji](plan-implementacji.md) | Szersza koncepcja oraz początkowe szacunki zakresu i czasu pracy |

## Od czego zacząć

- Aby zagrać: [szybkie uruchomienie](../README.md), potem opis treningu w [mechanikach](mechaniki-gry.md).
- Aby przygotować grafikę: [brief sprite’ów](lista-spriteow-szczeniaka.md), potem [integracja](integracja-spriteow.md).
- Aby rozwijać kod: [architektura](architektura.md), [dane](model-danych-i-zapis.md) i [testy](uruchomienie-i-testy.md).
- Aby ustalić następny zakres: [rozwój projektu](rozwoj-projektu.md).

## Utrzymywanie dokumentacji

Opisy architektury, mechanik i danych dotyczą obecnej implementacji. W dokumencie rozwoju oraz pierwotnym planie funkcje przyszłe są oznaczone jako planowane. Przy zmianie zachowania gry aktualizujemy odpowiedni opis razem z kodem.

Parametry mechanik są zebrane w jednym dokumencie; format PNG i manifestu opisuje instrukcja integracji. Nie zmieniamy nazw komend, klipów ani pól zapisu tylko w dokumentacji — muszą pozostać zgodne z kodem i dostarczanymi materiałami. Wyniki testów zawsze odnosimy do daty uruchomienia.

- [Lina 2.0 — zasady prototypu i zapis rekordów](lina-2.md)

## Grafika i dodatkowe eksporty

- [Plan rozwoju grafiki i referencje](rozwoj-grafiki.md) — aktualny zakres, makiety oraz zaadaptowane menu obiektów.
- [Testowy eksport Androida](android.md) — osobny preset i skrypt eksportu APK.

- [Przegląd menu ogrodu po scaleniu](przeglad-menu-ogrodu-2026-11-24.md) — regresja dotyku, dostępności akcji i trwających zabaw.
