# Sprite'y ogrodu

`sprites/` zawiera 14 przezroczystych PNG w rozdzielczości siatki pixel art (1 piksel obrazu = 3 jednostki świata). Dwanaście plików odpowiada stacjom z `RoomLayout.YARD_STATIONS`: `gate`, `garden`, `dig`, `fetch`, `bush_0`, `bush_1`, `bush_2`, `outing`, `shade`, `course`, `puddle` i `sprinkler`. `gate_open` i `puddle_dry` to dodatkowe stany tej samej stacji.

Każdy obiekt ma własny węzeł `YardStationView` i `Sprite2D`, co pozwala przesuwać, skalować, podświetlać lub wymieniać grafikę bez zmiany panoramy. Pulsujący obrys pochodzi z `scripts/ui/yard_sprite_glow.gdshader`; drobne błyski rysuje ten sam węzeł. Wzrost roślin, strumienie zraszacza, krople, rozłożony tor i efekt picia są nadal odrębnymi warstwami animacji.

Źródłowe kształty pozostają w kodzie Godota. Sprite'y można odtworzyć poleceniem:

```sh
godot --path . --script res://tools/export_yard_sprites.gd
```

Prostokąty kadrowania w jednostkach świata znajdują się w `scripts/model/yard_sprite_layout.gd`. Po odtworzeniu PNG należy uruchomić import zasobów Godota przed eksportem APK. Tło `assets/art/environments/yard-sunny-background-v1.png` zawiera tylko krajobraz; wszystkie interaktywne elementy są nad nim.
