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

No necesitas Firebase todavía: `FirebaseService` y `ApiService` usan datos simulados
(incluyendo el JSON de prueba que definiste) para que puedas navegar toda la app desde ya.

## 🔐 Configurar Firebase Auth (HU-M01)

La autenticación ya usa Firebase Auth real. Antes del primer `flutter run`:

1. En la consola de Firebase → *Authentication* → *Sign-in method*, habilita **Correo electrónico/contraseña**.
2. Instala la CLI y genera la configuración:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Esto crea `lib/firebase_options.dart` y los archivos nativos (`google-services.json`, `GoogleService-Info.plist`).
3. `flutter pub get && flutter run`

La sesión se mantiene al cerrar la app (Task 1.3) y el login recuerda el último email usado.

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

1. Conectar Firebase Auth real.
2. Conectar tu API / MQTT bridge de los ESP32.
3. Agregar notificaciones push (Firebase Cloud Messaging) para las alertas críticas.
4. Agregar el logo real de GREEN TECH en `assets/images/` y en el Splash.
5. Persistir preferencias de notificaciones (perfil) con `shared_preferences`.
