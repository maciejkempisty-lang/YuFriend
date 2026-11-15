# Muzyka pokoju

`room-video2.wav` to ścieżka audio wyodrębniona z dostarczonego przez użytkownika `video2.mp4` (15 listopada 2026). Drugi plik, `yu music.mp4`, nie został użyty. Oryginały pozostają bez zmian w katalogu projektu.

- Źródło: AAC stereo 44 100 Hz, 107,153991 s.
- SHA-256 źródłowego `video2.mp4`: `7d7fd8c8be935406fa07e4af8691dd8fdc999b1bbce2180b20caaac09e8af467`.
- Konwersja: systemowy `afconvert` do 16-bitowego WAV; nagłówek WAVE extensible przepisany na standardowy PCM bez zmiany próbek.
- Import Godota: QOA, stereo, bez normalizacji i obcinania utworu; pętla od początku do końca. Zachowany jest oryginalny cichy koniec utworu.
- Odtwarzanie: `BackgroundMusic`, poziom −18 dB, łagodne wejście przez 1 sekundę. Zmiana zakładki nie restartuje muzyki.
- Muzyka pauzuje podczas zawieszenia aplikacji. Przełącznik „Muzyka w tle” w Profilu zapisuje ustawienie w `user://audio.cfg`, niezależnie od zapisu psa.

Wideo jest wykluczone z eksportu. W aplikacji używany jest import audio, około 3,6 MB. Dokumentacja importu: https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_audio_samples.html

## Prawa do nagrania

Autorem muzyki jest właściciel projektu YuFriend — użytkownik potwierdził 15 listopada 2026, że to jego autorska muzyka demo. Źródłem technicznym pozostaje dostarczony `video2.mp4`; nie jest to utwór pobrany z biblioteki stockowej.

Status: **autorskie demo do projektu**. Nie przypisujemy nagraniu licencji Creative Commons ani licencji zewnętrznego dostawcy. Tytuł utworu i publiczna forma podpisu autora nie zostały określone. Obecny plik pozostaje wersją demonstracyjną.
