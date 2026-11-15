# Efekty dźwiękowe YuFriend

Pakiet zawiera 22 nagrania wygenerowane 15 listopada 2026 w ElevenLabs Sound Effects v3, na zalogowanym koncie użytkownika z planem Starter. To syntetyczne efekty, nie nagrania prawdziwego psa. Pierwotny zestaw liczył 20 nagrań; panel konta po jego wygenerowaniu pokazał 90 wykorzystanych kredytów z 40 000. Późniejsze poprawki i dwa piski radości opisano poniżej; nie zmieniano planu ani nie kupowano dodatkowych kredytów.

| Pliki | Zastosowanie |
|---|---|
| `puppy_bark_01–03.wav` | Animacja szczekania przy misce i przy drzwiach |
| `paw_wood_01–04.wav` | Kroki podczas rzeczywistego ruchu |
| `kibble_01–02.wav` | Rozpoczęcie posiłku po dotarciu do miski |
| `treat_01.wav` | Przyjęcie smaczka podczas treningu |
| `pet_stroke_01–02.wav` | Przyjęte głaskanie |
| `puppy_happy_01–02.wav` | Krótki pisk zadowolenia podczas przyjętego głaskania |
| `brush_01–02.wav` | Czesanie |
| `ball_roll_01.wav` | Rozpoczęcie toczenia piłki |
| `ball_bounce_01–03.wav` | Rezerwa do przyszłej animacji odbicia; obecnie bez wyzwalacza |
| `training_success.wav` | Prawidłowo przyjęta nagroda treningowa |
| `ui_tap.wav` | Zmiana zakładki |

## Odtwarzanie

[SoundEffects](../../../scripts/systems/sound_effects.gd) ładuje lokalne WAV, wybiera warianty i ogranicza efekty do czterech jednoczesnych głosów. Każda grupa ma własną głośność oraz minimalny odstęp. Odrzucona opieka nie uruchamia efektu. Zawieszenie aplikacji zatrzymuje efekty; wznowienie nie powtarza zaległych odgłosów. Profil ma niezależne przełączniki muzyki i efektów zapisane w `audio.cfg` obok zapisu psa. Brak pliku oznacza ciszę, nie błąd gry.

Szczek uruchamia `RoomView` po sygnale `PetAnimator.clip_started` dla `bark_stand`. Dzięki temu działa przy misce i przy drzwiach, czeka na zakończenie przejścia z innej pozycji i nie odtwarza się dla zastąpionej animacji w kolejce. Regresję sprawdza `tests/test_audio.gd`: `Godot --headless --path . --script res://tests/test_audio.gd`.

W gotowej aplikacji nie ma klienta ElevenLabs, klucza ani kosztów API. Muzyka nadal pochodzi z dostarczonego [video2](../music/README.md).

## Źródła i przygotowanie

- [generation.json](generation.json): dokładne prompty, parametry, wybrane numery wariantów i odnośniki do historii konta. Dostawca tworzy cztery propozycje; wybór numeru nie oznacza oceny odsłuchowej. Smaczek to trzeci, osobny wariant generacji chrupania. Jedna powtórzona generacja kroków pozostała niewykorzystana.
- `source/`: niezmienione pobrane WAV. `.gdignore` oraz wykluczenie eksportu oddzielają je od zasobów gry.
- [processing.json](processing.json): nazwy pobranych plików, SHA-256 źródeł i wyników, przycięcia, wzmocnienie oraz poziomy.
- [prepare_sfx.py](../../../tools/prepare_sfx.py): konwersja stereo do mono PCM16/48 kHz, usunięcie składowej stałej, ostrożny trim i mikrofade. Szczyt maksymalnie −3 dBFS, podbicie maksymalnie +12 dB.

Przykład ponownego przygotowania pobranych kroków:

```sh
python3 tools/prepare_sfx.py --prefix A_single_soft_padded --stem paw_wood --count 4 --max-duration 0.16
```

Oficjalny opis ElevenLabs dopuszcza komercyjne wykorzystanie efektów z płatnych planów bez obowiązkowego przypisania autorstwa: [Sound Effects](https://elevenlabs.io/sound-effects/professional). Szczegółowe warunki: [ElevenCreative Terms](https://elevenlabs.io/creative-terms). Plan Starter potwierdzono podczas generowania; ustawień udostępniania generacji nie zmieniano.

## Weryfikacja

Sprawdzono komplet plików, format, długości, brak przesterowania, brzegi próbek, import do Godota i wyzwalanie zdarzeń. Test UI wczytuje wszystkie 22 produkcyjne nagrania. **Naturalność, różnice między wariantami i balans z muzyką wymagają odsłuchu**, szczególnie kroki oraz cichy odgłos toczenia. Pomiary i testy programu nie zastępują tej oceny.

## Poprawka po odsłuchu na telefonie — 15 listopada 2026

Użytkownik zgłosił szczekanie podczas chodzenia. Mapowanie `step → paw_wood` i sygnał ruchu były prawidłowe; błędna była treść wygenerowanych próbek. Lokalny Apple SoundAnalysis wskazał `dog_bark` z pewnością 0,879 i 0,830 w starych krokach 02/03 oraz 0,800 w głaskaniu 02. Te wyniki wspierają zgłoszenie, ale nie są oceną odsłuchową.

Wymieniono cztery kroki, dwa głaskania, dwa czesania, sukces, smaczek i toczenie piłki (11 plików). Nowe prompty pomijają kontekst psa dla odgłosów przedmiotów, mają wpływ 100% i wyłączone automatyczne rozwijanie promptu. Kroki skrócono do 160 ms z wygaszeniem 20 ms, poniżej odstępu pomiędzy kontaktami łap; test UI sprawdza długość. Stare pliki i źródła pozostają w `source/pack-v1/`, poza eksportem.

Nowe kroki nie mają silnego wskazania szczekania, sukces klasyfikuje się jako muzyka/perkusja melodyczna, a smaczek jako gryzienie. Pielęgnacja jest bardzo cicha; toczenie nadal ma niejednoznaczną klasyfikację. **Balans i naturalność wymagają odsłuchu na telefonie.** Nie zmieniono odgłosów szczekania, jedzenia, kliknięcia ani nieużywanych odbić piłki. Dane pierwszej generacji i zużycie 90 kredytów powyżej dotyczą pakietu sprzed poprawki; metadane nowych generacji są w `repair_2026_11_15` w `generation.json`.

Wydzielony zakres audio przed publikacją sprawdzono osobno na bazie `c23df29`: **274/274** (104 logiki, 38 animacji, 132 UI). Obejmuje komplet 20 nagrań, kroki tylko podczas ruchu, limit 160 ms, brak dźwięku po odrzuconej opiece, zatrzymanie efektów w tle oraz niezależne wyciszenie. Te testy nie stanowią oceny naturalności nagrań.

## Pisk radości przy głaskaniu — 15 listopada 2026

Na prośbę użytkownika wygenerowano cztery propozycje łagodnego, radosnego pisku szczeniaka. Do gry trafiły warianty 1 i 3 jako `puppy_happy_01–02.wav` (0,887 i 0,951 s, mono PCM16/48 kHz, szczyt −3 dBFS). Grupa `pet_happy` gra na poziomie −16 dB z odstępem co najmniej 1,2 s, naprzemiennie wybierając warianty. Jest wywoływana wyłącznie po przyjętym głaskaniu, obok szelestu `pet`; czesanie, odmowa podczas snu lub jedzenia nie wyzwalają pisku. Obowiązują wspólne wyciszenie efektów i zatrzymanie w tle.

Wszystkie cztery oryginały i pomocnicza klasyfikacja Apple SoundAnalysis pozostają w `source/happy-petting-2026-11-15/`, poza eksportem. Wariant 4 pominięto ze względu na silne wskazanie szczekania. Klasyfikator nie ocenia emocji; miły charakter pisku oraz balans wymagają odsłuchu. Prompt i parametry zapisano w `happy_petting_2026_11_15` w `generation.json`, a przygotowanie w `processing.json`. Panel pokazał 12 kredytów za generację i zmianę dostępnego salda z 39 845 do 39 832; nie uruchamiano ponownej generacji.
