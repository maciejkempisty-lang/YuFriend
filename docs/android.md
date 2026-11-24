# Testowy APK Androida

Preset `Android Playtest` jest niezależny od `iOS Gloria Playtest`. Buduje podpisany debug APK dla `arm64-v8a`, identyfikator `com.maciejkempisty.yufriend.playtest`, wersja `0.1.0 (1)`. Korzysta ze standardowego eksportu Godota, bez Gradle. Nie zawiera dokumentacji, testów, źródłowych nagrań, materiałów referencyjnych ani natywnego kodu iOS.

W Godocie skonfiguruj Android SDK, JDK i debug keystore oraz zainstaluj szablony eksportu odpowiadające wersji używanego silnika. Lokalna wersja projektu: Godot 4.7.2.

```sh
sh tools/export_android.sh
# Opcjonalnie inny Godot i katalog wynikowy:
GODOT_BIN=/sciezka/do/godot sh tools/export_android.sh /tmp/yufriend-android
```

Skrypt importuje zasoby, potem zapisuje `YuFriend-debug.apk`, `import.log` i `export.log` do wybranego katalogu (domyślnie `exports/android/`). Błąd importu/eksportu przerywa skrypt. Nie instaluje SDK ani nie podłącza urządzeń.

Po przygotowaniu APK i autoryzacji debugowania USB instalacja na wybranym urządzeniu:

```sh
adb devices
adb -s NUMER_URZADZENIA install -r exports/android/YuFriend-debug.apk
```

`-r` aktualizuje aplikację. Zachowanie danych wymaga zgodnego identyfikatora i klucza podpisu; przed aktualizacją istniejącej gry zabezpiecz jej dane. Nie odinstalowuj aplikacji w celu obejścia błędu podpisu.

Android nie ma obecnie implementacji widgetu ani lokalnych przypomnień YuFriend. Kod tych funkcji jest natywny dla iOS. Przed dystrybucją APK sprawdź dotyk, tło/wznowienie, zapis i małe ekrany. Dodanie presetu 24 listopada 2026 nie oznacza wykonania nowego eksportu ani testu na fizycznym Androidzie. Historyczne próby autora gałęzi graficznej dotyczyły starszego kodu.
