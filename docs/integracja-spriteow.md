# Podpinanie sprite’ów szczeniaka

[Mapa dokumentacji](README.md) · [Architektura animacji](architektura.md)

Możesz przygotowywać klipy po kolei. Gra użyje dostarczonych klatek, a dla brakujących zachowa dotychczasowe ilustracje. Nie trzeba czekać na komplet 22 animacji. Brief ruchów i ich kolejność są w [liście sprite’ów](lista-spriteow-szczeniaka.md).

## Gdzie umieścić obrazy

- Ilustracja: `assets/sprites/puppy/simple/`
- Pixel art: `assets/sprites/puppy/pixel/`

W każdym folderze jest `manifest.example.json`. Skopiuj go jako `manifest.json`, wpisz rzeczywiste nazwy obrazów i pozostaw tylko klipy, których pliki już masz. Przykład ma dwa przyszłe arkusze `idle.png` i `walk.png`; nie są jeszcze dostarczone.

W obrębie jednego pakietu wszystkie klatki mają wspólny rozmiar i punkt podparcia. Startowe ustawienie ilustracji to **512 × 512**, punkt **(256, 430)**. Przykład pixel art używa **64 × 64**, punktu **(32, 54)** i wysokości wyświetlania 256, czyli skali 4× w przestrzeni sceny. Inna siatka wymaga zmiany tych wartości w manifeście. Skalowanie całego okna przez system może dodatkowo zmienić fizyczny rozmiar pikseli.

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

## Import do gry

1. Dodaj PNG i `manifest.json`. Otwórz projekt w Godocie i poczekaj na import obrazów, albo wykonaj pierwsze polecenie poniżej.
2. Uruchom importer dla wybranego stylu. Jeśli pakiet już był wygenerowany, dopisz `--replace`, aby go przebudować z aktualnego manifestu.
3. Uruchom grę ponownie i w **Profilu** wybierz właściwy styl.

Polecenia z katalogu projektu:

```sh
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --editor --quit
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script res://tools/import_sprites.gd -- simple res://assets/sprites/puppy/simple/manifest.json
```

Dla pixel art zmień `simple` na `pixel` w obu miejscach drugiego polecenia. Importer tworzy `data/animations/puppy_simple.res` lub `puppy_pixel.res`; gra wczytuje ten pakiet automatycznie. Nie modyfikuje źródłowych PNG, zapisu psa ani referencji. Ponowny import **zastępuje cały pakiet**: zachowaj w manifeście także wcześniej dostarczone animacje.

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
| `frames` | Dla osobnych plików: 1–64 ścieżki, wszystkie obrazy o rozmiarze `frame_size` |
| `fps` | Liczba większa od 0 i nie większa od 60 |
| `durations` | Opcjonalna tablica mnożników większych od 0 i nie większych od 60, po jednym na klatkę |

Importer sprawdza strukturę i geometrię plików. Przezroczystość, spójność rysunku i płynność ruchu wymagają oceny wizualnej. Źródła walidacji to [SpriteImporter](../scripts/pet/sprite_importer.gd) i [polecenie importu](../tools/import_sprites.gd).

## Edycja bez manifestu

Można też otworzyć `data/skins/puppy_simple.tres` albo `puppy_pixel.tres` w Inspektorze i przypisać własny `SpriteFrames` do pola `frames`. Ręcznie przypisany zasób ma pierwszeństwo przed generowanym pakietem. Ustaw wtedy także `frame_anchor`, `frame_height` i `display_height` oraz właściwe pętle i FPS. Pozostaw pole `frames` puste, jeśli korzystasz z importera.

## Sprawdzenie pierwszej partii

Najpierw sprawdzimy `idle`, `walk`, `sit_down`, `sit_idle`, `stand_up` oraz zgodność siadu i stania. Następnie machanie ogonem i `give_paw`. Kontrolujemy stabilność łap, brak skoków sylwetki przy zmianie klipu, poprawne odbicie i czytelność przy małym rozmiarze.

Prędkość przesuwania po pokoju oraz pozycję miski dopasujemy po otrzymaniu rzeczywistych klatek. Obecna miska i legowisko są elementami prototypowego pokoju, a ruchy pyska nie są jeszcze do nich dopasowane. `bark_stand` i `treat_take_stand` są rozpoznawane przez animator, lecz nie mają jeszcze osobnej sytuacji rozgrywki; pozostałe klipy uruchamiają opieka, ruch i trening.
