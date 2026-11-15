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
| Zabawy dotykiem | Rzut piłki z podglądem łuku, sześć pociągnięć liny i śledzenie smakołyka pod kubkami |
| Inicjatywa | Zaproszenia do czterech aktywności, pamięć reakcji i sekcja „Wasz rytm” w karcie psa |
| Trening | Przyjdź, siad, podaj łapę; pomoc gestem i samodzielna próba |
| Charakter | Cztery cechy losowane przy tworzeniu psa, niewielki dryf po aktywnych dniach, nabywane nawyki i stała ulubiona nagroda |
| Relacja | Więź oraz dziennik pierwszych zdarzeń i osiągnięć |
| Polecenia tekstowe | Zamknięty słownik polskich zwrotów, działający lokalnie |
| Wygląd | Jeden styl pixel art; podłączone 22 klipy / 142 klatki |
| Dane | Lokalny zapis JSON, poprzednia poprawna kopia, przeliczanie nieobecności |

Prototyp sprawdzono na macOS. Interfejs ma układ pionowy z myślą o telefonie oraz układ z panelem bocznym dla szerokiego okna. Starsza wersja działa już na testowym iPhonie; ta przebudowa interfejsu została dotąd sprawdzona na pulpicie i w symulowanych układach telefonu.

## Ekrany i sterowanie

Pokój zajmuje całą wysokość, a nagłówek, opieka i nawigacja pływają nad nim. W podstawowym widoku 390 × 844 około 75% wysokości znajduje się nad panelem opieki. Imię otwiera kartę psa, widoczna liczba i pasek pokazują więź, a zębatka prowadzi do ustawień dźwięku. Marginesy uwzględniają bezpieczny obszar urządzenia.

Jeden rząd pięciu przycisków łączy stan z akcją. Obwódka i procent pokazują poziom potrzeby: zielony od 60%, bursztynowy przy 30–59%, czerwony poniżej 30%. Niska potrzeba zmienia także podpis (np. „Głodny”). Wypełnienie ubywa w czasie oczekiwania; pozostałe sekundy są widoczne w przycisku. Podczas czynności wiersz statusu wyjaśnia, na co czekamy. Dotknięcie niedostępnej chwilowo opieki nadal daje wyjaśnienie.

| Miejsce | Działanie gracza |
|---|---|
| Dom | Nakarm, drzemka/obudź, wyczesz, pobaw się i pogłaszcz; każdy przycisk pokazuje odpowiadającą potrzebę |
| Trening | Wybór komendy i przełącznik z podpowiedzią / bez; trzy kroki z ikonami oraz kurczące się obwódki nagród |
| Album | Pełnoekranowa karta rzeczywistych wydarzeń, z datami i ikonami rodzaju wpisu |
| Imię | Karta psa: zmiana imienia, cechy jako paski, nawyki jako odznaki i odkryte preferencje |
| Zębatka | Osobne przełączniki muzyki i efektów, zapisywane od razu |
| Ikona klawiatury w treningu | Wpisanie rozpoznawanego zwrotu uruchamia samodzielną próbę |

Dotknięcie psa oznacza głaskanie, miski — karmienie, piłki — zabawę, a legowiska — odpoczynek lub budzenie. Drobne znaczniki dłoni wskazują dotykalne przedmioty. Miska i piłka mają strefy dotyku co najmniej 48 × 48 jednostek interfejsu. Stuknięty przedmiot krótko podskakuje. Wolna podłoga wskazuje cel spaceru, a przeciągnięcie poza piłką przesuwa kamerę bez wykonywania opieki. Przeciągnięcie piłki pokazuje łuk i pozwala ją rzucić. Przycisk „Pobaw się” otwiera również linę oraz kubki; wskazówki sterowania są w każdej zabawie. Wskazówka przesuwania znika po pierwszym geście i zapamiętuje ten stan.

Po rzeczywistym naliczeniu opieki nad psem unosi się przyrost potrzeby, a obwódka błyska. To wartość po ograniczeniu do 100%, bez dodatkowego przyrostu przy ponownym głaskaniu w czasie oczekiwania. Dymki podążają za psem i znikają po 3,5–6 sekundach. Dłuższe wiadomości pozostają dla wydarzeń i wyjaśnień. W treningu żaden rodzaj nagrody nie jest preferowany wizualnie, dopóki gracz nie odkryje ulubionej nagrody w udanej próbie.

Podczas treningu nagłówek jest niższy (68 zamiast 100 jednostek), a panel ma 274 zamiast 370 jednostek wysokości. Wybór komendy i klawiatura dzielą jeden wiersz, a kroki mają kompaktowe ikony. Komunikaty o próbie i przyrost opanowania pojawiają się wewnątrz panelu; nad psem nie ma wtedy dymka ani unoszącego się napisu. Przyciski nagród zachowują dotychczasowy rozmiar.

Zapis odbywa się automatycznie. Ostrzeżenie o nieudanym zapisie lub problemie z odczytem ma własne miejsce nad nawigacją, aby nie zasłaniać akcji.

## Co oznacza obecny wygląd psa

Gra korzysta z pełnego pakietu A+B w stylu pixel art. Animacje mają widok boczny z pyskiem w prawo i odbicie w lewo. Import zachowuje czasy klatek, a oddzielna kalibracja zmniejsza różnice skali i podparcia. Oryginalne obrazy pozostają zachowane. Starsze zapisy używają tej samej prezentacji, zachowując psa i postępy.

Dostarczone obrazy są dużymi arkuszami stylizowanymi na pixel art, bez jednolitej małej siatki. Drobne różnice proporcji między klipami nadal wymagają korekty. Osiem klipów pakietu A obejmuje podstawowy ruch i trening. Czternaście klipów pakietu B rozszerza opiekę i reakcje. Szczegóły określa [brief](lista-spriteow-szczeniaka.md).

## Dalszy zakres

Kolejne etapy obejmują pełne animacje, dopasowanie przedmiotów, dźwięki, testy na telefonie, więcej zachowań i sztuczek. Docelowo ten sam pies może przejść przez etapy młodego psa, dorosłości i seniora, zachowując tożsamość i postęp.

Opcjonalne AI ma rozszerzyć rozumienie poleceń i reakcje zgodne z charakterem. Obecny temperament i nauka komend są obliczane przez kod gry. Aplikacja nie korzysta z modelu językowego, kont użytkowników, płatności ani synchronizacji w chmurze.

Kolejność i warunki ukończenia tych prac opisuje [plan rozwoju](rozwoj-projektu.md).
