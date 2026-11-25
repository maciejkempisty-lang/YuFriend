# Agility na czas — build 43

Wejście: **Podwórko → Pobaw się → Tor na czas** albo dotknięcie toru
w zbliżeniu i wybór **Na czas**. Obok pozostaje **Spokojny tor**, korzystający
z dotychczasowego treningu Zostań. Skrót na mapie całego podwórka nadal
uruchamia spokojny tor.

## Przejazd

Po trzysekundowym odliczaniu Gloria podbiega do startu. Przed każdym z trzech
odcinków pojawia się znacznik oraz przycisk: **Slalom**, **Skacz**, **Stój**.
Gracz naciska go, gdy kółko dotrze do jasnego pola. Okno wynosi ±0,35 s
wokół punktu 1,5 s od pokazania komendy. Bez dotknięcia lub przy dotknięciu
za wcześnie pies zatrzymuje się na 1,5 s, a następnie kontynuuje. Każda komenda
jest oceniana tylko raz. W tej wersji pies czeka przy przeszkodzie na ocenę
komendy, a odcinki między nimi pokonuje samodzielnie.

Ruch i skok korzystają z istniejącej sceny ogrodu, ścieżki slalomu i
`PuppyJump`. Nie ma osobnego uproszczonego psa w oknie minigry. Na końcu
pojawia się wynik, liczba błędów, gwiazdki i rekord.

Czas zaczyna biec po dotarciu do startu i obejmuje ruch oraz rzeczywiste postoje.
Dojście z aktualnego miejsca w ogrodzie nie wpływa na rekord.
Kar nie dodaje się do niego ponownie. Limit przejazdu: 60 s. Brak błędów daje
3 gwiazdki, jeden błąd — 2, więcej — 1 za ukończenie. Przerwana lub
nieukończona runda nie zapisuje rekordu ani nagrody. Pierwsza ukończona
runda trafia do Albumu.

## Reguły i dane

Dostępność dziedziczy wymagania starego toru: podwórko, aktywny zapis,
brak innej czynności, pora dnia, energia ≥45, sytość ≥30, zmęczenie <63 oraz
dostępność Zostań według aktualnych odblokowań treningu. Podczas przejazdu
obowiązuje dotychczasowa kontrola bezpieczeństwa toru (m.in. energia ≥28).

Start kosztuje raz 3 energii i 2 czystości; koszt jest zapisywany przed ruchem.
Nie pobiera się dodatkowego kosztu treningu, nie zmienia opanowania, prób ani
sukcesów Zostań. Nagroda za ukończenie korzysta ze wspólnego odstępu 30 s
(+12 zabawy, +4 kontaktu, +0,35 więzi). Historia zabaw korzysta z istniejącego
licznika ball, wspomnienie ma osobny identyfikator `timed_course`.

Rekord jest minimum czasu w sekcji `agility` istniejącego `.games.cfg`.
Gwiazdki zapisywane są jako najlepsza ocena niezależnie od czasu. Plik
jest zapisywany atomowo po udanym zapisie postępów. Uszkodzony plik rekordów
nie jest nadpisywany. Schemat psa pozostaje v17.

Anulowanie, powrót do domu, utrata zapisu, sen i przejście w tło przerywają
rundę; skok wraca na ziemię. Nie przywracamy kosztu rozpoczętej rundy.
Losowanie trasy dnia pozostaje kolejnym etapem — obecnie jest jedna stała trasa.

## Weryfikacja i próba ręczna

`test_timed_course.gd`: 58 sprawdzeń punktacji, kar, kosztu, rekordów,
wspólnego odstępu nagród, blokad, anulowania i ochrony treningu.
`ui_timed_course.gd`: 22 sprawdzenia przy 320/390 pkt z prawdziwym ruchem
slalomu, skokiem, metą, oknem wyniku i anulowaniem w powietrzu.
Menu dziewięciu zabaw sprawdzone bez przewijania przy obu szerokościach.

Na iPhonie sprawdź:

- Czy znajdujesz Tor na czas w menu i oba warianty po dotknięciu toru?
- Czy przycisk jest wygodny, jasne pole czytelne, a trafienie zgodne z dotykiem?
- Czy jeden wczesny dotyk lub brak reakcji powoduje tylko jeden postój 1,5 s?
- Czy Gloria omija pachołki, przeskakuje płotek i pozostaje widoczna przy mecie?
- Czy wynik i lepszy rekord pozostają po ponownym uruchomieniu?
- Czy Przerwij i przejście w tło działają także podczas skoku?
- Czy Spokojny tor nadal pozwala ćwiczyć i pochwalić Zostań?

Ocena wygody fizycznych gestów pozostaje do wykonania przez użytkownika.
