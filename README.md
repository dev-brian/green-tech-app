# GREEN TECH — App móvil de monitoreo de cultivos

Proyecto base en Flutter siguiendo la arquitectura definida: Splash → Login/Registro →
Dashboard → Detalle de zona → Alertas → Perfil.

## 🧪 Integración continua

Cada pull request a `develop` o `main` (y cada push a ramas `feature/`, `feat/`, `fix/`, `chore/`) corre [`.github/workflows/ci.yml`](.github/workflows/ci.yml) con Flutter 3.44.9:

1. `flutter pub get --enforce-lockfile`
2. `flutter analyze` (reglas de `flutter_lints`)
3. `flutter test`
4. `flutter build apk --debug` (el APK queda como artefacto del run por 7 días)

Si el repo tiene el secreto `SLACK_WEBHOOK_URL`, el resultado se avisa en Slack.

## 🚀 Cómo correrlo

1. Instala Flutter (https://docs.flutter.dev/get-started/install) si no lo tienes.
2. Descomprime este proyecto y entra a la carpeta:
   ```bash
   cd greentech_app
   ```
3. Crea tu archivo `.env` a partir del ejemplo y pon tu `WEATHER_API_KEY`
   (es obligatorio: `pubspec.yaml` lo declara como asset, y sin él fallan
   `flutter run`, `flutter test` y `flutter analyze`):
   ```bash
   cp .env.example .env
   ```
4. Instala dependencias:
   ```bash
   flutter pub get
   ```
5. Corre la app (con un emulador o celular conectado):
   ```bash
   flutter run
   ```

Las zonas usan por ahora la fuente de prueba (`MockZoneStatusSource`); la
autenticación ya es real con Firebase.

## 🔐 Firebase Auth (HU-M01) — ya conectado

- Proyecto Firebase: `green-tech-96bb2` · App Android: `mx.greentech.app`
- Config: `lib/firebase_options.dart` (versionado). `android/app/google-services.json`
  está en `.gitignore` y no es necesario para compilar: Firebase se inicializa con
  `DefaultFirebaseOptions` y Google Sign-In con el `serverClientId` del proyecto.
- Proveedores habilitados en la consola: **Correo electrónico/contraseña** y **Google**
- Google en Android requiere registrar la huella SHA-1 de la llave de firma en
  Firebase → Configuración del proyecto → Tu app Android. Cada integrante debe agregar
  la SHA-1 de su `debug.keystore` (`cd android && ./gradlew signingReport`).

| Task | Dónde |
|---|---|
| 1.1 UI de login y recuperación | `lib/screens/login_screen.dart`, `lib/screens/forgot_password_screen.dart` |
| 1.2 Integración con Firebase Auth | `lib/services/firebase_service.dart` |
| 1.3 Persistencia segura de sesión | `lib/services/secure_token_storage.dart` (ID token cifrado con Android Keystore vía `flutter_secure_storage`) |

Para correrlo: `flutter clean && flutter pub get && flutter run` con un emulador/celular Android (API 23+).
El repo solo incluye la plataforma Android (iPhone y web quedan fuera del alcance). Si después se agrega otra,
se genera con `flutter create --platforms=ios .` y luego `flutterfire configure --project=green-tech-96bb2`.
Si cambias el `applicationId`, regenera también la config con `flutterfire configure`.

## 🔌 Conectar datos reales

- **Estado de las zonas**: pasa `FirestoreZoneStatusSource` a
  `SensorDataController` en lugar de la fuente de prueba. El backend debe
  publicar `greenhouses/{id}/state/latest` con el contrato de
  `docs/firestore-contract.md`.

## 🔔 Push de alertas (FCM)

La app **no calcula alertas**: solo registra el celular y muestra lo que manda el backend.

- Al iniciar sesión, `PushService` pide permiso de notificaciones y guarda el token en
  `users/{uid}/fcmTokens/{token}` (`token`, `platform: "android"`, `createdAt`, `lastSeenAt`).
  Si FCM lo renueva, se reemplaza; al cerrar sesión se borra y se invalida.
- Con la app abierta, el push se muestra como notificación local, salvo que la bandeja ya
  esté viendo ese invernadero (ella avisa sola). Tocar la notificación abre la bandeja.
- Con la app cerrada, Android la muestra solo en el canal `greentech_critico`.
- No hace falta `google-services.json`: Firebase se inicializa con `lib/firebase_options.dart`.

**Lo que tiene que mandar el backend** (al crear una alerta `critical`, a los tokens de todos
los miembros del invernadero):

```json
{
  "notification": { "title": "⚠️ pH alto en Zona 1", "body": "pH 7.4 (rango 5.5–6.5)" },
  "data": { "greenhouseId": "abc123", "alertId": "…", "zoneId": "zona-1", "variable": "ph", "severity": "critical" },
  "android": { "priority": "high", "notification": { "channelId": "greentech_critico" } }
}
```

Los tokens que FCM rechace (`messaging/registration-token-not-registered`) se deben borrar.

## 🎨 Sistema de colores (semáforo)

Los colores verde/amarillo/rojo viven en `lib/utils/colors.dart`
(`AppColors.forEstado`). La app **no calcula** si un valor está fuera de
rango: cada variable llega del backend con su `level` (`ok`, `warn` o
`critical`) y la app solo lo pinta. Los rangos de cada cultivo se ajustan en
el backend (ver `docs/firestore-contract.md`).

## 📁 Estructura

```
lib/
├── main.dart
├── screens/       # 7 pantallas de la app
├── widgets/        # variable_card, zone_section, alert_tile, live_clock
├── services/       # zone_status_source (Firestore y prueba), firebase_service (auth)
├── adapters/       # zone_status_adapter.dart (único que conoce los campos de Firestore)
├── models/         # zone_status.dart (7 variables), sensor_model.dart
└── utils/          # colors.dart (tema + semáforo)
```

## ✅ Próximos pasos sugeridos

1. Conectar tu API / MQTT bridge de los ESP32.
2. Agregar notificaciones push (Firebase Cloud Messaging) para las alertas críticas.
3. Agregar el logo real de GREEN TECH en `assets/images/` y en el Splash.
4. Persistir preferencias de notificaciones (perfil) con `shared_preferences`.
