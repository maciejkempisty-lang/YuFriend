# Tło pokoju pixel art

`puppy-room-pixel-v1.png` — nieprzezroczysty obraz RGB, 1254 × 1254 px, wygenerowany we wbudowanym ImageGen i dodany do gry 14 listopada 2026. [Dokładny prompt](puppy-room-pixel-v1-prompt.txt) jest zachowany obok obrazu. Obraz przedstawia sam pokój: ścianę, okno, roślinę, obrazek z łapą i podłogę. Pies, dywan oraz przedmioty opieki nie są w niego wtopione.

Panorama jest składana w `RoomArtwork` w świecie 1440 × 360. Środkowa ściana korzysta z regionu źródła (0, 186, 1254, 650), w jednolitej skali 0,4, od X=400. Kolory skrajnych kolumn przedłużają ścianę na oba końce pokoju. Region desek (0, 900, 600, 354) bez smugi słońca tworzy podłogę; pojedyncze światło jest dodawane pod oknem, a listwa leży przy Y=260 świata. Źródłowy PNG pozostaje niezmieniony.

Legowisko, miska, kosz, drzwi, piłka i cień mają własne węzły, rysowane na siatce 3 jednostek. Dane ich położeń i miejsc dojścia zawiera `RoomLayout`. Okno korzysta z istniejącej grafiki centralnej ściany; nowe stacje nie są wtopione w jeden obraz. Widok pokazuje około 2–3 ekranów całego pokoju. Jeden piksel logiczny odpowiada 3 jednostkom świata; `SubViewport` rasteruje źródła na tej siatce, a `Sprite2D` powiększa wynik całkowicie w pikselach okna. Zbliżenie 2× zwiększa ten mnożnik, bez płynnego zoomu ani ponownego próbkowania źródeł w większej rozdzielczości.

Statyczne listy rysowania nie są przebudowywane przy przesuwaniu kamery ani ruchu psa. Pierwszy plan jest sortowany według Y, więc pies może przejść za koszem lub przed nim. Jest to działający układ prototypowy oparty na obecnej grafice; docelowy atlas tła i przedmiotów można podmienić niezależnie od reguł opieki.

Grafika jest stylizowana na pixel art; generator nie zapewnia ścisłej logicznej siatki ani zamkniętej palety. Oceniono wygląd w Godocie na pionowych i poziomym układzie pulpitu. Równe bloki pikseli sprawdzono na zrzutach pulpitu, także w oknie 1080 × 2340. Fizyczny telefon nadal wymaga oceny po eksporcie. Docelowy ręczny pokój ma 480 × 120 px; wspólną siatkę psa i przedmiotów opisuje [integracja](../../../docs/integracja-spriteow.md).
