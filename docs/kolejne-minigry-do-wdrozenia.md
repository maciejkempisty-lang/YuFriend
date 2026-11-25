# Kolejne minigry — pakiety gotowe do implementacji

Stan: 25 listopada 2026, po implementacji pierwszego freestyle.
Bańki zostały zaimplementowane w buildzie 41: [opis](banki-mydlane.md).
Poniższy zakres baniek zachowano jako specyfikację odbioru; agility wdrożono w buildzie 43: [opis i testy](agility-na-czas.md).
Oba pakiety mają implementację; kolejnym krokiem jest fizyczna próba gestów i dostrojenie tempa.

## 1. Bańki mydlane

**Cel:** spokojniejsza zabawa gestem, inna od komend i szybkiego berka.
Wejście: Pobaw się → Bańki, na podwórku. Używa obecnego `play_readiness`;
nie omija snu, zmęczenia, zajętości ani blokady zapisu.

**Zakres pierwszego wdrożenia:**

1. Instrukcja i przycisk rozpoczęcia rundy 30 s. Przytrzymanie nadmuchuje
   bańkę (0,2–1,2 s), przesunięcie określa kierunek wypuszczenia.
   Anulowany dotyk nie wypuszcza bańki. Tylko jeden aktywny palec.
2. Promień rośnie od 14 do 32 punktów; większa bańka porusza się wolniej.
   Maksymalnie trzy bańki naraz. Powiew ma stały kierunek w jednej rundzie,
   pokazany strzałką; bez losowej zmiany podczas gestu.
3. Gloria podbiega do najbliższej osiągalnej bańki i skacze. Trafienie
   wymaga przecięcia bańki z pyszczkiem podczas skoku. Bańki poza zasięgiem
   odlatują; nie naliczać punktów za samo wypuszczenie.
4. Limit 10 wypuszczeń. Zwykła bańka daje 1 pkt; złota (co piąta) 2 pkt.
   Gwiazdki: 1 od 1 pkt, 2 od 6 pkt, 3 od 10 pkt; maksimum 12 pkt.
5. Wynik, rekord i możliwość powtórzenia. Pierwsze 3 gwiazdki — wspomnienie.
   Jedna nagroda za wynik, dotychczasowy wspólny odstęp 30 s.

**Miejsca zmian:** osobny `BubblePlay` (model), adapter w `SkillPlaySystem`,
rysowanie w `TouchPlayView`, menu w `GameUI`, rozliczenie w `GameSession`.
Rozszerzyć `SkillRecords` o jawny limit 12 dla bubbles, nie zwiększać limitu
pozostałych gier. Rekord w istniejącym `.games.cfg`; brak migracji pet.json.
Wykorzystać aktualne run/skok i kodowe okręgi z refleksami, bez nowych bitmap.

**Testy odbioru:**

- Jednakowe trajektorie i wyniki przy 30/60/120 FPS oraz dużym kroku czasu.
- Jeden kontakt liczy się raz; bańka poza ekranem znika; limit obiektów działa.
- Anulowanie, wielodotyk, wejście w tło i ponowne otwarcie usuwają obiekty.
- Zero punktów bez trafienia; brak nagrody po anulowaniu i podwójnego zapisu.
- Przyciski minimum 44 pkt, wygodny gest przy 320/390 pkt, pies i licznik widoczne.
- Rekord i wspomnienie przeżywają restart; odczyt kopii Glorii bez zmiany postępów.

**Poza pierwszym pakietem:** swobodne dmuchanie mikrofonem, sklep z płynami,
trwały zasób baniek, nowe potrzeby psa. Rozmiary i prędkości dostroić po próbie
na MagicPhone; podane wartości są startowymi parametrami implementacji.

## 2. Agility na czas

**Cel:** osobny wariant istniejącego toru, zachowujący zwykły trening Zostań.
Wejście: obiekt toru → wybór „Spokojny tor” / „Tor na czas”. Nowy tryb stosuje
`YardCourse.readiness`: podwórko, pora dnia, energia, posiłek, zmęczenie
oraz dostępność komendy. Nie zastępować działającej sekwencji starego toru.

**Zakres pierwszego wdrożenia:**

1. Krótkie odliczanie i trzy odcinki: slalom, skok, podest. Pies biegnie
   samodzielnie. Czytelny znacznik zapowiada moment „Slalom”, „Skacz”, „Stój”.
2. Jeden duży przycisk z aktualną komendą. Okno ±0,35 s. Błąd zatrzymuje psa
   na 1,5 s, po czym odcinek kończy się bez kolejnych kar za ten sam błąd.
   Celowo nie odejmować wcześniej zdobytych postępów ani opanowania Zostań.
3. Wynik = czas przejazdu + kary. Limit rundy 60 s. Przerwany lub nieukończony
   tor nie zapisuje rekordu. Gwiazdki pierwszej stałej trasy: 3 bez błędów,
   2 z jednym błędem, 1 za ukończenie z większą liczbą błędów.
4. Osobny rekord najlepszych sekund; dzienny układ to drugi etap, po ustaleniu
   i sprawdzeniu podstawowej trasy. Zapis czasu waliduje zakres 0–60 s.
5. Rozliczenie jednej rundy we wspólnym mechanizmie nagród. Koszt rozpoczęcia
   pobierany dokładnie raz; nie nakładać go drugi raz przez stary YardCourse.

**Miejsca zmian:** nowy `TimedCourse` obok `YardCourse`; wspólne sprawdzanie
warunków, ale oddzielna maszyna stanów. Wykorzystać `PuppyJump`, `RoomView`
i `YardActionMenu`. Rekord w `.games.cfg`, bez zmiany schematu psa.
Konieczne będzie jawne rozszerzenie walidacji sekund w `SkillRecords`
(obecnie 45 s dla berka), z zachowaniem starego limitu berka.

**Testy odbioru:**

- Dotychczasowy tor, trening i nagrody Zostań działają bez zmian.
- Brak skoku przed komendą, powtórnej kary, podwójnego kosztu i nagrody.
- Kolejność zdarzeń pozostaje zgodna przy różnych FPS i przerwaniu w locie.
- Zamknięcie menu, powrót do domu i tło przywracają psa na ziemię.
- Noc/zmęczenie/blokada zapisu odmawiają startu z jasnym komunikatem.
- Rekord minimalizuje czas i zachowuje lepszy wynik; brak zapisu po anulowaniu.
- Test fizyczny: przyciski wygodne jedną ręką, Gloria zawsze widoczna.

## Wydawanie

Każdy pakiet osobno: testy logiki i powiązanego UI → przegląd zrzutów → build
z kolejnym numerem → kopia Documents z telefonu → aktualizacja bez odinstalowania
→ porównanie danych przed/po → próba gestów. Nie zmieniać rzeczywistego zapisu
Glorii fixture’ami. Freestyle i bańki wymagają jeszcze oceny gestów na fizycznym telefonie.
