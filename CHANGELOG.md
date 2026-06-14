# Changelog

Todas las versiones notables se documentan aquí. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
[versionado semántico](https://semver.org/lang/es/).

## [No publicado]

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
