# SPEC — GREEN TECH App Móvil

**Monitoreo inteligente de cultivos**
Versión: 1.0.0 · Última actualización: 2026-07-07

---

## 1. Resumen del proyecto

App móvil en Flutter para agricultores, que muestra en tiempo real datos de
sensores IoT (ESP32) instalados en cultivos: temperatura, humedad ambiental y
humedad del suelo. Prioriza claridad visual y lectura rápida en campo mediante
un sistema de semáforo de colores (🟢 normal / 🟡 alerta / 🔴 crítico).

**Usuario objetivo:** productores agrícolas, no necesariamente familiarizados
con apps técnicas. La UI debe ser simple, visual y con textos cortos.

---

## 2. Stack técnico

| Capa | Tecnología |
|---|---|
| Framework | Flutter (Dart ≥3.3.0) |
| Autenticación | Firebase Auth *(pendiente de conectar; stub funcional incluido)* |
| Backend de datos | API REST propia / bridge MQTT desde ESP32 *(pendiente)* |
| Gráficas | `fl_chart` |
| HTTP client | `http` |
| Formateo de fechas | `intl` |
| Hardware IoT | ESP32 con sensores de temperatura, humedad de aire y humedad de suelo |

---

## 3. Arquitectura de carpetas

```
lib/
│── main.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── sensor_detail_screen.dart
│   ├── history_screen.dart
│   ├── alerts_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── sensor_card.dart
│   ├── chart_widget.dart
│   └── alert_tile.dart
├── services/
│   ├── firebase_service.dart
│   └── api_service.dart
├── models/
│   └── sensor_model.dart
└── utils/
    └── colors.dart
```

**Estado actual:** todas las carpetas y archivos existen y están implementados
con datos mock. `useMockData = true` en `api_service.dart` controla el modo
simulado.

---

## 4. Modelo de datos

### 4.1 Lectura de sensor (`SensorReading`)

```json
{
  "temperatura": 24.5,
  "humedad_aire": 65,
  "humedad_suelo": 70,
  "estado": "Óptimo",
  "sensor_id": "ESP32-01",
  "ubicacion": "Zona Tomate A",
  "timestamp": "2026-07-07T10:30:00"
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `sensor_id` | string | Identificador único del ESP32 |
| `ubicacion` | string | Zona/lote donde está instalado |
| `temperatura` | double | °C |
| `humedad_aire` | double | % humedad relativa ambiental |
| `humedad_suelo` | double | % humedad del sustrato |
| `timestamp` | ISO 8601 | Momento de la lectura |

`estado` no se persiste como campo: se **calcula en el cliente** a partir de
los rangos (ver sección 5) para evitar desincronización entre backend y UI.

### 4.2 Alerta (`AlertItem`)

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | string | Identificador único |
| `mensaje` | string | Texto descriptivo, ej. "Temperatura alta detectada (32°C)" |
| `nivel` | enum | `normal` \| `alerta` \| `critico` |
| `fecha` | datetime | Momento en que se generó |
| `activa` | bool | `true` si no ha sido resuelta |

### 4.3 Punto de gráfica (`ChartPoint`)

| Campo | Tipo |
|---|---|
| `time` | datetime |
| `value` | double |

---

## 5. Reglas de negocio — semáforo de estados

Definidas en `sensor_model.dart`, ajustables por tipo de cultivo:

| Métrica | 🟢 Normal | 🟡 Alerta | 🔴 Crítico |
|---|---|---|---|
| Temperatura | 18–26 °C | 15–18 °C ó 26–30 °C | fuera de esos rangos |
| Humedad aire | 50–80 % | 40–50 % ó 80–90 % | fuera de esos rangos |
| Humedad suelo | 60–80 % | 45–60 % ó 80–90 % | fuera de esos rangos |

**Estado general** = el peor nivel entre las 3 métricas (si una es crítica,
el estado general es crítico).

Mensajes asociados:
- Normal → "Condiciones óptimas"
- Alerta → "Atención: valores fuera de rango"
- Crítico → "Riesgo de estrés térmico"

---

## 6. Especificación de pantallas

### 6.1 Splash Screen
- **Objetivo:** branding mientras carga la app.
- **Contenido:** logo GREEN TECH (ícono placeholder actual, pendiente logo real), texto "Monitoreo inteligente de cultivos", animación de entrada (fade + scale), loader.
- **Comportamiento:** tras ~2.2s, redirige a Dashboard si hay sesión activa, o a Login si no.

### 6.2 Login / Registro
- **Objetivo:** autenticación (Firebase Auth, actualmente simulada).
- **Campos:** email, contraseña (con toggle mostrar/ocultar).
- **Validaciones:** email con "@", contraseña mínimo 6 caracteres.
- **Acciones:** Iniciar sesión / Registrarse (toggle entre modos), manejo de errores inline.
- **Pendiente:** MFA (opcional, no implementado aún).

### 6.3 Dashboard (pantalla principal)
- **Objetivo:** ver todo en tiempo real de un vistazo.
- **Componentes:**
  - Banner de estado general (color + ícono + mensaje + ubicación/sensor).
  - 3 tarjetas de sensores (Temperatura, Humedad ambiental, Humedad del suelo), cada una con color de semáforo, ícono y valor.
  - Tarjeta de acceso rápido a "Detalle del sensor".
  - Mini-gráfica de temperatura de las últimas 24h.
  - Pull-to-refresh y botón de refresh manual en la AppBar.
  - Navegación inferior (Inicio / Histórico / Alertas / Perfil).

### 6.4 Detalle de sensores
- **Objetivo:** datos técnicos del sensor activo.
- **Contenido:** ID del sensor, ubicación, "hace X seg/min" de última actualización, y las 3 lecturas con su color de estado individual.

### 6.5 Histórico de datos
- **Objetivo:** análisis de tendencias.
- **Contenido:** gráficas de línea de temperatura y humedad del suelo.
- **Filtros:** Hoy / Semana / Mes (chips seleccionables), recargan los datos al cambiar.

### 6.6 Alertas
- **Objetivo:** notificar problemas detectados.
- **Contenido:** lista de alertas con color por nivel, mensaje, fecha/hora, estado (Activa/Resuelta).
- **Filtro:** "Solo activas".

### 6.7 Perfil / Configuración
- **Objetivo:** control del usuario.
- **Contenido:** nombre/avatar, email, switches de notificaciones por tipo de alerta (temperatura, humedad aire, humedad suelo), botón "Cerrar sesión".

---

## 7. Sistema visual (UX)

- **Semáforo de colores** (definido en `AppColors`):
  - 🟢 `normal` → `#2E7D32`
  - 🟡 `alerta` → `#F9A825`
  - 🔴 `critico` → `#D32F2F`
- **Color de marca:** verde `#2E7D32` (AppBar, botones, acentos).
- **Tipografía:** Roboto, jerarquía clara (headline / title / body).
- **Componentes:** tarjetas con bordes redondeados (16px), sombras suaves, iconografía Material coherente por métrica (termómetro, gota, pasto).
- Todo el sistema de color vive en un único archivo (`utils/colors.dart`) para
  facilitar theming futuro (ej. modo oscuro, marca blanca).

---

## 8. Estado de implementación

| Módulo | Estado |
|---|---|
| Estructura de carpetas y navegación entre las 7 pantallas | ✅ Completo |
| UI de las 7 pantallas con datos mock | ✅ Completo |
| Cálculo de semáforo de estados | ✅ Completo |
| Gráficas (dashboard + histórico) | ✅ Completo |
| Autenticación real (Firebase Auth) | ⏳ Pendiente — stub listo en `firebase_service.dart` |
| Conexión a API/IoT real | ⏳ Pendiente — stub listo en `api_service.dart` (`useMockData = false`) |
| Notificaciones push para alertas críticas | ⏳ Pendiente |
| Logo real y assets de marca | ⏳ Pendiente |
| MFA en login | ⏳ Pendiente (opcional) |
| Persistencia de preferencias de notificaciones | ⏳ Pendiente |

---

## 9. Próximos pasos (roadmap sugerido)

1. Conectar Firebase Auth (`flutterfire configure`) y reemplazar los `TODO` en `firebase_service.dart`.
2. Definir contrato de API real (endpoints REST o bridge MQTT→HTTP) para los ESP32 y activar `useMockData = false`.
3. Implementar notificaciones push (FCM) enlazadas a las alertas críticas.
4. Agregar logo e identidad visual definitiva de GREEN TECH.
5. Persistir preferencias de notificaciones (`shared_preferences` o backend).
6. Evaluar soporte multi-sensor / multi-zona (actualmente el modelo asume un sensor activo por vista).
7. Pruebas de usabilidad con usuarios agrícolas reales (validar legibilidad bajo luz solar directa).

---

## 10. Notas de mantenimiento

- Los rangos de temperatura/humedad en `sensor_model.dart` son configurables y
  deben ajustarse según el cultivo monitoreado (los valores actuales están
  calibrados para hortalizas tipo tomate/lechuga, según los datos de prueba).
- El proyecto no usa gestión de estado externa (Provider/Riverpod/Bloc); usa
  `StatefulWidget` simple. Si la app crece, considerar migrar a un gestor de
  estado para compartir la lectura activa entre pantallas sin refetch.
