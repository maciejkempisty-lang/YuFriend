# Podpinanie sprite’ów szczeniaka

[Mapa dokumentacji](README.md) · [Architektura animacji](architektura.md)

Od 14 listopada 2026 gra używa pakietu **22 klipów / 142 klatek** z dostawy `YuFriend-AB`, w jednym stylu pixel art. Uwzględniono poprawione warianty snu i jedzenia. Opis źródeł, sumy kontrolne i uwagi jakościowe są w [katalogu pakietu](../assets/sprites/puppy/pixel/README.md). Importer nadal obsługuje częściowe zestawy; brief ruchów jest w [liście sprite’ów](lista-spriteow-szczeniaka.md).

## Gdzie umieścić obrazy

- Produkcyjne PNG: `assets/sprites/puppy/pixel/sheets/`
- Produkcyjny manifest: `assets/sprites/puppy/pixel/manifest.json`
- Starszy przykład ilustracji: `assets/sprites/puppy/simple/`; obecny interfejs go nie wybiera.

`manifest.example.json` pozostaje przykładem regularnej siatki dla przyszłych materiałów. Nie zastępuj nim produkcyjnego manifestu: obecny pakiet używa dokładnych prostokątów dostawy i indywidualnej kalibracji.

## Wspólna siatka — ustalenie z 15 listopada 2026

Jeden piksel logiczny to **3 jednostki świata**. Cały pokój ma **480 × 180 px** (1440 × 540 jednostek). Tło, przedmioty i pies trafiają do jednego małego `SubViewport`. Gotowy obraz jest powiększany metodą `nearest` całkowitą liczbę razy w pikselach okna, także przy ułamkowej skali interfejsu. Zbliżenie przełącza mnożnik 1×/2× zamiast płynnie skalować obraz; na bardzo krótkim ekranie zostaje widok podstawowy. Kamera i pozycje wyświetlanych obiektów są przyciągane do siatki.

Dla kolejnej, ręcznie dopracowanej dostawy ustalamy:

| Materiał | Siatka i wielkość |
|---|---|
| Szczeniak | Płótno **64 × 64 px**, podparcie **(32, 54)**; sylwetka około **40 × 40 px**, z zapasem na ogon i łapę |
| Pokój | **480 × 180 px**, osobne warstwy ściany/podłogi; przedmioty osobno, aby zachować zasłanianie |
| Legowisko / miska / piłka | Około **62 × 24 / 20 × 12 / 10 × 10 px**, ta sama gęstość co pies |
| Kolory | Zamknięta paleta psa i wspólne kolory otoczenia; wybór konkretnych odcieni po ręcznej klatce stojącej |

Płótno 64 px jest wystarczające dla **mniejszej sylwetki około 40 px**, z marginesami. Nie należy wciskać w nie wcześniejszego psa szerokości 55–60 px. Najpierw przygotować boczne stanie i siad oraz sprawdzić maksymalny zasięg ogona, łapy i ukłonu, potem animować resztę.

W obecnym importerze regularny pakiet 64 px ma `display_height: 300`, `scale: 1` i wspólne podparcie. Wynika to z istniejącej skali prezentacji: `300 / 64 × 0.64 / 3 = 1`, czyli jeden piksel źródła staje się jednym pikselem pokoju. [Przykładowy manifest](../assets/sprites/puppy/pixel/manifest.example.json) używa tej wartości. **Nie zastępuj nim obecnego manifestu dostawy**: duże arkusze nadal wymagają własnych regionów i kalibracji.

Obecne obrazy są makietą rasteryzowaną na wspólnej siatce, a nie automatycznie naprawionym ręcznym pixel artem. Oryginalne PNG pozostają nietknięte. Przerysowanie sylwetek, spójność palety i zgranie łap z ruchem nadal wymagają pracy graficznej. Przygotować próbę `idle`, `walk`, `sit_down` przed zmianą wszystkich 142 klatek.

PNG powinny mieć przezroczyste tło i identyczne marginesy. Pies jest skierowany w prawo; odbicie w lewo wykonuje gra. Chód rysujemy w miejscu, bez przesuwania płótna.

## Wariant 1: arkusz dla każdej animacji

```json
{
  "version": 1,
  "frame_size": [512, 512],
  "anchor": [256, 430],
  "display_height": 245,
  "animations": {
    "walk": {
      "sheet": "res://assets/sprites/puppy/simple/walk.png",
      "columns": 4,
      "count": 8,
      "fps": 10
    }
  }
}
```

Ten arkusz ma 2048 × 1024 px: cztery kolumny i dwa rzędy. Odczyt następuje od lewej do prawej, następnie od góry w dół. `count` podaje liczbę używanych klatek; puste pola na końcu arkusza zostają pominięte. Nie dodawaj odstępów ani obramowań między polami. Importer obsługuje od jednej do czterech kolumn.

## Wariant 2: osobne pliki PNG

Zamiast `sheet`, `columns` i `count` podaj uporządkowaną tablicę `frames`. Przykładowa zawartość pola `animations`:

```json
{
  "sit_down": {
    "frames": [
      "res://assets/sprites/puppy/simple/sit_down_00.png",
      "res://assets/sprites/puppy/simple/sit_down_01.png",
      "res://assets/sprites/puppy/simple/sit_down_02.png"
    ],
    "fps": 5
  }
}
```

Ten przykład ma trzy klatki i trwa 0,6 s. Lista może mieć inną długość zgodnie z gotową animacją; nie narzucamy liczby klatek z briefu. Nie wpisuj jednocześnie `frames` i `sheet` dla tego samego klipu.

## Czas klatek

Bez dodatkowych ustawień każda klatka trwa `1 / fps` sekundy. Opcjonalne `durations` zawiera po jednym dodatnim mnożniku na klatkę. Przykładowo `fps: 8` i `durations: [1, 1, 3, 1]` dają łącznie 0,75 s; trzecia klatka trwa trzy razy dłużej. To przydatne do zatrzymania uniesionej łapy.

Pętle i klipy jednorazowe wynikają z nazw w briefie. Importer ustawia je automatycznie. Gra odczytuje faktyczny czas klipu, przeprowadza potrzebne przejścia między pozycjami i czeka z nagrodą na koniec sztuczki. Okno nagrody pozostaje osobnym parametrem rozgrywki.

## Wariant 3: dokładne prostokąty i kalibracja dostawy

Obecny pakiet używa `sheet` oraz `regions` zamiast `columns` i `count`. Każdy region to `[x, y, szerokość, wysokość]` w oryginalnym PNG; kolejność tablicy jest kolejnością odtwarzania. Pola mogą różnić się wymiarami, np. 443/444 px w `walk`. Nie przycinamy ani nie skalujemy zapisanych obrazów.

Każdy klip ma `anchors`: po jednym `[x, y]` w lokalnych współrzędnych regionu, oraz `scale`: jednolity mnożnik rozmiaru klipu. Bazowa skala wynosi `display_height / frame_size[1]`, a potem jest mnożona przez `scale`. Dla tej dostawy podparcie Y zmierzono przy nieprzezroczystej sylwetce, a X pozostaje stały w klipie. Skala jest kalibracją prezentacji, nie zmianą danych psa. Odbicie w lewo uwzględnia rzeczywistą szerokość regionu.

Manifest ma `fps: 10`; każdy `durationMs` z dostawy został przeliczony na mnożnik `durationMs / 100`. Zachowuje to również nierówne czasy przy podawaniu łapy. Wszystkie 22 klipy trafiają do jednego `puppy_pixel.res`, z metadanymi `clip_layouts`. Próg alfa 0,5 w `puppy_pixel.tres` usuwa przy renderowaniu słabo przezroczyste obwódki; źródłowe PNG pozostają nietknięte.

## Import do gry

1. Dodaj PNG i `manifest.json`. Otwórz projekt w Godocie i poczekaj na import obrazów, albo wykonaj pierwsze polecenie poniżej.
2. Uruchom importer dla wybranego stylu. Jeśli pakiet już był wygenerowany, dopisz `--replace`, aby go przebudować z aktualnego manifestu.
3. Uruchom grę ponownie. Pixel art jest wybierany automatycznie także przy starym zapisie; w Profilu nie ma przełącznika stylu.

Polecenia z katalogu projektu:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --editor --quit
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tools/import_sprites.gd -- pixel res://assets/sprites/puppy/pixel/manifest.json --replace
```

Importer tworzy `data/animations/puppy_pixel.res`; gra wczytuje ten pakiet automatycznie. Importer produkcyjny przyjmuje wyłącznie `pixel`; ilustracyjne referencje i dawne przykłady pozostają materiałami źródłowymi. Import nie modyfikuje źródłowych PNG, zapisu psa ani referencji. Ponowny import **zastępuje cały pakiet**: zachowaj w manifeście także wcześniej dostarczone animacje.

Nieznana nazwa klipu, brak pliku, niezgodny rozmiar lub błędny czas klatki zatrzymują import przed zastąpieniem istniejącego pakietu. Lista brakujących klipów jest informacją: nadal można uruchomić grę z częściowym zestawem.

## Walidowane parametry manifestu

| Pole | Wymaganie importera |
|---|---|
| `version` | Wartość `1` |
| `frame_size` | Dwa całkowite wymiary od 1 do 4096 |
| `anchor` | Dwie liczby określające punkt wewnątrz płótna, łącznie z jego krawędzią |
| `display_height` | Od 32 do 400 jednostek sceny; domyślnie 245 |
| `animations` | Co najmniej jeden klip o nazwie z briefu |
| `sheet` / `frames` | Dokładnie jedno źródło klatek dla klipu; PNG wewnątrz `res://assets/` |
| `columns` i `count` | Dla arkusza: 1–4 kolumny i 1–64 używane klatki mieszczące się w arkuszu |
| `regions` | Alternatywa dla `columns/count`: 1–64 całkowite prostokąty wewnątrz arkusza; wymaga `anchors` |
| `anchors` | Opcjonalnie po jednym punkcie wewnątrz odpowiedniej klatki; obowiązkowe z `regions` |
| `scale` | Opcjonalny skończony mnożnik od 0,1 do 8; domyślnie 1 |
| `frames` | Dla osobnych plików: 1–64 ścieżki, wszystkie obrazy o rozmiarze `frame_size` |
| `fps` | Liczba większa od 0 i nie większa od 60 |
| `durations` | Opcjonalna tablica mnożników większych od 0 i nie większych od 60, po jednym na klatkę |

Importer sprawdza strukturę i geometrię plików. Przezroczystość, spójność rysunku i płynność ruchu wymagają oceny wizualnej. Źródła walidacji to [SpriteImporter](../scripts/pet/sprite_importer.gd) i [polecenie importu](../tools/import_sprites.gd).

## Edycja bez manifestu

Można też otworzyć `data/skins/puppy_pixel.tres` w Inspektorze i przypisać własny `SpriteFrames` do pola `frames`. Ręcznie przypisany zasób ma pierwszeństwo przed generowanym pakietem. Ustaw wtedy także `frame_anchor`, `frame_height` i `display_height` oraz właściwe pętle i FPS. Pozostaw pole `frames` puste, jeśli korzystasz z importera.

## Ocena obecnej dostawy

Obejrzano wszystkie 142 klatki wyrenderowane w Godocie oraz ekran Domu i Treningu. Podparcie i skala są skorygowane, a nagroda nadal czeka na koniec sztuczki. Nie jest to jeszcze finalny ręczny pixel art: między klipami pozostają różnice anatomii, palety i gęstości „pikseli”, szczególnie przy wstawaniu z leżenia. Weryfikacja na fizycznym telefonie pozostaje otwarta.

Chód przesuwa psa o 38,4 jednostki świata na sekundę, niezależnie od szerokości okna. Klip gra w oryginalnym tempie 1×, także przy podążaniu za piłką. Osobny klip `run` jest kolejnym zadaniem graficznym; nie ma go jeszcze w pakiecie ani na liście importera. Ostateczne zgranie faz łap z ruchem wymaga dopracowania samego cyklu. Miska i legowisko pozostają elementami prototypowego pokoju; pysk nie jest jeszcze dokładnie dopasowany do miski. `bark_stand` wita po ponownym uruchomieniu gry po ponad 5 minutach nieobecności, jeśli pies nie śpi. `treat_take_stand` pokazuje przyjęcie smakołyku po ćwiczeniu na stojąco; po siadzie pies zachowuje pozycję i macha ogonem. Szczeknięcie jest na razie bez dźwięku.
