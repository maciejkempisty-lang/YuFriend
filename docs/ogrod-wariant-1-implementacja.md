# Ogród — wariant 1 w grze

Tło `assets/art/environments/yard-sunny-background-v1.png` powstało 19 listopada 2026 w ImageGen jako edycja makiety `docs/images/ogrod-makieta-a-sloneczny.png`. Obraz ma 2172 × 724 px. Zawiera wyłącznie niebo, drzewa, płot i trawę. Nie zawiera psa, zwierząt, pogody ani stacji interaktywnych.

`RoomArtwork` kadruje źródło do proporcji świata 1440 × 360 (prostokąt źródłowy: x=0, y=30, 2172 × 543 px). Dalsza trawa na wysokich ekranach korzysta z powtarzanego fragmentu tej samej tekstury. Filtr tekstur w `RoomView` jest ustawiony na `NEAREST`.

Pozostałe warstwy działają w czasie gry: bramka otwiera się, ogródek pokazuje wzrost roślin, kałuża zależy od pogody, zraszacz animuje strumienie, tor rozkłada przeszkody podczas rundy, a pies, piłka, zwierzęta i znaczniki są osobnymi obiektami. `YardWeatherView` przyciemnia nowe tło w deszczu i nocą. Stacje zachowują pozycje oraz obszary dotyku z `RoomLayout.YARD_STATIONS`.

Prompt edycji tła: „Edit Variant A into a clean static background only. Preserve the panoramic camera, palette, blue sky, distant trees, wooden fence and grassy ground. Remove the dog, all animals, gate, canopy, bed, bowls, bushes, puddle, garden bed, digging patch, ball, flags, cones, hurdle, platform, sprinkler, hose, outing sign, sun and clouds. Repaint the gaps seamlessly. Keep one uninterrupted playable lawn, crisp pixel art, no UI or text.”

Podgląd w działającej grze: `docs/images/ogrod-wariant-1-w-grze.png`.

## Interaktywne obiekty

Stałe stacje ogrodu są osobnymi węzłami `YardStationView`; cień, woda i tor mają własne istniejące warstwy. Każdy obiekt ma delikatny, pulsujący błysk na 3-jednostkowej siatce. W zwykłym widoku nie ma już stale widocznych etykiet nad płotem. Dotknięcie samego obiektu wybiera najbliższą stację, kieruje do niej pieska i po dojściu otwiera dymek z nazwą oraz przyciskiem czynności. Dotychczasowe akcje i zasady ich dostępności pozostają w `GameSession`.

W czasie zwykłego spaceru znikają też stałe przyciski „Dom”, „Krzaki” i „Kąpiel”. Powrót odbywa się przez furtkę; krzak oferuje szukanie i chowankę, a kałuża oraz zraszacz oferują zabawę w wodzie i kąpiel. Pasek pojawia się tylko przy trwających czynnościach, które wymagają przycisków „Przerwij”, „Plusk!”, „Skacz” lub odpowiedzi na zaproszenie.

Na ekranie 320 × 640 dymek akcji zastępuje na chwilę panel opieki, aby nie zasłaniał psa. Widok przeglądu ogrodu nadal pokazuje wszystkie dwanaście miejsc jako siatkę do nawigacji. Podglądy: `docs/images/ogrod-obiekty-bez-etykiet.png`, `docs/images/ogrod-dymek-po-dojsciu.png`, `docs/images/ogrod-dymek-waski-ekran.png`.

20 listopada 2026 stałe rysunki dwunastu stacji przeniesiono do osobnych przezroczystych PNG w `assets/art/yard/sprites/`. Każda stacja ma teraz własny `Sprite2D` i osobny, animowany obrys. Furtka i kałuża zmieniają teksturę zależnie od stanu; rośliny, woda, odpoczynek i tor zachowały ruchome warstwy. Źródła, rozmiary oraz polecenie odtworzenia plików opisuje `assets/art/yard/README.md`. Panorama trawy i płotu nie została zmieniona.

Podgląd po rozdzieleniu warstw: `docs/images/ogrod-sprite-w-grze.png`.

Zrzut po instalacji Android APK na telefonie: `docs/images/ogrod-obiekty-telefon.png`.
