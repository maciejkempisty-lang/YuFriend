# Testowy APK Androida

Preset `Android Playtest` w `export_presets.cfg` eksportuje debug APK tylko dla `arm64-v8a`. Pakiet ma identyfikator `com.maciejkempisty.yufriend.playtest` i wersję `0.1.0 (1)`. Używa standardowego eksportu Godota, bez Gradle. Do paczki nie wchodzą dokumentacja, testy, źródłowe nagrania ani pliki natywne iOS.

Wymagane są Godot 4.7.2, jego [oficjalne szablony eksportu](https://godotengine.org/download/archive/4.7.2-stable/) oraz skonfigurowane Android SDK, JDK i debug keystore w ustawieniach edytora. Po imporcie projektu:

```sh
mkdir -p exports/android
touch exports/.gdignore
godot --headless --path . --editor --quit
godot --headless --path . --export-debug 'Android Playtest' exports/android/YuFriend-debug.apk
```

Na tym komputerze Godot jest w `/Users/bartoszzajac/Desktop/godot/Godot.app/Contents/MacOS/Godot`; w poleceniach można zastąpić nim `godot`. Gotowy plik jest w `exports/android/` (katalog pomijany przez Git). Instalacja: `adb install -r exports/android/YuFriend-debug.apk`.

18 listopada 2026 APK wyeksportowano przy użyciu oficjalnego szablonu debug Godot 4.7.2. Weryfikacja podpisu `apksigner` przeszła; plik zainstalowano i uruchomiono na emulatorze Pixel 7 z Androidem API 36. Ekran Dom wyrenderował się poprawnie. To weryfikacja uruchomienia, nie pełny test gestów, zapisu i wszystkich ekranów na fizycznym telefonie. Widget i lokalne przypomnienia są obecnie implementacjami iOS; Android ich nie udostępnia.

19 listopada 2026 ponownie wyeksportowano APK po dodaniu kuchni według wariantu B. Test interfejsu w Godocie zakończył się wynikiem 241/241. Podczas tego eksportu `adb devices` nie wykazał podłączonego urządzenia, więc tej wersji nie zainstalowano na telefonie.
