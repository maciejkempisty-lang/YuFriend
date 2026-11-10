# Plan implementacji YuFriend z golden retrieverem

Wstępny plan z 10 listopada 2026. Celem pierwszego prototypu jest opieka nad jednym szczeniakiem golden retrievera, wzorowanym na zdjęciu psa użytkownika. Pies samodzielnie porusza się po pokoju, zachowuje trwały temperament i uczy się trzech komend: „przyjdź”, „siad” oraz „podaj łapę”.

Aktualny opis działającego kodu znajduje się w [mapie dokumentacji](README.md). Ten plan zachowuje pierwotny zakres i szacunki; bieżącą kolejność dalszych prac opisuje [rozwój projektu](rozwoj-projektu.md).

Projekt przyjmuje grę 2D na telefon w orientacji pionowej, sterowanie dotykiem i jedną scenę pokoju. Podstawowa opieka, trening i zapis działają lokalnie. AI dołączymy po sprawdzeniu, czy sama zabawa i nauka sztuczek są interesujące. Pierwsze uruchomienia mogą odbywać się na komputerze; test eksportu na fizyczny telefon jest częścią pierwszego etapu.

## Stan po uruchomieniu prototypu

10 listopada 2026 powstał lokalny prototyp w Godot 4.7.2: pionowy interfejs, rysowany pokój, poruszanie psa, pięć potrzeb, opieka, losowany i zapisywany temperament, trzy komendy z nagrodą, dziennik, profil i przełączanie ilustracji/pixel art. Zapis jest wersjonowany, z walidacją, kopią i ograniczonym przeliczaniem nieobecności. Polecenia tekstowe działają przez lokalny słownik.

Interfejs został następnie przebudowany: pokój zajmuje większą część ekranu, nawigacja obejmuje Dom / Trening / Album, opieka działa także przez dotknięcie psa i przedmiotów, a szerokie okno otrzymało panel boczny. Aktualny opis obsługi znajduje się w [opisie projektu](opis-projektu.md#ekrany-i-sterowanie).

Animator obsługuje nazwy 22 klipów, przejścia między pozycjami i rzeczywisty czas dostarczonych klatek. Importer przyjmuje częściowe zestawy PNG i arkuszy. Właściwe klatki przygotowuje użytkownik; teraz widoczne są referencje z prostymi ruchami całego obrazka. Nauka i przesuwanie czekają na odpowiednią fazę animacji.

Sprawdzono logikę, zapis, integrację sprite’ów i interfejs w działającym oknie macOS. Eksport na telefon, dźwięki, dopasowanie miski do pyska, pełny balans oraz integracja AI pozostają do wykonania. Etapy i szacunki poniżej opisują docelowy zakres, nie deklarację jego ukończenia. [Uruchomienie i aktualna struktura](../README.md) · [Podpinanie sprite’ów](integracja-spriteow.md).

## Zakres pierwszego prototypu

- Jeden golden retriever rozpoczynający jako szczeniak i jeden pokój z miską, legowiskiem oraz miejscem treningu.
- Potrzeby: sytość, energia, czystość, potrzeba zabawy i kontaktu.
- Działania opiekuna: nakarm, odpocznij, pogłaszcz, pobaw się, rozpocznij trening.
- Trzy komendy, nagradzanie w odpowiednim momencie oraz trwały postęp dla każdej komendy.
- Temperament: ciekawość, cierpliwość, towarzyskość i wrażliwość na rozproszenie. Preferencja nagrody: smakołyk, pochwała lub zabawa.
- Zapis stanu, kopia bezpieczeństwa oraz łagodne przeliczenie upływu czasu po powrocie do gry.
- Krótki dziennik rzeczywistych zdarzeń, np. pierwszej nagrodzonej próby sztuczki.

Kolejny zakres obejmuje „zostań”, obrót i aport, więcej zachowań spontanicznych oraz interpretowanie swobodnych poleceń wykraczających poza obecny lokalny słownik. Głos, wiele zwierząt, rozbudowa domu i synchronizacja między urządzeniami należą do późniejszych etapów.

## Wygląd golden retrievera

Wzorzec postaci pochodzi ze zdjęcia golden retrievera użytkownika jako szczeniaka: jasna złota sierść, ciemniejsze opadające uszy, potargana grzywka, ciemne oczy, czarny nos i jaśniejsze końce łap. Uproszczenie zachowuje te cechy, a ogranicza szczegóły sierści. Porównujemy dwa kierunki: prostą ilustrację 2D i pixel art. Wybór stylu pozostaje otwarty.

Docelowy podstawowy widok podczas ruchu pokazuje psa z boku, zwróconego w prawo. Ruch w lewo wykorzystuje lustrzane odbicie całej postaci. Pies porusza się początkowo wzdłuż jednej płaszczyzny podłogi. Dostępne wzorce szczeniaka obejmują siad ze spojrzeniem w stronę gracza oraz pozycję stojącą z boku i od tyłu. Przed przygotowaniem animacji trzeba wyrównać skalę, położenie względem podłoża i punkty odniesienia między ujęciami.

Aktualne propozycje szczeniaka: [prosta wersja 2D](../assets/art/reference/golden-puppy-simple-v1.png) i [wersja pixel art](../assets/art/reference/golden-puppy-pixel-v1.png). Powstały we wbudowanym narzędziu ImageGen na podstawie zdjęcia użytkownika i wcześniejszych propozycji stylu. Obok zapisano [prompt wersji 2D](../assets/art/reference/golden-puppy-simple-v1-prompt.txt) i [prompt pixel art](../assets/art/reference/golden-puppy-pixel-v1-prompt.txt).

Dodatkowe widoki stojącego szczeniaka, oparte na powyższych wzorcach:

| Styl | Widok z boku | Widok od tyłu |
|---|---|---|
| Prosta ilustracja 2D | [PNG z boku](../assets/art/reference/golden-puppy-simple-side-v1.png) | [PNG od tyłu](../assets/art/reference/golden-puppy-simple-rear-v1.png) |
| Pixel art | [PNG z boku](../assets/art/reference/golden-puppy-pixel-side-v1.png) | [PNG od tyłu](../assets/art/reference/golden-puppy-pixel-rear-v1.png) |

Wszystkie cztery obrazy mają przezroczyste tło. [Zestaw promptów](../assets/art/reference/golden-puppy-standing-views-v1-prompts.txt) opisuje referencje i sposób generacji we wbudowanym ImageGen. Są to pojedyncze wzorce ujęć; nie tworzą jeszcze wyrównanego arkusza klatek.

Wcześniejsze propozycje wyglądu są zachowane: [pierwszy wzorzec](../assets/art/reference/golden-retriever-base-v1.png), [uproszczony pies stojący](../assets/art/reference/golden-retriever-simple-v2.png) oraz [stojący pies pixel art](../assets/art/reference/golden-retriever-pixel-v1.png).

Plik bazowy będzie służył jako wzorzec wyglądu i tymczasowy statyczny sprite. Animowane klatki oraz ewentualny podział na warstwy trzeba przygotować oddzielnie. Na początek wybieramy animację klatkową; decyzję o szkielecie 2D można podjąć po sprawdzeniu kosztu tworzenia kolejnych ruchów.

## Etapy dorastania

Pierwszy prototyp obejmuje etap szczeniaka. Kolejne etapy planujemy jako wygląd i zestaw animacji tego samego psa, z zachowaniem identyfikatora, temperamentu, więzi, wspomnień i wyuczonych komend. Tempo przechodzenia między etapami gry pozostaje do ustalenia; nie przypisujemy teraz rzeczywistych miesięcy życia ani automatycznego starzenia podczas nieobecności gracza.

| Etap | Proponowane cechy wyglądu | Zakres |
|---|---|---|
| Szczeniak | Większa głowa względem tułowia, krótkie łapy, duże łapki, potargana grzywka, jasna sierść | Bieżące ilustracje i pierwszy zestaw animacji |
| Młody pies | Dłuższe łapy, smuklejsza sylwetka, stopniowo pełniejszy ogon | Późniejszy etap rozbudowy |
| Dorosły pies | Pełna sylwetka goldena, dłuższa sierść na piersi i ogonie, dojrzalsze proporcje | Późniejszy etap rozbudowy |
| Senior | Delikatnie jaśniejszy pysk i spokojniejszy sposób poruszania się | Opcjonalny późniejszy etap |

W danych zapisujemy `life_stage`. Docelowo wygląd będzie dobierany przez osobny zestaw `SpriteFrames` dla każdego etapu; obecny prototyp prezentuje tylko szczeniaka. Nazwy klipów pozostaną wspólne, np. `idle`, `walk`, `sit_down`, `give_paw`. Każdy etap będzie wymagał własnych punktów pyska i łap oraz ustawienia grafiki względem podłoża. Zmiana wieku nie polega wyłącznie na powiększeniu całego obrazka. Zmiany tempa ruchu lub długości sesji treningowej są parametrami rozgrywki i wymagają sprawdzenia w testach.

Aktualna [lista spriteów szczeniaka](lista-spriteow-szczeniaka.md) obejmuje 22 klipy dla głównego widoku bocznego. Każdy kolejny etap wieku wymaga adaptacji tego zestawu, co zwiększa nakład pracy graficznej ponad oszacowanie pierwszego prototypu.

## Kolejność implementacji

| Etap | Zakres | Warunek ukończenia | Szacunek pracy |
|---|---|---|---|
| 1. Scena i zapis | Projekt Godot 4 w stabilnej wersji, ekran telefonu, pokój, statyczny pies, dotyk, ruch do wskazanego miejsca, zapis wersjonowany | Pies jest widoczny na fizycznym telefonie; po restarcie wracają imię, pozycja i stan | 12–20 h |
| 2. Potrzeby i zachowania | Pięć potrzeb, akcje opieki, temperament, wybór zachowania, pierwsze animacje ruchu i opieki | Pies sam wybiera odpoczynek lub kontakt, a potrzeby i temperament wpływają na zachowanie | 20–35 h |
| 3. Trening | Sesja treningowa, naprowadzanie, okno nagrody, znajomość komendy, zmęczenie, trzy sztuczki | Widać różnicę przed i po treningu; postęp przetrwa restart | 25–40 h |
| 4. Pamięć i reakcje | Dziennik zdarzeń, preferencje, lokalne reakcje, dopracowanie przejść między animacjami | Pies pamięta osiągnięcia, reaguje na ulubioną nagrodę i zachowuje spójność temperamentu | 12–20 h |
| 5. Opcjonalne AI | Backend, krótki kontekst, rozpoznawanie poleceń tekstowych, ograniczone reakcje, limity i pomiar kosztów | AI korzysta z istniejących czynności; awaria sieci nie zatrzymuje opieki ani treningu przyciskami | 15–25 h |
| 6. Testy i dopracowanie | Przerwanie sesji, wznowienie aplikacji, błędny zapis, brak internetu, jakość animacji i czytelność dotyku | Można przejść kilka dni opieki bez utraty danych i zrozumieć postęp bez instrukcji autora | 20–35 h |

Suma to 104–175 godzin pracy programistycznej i integracyjnej, przy dostarczonych materiałach graficznych. To szacunek dla ograniczonego prototypu, nie kompletnej gry sklepowej. Produkcja ilustracji, animacji, dźwięków i nauka Godota wymagają osobnego czasu. Przy 10 godzinach tygodniowo sam ten zakres odpowiada około 11–18 tygodniom. Pierwszy grywalny fragment można ocenić po etapach 1–3.

## Sceny i odpowiedzialności

Pierwotnie proponowany podział docelowego projektu (bieżący prototyp ma jedną scenę i moduły opisane w README):

```text
scenes/
  Main.tscn
  Room.tscn
  Pet.tscn
  CareHUD.tscn
  TrainingPanel.tscn
scripts/
  pet/pet_controller.gd
  pet/pet_brain.gd
  pet/pet_animator.gd
  systems/needs_system.gd
  systems/training_system.gd
  systems/memory_store.gd
  systems/save_system.gd
  services/ai_client.gd
data/
  tricks/
  rewards/
assets/
  art/reference/
  sprites/golden/
  sprites/props/
  audio/
docs/
```

W docelowym podziale `PetController` obsługuje ruch, cel i aktualny stan, a `PetBrain` wybiera dozwolone działanie na podstawie potrzeb, cech i bieżącego zajęcia. Obecnie te obowiązki realizują `RoomView` i `GameSession`. `PetAnimator` mapuje stan na klip i zgłasza jego zakończenie. Rozdzielenie kolejnych scen i zasobów będzie następować wraz z rozbudową gry.

Do klatek użyjemy `AnimatedSprite2D` i zasobu `SpriteFrames`. `AnimationPlayer` może sterować miską, piłką, efektami nagrody i przejściami interfejsu. Definicje sztuczek oraz nagród warto przechowywać jako zasoby `Resource`. `TrainingSystem` oblicza postęp niezależnie od animacji i od API.

Podstawowe stany psa: bezczynność, chód, siadanie, siedzenie, wykonywanie sztuczki, kładzenie się, sen, budzenie i jedzenie. Wejścia i wyjścia ze stanu mają jawne przejścia. Krótkie reakcje, takie jak radość, wracają do zgodnego stanu końcowego. Miska, smakołyk, piłka i cień pod psem są oddzielnymi elementami sceny.

## Nauka trzech komend

| Komenda | Sposób nauki | Co zapisujemy | Wymagane animacje |
|---|---|---|---|
| Przyjdź | Przywołanie, podejście do miejsca opiekuna, nagroda po dotarciu | Rozpoznanie komendy, pewność podejścia, ostatni trening | Chód, bezczynność, radość |
| Siad | Naprowadzenie, próba siadania, nagroda po właściwym ruchu | Rozpoznanie komendy, poziom opanowania, wykonania bez naprowadzenia | Siadanie, siedzenie, wstawanie |
| Podaj łapę | Wymagane siedzenie, uniesienie łapy, nagroda w odpowiednim momencie | Opanowanie sztuczki, pewność reakcji, historia ostatnich prób | Podanie łapy, siedzenie |

Każda komenda przechodzi przez etapy: nieznana, próby z naprowadzaniem, wykonania z pomocą, samodzielne wykonania. Krótkie sesje pozwalają uniknąć bezmyślnego wielokrotnego klikania. Dobrze wykonane próby i nagrody w odpowiednim momencie utrwalają naukę. Zmęczenie lub głód obniżają aktualną gotowość do ćwiczeń, lecz nie usuwają zdobytych umiejętności.

Temperament zmienia długość skupienia, tempo rozpraszania i wartość różnych nagród. Nie powinien blokować nauczenia podstawowych komend. W trakcie sesji gracz widzi zrozumiałą informację, np. że pies potrzebuje odpoczynku, zamiast pozornie losowej odmowy.

## Animacje potrzebne do prototypu

Szczegółowy brief, nazwy plików, pozycje bazowe, liczby klatek i kolejność przygotowania znajdują się w [liście spriteów i animacji szczeniaka](lista-spriteow-szczeniaka.md). To docelowy zakres materiałów, a nie zestaw już gotowych animacji.

| Pakiet | Zakres | Klipy | Orientacyjne klatki |
|---|---|---:|---:|
| A | Stanie, chód, siadanie, siedzenie, wstawanie, machanie ogonem w staniu i siadzie, podawanie łapy | 8 | 54 |
| B | Szczekanie, zaciekawienie, głaskanie, leżenie i sen z przejściami, jedzenie, smakołyk w staniu i zaproszenie do zabawy | 14 | 88 |
| Razem | Główny widok boczny szczeniaka | 22 | 142 |

Najpierw powstaje pakiet A. Na start nie mnożymy wszystkich klipów przez widok przedni i tylny. Radość po komendzie wykonywanej w siadzie korzysta z `tail_wag_sit`, a podczas stania z `tail_wag_stand`. Dźwięki, miska, piłka, smakołyk i efekty nagrody są oddzielnymi zasobami.

Przejście przez sen ma osobne fazy: położenie się, neutralne leżenie, zaśnięcie, sen, pobudka do leżenia i wstanie. Pozwala to wykorzystać leżenie również podczas odpoczynku bez snu. Każdy klip kończy się w jawnie określonej pozycji, aby łączenie animacji było płynne.

## Animacje do późniejszej rozbudowy

Pakiet C w [briefie spriteów](lista-spriteow-szczeniaka.md) obejmuje m.in. bieg, węszenie, reakcje w siadzie, ziewanie, przeciąganie, drapanie, otrzepywanie, picie, sen na boku, aport, obrót i turlanie. Materiały do poszczególnych czynności powstają wraz z rozbudową rozgrywki. Komenda „zostań” wykorzystuje już istniejące stanie lub siedzenie oraz mechanikę utrzymywania pozycji.

## Specyfikacja materiałów dla animatora

- Wzorzec postaci: pełna sylwetka z przezroczystością, proporcje i kolory zgodne z wybraną wersją szczeniaka; wspólne cechy psa zachowane między etapami dorastania.
- Dla gładkiej ilustracji 2D: PNG RGBA, jednakowe płótno 512 × 512 px. Materiał źródłowy można przygotować w większej rozdzielczości. Dla pixel art najpierw ustalamy rzeczywistą małą siatkę, np. 64 × 64 px, oraz paletę; wygenerowane duże przykłady są koncepcjami stylu, a nie gotowymi arkuszami na tej siatce.
- Dla płótna 512 × 512 px: wspólna linia podłoża na wysokości około 430 px i punkt odniesienia postaci w okolicy `(256, 430)`. Dla pixel art ustalamy odpowiednie całkowite współrzędne po wyborze siatki. Są to ustalenia dla przyszłych klatek; wzorzec koncepcyjny nie musi być już tak zarejestrowany.
- Bez automatycznego przycinania przezroczystych marginesów osobno dla każdej klatki. Stała skala, kamera i położenie względem punktu odniesienia zapobiegają skakaniu obrazu.
- Jeden kierunek źródłowy: w prawo. Dla ruchu w lewo odbijamy postać i powiązane punkty przedmiotów. Unikamy asymetrycznych napisów i akcesoriów.
- Oddzielny arkusz dla każdego klipu, maksymalnie 4 kolumny, albo numerowane pliki, np. `walk_00.png`. Puste końcowe pola arkusza nie są klatkami animacji.
- Przy klatkach 512 × 512 px i 4 kolumnach arkusz ma szerokość 2048 px; najdłuższy klip 12 klatek zajmie 3 rzędy. Dla pixel art rozmiar arkusza wynika z wybranej małej siatki. W Godocie ustawiamy liczbę klatek jawnie.
- W klipach zapętlonych pierwsza i ostatnia faza ruchu muszą się płynnie łączyć. Pierwszej klatki nie trzeba duplikować na końcu.
- Miska, piłka, smakołyki i cień pod psem są osobnymi grafikami. Przy zmianie kierunku należy sprawdzić pozycję pyska i przedmiotów.
- Chód animujemy w miejscu. Przesuwanie postaci wykonuje `PetController`, z prędkością dobraną do cyklu, aby łapy nie ślizgały się po podłodze.
- Kontrola jakości: anatomia czterech nóg, czytelne uszy i ogon, stałe proporcje, przezroczyste krawędzie, brak drgań sylwetki oraz czytelność na telefonie przy docelowym rozmiarze.

Gdybyśmy przeszli na szkielet 2D, potrzebne będą osobne warstwy tułowia, głowy, uszu, ogona oraz segmentów wszystkich łap, z dorysowanymi fragmentami ukrytymi pod sąsiednimi częściami. Pojedynczy spłaszczony PNG nie zastępuje tych warstw.

## Zapis stanu i działanie bez internetu

Zapis obejmuje `schema_version`, identyfikator psa, imię, `life_stage`, ziarno losowania temperamentu, cechy, preferencje, potrzeby, relację, postęp komend, krótką listę ważnych zdarzeń oraz czas ostatniego zapisu. Dane są przechowywane w `user://`, z zapisem do pliku tymczasowego i zachowaniem poprzedniej poprawnej kopii. Zmiana etapu dorastania zachowuje dane tego samego psa i jego postęp.

Potrzeby aktualizujemy według czasu, a nie liczby klatek. W sesji korzystamy z monotonicznego pomiaru czasu; po wznowieniu obliczamy ograniczoną różnicę czasu zapisanego i bieżącego. Cofnięcie zegara nie może przyznać postępu ani odjąć ujemnego czasu. Długa nieobecność nie usuwa psa ani wyuczonych sztuczek. Zapis wykonujemy po zakończeniu ważnej akcji, przy wstrzymaniu aplikacji i okresowo.

## Integracja AI po uruchomieniu podstawowej gry

Godot wysyła żądania HTTPS do własnego backendu. Backend przechowuje klucz dostawcy, sprawdza limit żądań i budżet oraz wysyła zwięzły kontekst do modelu. Wybór modelu i dostawcy pozostaje konfigurowalny. Uruchomienie płatnej integracji wymaga późniejszego skonfigurowania dostępu do API.

AI może mapować wpisane polecenie na dozwoloną komendę i proponować krótką reakcję zgodną z temperamentem. Zwrot zawiera dane według ustalonego schematu, np. identyfikator intencji i identyfikator reakcji. Logika gry sprawdza, czy pies zna komendę, czy ma warunki do wykonania oraz czy wskazana reakcja pasuje do bieżącego stanu. Model nie przyznaje punktów treningu ani nie zmienia bezpośrednio cech.

Pamięć opiera się na zdarzeniach zapisanych przez grę; wygenerowany opis nie może dopisać nieodbytego treningu. Odpowiedzi sieciowe są przypisane do identyfikatora żądania i wersji sytuacji, aby spóźniona odpowiedź nie zmieniła nowego stanu. Po przekroczeniu czasu oczekiwania korzystamy z lokalnej reakcji. Mierzymy liczbę żądań i zużycie tokenów, z limitem na gracza i limitem globalnym.

## Sprawdzenie prototypu

- Po ponownym uruchomieniu pies zachowuje temperament, imię, potrzeby i opanowanie komend.
- Przerwanie treningu lub uśpienie telefonu nie powoduje podwójnego naliczenia nagrody.
- Postęp zależy od wykonania ćwiczenia i właściwego nagradzania; sam licznik kliknięć nie wystarcza.
- Dwa psy z różnymi parametrami wykazują zauważalne różnice w skupieniu i wyborze nagród, ale oba mogą nauczyć się podstawowych sztuczek.
- Brak internetu, błędna odpowiedź API i przekroczenie limitu kosztów pozostawiają sprawną opiekę oraz trening przyciskami.
- Przejścia siad–łapa–siad, stanie–sen–stanie i stanie–jedzenie–stanie nie przeskakują między niezgodnymi pozami.
- Ruch w obie strony zachowuje ustawienie łap, miski i punktu pyska. Interfejs jest czytelny na fizycznym telefonie.

## Dokumentacja techniczna

- [AnimatedSprite2D](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html)
- [SpriteFrames](https://docs.godotengine.org/en/stable/classes/class_spriteframes.html)
- [Zapisywanie gry](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)
- [Eksport na iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
