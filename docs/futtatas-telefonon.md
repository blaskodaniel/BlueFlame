# Futtatás telefonon (Android, USB)

Útmutató a Kékláng app elindításához egy USB-n csatlakoztatott Android telefonon (pl. Pixel 9a).

## Egyszeri beállítás

### A gépen

Ezek már telepítve vannak:

| Eszköz | Helye |
| --- | --- |
| Flutter SDK | `C:\Develop\flutter` |
| JDK 17 | `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot` (`JAVA_HOME`) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` (`ANDROID_HOME`) |

A `flutter` és az `adb` parancs a felhasználói PATH-on van. Ha a VS Code a telepítés előtt
indult, egyszer indítsd újra, különben a terminálja nem találja a parancsokat.

### A telefonon (Pixel 9a)

1. **Fejlesztői beállítások bekapcsolása:** Beállítások → A telefonról → koppints hétszer a
   **Build-szám** sorra, majd add meg a PIN-kódot.
2. **USB-hibakeresés:** Beállítások → Rendszer → Fejlesztői beállítások → **USB-hibakeresés** be.
3. **USB-mód:** csatlakoztatás után az értesítési sávban koppints a „Készülék töltése USB-n
   keresztül” értesítésre, és válaszd a **Fájlátvitel** módot. Ugyanez megtalálható a
   Beállítások → Csatlakoztatott eszközök → USB menüben is.
4. **Engedélyezés:** az első csatlakozáskor a telefonon megjelenik az „Engedélyezed az
   USB-hibakeresést?” kérdés. Pipáld be a **Mindig engedélyezés erről a számítógépről** opciót,
   és koppints az **Engedélyezés** gombra.

## Minden alkalommal

1. **Csatlakoztasd a telefont** USB-n, és oldd fel a képernyőt.
2. **Nyiss terminált** a VS Code-ban (Terminal → New Terminal), a projekt mappájában
   (`C:\Develop\BlueFlame`).
3. **Ellenőrizd a kapcsolatot:**

   ```powershell
   adb devices
   ```

   | Eredmény | Jelentése / teendő |
   | --- | --- |
   | `device` | Rendben, mehet tovább. |
   | `unauthorized` | A telefonon fogadd el az USB-hibakeresési kérdést (feloldott képernyőn). |
   | üres lista | Húzd ki és dugd vissza a kábelt. Nézd meg, hogy az USB-mód „Fájlátvitel”-en áll-e. Próbálj másik kábelt is: sok kábel csak töltésre jó. |

   A Flutter oldaláról is ellenőrizheted:

   ```powershell
   flutter devices
   ```

   Ha a kapcsolat rendben van, megjelenik egy `Pixel 9a` sor.

4. **Indítsd el az appot fejlesztői módban:**

   ```powershell
   flutter run
   ```

   Az első indítás 1–2 percig tart. Amíg fut, a terminálban:

   | Billentyű | Hatása |
   | --- | --- |
   | `r` | Hot reload: a kódváltozás azonnal megjelenik a telefonon. |
   | `R` | Az app teljes újraindítása. |
   | `q` | Kilépés (az app a telefonon marad). |

   Fejlesztői módban az animációk akadozhatnak; ez a végleges verzióban nincs így.

5. **A végleges (release) verzió telepítése:** gyorsabb és simább, és a telefonon marad akkor
   is, ha kihúzod a kábelt.

   ```bat
   flutter build apk --release --target-platform android-arm64
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

   Az első parancs elkészíti az APK-t, a második frissíti vele az appot a csatlakoztatott
   telefonon. A rögzített adatok megmaradnak.

   > **Ne használd a `flutter install` parancsot!** Telepítés előtt mindig törli az appot,
   > és vele együtt **az összes rögzített leolvasást is**.

   Ehhez be kell állítani a saját aláíró kulcsot: [release-alairas.md](release-alairas.md).

## Kódváltozás után

Ha az adatbázis szerkezete változott (`lib/data/database.dart`), indítás előtt generáld újra a
drift kódot:

```powershell
dart run build_runner build
```

Ellenőrzés:

```powershell
flutter analyze
flutter test
```

## Hibaelhárítás

- **`flutter` / `adb` nem található:** indítsd újra a VS Code-ot. Ha így sem megy, a parancs
  teljes útvonallal is futtatható:
  `C:\Develop\flutter\bin\flutter.bat` és `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
- **Nem jelenik meg az engedélyezési ablak:** Fejlesztői beállítások → **USB-hibakeresési
  engedélyek visszavonása**, majd húzd ki és dugd vissza a kábelt.
- **A környezet állapota:** a `flutter doctor` parancs listázza, ha valami hiányzik.
  A „Visual Studio” hiba figyelmen kívül hagyható, mert az csak Windows-asztali apphoz kell.
