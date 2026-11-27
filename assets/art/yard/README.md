# Sprite'y ogrodu

`sprites/` zawiera 14 przezroczystych PNG w rozdzielczości siatki pixel art (1 piksel obrazu = 3 jednostki świata). Dwanaście plików odpowiada stacjom z `RoomLayout.YARD_STATIONS`: `gate`, `garden`, `dig`, `fetch`, `bush_0`, `bush_1`, `bush_2`, `outing`, `shade`, `course`, `puddle` i `sprinkler`. `gate_open` i `puddle_dry` to dodatkowe stany tej samej stacji.

Każdy obiekt ma własny węzeł `YardStationView` i `Sprite2D`, co pozwala przesuwać, skalować, podświetlać lub wymieniać grafikę bez zmiany panoramy. Pulsujący obrys pochodzi z `scripts/ui/yard_sprite_glow.gdshader`; drobne błyski nadal obsługuje istniejący `YardSparkle`. Obrys i błyski znikają po odkryciu miejsca zgodnie z dotychczasowymi regułami. Wzrost roślin, strumienie zraszacza, krople, rozłożony tor i efekt picia są nadal odrębnymi warstwami animacji.

Źródłowe kształty pozostają w kodzie Godota. Sprite'y można odtworzyć poleceniem:

```sh
godot --path . --script res://tools/export_yard_sprites.gd
```

Prostokąty kadrowania w jednostkach świata znajdują się w `scripts/model/yard_sprite_layout.gd`. Po odtworzeniu PNG należy uruchomić import zasobów Godota przed eksportem gry. Tło `level-editor/assets/environment-yard-sunny-background-v1.png` zawiera tylko krajobraz; wszystkie interaktywne elementy są nad nim.


Warstwy świata i parametry nowych grafik: [wytyczne grafik](../../../docs/wytyczne-grafik.md). Stacje przestrzenne są teraz dziećmi MiddleGround z Y-sort; ich punkt podstawy określa `YardSpriteLayout.SORT_ORIGINS`. PNG zachowują dotychczasowe położenie dzięki przesunięciu lokalnemu. Ziemia, kałuża i istniejący złożony zestaw odpoczynku pozostają w Background. Kolorystykę przestrzennych sprite'ów w deszczu i nocą zachowuje `yard_weather_tint.gdshader`.
