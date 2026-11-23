# Contrato de datos en Firestore (app móvil)

Proyecto Firebase: **green-tech-96bb2**, compartido con la PWA.

> **Fuente única:** el esquema completo vive en
> [`docs/contrato-datos.md` del repo de la PWA](https://github.com/dev-brian/green-tech/blob/develop/docs/contrato-datos.md)
> (Esquema de datos de Firebase v0.2). Este archivo solo resume **qué lee y
> qué escribe la app** y dónde está el código que conoce cada campo. Si el
> contrato cambia, se cambia allá primero.

La app es el complemento de campo de la PWA: **no calcula el semáforo ni las
alertas**. Todo lo calcula el backend (ingesta + motor de alertas) y la app
solo lo muestra. Plantas, umbrales y miembros se gestionan solo en la PWA.

## Qué lee la app

| Ruta | Para qué | Adapter / repositorio |
|---|---|---|
| `greenhouses` `where memberIds array-contains uid` | Invernaderos del usuario (selector) | `GreenhouseAdapter`, `FirestoreGreenhouseRepository` |
| `greenhouses/{id}/members/{uid}` | Rol (`admin` / `operador`), solo se muestra | `GreenhouseAdapter` |
| `greenhouses/{id}/state/latest` | Dashboard en vivo: 7 variables por zona con su `level` | `ZoneStatusAdapter`, `FirestoreZoneStatusSource` |
| `greenhouses/{id}/alerts` (100 más recientes por `createdAt`) | Bandeja de alertas y notificaciones | `AlertAdapter`, `FirestoreAlertsRepository` |
| `greenhouses/{id}/readings` (últimas 24 h de la zona) | Gráfica de 24 h, promediada cada 5 min | `HistoryAdapter`, `FirestoreHistoryRepository` |
| `greenhouses/{id}/readingsHourly` (7 y 30 días) | Gráficas de 7 y 30 días | `HistoryAdapter`, `FirestoreHistoryRepository` |
| `greenhouses/{id}/actuators/{zoneId}` | Tarjeta de actuadores, solo lectura | `ActuatorAdapter`, `FirestoreActuatorsRepository` |
| `greenhouses/{id}.thresholdsByCrop` (y `thresholds` legado) | Umbrales reales por cultivo, **solo lectura** | `ThresholdAdapter`, `FirestoreGreenhouseRepository` |
| `greenhouse_invites/{code}` | Resolver el código al unirse | `FirestoreGreenhouseRepository` |

Los adapters (`lib/adapters/`) son los **únicos** lugares que conocen los
nombres de los campos. Si una variable falta o viene mal formada, la app la
muestra como **"Sin datos"**: nunca la supone `ok`.

### Umbrales (`thresholdsByCrop`, solo lectura)

La app consulta los umbrales efectivos de cada cultivo para mostrarlos,
pero **no los calcula ni los escribe**. El backend evalúa con los mismos
rangos. Cada variable tiene cuatro cortes
(`redMin ≤ yellowMin ≤ yellowMax ≤ redMax`) y los perfiles por defecto de
`jitomate`/`lechuga` viven en `lib/models/crop_thresholds.dart` (copia de la
PWA). El campo viejo `thresholds` se respeta solo para jitomate.

### `state/latest` (resumen)

```jsonc
{
  "zona-1": {
    "airTemp": { "value": 22.5, "level": "ok" },
    "ph":      { "value": 7.6,  "level": "critical" },
    // … las 7 variables
    "timestamp": "<Timestamp>"
  }
}
```

`level` ∈ `"ok"` · `"warn"` · `"critical"`. Si el `timestamp` de una zona
tiene más de 5 minutos, la zona se pinta en gris ("Sin datos recientes").

### `alerts/{alertId}` (resumen)

`zoneId`, `variable`, `severity` (`warn` | `critical`), `value`, `message`,
`status` (`new` | `attended` | `auto_resolved`), `createdAt`, `attendedBy`,
`attendedAt`, `resolvedAt`.

### `actuators/{zoneId}`

```jsonc
{
  "zoneId": "zona-1",
  "recirculationPump": { "on": true,  "updatedAt": "…", "updatedBy": "backend" },
  "phDoser":           { "on": false, "updatedAt": "…", "updatedBy": "backend" },
  "nutrientDoser":     { "on": false, "updatedAt": "…", "updatedBy": "backend" },
  "ventilation":       { "on": false, "updatedAt": "…", "updatedBy": "backend" },
  "updatedAt": "…"
}
```

## Qué escribe la app

Solo dos cosas, las mismas que la PWA y las que permiten las reglas:

1. **Atender una alerta:** `update` de `status: "attended"`, `attendedBy: <uid>`
   y `attendedAt: serverTimestamp()`. Nada más (regla `isValidAlertAcknowledge`).
   Sin señal, Firestore encola el cambio y lo sube al reconectar.
2. **Unirse con código de invitación:** en un batch, `arrayUnion(uid)` en
   `greenhouses/{id}.memberIds` y `members/{uid}` con `role: "operador"` y el
   `inviteCode` (regla `isJoiningWithValidInvite` / `isSelfJoiningAsOperator`).

Pendiente (fase 4): `users/{uid}/fcmTokens/{tokenId}` con
`platform: "android"`, cuando el motor de alertas envíe push.

## Índices

La consulta de 24 h (`zoneId ==`, `timestamp >=`, `orderBy timestamp`) y la
de 7/30 días (`zoneId ==`, `hour >=`, `orderBy hour`) usan índices compuestos
`zoneId ASC, timestamp ASC` y `zoneId ASC, hour ASC`. Si aún no están
creados, la app lo detecta (`failed-precondition`) y cae a la consulta por
fecha filtrando la zona en el celular: funciona, pero lee las lecturas de
todas las zonas. Conviene crear los índices desde el repo de la PWA.

## Modo demo

"Ver demostración sin cuenta" en el login usa `DataSources.demo()`: datos de
prueba cada 5 s (`MockZoneStatusSource`), un motor de alertas de prueba que se
comporta como el del backend, histórico sintético y actuadores coherentes con
el escenario. Los escenarios se fuerzan desde el ícono 🧪 del Dashboard. Con
sesión iniciada nunca se usa.
