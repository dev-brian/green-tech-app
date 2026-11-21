# APK release de GreenTech (Android)

Guía corta para compilar y firmar la versión release de la app. Cubre la
sección 18 del checklist de servicios en la nube.

## 1. Crear la llave del equipo (una sola vez)

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias greentech
```

Guarda el `.jks` y las contraseñas fuera del repo (gestor de contraseñas del
equipo). Si se pierde la llave no se pueden publicar actualizaciones.

## 2. Compilar en local

Copia el `.jks` a `android/app/upload-keystore.jks` y crea `android/key.properties`:

```properties
storeFile=upload-keystore.jks
storePassword=...
keyAlias=greentech
keyPassword=...
```

Ninguno de los dos se versiona (`android/.gitignore`). Luego:

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

Sin `key.properties` el release se firma con la llave debug: sirve para
probar en un teléfono, no para publicar.

## 3. Compilar en el CI

El job `build APK (release)` de `.github/workflows/ci.yml` firma con la llave
del equipo si existen estos secretos del repo (Settings → Secrets → Actions):

| Secreto | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | contraseña del almacén |
| `ANDROID_KEY_ALIAS` | `greentech` |
| `ANDROID_KEY_PASSWORD` | contraseña de la llave |

El mismo job revisa que el APK no tenga llaves privadas, cuentas de servicio
ni claves del backend, y lo deja como artefacto 30 días.

## 4. Huella SHA-1 para Google Sign-In

Google Sign-In y Firebase validan la app por paquete + huella. Con una llave
nueva, agrega su SHA-1 y SHA-256 en Firebase → Configuración del proyecto →
la app Android:

```bash
keytool -list -v -keystore upload-keystore.jks -alias greentech
```

## 5. Paquete de la app

Desde el 21/11/2026 la app es `mx.greentech.app` (antes `com.example.greentech_app`,
que Play Store no acepta). La app vieja sigue registrada en Firebase para las
APK ya instaladas; se puede borrar después de la entrega. Si hubiera que
cambiarlo otra vez:

1. En Firebase → Configuración → Agregar app → Android, registra el paquete
   nuevo (por ejemplo `mx.greentech.app`) con las huellas SHA-1/SHA-256.
2. En `android/app/build.gradle.kts` cambia `applicationId` y `namespace`, y
   mueve `MainActivity.kt` a la carpeta del paquete nuevo.
3. Corre `flutterfire configure --project=green-tech-96bb2` para regenerar
   `lib/firebase_options.dart` con el `appId` nuevo.
4. Prueba inicio de sesión (correo y Google) y un push en un teléfono real.

## 6. Plan de reversión

- Código: revertir el PR en GitHub; `main` lleva etiquetas `vX.Y.Z` para
  volver a la última versión buena.
- Reglas de Firestore: Firebase → Firestore → Reglas → historial, y
  publicar la versión anterior.
- APK: reinstalar el artefacto release de la ejecución anterior del CI.
