# Ciepły dom i ogród — wariant 1

Projekt do otwarcia w YuFriend Studio:
`level-editor/projects/art-kit-warm-native.json`.

Ten katalog zawiera **41 osobnych PNG**: dwa tła 480 × 120 px oraz
39 elementów domu i ogrodu. Przedmioty mają przezroczyste tło, a widoki za
oknami są pełnymi prostokątami. Wszystkie pliki są dopasowane do
siatki poziomu 1440 × 360 jednostek (1 piksel grafiki = 3 jednostki świata).
Elementy środkowej warstwy mają pivot przy podstawie, więc mogą zasłaniać
pieska zgodnie z pozycją na ziemi.

## Dom

Tło obejmuje wyłącznie ścianę, boazerię, podłogę i wnęki. Osobne PNG mają:
drzwi, oba okna i widoki za nimi, kuchnię, lampkę wiszącą i stojącą, obraz,
zegar, roślinę, skrzynię, komodę z gramofonem, półkę, gitarę, dywan,
legowisko, miskę, piłkę i kosz z zabawkami. Widoki za oboma oknami są w
wersjach `day` i `night`. Lampki są w wersjach `off` i `on`, z takimi samymi
wymiarami i pozycjami par.

## Ogród

Tło zawiera trawę, płot, dalszą zieleń, drzewo oraz fragment domu z pustymi
wnękami. Osobne PNG mają pasujące drzwi, okno, pergolę, legowisko, miskę,
grządkę, konewkę, miejsce kopania, matę do aportowania, piłkę, krzak,
przeszkodę, kałużę, zraszacz i tabliczkę. Krzak można powielać w edytorze.

Projekt otwiera się w stanie dziennym z wyłączonymi lampkami. Wersje nocne i
lampki `on` są umieszczone w tych samych pozycjach jako ukryte elementy;
zmienia się je przełącznikiem widoczności. Grafiki źródłowe HD znajdują się
w `level-editor/assets/warm-v1/`, a pełne koncepcje w `docs/images/`.
Eksport do siatki 480 × 120 obejmuje całą panoramiczną ilustrację bez
przycinania; pierwotna koncepcja HD ma proporcje 3:1, więc natywne tło jest
nieznacznie spłaszczone w pionie do proporcji poziomu 4:1.

Podglądy kompozycji: `docs/images/warm-native-home.png`,
`docs/images/warm-native-home-night.png` i `docs/images/warm-native-yard.png`.
Projekt HD można również otworzyć jako `art-kit-warm.json`.

Regeneracja metadanych i eksportu: `python3 tools/build_warm_editor_project.py`,
następnie `python3 tools/export_warm_native.py`.
