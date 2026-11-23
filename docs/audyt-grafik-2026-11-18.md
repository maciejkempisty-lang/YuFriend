# Audyt grafik YuFriend — 18 listopada 2026

## Zakres i wynik

Sprawdzono pliki w `assets/`, manifest animacji, odwołania w kodzie oraz reprezentatywne zrzuty Domu, podwórka, kąpieli i odpoczynku. To przegląd zasobów i wyglądu wybranych ekranów; nie jest ręcznym obejrzeniem wszystkich 172 klatek w ruchu ani testem całej gry na każdym telefonie.

**Wniosek:** gra ma kompletny zestaw grafik do obecnych mechanik. Największą potrzebą nie jest uzupełnianie pustych miejsc, lecz ujednolicenie skali, palety, sylwetki i przejść animacji Glorii oraz dopracowanie kilku ruchów składanych dziś z innych klipów.

## Co mamy

| Obszar | Stan w repozytorium | Jak jest używany |
|---|---|---|
| Gloria | 26 arkuszy PNG, [manifest](../assets/sprites/puppy/pixel/manifest.json) zawierający **28 klipów i 172 klatki**, pakiet [`.res`](../data/animations/puppy_pixel.res) | Ruch, opieka, sen, zabawy, sztuczki, kopanie, bieg, węszenie i otrzepywanie. Wszystkie arkusze z manifestu istnieją; nie ma osieroconych arkuszy w `sheets/`. Lewy kierunek powstaje przez odbicie. |
| Pokój | [Tło](../assets/art/environments/puppy-room-pixel-v1.png), [atlas dekoracji](../assets/art/environments/decor-v1.png) | `RoomArtwork` składa panoramę, dywan, portret, rośliny i półkę. Legowisko, miska, piłka, okno, lampa i część mebli są rysowane w kodzie. |
| Podwórko i łazienka | Grafika rysowana w GDScript | Płot, krzaki, ogródek, pogoda, woda, tor przeszkód, zadaszenie, legowisko i miska na podwórku, a także kafelki i piana w kąpieli. |
| Zwierzęta tła i goście | [Ilustracja znajomych](../assets/art/visitors/fence-friends-v1.png) oraz grafika rysowana w kodzie | Ilustracja jest nagłówkiem Albumu. Ptak, motyl, ślimak, wiewiórka i odwiedziny przy płocie powstają z pikseli lub kształtów w skryptach. |
| Interfejs | **21 ikon** opisanych ścieżkami SVG w [GameIcons](../scripts/ui/game_icons.gd) | Potrzeby, czynności, nawigacja, trening i nagrody. Ikony są rasteryzowane w grze; tekst i symbole dzielą wspólny HUD. |
| Ikona aplikacji | [PNG 1254 × 1254](../assets/art/app/yufriend-icon-v1.png) | Konfiguracja projektu i eksport mobilny. Weryfikacja APK pokazała właściwy portret psa jako ikonę Androida. |
| Materiały pomocnicze | 9 PNG w [`assets/art/reference/`](../assets/art/reference/) i zrzuty w [`docs/images/`](images/) | Wzorce i dokumentacja, nie produkcyjne klipy gry. [Makieta bardziej ikonowego HUD-u](images/makieta-interfejs-ikony.png) jest propozycją, nie częścią aplikacji. |

W `assets/` jest łącznie 39 PNG: 30 używanych lub przeznaczonych dla gry (26 arkuszy i 4 samodzielne obrazy) oraz 9 obrazów referencyjnych. Historia pierwszych 22 klipów i kopania ma sumy źródeł w [`sources.json`](../assets/sprites/puppy/pixel/sources.json); nowsze arkusze opisują notatki `YARD-GENERATION.md`, `BATH-GENERATION.md` i `STAGE5-GENERATION.md`. Nie ma w repo warstwowych plików edycyjnych typu Aseprite, PSD lub Krita.

## Co wymaga pracy

| Priorytet | Potrzeba | Powód i zakres |
|---|---|---|
| **P0** | Wzorzec Glorii i próbna korekta 3 klipów | Obecne arkusze są dużymi obrazami stylizowanymi na pixel art. [Instrukcja integracji](integracja-spriteow.md) i ogląd arkuszy wskazują różnice w anatomii, palecie i wielkości pikseli. Ustalić jedną sylwetkę, zamkniętą paletę, linię łap i punkt podparcia. Najpierw dopracować `idle`, `walk`, `sit_down`; sprawdzić je w 320 i 390 px przed przerabianiem reszty. |
| **P0** | Płynne przejścia odpoczynku i jedzenia | Zestawić klatkę końcową jednego ruchu z pierwszą kolejnego: `idle_lie → get_up`, `sleep → wake_up`, `eat_loop → eat_exit`. Obecny opis pakietu wymienia te przejścia jako najbardziej wymagające korekty. Sprawdzić kontakt łap z podłożem i pyska z miską. |
| **P1** | Dedykowany skok i picie | Skok w torze łączy `play_bow` z `run` w [`PuppyJump`](../scripts/ui/puppy_jump.gd). Picie wody używa klipów jedzenia w [`YardRest`](../scripts/systems/yard_rest.gd). Oba działają, ale własne klatki poprawiłyby czytelność ruchu i kontakt z przedmiotem. |
| **P1** | Spójność pokoju, podwórka i kąpieli | Pokój łączy obraz generowany z detalami kodowymi; podwórko i kąpiel mają prostszy język kształtów. Porównać paletę, grubość konturów i gęstość detali na telefonie. Zachować elementy kodowe, które są czytelne; przerysować te, które wyraźnie odstają. |
| **P1** | Grafiki do najbliższego pakietu | Planowane głaskanie podczas leżenia, przeciąganie po drzemce i spokojne merdanie w leżeniu potrzebują nowych klipów. Jeśli Gloria ma **przynosić** piłkę, potrzebny jest także czytelny moment podniesienia, przeniesienia przy pysku i odłożenia piłki, albo równie jasne rozwiązanie z osobnym obiektem piłki. [Plan](rozwoj-projektu.md) nie deklaruje tych grafik jako już wdrożonych. |
| **P2** | Ikony dla uproszczonego HUD-u | Dotychczasowe 21 ikon pokrywa podstawy, ale [makieta](images/makieta-interfejs-ikony.png) używa również symbolu „Dziś”, statusu przy psie i sterowania kadrem. Przed wdrożeniem przygotować je w jednym stylu, z nazwami dostępności i stanami aktywny/niedostępny. |
| **P2, później** | Grafiki następnych pakietów | Jesienne liście i znaleziska, ścieżka spaceru z trzema przystankami oraz oprawa zdjęć w Albumie należą do kolejnych etapów planu. Nie są brakami bieżącej gry. |

## Kolejność wykonania i odbiór

1. Ustalić wzorcowe stojące i siedzące ujęcie Glorii na siatce 64 × 64 px, ze wspólną paletą i punktem podparcia (32, 54), według [specyfikacji](integracja-spriteow.md#wspólna-siatka--ustalenie-z-15-listopada-2026).
2. Dostarczyć próbę `idle`, `walk`, `sit_down` i obejrzeć ją w grze na małym ekranie. Ocenić rozpoznawalność Glorii, stabilność łap, spójność obrysu i cykl chodu.
3. Poprawić przejścia leżenia, snu i jedzenia; następnie zdecydować o reszcie 28 klipów na podstawie tego wzorca. Zachować oryginalne PNG, manifest i pochodzenie każdej zmiany.
4. Przygotować nowe klipy najbliższego pakietu i grafiki piłki, potem dopracować dedykowany skok oraz picie.
5. Porównać Dom, podwórko i kąpiel na telefonie przy 320/390 px oraz na fizycznym Androidzie i iPhonie. Zatwierdzić grafiki po oglądzie ruchu, nie na podstawie samego importu lub statycznego zrzutu.

## Uwagi do dokumentacji

Starsze dokumenty, m.in. [`lista-spriteow-szczeniaka.md`](lista-spriteow-szczeniaka.md) i [`integracja-spriteow.md`](integracja-spriteow.md), nadal opisują pakiet 22 klipów / 142 klatek i planują `run` jako przyszły. Stan kodu i manifestu to 28 klipów / 172 klatki. Przy zlecaniu nowych grafik należy posługiwać się bieżącym manifestem i tym audytem, a stare liczby traktować jako historię pakietu A+B.
