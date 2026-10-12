# GREEN TECH — App móvil de monitoreo de cultivos

Proyecto base en Flutter siguiendo la arquitectura definida: Splash → Login/Registro →
Dashboard → Detalle de sensores → Histórico → Alertas → Perfil.

## 🚀 Cómo correrlo

1. Instala Flutter (https://docs.flutter.dev/get-started/install) si no lo tienes.
2. Descomprime este proyecto y entra a la carpeta:
   ```bash
   cd greentech_app
   ```
3. Instala dependencias:
   ```bash
   flutter pub get
   ```
4. Corre la app (con un emulador o celular conectado):
   ```bash
   flutter run
   ```

`ApiService` aún usa datos simulados; la autenticación ya es real con Firebase.

## 🔐 Firebase Auth (HU-M01) — ya conectado

- Proyecto Firebase: `green-tech-96bb2` · App Android: `com.example.greentech_app`
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
Si cambias el `applicationId` o agregas iOS/Web, regenera la config con
`flutterfire configure --project=green-tech-96bb2`.

## 🔌 Conectar datos reales

- **API / IoT (ESP32)**: en `lib/services/api_service.dart` cambia
  `useMockData = false` y define `baseUrl` con tu backend real. Ya está listo el
  paquete `http` para que solo reemplaces los métodos marcados con `TODO`.

## 🎨 Sistema de colores (semáforo)

Todo el semáforo verde/amarillo/rojo vive en `lib/utils/colors.dart`
(`AppColors.normal`, `AppColors.alerta`, `AppColors.critico`) y los rangos que
determinan cada estado están en `lib/models/sensor_model.dart`
(`estadoTemperatura`, `estadoHumedadAire`, `estadoHumedadSuelo`). Ajusta esos
rangos según el cultivo que estés monitoreando.

## 📁 Estructura

```
lib/
├── main.dart
├── screens/       # 7 pantallas de la app
├── widgets/        # sensor_card, chart_widget, alert_tile
├── services/       # api_service (datos), firebase_service (auth)
├── models/         # sensor_model.dart
└── utils/          # colors.dart (tema + semáforo)
```

## ✅ Próximos pasos sugeridos

1. Conectar tu API / MQTT bridge de los ESP32.
2. Agregar notificaciones push (Firebase Cloud Messaging) para las alertas críticas.
3. Agregar el logo real de GREEN TECH en `assets/images/` y en el Splash.
4. Persistir preferencias de notificaciones (perfil) con `shared_preferences`.
