# Przegląd menu ogrodu po scaleniu — 24 listopada 2026

Sprawdzona wersja: `b7e0e1e`, kod buildu 38. **Nie stwierdzono blokowania dotychczasowych akcji przez nowe menu.** Przegląd nie wymagał zmiany kodu gry, zasobów, zapisu ani konfiguracji wydania.

## Nowa regresja

`tests/ui_yard_menu_actions.gd`: **296/296 sprawdzeń**, 54 niezależne scenariusze przy szerokościach 320 i 390 px. Test wysyła zdarzenia dotyku i przeciągania przez viewport, sprawdza rzeczywiste cele w scenie i widoczne przyciski. Każdy scenariusz zaczyna się od nowego zapisu testowego. Fokus syntetycznej sceny ustawiany jest jawnie po zamknięciu poprzedniego okna dialogowego, aby spóźnione zdarzenie systemowego fokusu nie zmieniało warunków kolejnego testu.

| Zakres | Sprawdzenie |
|---|---|
| Wszystkie 12 miejsc | Przejście z otwartego menu do furtki, cienia, toru, kałuży, zraszacza, trzech krzaków, aportu, kopania, ogródka i wyjścia na potrzebę. |
| Skróty | Rzeczywiste dotknięcia „Do domu”, „Na potrzebę”, „Kąpiel”, „Chowany” i komendy przy otwartym menu; kontrola widoczności, aktywności i rozmiaru celu. |
| Piłka i kamera | Gest rzutu działa nad sceną mimo otwartego menu; mapa pozostaje dostępna i udostępnia wszystkie miejsca. |
| Powrót do opieki | „Wróć” przywraca przyciski, uwagę i zaproszenia; można rozpocząć drzemkę na podwórku. |
| Zmiana stanu | Woda, tor, odpoczynek, gość, zaproszenie, sprzątanie i wybór krzaka w chowanym zamykają menu oraz udostępniają właściwe sterowanie. |
| Przyciski aktywności | Działają „Plusk!”, „Otrzep się”, „Skacz”, przerwanie toru/odpoczynku, uspokojenie gościa, przyjęcie zaproszenia i sprzątanie. |

## Regresja dotychczasowych przepływów

**19/19 zestawów UI zaliczonych w końcowym przebiegu**, bez błędów skryptów:

`ui_yard_menu_actions`, `ui_yard_menu`, `ui_yard_places`, `ui_yard`, `ui_yard_hide`, `ui_yard_rest`, `ui_yard_routines`, `ui_yard_transition`, `ui_yard_sprites`, `ui_water`, `ui_course`, `ui_outdoor_commands`, `ui_visitors`, `ui_npc_schedule`, `ui_potty`, `ui_digging`, `ui_bath`, `ui_wellbeing`, `ui_play`.

Dotychczasowe zestawy obejmują również pełne rundy zabaw, komendy Przyjdź/Zostań i pochwałę, odwołanie psa od gościa, wzrost roślin oraz przejście aplikacji w tło. Nie osłabiono ich asercji ani nie modyfikowano warunków dostępności w grze.

Menu celowo zastępuje przyciski opieki podczas wyboru. Powracają po „Wróć” lub zmianie czynności. Podczas aktywnych gier obowiązują ich dotychczasowe blokady; menu ich nie dodaje ani nie usuwa. Dostępność jest ponownie sprawdzana w momencie wykonania wybranej opcji.

Wyniki: `exports/review-yard-menu-2026-11-24/summary.log` oraz `suites/` (lokalne, pomijane przez Git). Testy przeprowadzono w Godocie na macOS, z symulowanym dotykiem. Nie wykonywano akcji na zapisie Glorii ani dodatkowej instalacji na telefonie. Build 38 zachowuje identyczny kod wykonawczy.
