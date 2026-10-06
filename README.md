# Kétzónás intelligens garázsbeállást segítő rendszer

ESP32-alapú, hálózatra kapcsolható IoT-prototípus, amely egy jármű garázson belüli elhelyezkedését két külön mérési zónában figyeli.

## A projekt célja

A rendszer célja, hogy segítse a biztonságos garázsbeállást:

- mérje az autó és az első fal közötti távolságot;
- figyelje az autó melletti biztonsági vagy ajtónyitási területet;
- fény- és szöveges jelzést adjon a használónak;
- helyi webes felületen is megjelenítse a mérési adatokat.

A működés egy asztalon bemutatható garázsmaketten és mozgatható autómodellen lesz szemléltethető.

## Tervezett funkciók

- két külön távolságmérési zóna;
- zöld, sárga és piros parkolási állapot;
- külön oldalsó akadályjelzés;
- aktuális értékek megjelenítése egy kis kijelzőn;
- telefonról vagy számítógépről megnyitható helyi webes felület;
- állítható figyelmeztetési távolságok;
- alapvető működés hálózati kapcsolat nélkül is;
- saját Wi-Fi-hálózat a tantermi bemutatóhoz.

## Tervezett technológiák

- ESP32-S3 mikrokontroller;
- PlatformIO IDE;
- Arduino keretrendszer;
- C++;
- HTML, CSS és JavaScript;
- Git és GitHub.

## Tervezett működés

Az elülső érzékelő az autómodell és a garázs első fala közötti távolságot méri. A rendszer a beállított határértékek alapján zöld, sárga vagy piros jelzést ad.

A második érzékelő egy oldalsó biztonsági területet figyel. Ha ezen a területen akadály található, a rendszer külön figyelmeztetést jelenít meg akkor is, ha az autó elöl megfelelő helyen áll.

Az ESP32 saját helyi weboldalt szolgáltat. A felület telefonról és számítógépről is megnyitható. A tantermi bemutatóhoz az ESP32 saját Wi-Fi-hálózatot hozhat létre, ezért nincs szükség internetkapcsolatra.

## Projektállapot

A projekt jelenleg tervezési szakaszban van.

- [x] Projektötlet kiválasztása
- [x] Első projektterv elkészítése
- [x] PlatformIO-projekt létrehozása
- [x] Git- és GitHub-repository létrehozása
- [ ] Alkatrészek végleges kiválasztása
- [ ] Elülső mérési zóna elkészítése
- [ ] Oldalsó mérési zóna elkészítése
- [ ] Helyi visszajelzés kialakítása
- [ ] Webes felület elkészítése
- [ ] Garázsmakett megépítése
- [ ] Tesztelés és dokumentálás

## Dokumentáció

A részletes első projektterv itt található:

[Projektterv – Kétzónás intelligens garázsbeállást segítő rendszer](docs/IoT-projektterv-ketzonas-garazsjelzo.docx)

## Korlátozás

A készülék oktatási és demonstrációs célú prototípus. Nem minősített gépjármű-biztonsági berendezés, ezért valódi garázsban történő használata csak további pontossági, környezeti és megbízhatósági vizsgálatok után lenne lehetséges.