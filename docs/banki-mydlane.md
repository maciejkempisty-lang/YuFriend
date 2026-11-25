# Bańki mydlane — build 41

Wejście: Podwórko → Pobaw się → Bańki mydlane. Po instrukcji wybierz
„Puszczamy bańki!”. Przytrzymaj palec w scenie przez 0,2–1,2 s, przesuń go
w wybranym kierunku i puść. Dłuższe przytrzymanie tworzy większą, wolniejszą
bańkę. Kierunek powiewu jest stały przez całą rundę i widoczny w opisie.

Gloria sama podbiega i skacze do osiągalnych baniek. Punkt jest przyznawany
przy kontakcie pyszczka z bańką podczas skoku. Nie ma punktów za samo
wypuszczenie. Efekt rozbłysku pokazuje trafienie. Grafika pyszczka jest
wyrównana do punktu kontaktu symulacji, także po odbiciu lustrzanym.

Runda trwa maksymalnie 30 s, obejmuje 10 wypuszczeń i najwyżej 3 bańki naraz.
Co piąta bańka jest złota, warta 2 pkt; pozostałe po 1. Maksimum: 12 pkt.
Gwiazdki: 1 od 1 pkt, 2 od 6 pkt, 3 od 10 pkt. Gdy wypuszczono wszystkie
bańki i ostatnia zniknie, runda kończy się wcześniej. Pierwszy wynik 3 gwiazdek
trafia do Albumu; rekord zapisuje istniejący `.games.cfg`.

Szybkie tapnięcie, anulowanie dotyku i drugi palec nie tworzą dodatkowej
bańki. Wyjście lub przejście w tło usuwa bieżącą rundę. Sen, brak energii,
zajętość oraz blokada zapisu korzystają ze wspólnych reguł zabaw. Pozostają
jednokrotne rozliczenie i wspólny odstęp nagród 30 s. Nie ma nowego zasobu,
zakupów, mikrofonu ani migracji pet.json (nadal v17). Statystyka liczby zabaw
korzysta z istniejącego pola ball, rekord i wspomnienie mają własne klucze.

Model `BubblePlay` używa stałego kroku 1/120 s. Rysowanie baniek i rozbłysków
jest kodowe, animacje psa pochodzą z dotychczasowego pakietu. Prostokąt gry
przycina odlatujące bańki, żeby nie zachodziły na przyciski dialogu.

Testy automatyczne: `test_soap_bubbles.gd` (20 sprawdzeń),
`ui_soap_bubbles.gd` (22 sprawdzenia przy 320/390 pkt), w tym różne FPS,
limity, anulowanie, rekord 12 pkt, powtórne rozliczenie, tło i zgodność pyska
z fizyką. Obejrzano zrzut sceny 320 pkt.

Pełna regresja: 43/43 zestawów logiki; 38/39 UI w pierwszym przebiegu,
a następnie 22/22 sprawdzenia UI baniek po poprawie synchronizacji pyska
przed renderowaniem. Kopia Glorii: 69/69 sprawdzeń odczytu i zapisu.

Próby ręczne: [lista dla buildu 41](testy-reczne-build-41.md).
