# Cykl zachowań YuFriend

## Automatyczny sen — 22 listopada 2026

Pies sam zasypia i budzi się według lokalnego zegara, także poza aplikacją. Domyślnie śpi około **18 godzin na dobę**. Okna czuwania to **06–07, 09–10, 12–13, 15–16, 18–19 i 21–22**. Pomiędzy nimi trwają dwugodzinne drzemki, a nocą sen 22–06. Istniejące stopniowe dopasowanie do nawyków przesuwa cały harmonogram; aktualne godziny pobudek pokazuje profil.

Otwarcie gry ani powrót z tła nie budzą śpiącego psa. Podczas snu dymek i pasek opieki pokazują godzinę następnej pobudki. Po 20 sekundach zapowiedzi pies sam idzie do legowiska, również z podwórka. Rozpoczęta czynność, trening lub gra kończą się przed snem; sama otwarta zakładka treningu ani pozostawiony wynik zakończonej gry nie blokują zaśnięcia. Dotknięcie pieska albo „Obudź” daje dziesięć minut wspólnego czasu. Ten termin jest zapisany, nie odnawia go kolejne głaskanie ani restart. Potem pies wraca do swojego rytmu. Przycisk drzemki pozostaje opcjonalny; nie jest potrzebny do zwykłego snu.

W zaplanowanym śnie energia odzyskuje **13 punktów na godzinę netto**, a pozostałe potrzeby maleją z **35% zwykłego tempa**. Pełna energia nie kończy snu. Reguły są takie same w grze i w projekcji nieobecności/widgetu. Potrzeby poza aplikacją nadal zmieniają się najwyżej przez osiem godzin; aktualny stan snu wynika z bieżącego zegara nawet po dłuższej nieobecności. Dodatkowy krótki odpoczynek wybrany przy zmęczeniu w oknie czuwania zachowuje wcześniejszą szybką regenerację w otwartej grze.

Po pobudce pies mówi **„Już nie śpię!”** i przez minutę pokazuje maksymalnie dwie aktualne potrzeby. Prośba o wyjście uwzględnia wykonane wyjście i niezebrany bałagan. Pozostałe potrzeby są wybierane poniżej 60 punktów, od najniższej; energia nie jest prośbą o ręczne zarządzanie snem. Jeśli potrzeby są zaspokojone, pies mówi, że wszystko jest w porządku. Przycisk dymka prowadzi do odpowiedniej czynności. Jeśli na małym ekranie nie ma miejsca na dymek, komunikat pojawia się w panelu opieki nad przyciskami potrzeb. Powrót do tej samej pobudki nie odtwarza komunikatu ponownie.

Po włączeniu „Przypomnień od pieska” i zgodzie iOS telefon planuje wiadomości o potrzebach na pobudki w godzinach **09–21**, najwyżej cztery na dzień i ruchome 24 godziny. Nie budzi opiekuna nocą. Szczegóły i ograniczenia: [powiadomienia iOS](powiadomienia-ios.md).

Schemat zapisu **v17** dodaje do `rhythm` wyłącznie `awake_until` oraz `wake_notice_at`. Migracja zachowuje pozostały postęp i archiwizuje oryginał starszego zapisu. Widget odczytuje harmonogram v17, a starsze snapshoty nadal obsługuje według poprzednich zasad.

## Zachowania w czasie czuwania

`BehaviorSystem` wybiera scenki aktywne i spokojne z uwzględnieniem pory, nastroju, cech i historii. Sen nie jest już wynikiem losowania. Wieczorem i nocą pies sam nie proponuje piłki. W czasie jawnie rozpoczętej krótkiej pobudki można grać i trenować, o ile pozwalają na to energia i zmęczenie.

## Dopasowanie do gracza

Na podstawie istniejących nawyków docelowy harmonogram wynosi:

- poranny: 21:30–5:30;
- domyślny: 22–6;
- wieczorny: 23:30–7:30;
- nocny: 1–9.

Przesunięcie całego harmonogramu zmienia się najwyżej o 30 minut na nowy zaobserwowany dzień. Jest zapisane wraz ze znacznikiem dnia; restart, cofnięty zegar i dłuższa nieobecność nie powodują skoku. Aktualne godziny widać w profilu. Historia nadal zawiera cztery szerokie pory dnia: nie przewidujemy dokładnej godziny przyjścia gracza. Odpowiedni nawyk zwiększa szansę czekania przy drzwiach w danej porze.

## Widoczne zachowania

Katalog obejmuje patrol, okno, drzwi, kosz, piłkę, oglądanie miski, dywan, czekanie pośrodku, podejście po kontakt i drzemkę. Sekwencje wykorzystują istniejące animacje i ruch w świecie. Można je przerwać opieką, zabawą lub treningiem. Przejście w tło usuwa niedokończoną kolejkę.

„Patrol przy oknie” dodaje pojedyncze szczeknięcie w dzień; „Zabawki po swojemu” dodają ponowne podejście do kosza; „Kółko przed snem” dodaje obejście legowiska przed automatycznym snem; „W poszukiwaniu ciepła” przenosi automatyczną drzemkę pod okno. Pozostałe preferencje wpływają na wagi istniejących zachowań. Automatyczne scenki nie zapisują działań gracza ani nie przyznają efektów opieki.

Po minucie bezczynności, gdy skończy się bieżąca scenka, pies może usiąść i zwrócić uwagę na gracza. Po jedzeniu i zakończonej animacji zabawy wybiera odpoczynek na dywanie. Nagroda treningowa kończy się pozostaniem w bieżącej pozycji; otwarta zakładka treningu wstrzymuje samodzielne spacery i scenki także między próbami. Po wyjściu do pokoju samodzielne zachowania wracają. Po przesunięciu pokoju może po trzech sekundach podejść w oglądaną stronę; nowa akcja i przycisk powrotu do psa anulują oczekujące podążanie. Przesunięcie nie budzi śpiącego psa.

Pełne osobne scenki pozostałych dziwactw i nowe animacje pozostają możliwymi rozszerzeniami.

## Weryfikacja

`tests/test_auto_sleep.gd` sprawdza 18 godzin snu dla każdego przesunięcia nawyków, granice drzemek, potrzeby po pobudce, restart, krótkie obudzenie, cofnięcie zegara oraz zachowanie wszystkich wcześniejszych pól przy migracji v16. `test_rhythm.gd` zachowuje testy pór, adaptacji, sekwencji i treningu. `ui_rhythm.gd` sprawdza prawdziwe przejścia animatora, dymek snu, pobudkę i przycisk karmienia.

`tools/test_ios_widget.sh` porównuje obliczenia Godota i Swifta dla starego oraz nowego rytmu. `tools/test_ios_reminders.sh` sprawdza terminy pobudek, przesunięcia, zmiany czasu, ciszę nocną, zgodę i trwały limit. Rzeczywiste doręczenie na iPhonie wymaga próby po instalacji nowej wersji.
