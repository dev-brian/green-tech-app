# Patrones de diseño de la app

Catálogo de los patrones que usa la app, dónde viven y qué problema resuelven.
Sirve para la clase y para que cualquier integrante sepa dónde poner código nuevo.

La regla que los une: **la app es complemento de la PWA**. Lee los mismos datos,
del mismo Firestore, y no recalcula reglas de negocio (umbrales, semáforo,
alertas); eso lo hace el backend.

| Patrón | Tipo | Problema que resuelve aquí | Dónde | Estado |
|---|---|---|---|---|
| Repository | Arquitectura | Las pantallas no deben saber que existe Firestore | `lib/services/telemetry_repository.dart` | Hecho para telemetría; faltan zonas, alertas y actuadores |
| Singleton + inyección de dependencias | Creacional | Un solo cliente de cada servicio, pero reemplazable en pruebas | `lib/core/di.dart` | Hecho (este PR) |
| Facade | Estructural | Una puerta simple a Firebase Auth, Google Sign-In y almacenamiento seguro | `lib/services/firebase_service.dart` | Hecho |
| Observer | Comportamiento | La UI se redibuja sola cuando cambia un dato | `Stream` de Firestore + `ValueNotifier` en `SensorDataController` | Hecho; pasa a `BlocBuilder` con los Cubits |
| Adapter | Estructural | El contrato de datos de la PWA cambia nombres y forma; el modelo de la app no | `SensorReading.fromFirestore` (a medias) | Pendiente: adaptador contra `docs/contrato-datos.md` de green-tech |
| BLoC / Cubit | Gestión de estado | Separar la lógica de cada pantalla del widget y probarla sin UI | `features/*/presentation/` | Pendiente |
| Strategy | Comportamiento | Cada variable (pH, EC, tanque…) se presenta distinto; "datos viejos" es una política intercambiable | `VariablePresenter`, `StalenessPolicy` | Pendiente |
| Factory | Creacional | Crear modelos desde mapas y elegir implementación en un solo lugar | `SensorReading.fromJson` / `fromFirestore` | Hecho en modelos |

## Singleton con inyección de dependencias (`lib/core/di.dart`)

Antes cada clase tenía su propio `static final instance` y las pantallas lo
llamaban directo (`SensorDataController.instance`). Eso garantiza una sola
instancia, pero ata a todos a esa clase concreta: para probarla hubo que
agregar un constructor especial `forTesting`.

Ahora:

1. `setupDependencies()` registra cada servicio una vez, al arrancar la app.
2. Las clases reciben lo que necesitan por su constructor
   (`SensorDataController(repository: ..., notifications: ...)`).
3. Las pantallas lo piden al localizador: `sl<SensorDataController>()`.
4. Las pruebas crean el controlador con un repositorio falso, o hacen
   `sl.reset()` y registran sus propias versiones.

```dart
sl.registerLazySingleton<TelemetryRepository>(
    () => FirestoreTelemetryRepository());
sl.registerLazySingleton<SensorDataController>(
  () => SensorDataController(repository: sl<TelemetryRepository>()),
);
```

`registerLazySingleton` no crea nada hasta que alguien lo pide, así que las
pruebas de widgets no tocan Firebase.
