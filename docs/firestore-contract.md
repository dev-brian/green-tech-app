# Contrato de datos en Firestore (app móvil)

Proyecto Firebase: **green-tech-96bb2**, compartido con la web.

La app móvil **solo lee** estas colecciones. Quien escribe es el proyecto
simulador (y más adelante los ESP32). El simulador escribe con el Admin SDK,
así que no pasa por las reglas de seguridad.

Los documentos se enlazan con la web mediante `greenhouseId`, que es el id
del documento en `greenhouses/{id}`. Es el mismo campo que ya usa `alerts`.

## `greenhouses/{greenhouseId}/state/latest`

Estado actual de todas las zonas del invernadero, en **un solo documento** que
el backend sobrescribe con cada lectura. Hay una entrada por `zoneId`.

Cada variable trae su `value` y su `level`. **El `level` lo calcula el
backend**; la app no tiene rangos propios y solo lo pinta (verde / ámbar /
rojo).

```jsonc
{
  "zona-1": {
    "airTemp":      { "value": 22.5,  "level": "ok" },
    "humidity":     { "value": 65,    "level": "ok" },
    "light":        { "value": 18000, "level": "ok" },
    "ph":           { "value": 7.6,   "level": "critical" },
    "ec":           { "value": 0.8,   "level": "warn" },
    "solutionTemp": { "value": 20.5,  "level": "ok" },
    "tankLevel":    { "value": 78,    "level": "ok" },
    "timestamp": "<serverTimestamp()>"
  },
  "zona-2": { "...": "..." }
}
```

| Campo | Tipo | Unidad | Notas |
|---|---|---|---|
| `airTemp` | `{value, level}` | °C | Temperatura del aire |
| `humidity` | `{value, level}` | % | Humedad relativa |
| `light` | `{value, level}` | lux | Luz |
| `ph` | `{value, level}` | — | pH de la solución |
| `ec` | `{value, level}` | mS/cm | Conductividad eléctrica |
| `solutionTemp` | `{value, level}` | °C | Temperatura de la solución |
| `tankLevel` | `{value, level}` | % | Nivel del tanque |
| `timestamp` | timestamp | — | También se acepta un string ISO 8601 |

`level` ∈ `"ok"` · `"warn"` · `"critical"`.

En la app, el único lugar que conoce estos nombres es
`lib/adapters/zone_status_adapter.dart`. Si una variable falta, no es numérica
o trae un `level` desconocido, la app la muestra como **"Sin datos"**: nunca
la supone `ok`.

Mientras el backend no publique este documento, la app usa
`MockZoneStatusSource` (datos de prueba cada 5 s, con escenarios forzables
desde el ícono 🧪 del Dashboard). Para pasar a datos reales hay que inyectar
`FirestoreZoneStatusSource` en `SensorDataController`.

> `telemetria/{sensorId}` (temperatura / humedad del aire / humedad del suelo)
> queda **reemplazada** por este documento y la app ya no la lee.

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

Pendiente: para que `FirestoreZoneStatusSource` pueda leer el estado hace
falta una regla de lectura para `greenhouses/{id}/state/latest`, p. ej.
`match /greenhouses/{id}/state/{doc} { allow read: if request.auth != null; }`.

Cuando entre el login real (HU-M01), la lectura pasa a `request.auth != null`.
