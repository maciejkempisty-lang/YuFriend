# Psi freestyle — pierwsza wersja, 25 listopada 2026

Wejście: **Pobaw się → Psi freestyle**, w domu lub na podwórku.
Zabawa jest dostępna, gdy przynajmniej jedna sztuczka osiągnie 50% opanowania.
Używa Siad, Podaj łapę, Leżeć, Ukłon, Kręć się i Turlaj się. Nie podnosi
opanowania sztuczek ani nie zmienia wcześniejszych wyników treningu.

Po przeczytaniu instrukcji gracz wybiera „Zaczynamy!”, następnie dotyka
„W rytm!”, gdy kółko z numerem komendy trafi na pionową linię. Nazwa następnej
komendy widnieje nad ścieżką. Gloria wykonuje odpowiadającą sztuczkę.

| Znane sztuczki | Układ | Liczba komend |
|---|---|---|
| 1–2 | 20 s | 4 |
| 3–4 | 40 s | 8 |
| 5–6 | 60 s | 12 |

Pierwsza komenda przypada w 3. sekundzie, kolejne co 5 sekund.
Odchylenie do 0,18 s daje 2 punkty („Idealnie”), do 0,4 s — 1 („Dobrze”).
Spóźnienie lub przedwczesne naciśnięcie zużywa komendę bez punktów i przerywa
serię. Wszystkie idealne trafienia dają 3 gwiazdki; co najmniej połowa
maksymalnych punktów daje 2, dowolny dodatni wynik — 1. Brak trafień — 0.
Nie ma losowej porażki psa po poprawnym trafieniu.

Dźwięk to prosty puls 120 BPM z akcentem co cztery uderzenia, sterowany tym
samym zegarem co znaczniki. W czasie tańca zwykła muzyka jest wstrzymana.
Wyłączenie muzyki wycisza puls, ale wizualne sterowanie pozostaje aktywne.
To pierwsza wersja rytmiczna, nie synchronizacja istniejącej piosenki ani
nowy muzyczny utwór. Animacje korzystają z dotychczasowego pakietu psa.

Rekordy układów są osobne: `freestyle_20`, `freestyle_40`, `freestyle_60`
w istniejącym `.games.cfg`. Aktualizacja jest atomowa i następuje po udanym
zapisie rundy. Schemat pet.json pozostaje v17. Historia zabaw korzysta
z istniejącego klucza ball, wspomnienia mają własne identyfikatory freestyle.
Pierwszy układ bez pudła trafia do Albumu. Pozostaje wspólne ograniczenie
nagród co 30 sekund; anulowana runda nie daje wyniku ani wspomnienia.

Wyjście, przejście w tło oraz istniejące blokady snu, zajętości i zapisu
korzystają ze wspólnego systemu zabaw. Po zamknięciu wraca zwykła muzyka.

## Weryfikacja

- `test_freestyle.gd`: 23 sprawdzenia logiki, progów, rekordów, ochrony treningu,
  wspomnienia, jednokrotnej nagrody oraz przerwania w tle.
- `ui_freestyle.gd`: 22 sprawdzenia przy 320/390 punktach: menu, dialog,
  przyciski minimum 44 punkty, sterowanie, dźwięk i powrót do starszej gry.
- Regresja: 42/42 zestawów logiki; 37/38 UI w pełnym przebiegu, następnie
  pozostały `ui_wellbeing` 16/16 po ustaleniu powrotu fokusu w przygotowaniu
  testu. Kopia Glorii po instalacji buildu 40: 69/69 sprawdzeń zapisu.
- Obejrzano zrzut układu 320 punktów. Próba rytmu palcem na iPhonie pozostaje
  do wykonania; pierwsza wersja została dołączona do zainstalowanego buildu 41.

Kolejny zakres: [bańki i agility](kolejne-minigry-do-wdrozenia.md).
