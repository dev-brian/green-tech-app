# Contrato de datos en Firestore (app móvil)

Proyecto Firebase: **green-tech-96bb2**, compartido con la web.

La app móvil **solo lee** estas colecciones. Quien escribe es el proyecto
simulador (y más adelante los ESP32). El simulador escribe con el Admin SDK,
así que no pasa por las reglas de seguridad.

Los documentos se enlazan con la web mediante `greenhouseId`, que es el id
del documento en `greenhouses/{id}`. Es el mismo campo que ya usa `alerts`.

## `telemetria/{sensorId}`

Última lectura de cada sensor: un documento por sensor, que se sobrescribe
con cada lectura nueva.

| Campo | Tipo | Ejemplo | Notas |
|---|---|---|---|
| `sensor_id` | string | `"ESP32-01"` | Opcional; si falta, se usa el id del documento |
| `greenhouseId` | string | `"axtR6p9ocsE0L79H5wbN"` | Id de `greenhouses/{id}` |
| `ubicacion` | string | `"Zona Tomate A"` | Texto libre para mostrar |
| `temperatura` | number | `24.5` | °C |
| `humedad_aire` | number | `65` | % humedad relativa |
| `humedad_suelo` | number | `70` | % humedad del sustrato |
| `timestamp` | timestamp | `serverTimestamp()` | También se acepta un string ISO 8601 |

El `estado` (semáforo) **no** se guarda: la app lo calcula con los rangos de
`lib/models/sensor_model.dart` (ver `spec.md` §5).

## `actuadores/{actuadorId}`

Estado de los equipos (HU-M03). La app solo lo observa; no lo modifica.

| Campo | Tipo | Ejemplo |
|---|---|---|
| `nombre` | string | `"Bomba de riego"` |
| `tipo` | string | `"bomba"` \| `"ventilador"` \| `"calefactor"` \| `"luz"` |
| `sensor_id` | string | `"ESP32-01"` |
| `greenhouseId` | string | `"axtR6p9ocsE0L79H5wbN"` |
| `encendido` | bool | `true` |
| `actualizado` | timestamp | `serverTimestamp()` |

## Reglas actuales (temporales)

```
match /telemetria/{id} { allow read: if true; allow write: if false; }
match /actuadores/{id} { allow read: if true; allow write: if false; }
```

Cuando entre el login real (HU-M01), la lectura pasa a `request.auth != null`.
