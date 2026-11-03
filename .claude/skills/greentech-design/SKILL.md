---
name: greentech-design
description: Sistema de diseño de la app Flutter Green Tech (monitoreo de invernaderos hidropónicos) — colores de estado con contraste WCAG AA, tarjetas de variable, secciones por zona, reglas de legibilidad a 360 px y bajo sol directo, y cómo verificarlo con pruebas y capturas. Úsalo SIEMPRE que crees, rediseñes o ajustes cualquier pantalla, widget, tarjeta, color, ícono, texto de estado, banner o layout en green-tech-app (Dashboard, Detalle, Alertas, Histórico, Perfil, Login), aunque el cambio parezca pequeño ("cambia el color", "agrega una tarjeta", "muestra la variable X", "arregla que se corta el texto") o el usuario no diga "diseño".
---

# Diseño de Green Tech

La app la usa un productor **en el invernadero**: teléfono Android pequeño
(360 px de ancho), a pleno sol, a veces con guantes y con mala señal. Cada
regla de este documento sale de esa situación. Cuando una decisión no esté
cubierta aquí, pregúntate qué funciona mejor para esa persona en ese lugar.

## Principios

1. **El estado nunca se comunica solo con color.** Siempre van juntos color,
   ícono y texto ("Normal" / "Alerta" / "Crítico"). Con el reflejo del sol,
   en daltonismo o en una pantalla gastada, el color solo no se distingue.
2. **La app no calcula niveles.** El `level` (`ok`/`warn`/`critical`) lo manda
   el backend en cada variable; la app solo lo pinta. No agregues rangos ni
   umbrales en la UI: si dos pantallas los calcularan distinto, se
   contradirían. Agregar niveles (el peor de una zona) sí está bien.
3. **Un dato viejo no puede verse sano.** Si la lectura tiene más de 5 min
   (`lecturaDesactualizada`), la tarjeta pasa a gris con "Sin datos
   recientes". Un verde con datos de hace una hora es peor que no mostrar nada.
4. **Lo urgente arriba.** Las listas de zonas se ordenan de peor a mejor con
   `zonasPorSeveridad`: crítico → sin datos recientes → alerta → normal.
5. **Una sola fuente para cada cosa.** Colores en `lib/utils/colors.dart`;
   nombre, unidad, ícono, decimales y grupo de cada variable en la tabla
   `variableSpecs` (`lib/config/variable_config.dart`). Nada de `switch` por
   variable en los widgets: para agregar o cambiar una variable se edita
   solo la tabla.

## Colores

Usa siempre los tokens de `AppColors`; no escribas `Color(0x…)` en pantallas.

| Para | Token | Por qué |
|---|---|---|
| Texto, íconos y borde de estado | `AppColors.estadoTexto(nivel, isDark: …)` | Variantes que pasan AA (≥ 4.5:1) sobre la tarjeta y sobre la píldora teñida |
| Lectura vieja o ausente | `AppColors.sinDatos(isDark: …)` | Gris con contraste AA, no un gris "deshabilitado" ilegible |
| Texto principal / secundario | `textPrimary`, `textSecondary` (y `dark…`) | `textSecondary` es `#475569` (6.6:1); el anterior `#64748B` no llegaba a AA |
| Rellenos, acentos, marca | `primary`, `secondary`, `accentOrange`, `critico`, `forEstado()` | **No sirven para texto pequeño en modo claro** (1.9–3.3:1). Úsalos solo en fondos, rellenos grandes o decoración |

Si necesitas un color nuevo, agrégalo a `colors.dart` con su contraste en un
comentario y verifícalo con el script (abajo). Define siempre su versión clara
y oscura.

## Componentes que ya existen

Antes de crear un widget, revisa si alguno de estos resuelve el caso:

- **`VariableCard`** (`lib/widgets/variable_card.dart`): tarjeta de una
  variable con nombre, valor grande + unidad y píldora de estado. Ya maneja
  lectura vieja (`desactualizada`), variable ausente (`measurement: null` →
  "—" y "Sin datos"), borde de 2 px en alerta/crítico, `Semantics` y toque en
  toda la tarjeta.
- **`EstadoPill`**: píldora ícono + texto para estados fuera de una tarjeta
  (encabezados, resúmenes).
- **`ZoneSection`** y **`zonasPorSeveridad`** (`lib/widgets/zone_section.dart`):
  sección de zona con encabezado, botón › de 48 px y los grupos de
  `VariableGroup` (Ambiente / Solución nutritiva) en rejilla de 2 columnas
  (4 desde 600 px).
- **`LiveClock`**, `formatHace`, `lecturaDesactualizada`
  (`lib/widgets/live_clock.dart`): "Hace N min" que avanza solo y la regla de
  los 5 minutos.
- **`NeumorphismDecoration.extruded/glowingExtruded`**: superficies de tarjeta
  del estilo de la app.

## Layout y texto

- **Diseña primero para 360 px.** Padding lateral de 16, separación de 12
  entre tarjetas, 2 columnas. Comprueba que nada desborde: un `Row` con un
  título largo y un botón necesita `Expanded` en el texto.
- **Deja que el texto crezca.** Etiquetas con `maxLines: 2` y `ellipsis`;
  valores grandes dentro de `FittedBox(fit: BoxFit.scaleDown)`. En rejillas,
  usa filas con `IntrinsicHeight` (como `_CardGrid`) en vez de alturas
  fijas, para que no se recorte con el tamaño de letra del sistema.
- **Jerarquía:** valor de la variable 30 px negrita (Poppins); nombre 13 px
  semibold; texto de estado 12 px negrita; títulos de sección 20–22 px.
- **Toques de al menos 48 × 48 px.** Haz tocable toda la tarjeta (`InkWell`)
  y usa `IconButton`/`TextButton`, que ya cumplen el mínimo. No pongas
  `GestureDetector` sobre un ícono de 20 px.
- **Lectores de pantalla:** las tarjetas llevan `Semantics(label: "pH: 7.6.
  Crítico")`; los títulos de grupo, `header: true`; los avisos que aparecen
  solos (sin conexión), `liveRegion: true`.

## Mensajes estándar

Usa estos textos tal cual para que la app hable igual en todas partes:

- Sin red, mostrando caché: **"Sin conexión · datos de las HH:MM"** (hora del
  dato más reciente, `DateFormat('HH:mm')`), con ícono `wifi_off_rounded` y
  color `estadoTexto(alerta)`.
- Lectura de más de 5 min: **"Sin datos recientes"** + ícono `schedule_rounded`.
- Variable que no llegó: valor **"—"** y estado **"Sin datos"**.
- Antigüedad: `formatHace` ("Justo ahora", "Hace 40 seg", "Hace 7 min").

## Cómo verificar un cambio de UI

Haz los cuatro pasos antes de dar un cambio visual por terminado; los
detalles y los problemas conocidos de cada uno están en
`references/verificacion.md`.

1. **Contraste:** `python3 .claude/skills/greentech-design/scripts/contrast.py --app`
   audita la paleta de estado; con `FG BG [--tint 0.1]` revisas un par
   concreto.
2. **Pruebas de accesibilidad:** en la prueba de widget de la pantalla,
   móntala a 360 px de ancho y agrega
   `await expectLater(tester, meetsGuideline(androidTapTargetGuideline));` y
   `textContrastGuideline`. Ve el ejemplo en `test/dashboard_screen_test.dart`.
3. **Capturas a 360 px:** `tool/screenshots/dashboard_360_test.dart` genera
   PNG con texto e íconos reales. Para otra pantalla, copia ese archivo y
   cambia el widget montado. Mira las capturas antes de entregar: muestran
   desbordes y problemas de jerarquía que las pruebas no ven.
4. **`flutter analyze` y `flutter test`** sin errores nuevos.

Si el cambio es un rediseño, toma capturas **antes y después**, guárdalas en
`docs/screenshots/` y enlázalas en el PR.
