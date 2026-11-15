# Pixel art szczeniaka — pakiet A+B

Wgrano 14 listopada 2026 z lokalnego katalogu `YuFriend-AB/`: **22 klipy, 142 klatki**. `sheets/` zawiera niezmienione kopie wybranych PNG. `sleep.png` i `eat_loop.png` odpowiadają dostarczonym wariantom `spritesheet-v2.png`. Pochodzenie i sumy SHA-256 zapisano w [sources.json](sources.json).

[manifest.json](manifest.json) określa dokładne prostokąty z materiałów źródłowych, kolejność, indywidualne czasy i kalibrację. Nie wolno dzielić każdego arkusza na jednakowe pola 512 × 512: np. `walk` ma szerokości 443/444 px, a `give_paw` pola 362 × 362. Dłuższe zatrzymanie łapy trwa zgodnie z dostawą; cały klip ma 1,5 s.

`scale` wyrównuje wielkość sylwetki między klipami. `anchors` ustala podparcie każdej klatki względem nieprzezroczystej części psa; punkt X jest stały w obrębie klipu, żeby nie podążać za ogonem. Oryginalne marginesy, kolory i pliki pozostają zachowane. Filtr `nearest` oraz próg alfa 0,5 w skórce ograniczają rozmycie i słabe obwódki podczas wyświetlania.

To duże obrazy stylizowane na pixel art, a nie ręcznie opracowana siatka 64/80/96 px. Kalibracja zmniejsza skoki wielkości, lecz nie usuwa różnic rysunku, proporcji, palety i nierównych „pikseli”. Warto dopracować przede wszystkim przejścia `idle_lie → get_up`, `sleep → wake_up` i `eat_loop → eat_exit`. Pokój ma już [tło pixel art](../../../art/environments/README.md) i osobno rysowane na siatce przedmioty. Ich położenie względem pyska i animacji odpoczynku wymaga dalszej integracji.

Pakiet `.res` jest zapisany w `data/animations/puppy_pixel.res`. Przebudowa z katalogu projektu:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --editor --quit
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tools/import_sprites.gd -- pixel res://assets/sprites/puppy/pixel/manifest.json --replace
```

Źródłowy folder i ZIP są zachowane lokalnie, pomijane przez Git; `.gdignore` w folderze dostawy wyłącza jego import jako dodatkowych zasobów gry. Zwykłe uruchomienie projektu korzysta z kopii w `assets/` i nie wymaga ZIP-a ani strony podglądu. Szczegóły formatu: [integracja sprite’ów](../../../../docs/integracja-spriteow.md).
