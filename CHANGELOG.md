# Changelog

Todas las versiones notables se documentan aquí. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
[versionado semántico](https://semver.org/lang/es/).

## [No publicado]

## [0.6.0]

### Arreglado
- **El fichaje de salida ya no llega tarde ni se pierde.** En móviles con capas
  agresivas (Xiaomi/MIUI y similares), el sistema "aparcaba" la alarma con la
  pantalla apagada y la salida salía con minutos —u horas— de retraso (o se
  descuadraba el historial). Ahora las alarmas usan el mecanismo de
  **despertador del sistema** (`setAlarmClock`), que ni Doze ni el ahorro de
  batería pueden demorar: el fichaje sale a su hora aunque el móvil lleve horas
  en reposo. *(Verificado: 0 s de retraso, antes 3 min en la misma prueba.)*

### Añadido
- **Red de seguridad**: una comprobación periódica recupera la entrada o la
  salida del día si, por lo que sea, la alarma no llegó a registrarlas (mirando
  antes en Séneca para no duplicar).
- **Diagnóstico** (Ajustes → Contacto → «Ver diagnóstico»): un registro de la
  actividad de fichaje que puedes **enviar al desarrollador con un toque** si
  algo falla. No incluye tu contraseña ni datos personales.
- Las alarmas del día **sobreviven a un reinicio** del teléfono.

## [0.5.0]

### Añadido
- **Contacto desde la app.** Nueva sección **Ajustes → Contacto**:
  - **Escribir al desarrollador**: abre el correo con un mensaje prellenado
    (incluye tu versión). Si no tienes app de correo, copia la dirección.
  - **Reportar en GitHub**: abre los *issues* del proyecto.
- El README incluye una sección **Contacto y soporte** para quien no sepa abrir
  un *issue* en GitHub.

### Cambiado
- **Nuevo icono de la app**, en su versión clara: el mosaico de teselas cian
  sobre fondo claro (como el logo de la pantalla de registro), en lugar del
  cuadrado oscuro. Hecho como icono adaptable (glifo + fondo de color).

## [0.4.0]

### Añadido
- **Fiabilidad del fichaje automático.** La app ahora **pide los permisos** que
  necesita para fichar en segundo plano, en vez de solo declararlos:
  - Al activar el fichaje automático solicita **notificaciones** y **exención de
    optimización de batería** (diálogos del sistema).
  - **Guía por fabricante** (Xiaomi, Samsung, Huawei/Honor, Oppo/Realme,
    OnePlus, Vivo): abre la pantalla de *Inicio automático* correspondiente y
    avisa de desactivar *«Pausar la actividad si no se utiliza»* (hibernación de
    apps), que en móviles agresivos hacía que los fichajes salieran tarde o se
    perdieran.
  - **Aviso en Inicio** si el fichaje automático está activo pero falta algún
    permiso crítico, con botón **Arreglar**.

### Cambiado
- La app arranca en **tema claro por defecto** (también en el registro).

### Arreglado
- El mensaje de "Fichaje registrado a las…" del fichaje manual **se oculta solo**
  a los pocos segundos (antes se quedaba fijo en pantalla).
- "Últimos fichajes" **se actualiza** tras un fichaje manual (antes no reflejaba
  el que acababas de registrar).

## [0.3.3]

### Cambiado
- Las notas de cada actualización muestran ahora los **cambios reales** de la
  versión (extraídos del CHANGELOG) y se ven limpias en el diálogo, sin marcas
  de markdown, en vez del enlace genérico "Full Changelog" de GitHub.

## [0.3.2]

### Cambiado
- "Buscar actualizaciones" (Ajustes) ahora **actualiza en el sitio**: si hay
  versión nueva, muestra un diálogo con las novedades y un botón **Actualizar**
  que descarga e instala con barra de progreso. Antes te mandaba a Inicio, donde
  el banner no aparecía hasta reiniciar la app.

## [0.3.1]

### Arreglado
- La barra de navegación inferior ahora **sí** cambia de color al instante al
  alternar claro/oscuro (en 0.3.0 el arreglo no llegaba a la raíz). Sus colores
  salen del tema, por lo que se repintan de forma heredada y animada.
- El historial y el panel del día del calendario se muestran en **orden
  cronológico**: días de más reciente a más antiguo y, dentro de cada día, la
  entrada antes que la salida (antes podían aparecer al revés).
- "Últimos fichajes" de Inicio ya no muestra "Sin fichajes recientes" cuando en
  realidad falló la carga: distingue el error (con opción de **Reintentar**) del
  caso de no tener fichajes.

## [0.3.0]

### Añadido
- Calendario del historial con un tercer estado: 🟢 fichado completo, 🟠
  incompleto (falta la entrada o la salida) y 🔴 día lectivo sin fichar. Antes
  un día a medias se mostraba igual que uno completo.

### Arreglado
- La barra de navegación inferior ahora cambia de color al instante al pasar de
  tema claro a oscuro (antes conservaba el color anterior hasta cambiar de
  pestaña).

### Cambiado
- Toolchain de Android al día: Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20 y
  `compileSdk` 36 (silencia avisos de los plugins).
- README: instrucciones claras sobre los avisos de seguridad al instalar y
  actualizar fuera de la Play Store.

## [0.2.0]

Versión de prueba para validar la actualización automática in-app. Sin cambios
funcionales respecto a 0.1.0.

## [0.1.0]

Primera versión (en pruebas).

### Añadido
- Fichaje automático de entrada y salida según el horario de Séneca.
- Hora de fichaje **aleatoria** dentro del margen (no siempre la misma hora).
- Historial de fichajes con vista de lista (filtros) y calendario.
- Importación automática del horario en el alta y refresco diario.
- Modo periodo no lectivo (horario fijo de L a V).
- Tema claro / oscuro / automático.
- Re-login automático ante expiración del token (401).
- Actualizaciones in-app desde GitHub Releases.
