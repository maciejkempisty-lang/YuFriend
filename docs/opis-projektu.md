# Opis projektu YuFriend

[Mapa dokumentacji](README.md)

## Cel gry

Gracz opiekuje się jednym psem i stopniowo poznaje jego temperament. Krótkie sesje łączą codzienne rytuały z uczeniem sztuczek. Punktem wyjścia dla postaci jest golden retriever użytkownika jako szczeniak: jasna sierść, ciemniejsze opadające uszy, grzywka, ciemne oczy i jasne końce łap.

Pies zachowuje imię, cechy, preferencję nagrody, więź i zdobyte umiejętności po ponownym uruchomieniu. Długa nieobecność nie usuwa zwierzaka ani wyuczonych komend. Potrzeby przeliczają się łagodnie i mają ograniczony zakres spadku.

## Podstawowa pętla rozgrywki

1. Gracz sprawdza potrzeby i obserwuje pieska w pokoju.
2. Wybiera jedzenie, kontakt, zabawę, pielęgnację lub odpoczynek.
3. Rozpoczyna krótkie ćwiczenie z naprowadzaniem albo prosi o samodzielne wykonanie.
4. Po poprawnej próbie nagradza psa w wyznaczonym czasie.
5. Rosną opanowanie komendy i więź, a ważne pierwsze zdarzenia trafiają do wspomnień.

Naprowadzanie pozwala bezpiecznie rozpocząć naukę nieznanej komendy. Samodzielna próba zależy od opanowania, więzi i zmęczenia. Wybranie ulubionej nagrody daje dodatkowy postęp.

## Zakres obecnego prototypu

| Obszar | Obecne zachowanie |
|---|---|
| Postać | Jeden szczeniak, domyślnie Biszkopt; imię można zmienić |
| Pokój | Tło pixel art z oknem, rośliną i drewnianą podłogą; osobny pikselowy dywan oraz dotykowe legowisko, miska i piłka |
| Ruch | Chodzenie w lewo i prawo do wskazanego miejsca; okazjonalne samodzielne spacery |
| Potrzeby | Sytość, energia, czystość, zabawa i bliskość |
| Opieka | Jedzenie, głaskanie, zabawa, czesanie, odpoczynek i budzenie |
| Trening | Przyjdź, siad, podaj łapę; pomoc gestem i samodzielna próba |
| Charakter | Cztery cechy losowane przy tworzeniu psa, niewielki dryf po aktywnych dniach, nabywane nawyki i stała ulubiona nagroda |
| Relacja | Więź oraz dziennik pierwszych zdarzeń i osiągnięć |
| Polecenia tekstowe | Zamknięty słownik polskich zwrotów, działający lokalnie |
| Wygląd | Jeden styl pixel art; podłączone 22 klipy / 142 klatki |
| Dane | Lokalny zapis JSON, poprzednia poprawna kopia, przeliczanie nieobecności |

Prototyp sprawdzono na macOS. Interfejs ma układ pionowy z myślą o telefonie oraz układ z panelem bocznym dla szerokiego okna. Wydanie i testy na fizycznym urządzeniu mobilnym są jeszcze przed nami.

## Ekrany i sterowanie

Głównym elementem ekranu jest pies w pokoju. Nad nim widać imię, opis relacji i pięć okrągłych wskaźników potrzeb. Poniżej znajdują się komunikat, panel bieżącej zakładki i stała nawigacja **Dom / Trening / Album**. Akcje mieszczą się bez przewijania całego ekranu; przewijana jest lista wspomnień w albumie. W szerokim oknie informacje o psie i sterowanie tworzą panel obok pokoju.

Wskaźniki pokazują poziom zaspokojenia potrzeb; poniżej 30% zmieniają kolor. Dokładna wartość jest dostępna w podpowiedzi po najechaniu i w nazwie dostępności kontrolki. Opis więzi zmienia się z „Poznajecie się” przez „Coraz bliżej” na „Najlepsi przyjaciele”.

| Miejsce | Działanie gracza |
|---|---|
| Dom | Podpisane ikony: jedzenie, głaskanie, zabawa, czesanie, drzemka; przycisk przejścia do treningu |
| Trening | Wybór komendy, „Pokaż gest” lub „Samodzielnie”; po rozpoczęciu próby w tym samym miejscu pojawiają się nagrody, dostępne po wykonaniu sztuczki |
| Album | Faktycznie zapisane wydarzenia z datą, od najnowszego |
| Ustawienia obok imienia | Profil: zmiana imienia, cechy, nawyki i ulubiona nagroda |
| Ikona klawiatury w treningu | Wpisanie rozpoznawanego zwrotu, który uruchamia samodzielną próbę |

Pokój również jest interaktywny: dotknięcie pieska oznacza głaskanie, miski — karmienie, piłki — zabawę, a legowiska — odpoczynek lub budzenie. Dotknięcie wolnej podłogi wskazuje cel spaceru. Są to pojedyncze dotknięcia; głaskanie przesuwaniem palca i rzucanie piłki gestem pozostają dalszym pomysłem.

Po rozpoczęciu czynności część przycisków jest czasowo zablokowana. Komunikat wskazuje, czy trzeba poczekać, odpocząć, nakarmić psa albo nauczyć go podstaw siadu.

Zapis odbywa się automatycznie. Ostrzeżenie o nieudanym zapisie lub problemie z odczytem ma własne miejsce nad nawigacją, aby nie zasłaniać akcji.

## Co oznacza obecny wygląd psa

Gra korzysta z pełnego pakietu A+B w stylu pixel art. Animacje mają widok boczny z pyskiem w prawo i odbicie w lewo. Import zachowuje czasy klatek, a oddzielna kalibracja zmniejsza różnice skali i podparcia. Oryginalne obrazy pozostają zachowane. Starsze zapisy używają tej samej prezentacji, zachowując psa i postępy.

Dostarczone obrazy są dużymi arkuszami stylizowanymi na pixel art, bez jednolitej małej siatki. Drobne różnice proporcji między klipami nadal wymagają korekty. Osiem klipów pakietu A obejmuje podstawowy ruch i trening. Czternaście klipów pakietu B rozszerza opiekę i reakcje. Szczegóły określa [brief](lista-spriteow-szczeniaka.md).

## Dalszy zakres

Kolejne etapy obejmują pełne animacje, dopasowanie przedmiotów, dźwięki, testy na telefonie, więcej zachowań i sztuczek. Docelowo ten sam pies może przejść przez etapy młodego psa, dorosłości i seniora, zachowując tożsamość i postęp.

Opcjonalne AI ma rozszerzyć rozumienie poleceń i reakcje zgodne z charakterem. Obecny temperament i nauka komend są obliczane przez kod gry. Aplikacja nie korzysta z modelu językowego, kont użytkowników, płatności ani synchronizacji w chmurze.

Kolejność i warunki ukończenia tych prac opisuje [plan rozwoju](rozwoj-projektu.md).
