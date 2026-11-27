# Grafiki pokoju i ogrodu — rozmiary, warstwy i spójność

Stan: 26 listopada 2026. Specyfikacja nowych grafik i zamienników; obecne źródła pozostają bez zmian. Pokój i ogród korzystają z tego samego układu `SceneLayers` w `RoomView`. To węzły tworzone przy uruchomieniu, widoczne w zdalnym drzewie Godota, a nie trzy oddzielne pliki scen do ręcznej edycji.

## Trzy warstwy

| Warstwa | Zastosowanie | Przykłady |
|---|---|---|
| Background | Zawsze pod postaciami; tło i płaskie elementy podłoża | Ściany, niebo, dalekie drzewa, podłoga, dywan, kałuża, ziemia, legowisko |
| MiddleGround | Wspólne sortowanie postaci i przestrzennych przedmiotów według podstawy | Pies, goście, kosz, miska, krzaki, tabliczki, rośliny, przeszkody |
| Foreground | Zawsze nad światem; dekoracje blisko kamery i efekty wymagające widoczności | Liście przy krawędzi, krople otrzepywania, wskazówka rzutu |

HUD, przyciski, menu i dymki UI pozostają poza tymi warstwami. Wszystkie trzy warstwy świata mają wspólny początek i tę samą kamerę; nie ma paralaksy.

Obecny PNG `shade` łączy daszek, legowisko i miskę, dlatego pozostaje w Background, aby zachować odpoczynek i picie. Przy nowej wersji dostarcz je osobno: podłoże/legowisko do Background, miska i słupki z własnymi podstawami do MiddleGround. Mata Zostań również pozostaje pod psem. Ogon w chowanego to wskazówka w Foreground, aby krzak jej nie zasłaniał.

## Wspólna skala

- Docelowa panorama: **480 × 180 pikseli logicznych**, czyli **1440 × 540 jednostek świata** (1 piksel = 3 jednostki). Starsze arkusze 480 × 120 (1440 × 360) są wspierane przez migrację projektów edytora, ale nowe tła autorsko rysuj w nowej skali.
- **1 piksel grafiki = 3 jednostki świata.** Przykład: przedmiot 32 × 24 px zajmuje 96 × 72 jednostki świata.
- Pracuj w rozdzielczości logicznej. Powiększony podgląd eksportuj osobno, skalowaniem nearest-neighbor 3× lub 6×.
- Nie dopasowuj plików do rozdzielczości telefonu. Gra skaluje wspólny świat; UI ma osobny układ bazowy 390 × 844.
- Pas ruchu łap: X=95–1345, Y=286–328 świata (około X=32–448, Y=95–109 px logicznych). Linia podłogi pokoju: Y=260 świata (około 87 px).
- Podłoga jest przedłużana w dół do Y=960, a ściana nad panoramę dla różnych kadrów. Nowa panorama 480 × 120 powinna mieć osobny prosty fragment/kolor do przedłużenia góry i podłoża. Sama panorama nie pokryje wszystkich proporcji telefonu.

Stare źródło pokoju 1254 × 1254 px jest kadrowane i składane przez kod. **Nie zastępuj go bezpośrednio panoramą 480 × 120 pod tą samą nazwą**: wymaga to zmiany regionów rysowania. Powyższy format to docelowa dostawa nowego tła, nie format istniejącego atlasu.

## Gotowe rozmiary zamienników ogrodu

Te rozmiary odpowiadają obecnym PNG. Zachowaj pełne płótno, przezroczyste marginesy oraz pozycję obiektu. Wariant otwarty/zamknięty lub mokry/suchy musi mieć identyczne wymiary i wyrównanie.

| Plik w `assets/art/yard/sprites/` | PNG, px logiczne | Obszar świata |
|---|---:|---:|
| gate / gate_open | 37 × 32 | 111 × 96 |
| garden | 50 × 22 | 150 × 66 |
| dig | 46 × 18 | 138 × 54 |
| fetch | 85 × 27 | 255 × 81 |
| bush_0 / bush_1 / bush_2 | 54 × 31 | 162 × 93 |
| outing | 18 × 19 | 54 × 57 |
| shade | 71 × 49 | 213 × 147 |
| course | 21 × 22 | 63 × 66 |
| puddle / puddle_dry | 48 × 17 | 144 × 51 |
| sprinkler | 34 × 27 | 102 × 81 |

Źródłem wymiarów jest `scripts/model/yard_sprite_layout.gd`: `CROPS` podaje obszary w jednostkach świata, `SORT_ORIGINS` punkty podstawy. Domowa miska, kosz i legowisko są obecnie rysowane kodem; nie mają obowiązujących rozmiarów osobnych plików PNG.

## Punkt podstawy i zasłanianie

Dla każdego nowego assetu MiddleGround podaj **pivot**, czyli punkt styku z podłożem, liczony w pikselach od lewego górnego rogu PNG. Dla postaci to punkt między łapami na ziemi, dla kosza środek podstawy, dla tabliczki dół słupka. Nie wyznaczaj go z końca cienia ani pustego marginesu.

Węzeł obiektu stoi w świecie na tym punkcie, a Sprite2D ma przesunięcie `-pivot` i skalę 3. Obiekty w MiddleGround mają wspólne `z_index = 0`; większe Y podstawy oznacza rysowanie z przodu. Nie używaj z_index do poprawiania błędnie ustawionego pivotu. Skok przesuwa grafikę psa w górę, ale jego podstawa na ziemi nadal wyznacza kolejność zasłaniania.

Nowe grupy obiektów, które trzeba osobno obchodzić, dostarczaj jako oddzielne PNG. Donica i pies nie powinny być wtopione w panoramę. Podłoże pod pergolą, słupki i liście zasłaniające postacie wymagają osobnych części. Cienie najlepiej dostarczać osobno, bez powiększania podstawy obiektu.

Warstwa nie określa kolizji, pola dotyku ani punktu dojścia. Te dane ustawiamy oddzielnie w kodzie. Zamiennik o innej sylwetce wymaga sprawdzenia dotyku, nie tylko rozmiaru pliku.

## Styl

- Ciepły, spokojny pixel art, widok z boku z płytką głębią; bez perspektywy izometrycznej.
- Drewno i ziemia: `#947354`, `#805733`, `#C79457`; zieleń: `#729885`, `#8CA374`, `#648778`; jasne akcenty: `#E5CE96`, `#F4E3BC`; woda: `#72A9AF`, `#AFD6D2`. To punkty odniesienia z gry, nie zamknięta paleta.
- Zachowuj kierunek światła i kontrast sąsiadujących elementów. Pies i obiekty interaktywne mają pozostać czytelne na tle.
- Bez wygładzania krawędzi, rozmycia i filtrów fotograficznych. Kształty buduj całymi pikselami. Miękką przezroczystość zostaw na świadome efekty/cienie.
- PNG RGBA z przezroczystością dla przedmiotów. Tło może być nieprzezroczyste. Bez białej obwódki po usunięciu tła, napisów, interfejsu i watermarków.
- Animacje: ten sam rozmiar klatki, pivot, skala sylwetki i oświetlenie; nie przycinaj każdej klatki inaczej. Dla psa obowiązuje dodatkowo `docs/integracja-spriteow.md` i istniejący manifest — nie skaluj jego historycznych arkuszy automatycznie do formatu dekoracji.

## Co przekazać razem z grafiką

1. PNG w docelowej rozdzielczości oraz opcjonalnie plik źródłowy z warstwami.
2. Nazwę lokacji i warstwy, rozmiar płótna, pivot w pikselach, proponowaną pozycję w świecie.
3. Dla animacji: kolejność klatek, czas każdej klatki i informację, czy pętla ma się powtarzać.
4. Podgląd na tle gry, w skali 1× i powiększeniu nearest-neighbor. Podgląd nie zastępuje oryginalnego PNG.

Przykład opisu nowego assetu: `ogrod-donica-v1.png; MiddleGround; 32×40 px; pivot=(16,38); świat=(720,315); statyczny; cień osobno`.

Po integracji sprawdzamy psa przed i za przedmiotem, dotyk, panoramę, zbliżenie, szerokości 320 i 390 punktów oraz noc/deszcz, jeśli dotyczą lokacji. W Foreground nie umieszczamy dużych nieprzezroczystych dekoracji zasłaniających miejsca zabawy lub całego psa.

## Podłączenie w kodzie

W `RoomView` warstwy są dostępne jako `world.background`, `world.middle_ground` i `world.foreground`. Przykład dla nowej donicy (plik trzeba najpierw dostarczyć):

```gdscript
var prop := Node2D.new()
prop.position = Vector2(720, 315) # podstawa w świecie
var sprite := Sprite2D.new()
sprite.texture = load("res://level-editor/assets/yard-ogrod-donica-v1.png")
sprite.centered = false
sprite.scale = Vector2.ONE * RoomLayout.PIXEL_SIZE
sprite.position = -Vector2(16, 38) * RoomLayout.PIXEL_SIZE
prop.add_child(sprite)
world.middle_ground.add_child(prop)
```

Dla obiektu stale przed lub za postaciami zmień rodzica na odpowiednią warstwę. Widoczność w danej lokacji oraz interakcje trzeba podłączyć osobno. Nie przenoś całego HUD-u do Foreground. Dla obecnych stacji ogrodu używaj `YardStationView`; utrzymuje również warianty, podświetlenie i kolorystykę pogody.
