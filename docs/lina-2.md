# Lina 2.0 — prototyp

Wdrożone lokalnie 22 listopada 2026. Pierwsza nowa minigra z propozycji;
pozostałe zabawy i wspólny system malejących nagród nie są częścią tej zmiany.

## Jak grać

1. Wybierz Dom → Pobaw się → Lina · ciągnij i odpuszczaj.
2. Za pierwszym razem pokaz czeka na przeciągnięcie węzła w prawo, a potem
   na puszczenie palca przy przykucnięciu. Nie daje punktów ani nagród.
3. „Zagraj rundę” rozpoczyna pięć wymian, łącznie około 20 sekund.
4. Przez 2 sekundy pies odpuszcza: przeciągnij węzeł w prawo i trzymaj.
5. Przykucnięcie, kolor napięcia oraz napis „PUŚĆ PALEC” zapowiadają
   szarpnięcie przez 1 sekundę. Puść palec w tym czasie.
6. Szarpnięcie trwa 0,6 sekundy, potem jest 0,4 sekundy na zmianę wymiany.

Udana wymiana wymaga pociągnięcia i puszczenia w zapowiedzi. Puszczenie za
wcześnie, trzymanie przez szarpnięcie, brak pociągnięcia lub anulowany dotyk
nie dają punktu. Runda trwa dalej: po błędzie można odzyskać kontrolę.
Nie ma losowej porażki ani trudności rosnącej wraz z więzią.

## Ocena i zapis

- 0 udanych wymian: 0 gwiazdek; 1–2: jedna; 3–4: dwie; 5: trzy.
- Wynik podaje liczbę udanych wymian i rekord (najlepszy wynik z pięciu).
- „Jeszcze raz” od razu rozpoczyna kolejną rundę, bez powtarzania pokazu.
- Ukończenie pokazu i rekord trafiają do pliku `<ścieżka zapisu psa>.tug.cfg`.
  Rekord może tylko rosnąć; zapis używa pliku tymczasowego i zmiany nazwy.
- Model psa i jego migracje pozostają bez zmian w tej funkcji. Istniejące
  równoległe prace nad więzią nie są częścią prototypu Liny 2.0.
- Rekord zapisuje się po pomyślnym zapisie zakończonej rundy. Nieudany zapis
  rekordu daje komunikat. Samo zamknięcie zabawy nie zapisuje wyniku rundy.

Zachowano dotychczasowe przyrosty potrzeb i wspólny odstęp 30 sekund dla
nagród. Runda bez żadnego pociągnięcia nie daje nagrody. Wynik w gwiazdkach
nie ogranicza zaspokajania potrzeby zabawy: to odrębna ocena umiejętności.
Nie dodano premii za celowe przegrywanie, zmiennych rytmów ani nowych sprite’ów.

## Weryfikacja

`test_play.gd` sprawdza dobre i błędne wymiany, brak nagrody za bezczynność,
odzyskanie kontroli, anulowanie dotyku, jednorazowe rozliczenie, zapis rekordu
oraz dotychczasowe kubki i piłkę. `ui_play.gd` przechodzi pokaz, pięć wymian
przez zdarzenia dotyku, drugi palec, wynik, zapis rekordu i natychmiastową powtórkę.
Testy działają na osobnych zapisach w katalogu tymczasowym.

Ocena przyjemności i czytelności sygnału na fizycznym iPhonie pozostaje
następnym krokiem. Ta zmiana nie instaluje aktualizacji na urządzeniu.

Wynik weryfikacji kopii projektu: 33/33 zestawy logiki i 28/28 zestawów UI.
Dodatkowy końcowy przebieg ui_play: 46 sprawdzeń, zero błędów, w tym wynik
Liny na 320 × 640 i 1100 × 720. Logi i zrzuty: `test-results/tug-v2/`.
