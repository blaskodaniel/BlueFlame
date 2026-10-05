# Release aláírás és telepítés

A végleges (release) appot egy saját kulccsal kell aláírni. Az Android csak akkor engedi
frissíteni a telepített appot, ha az új verzió **ugyanazzal a kulccsal** van aláírva.

> **Ha a kulcsfájl vagy a jelszava elveszik, az appot nem lehet többé frissíteni.** Csak
> törléssel és újratelepítéssel lehet új verziót feltenni, és ekkor elvesznek a telefonon
> tárolt leolvasások. Készíts biztonsági mentést a kulcsfájlról és a jelszóról, pl. egy
> jelszókezelőbe.

## Új release kiadása (röviden)

Ha az aláíró kulcs már be van állítva (1–2. lépés), egy új verzió kiadása így néz ki:

1. **Verzió növelése** a `pubspec.yaml`-ban (lásd [Verziózás](#verziózás)), pl.
   `version: 0.1.1+2` → `version: 0.1.2+3`.
2. **A telefon csatlakoztatása** USB-n, majd ellenőrzés:

   ```bat
   adb devices
   ```

   Az eredmény legyen `device` (részletek: [futtatas-telefonon.md](futtatas-telefonon.md)).
3. **Fordítás:**

   ```bat
   flutter build apk --release --target-platform android-arm64
   ```

4. **Telepítés frissítésként** (az adatok megmaradnak):

   ```bat
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

5. **Ellenőrzés:** a telefonon a Beállítások alján az új verziószámnak kell látszania.

> **Ne használd a `flutter install` parancsot!** Telepítés előtt mindig törli az appot, és
> vele együtt **az összes rögzített leolvasást is**.

## 1. Kulcs létrehozása (egyszer)

A kulcsfájl a projekten **kívül** legyen, hogy véletlenül se kerüljön a gitbe:

Két külön parancs, mindkettő egy sor (VS Code terminál, PowerShell):

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\keys"
```

```powershell
& "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\keytool.exe" -genkeypair -v -keystore "$env:USERPROFILE\keys\keklang-release.jks" -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias keklang
```

Ha a terminál `cmd` és nem PowerShell, a második parancs így néz ki (a `&` nélkül):

```bat
"C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\keytool.exe" -genkeypair -v -keystore "%USERPROFILE%\keys\keklang-release.jks" -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias keklang
```

A parancs közben ezeket kérdezi:

- **Jelszó** (kétszer). Legalább 6 karakter legyen, és jegyezd fel. PKCS12 tárolónál a
  kulcs jelszava ugyanez lesz.
- **Név, szervezet, város stb.** Bármit megadhatsz, vagy Enterrel átugorhatod. A végén
  `igen`/`yes` válasszal hagyd jóvá.

## 2. `key.properties` kitöltése (egyszer)

Másold le az `android/key.properties.example` fájlt `android/key.properties` néven, és
töltsd ki:

```properties
storeFile=C:/Users/<felhasználó>/keys/keklang-release.jks
storePassword=<a jelszó>
keyAlias=keklang
keyPassword=<ugyanaz a jelszó>
```

- Az elérési útban perjelet (`/`) használj, ne fordított perjelet (`\`).
- A `key.properties` és a `*.jks` fájl benne van az `android/.gitignore`-ban, nem kerül
  a gitbe.
- Ha a fájl hiányzik, a release fordítás hibaüzenettel leáll, így nem készülhet véletlenül
  rossz kulccsal aláírt app. A debug verzió (`flutter run`) kulcs nélkül is működik.

## 3. Fordítás

```bat
flutter build apk --release --target-platform android-arm64
```

Az eredmény: `build\app\outputs\flutter-apk\app-release.apk` (kb. 21 MB). Csak a 64 bites ARM
processzorokhoz (`arm64-v8a`) készül. Ilyen van a Pixel 9a-ban és szinte minden mai
telefonban.

Ha nagyon régi telefonra vagy emulátorra is kell, a kapcsoló nélkül minden processzortípust
tartalmazó, kb. 59 MB-os APK készül:

```bat
flutter build apk --release
```

## 4. Telepítés a telefonra

**USB-n** (a telefon csatlakoztatása: [futtatas-telefonon.md](futtatas-telefonon.md)):

```bat
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Az `-r` kapcsoló frissítésként telepít, így a telefonon tárolt adatok megmaradnak.

> **Ne használd a `flutter install` parancsot!** Telepítés előtt mindig törli az appot, és
> vele együtt **az összes rögzített leolvasást is**.

**Fájlként, kábel nélkül:** másold át az APK-t a telefonra (Google Drive, e-mail vagy
USB-fájlátvitel), és nyisd meg a telefonon. Az első alkalommal engedélyezni kell, hogy az az
app (pl. Fájlok vagy Drive) ismeretlen alkalmazást telepíthessen.

**Google Play:** ehhez Google Play fejlesztői fiók kell (egyszeri díj), és APK helyett App
Bundle-t kell feltölteni:

```bat
flutter build appbundle
```

## Verziózás

A verzió a `pubspec.yaml` `version` sorában van, pl.:

```yaml
version: 0.1.1+2
```

Ez két külön számot tartalmaz:

| Rész | Neve | Mire való | Ki látja |
| --- | --- | --- | --- |
| `0.1.1` | **verziónév** (versionName) | Az ember számára olvasható verzió | A felhasználó: a Beállítások alján és az Android alkalmazásinformációinál |
| `2` | **build szám** (versionCode) | Egész szám, ebből dönti el az Android, hogy egy APK újabb-e | Főleg a rendszer. Mindig nőnie kell, különben a Google Play nem fogadja el a frissítést. |

A Beállítások alján így jelenik meg: `Kékláng 0.1.1 (2)`, vagyis `verziónév (build szám)`.
A zárójel csak megjelenítési forma. A két szám független egymástól, nem kell egyezniük.

**Mikor melyiket növeld:**

- **Build szám (`+` után):** minden új APK-nál eggyel nagyobbra.
- **Verziónév** (szemantikus verziózás, `fő.al.javítás`):
  - `0.1.0` → `0.1.1`: hibajavítás, apró módosítás
  - `0.1.0` → `0.2.0`: új funkció (pl. CSV-export)
  - `0.x.y` → `1.0.0`: amikor az appot késznek, „első igazi” verziónak tekinted

Példa egymás utáni kiadásokra: `0.1.0+1` → `0.1.1+2` → `0.2.0+3` → `0.2.1+4`.

## Kulcsváltás a már telepített appnál

Ha a telefonon egy másik kulccsal aláírt verzió van (pl. a korábbi, debug kulccsal aláírt),
a telepítés `INSTALL_FAILED_UPDATE_INCOMPATIBLE` hibával leáll. Ilyenkor először töröld az
appot a telefonról (**a rajta tárolt adatok elvesznek**), utána telepítsd újra.
