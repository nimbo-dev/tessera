# Tessera

[![Release](https://img.shields.io/github/v/release/nimbo-dev/tessera)](https://github.com/nimbo-dev/tessera/releases)
[![Descargas](https://img.shields.io/github/downloads/nimbo-dev/tessera/total)](https://github.com/nimbo-dev/tessera/releases)
[![Licencia](https://img.shields.io/github/license/nimbo-dev/tessera)](LICENSE)

Tessera es una app que automatiza el control de presencia en Séneca para el profesorado andaluz. Registra tu entrada y salida cada día lectivo según tu horario, sin necesidad de abrir la aplicación, también cuando trabajas fuera del centro, como en las visitas de FP Dual.

> *Disponible para Android. Versión para iOS en desarrollo*. Aplicación no oficial, sin afiliación con la Junta de Andalucía ni con el proyecto Séneca.

---

## Cómo funciona

1. **Una sola vez:** conectas tu cuenta de Séneca (usuario + contraseña) y verificas un código SMS. Es el **único SMS** que necesitarás. Al terminar, Tessera importa tu horario semanal automáticamente.
2. **Activas el fichaje automático** con el interruptor de la pantalla de inicio.
3. **Te olvidas.** Cada día lectivo, 30 minutos antes de tu primera clase, Tessera consulta tu horario en Séneca (festivos y días sin clase incluidos) y programa los fichajes.
4. Recibes una **notificación** cada vez que se registra una entrada o salida.

No necesitas volver a abrir la app.

---

## Características

- **Fichaje automático** de entrada y salida según tu horario real de Séneca.
- **Hora natural, no robótica:** cada día ficha en un momento **al azar** dentro de un margen (p. ej. hasta 10 min antes de entrar y después de salir), para que no sea siempre la misma hora exacta.
- **Historial** de fichajes con vista de **lista** (filtros entrada/salida) y **calendario** (días fichados y días lectivos sin fichar).
- **Funciona en jornadas fuera del centro** (visitas de FP Dual, etc.).
- **Periodo no lectivo:** modo de horario fijo de L a V para inicio de septiembre y final de junio.
- **Tema claro / oscuro / automático.**
- **Fichaje manual** a un toque, por si quieres registrar al momento.
- **Privacidad:** tus credenciales se guardan **cifradas en el dispositivo** (Keystore de Android) y solo viajan a Séneca.

---

## Instalación

### Requisitos
- Android 7.0 o superior.
- Cuenta activa en Séneca / iSéneca (Junta de Andalucía).
- Conexión a internet en el momento del fichaje.

### Instalar el APK
1. Descarga el APK (`tessera-vX.Y.Z.apk`) desde la sección **[Releases](../../releases)**.
2. Ábrelo en el móvil (desde la notificación de descarga o desde la carpeta *Descargas*).
3. Android te pedirá **permitir instalar apps de esta fuente** (tu navegador o gestor de archivos): actívalo y vuelve atrás.
4. Pulsa **Instalar** y, al terminar, abre la app.

> ⚠️ **Vas a ver avisos de seguridad. Es normal y no significa que la app sea peligrosa.**
> Como Tessera **no se instala desde Google Play** (mantenerla anónima y fuera de la Play Store es deliberado), Android te avisará. Esto es lo que verás y qué hacer:
>
> | Aviso | Qué hacer |
> |---|---|
> | **"Por tu seguridad, el teléfono no puede instalar apps de esta fuente"** | Toca **Ajustes** → activa **Permitir de esta fuente** → vuelve atrás. |
> | **Play Protect: "App no segura"** o **"¿Quieres analizar la app?"** | Toca **Instalar de todos modos** (o **No analizar**). Play Protect marca así toda app que no viene de la Play Store, no es que haya detectado nada. |
> | **Xiaomi / MIUI / Redmi:** análisis extra, cuenta atrás de 10 s, "Instalación bloqueada" | Espera la cuenta atrás y pulsa **Instalar de todos modos**. Si lo bloquea del todo, desactiva *Ajustes → Protección de privacidad → Analizar apps antes de instalar*. |
>
> Si quieres verificar tú mismo lo que instalas: el código es público en este repositorio y cada APK se compila de forma automática y firmada por [GitHub Actions](.github/workflows/release.yml), no a mano.

### Actualizar la app
Tessera **te avisa sola** cuando hay una versión nueva: aparece un banner en la pantalla de **Inicio** (o pulsa **Ajustes → Buscar actualizaciones**). Al aceptar, descarga el nuevo APK y lanza la instalación.

> ⚠️ Al actualizar **volverán a salir los mismos avisos de seguridad** del paso anterior (fuente desconocida, Play Protect, MIUI). Es lo normal: respóndelos igual (**Instalar de todos modos**). La sesión y tu configuración **se conservan**; no tendrás que volver a iniciar sesión ni a meter el SMS.
>
> Tessera se actualiza **sobre la versión instalada** porque todas las releases van firmadas con la misma clave. No desinstales la versión anterior: si lo haces, perderás la sesión guardada.

### Permisos que solicita
| Permiso | Para qué |
|---|---|
| Internet | Comunicación con la API de Séneca |
| Alarmas exactas | Fichar a la hora justa aunque el teléfono esté en reposo |
| Notificaciones | Confirmar que el fichaje se registró |
| Inicio automático | Reprogramar las alarmas tras reiniciar el teléfono |
| Instalar apps | Aplicar las actualizaciones dentro de la propia app |

> **Batería:** para que los fichajes salgan a su hora, excluye Tessera de la optimización de batería (Ajustes → Batería → Tessera → No optimizar).

---

## Uso

La app tiene tres pestañas:

- **Inicio** — estado del fichaje automático (interruptor), el horario de hoy, el botón de fichaje manual y tus últimos fichajes.
- **Historial** — todos tus fichajes, en lista (con filtros) o en calendario.
- **Ajustes** — tu cuenta, apariencia (claro/oscuro), qué fichar (entrada/salida), periodo no lectivo y opciones avanzadas (actualizar horario y márgenes).

### Cuándo actualizar el horario
El horario se mantiene solo (se refresca cada mañana al consultar Séneca). Aun así, puedes forzar una actualización desde **Ajustes → Avanzado** al inicio de curso o si durante el curso cambia el horario.

---

## Preguntas frecuentes

**¿Tiene que estar abierta la app para fichar?**
No. Las alarmas se programan en el sistema y se ejecutan con la app cerrada y el teléfono en reposo.

**¿Y si no tengo cobertura a esa hora?**
Hay un reintento automático (WorkManager) en cuanto vuelve la conexión.

**¿Ficha en festivos o días sin clase?**
No. Cada mañana consulta el horario del día en Séneca; si no hay clase, no ficha.

**¿Mis credenciales están seguras?**
Sí. La contraseña y el token se guardan en el Keystore cifrado de Android (`flutter_secure_storage`) y solo se envían a Séneca.

**¿Por qué solo pide el SMS una vez?**
Al verificarlo, Séneca devuelve un token de dispositivo de confianza de larga duración; los accesos siguientes lo usan para entrar sin SMS.

**Al instalar/actualizar me salen avisos de "app no segura". ¿Es peligrosa?**
No. Son los avisos que Android y Play Protect muestran con **cualquier** app que no venga de la Play Store; no es una detección real. Tessera está fuera de la Play Store a propósito (anonimato). Pulsa **Instalar de todos modos**. Ver [Instalación](#instalación) para el detalle por marca (incluido Xiaomi/MIUI).

---

## Compilar desde el código fuente

### Requisitos
- Flutter 3.x y Android SDK (API 34).
- Java 17 (incluido en Android Studio).

### Ficheros que NO están en el repositorio
Por seguridad están en `.gitignore`; créalos tras clonar:

| Fichero | Qué es | Cómo obtenerlo |
|---|---|---|
| `android/local.properties` | Ruta de tu Android SDK | Se genera solo al abrir el proyecto en Android Studio o al compilar. |
| `android/key.properties` | Firma del release | Copia `key.properties.example` → `key.properties` y rellénalo. **Opcional** para compilar en debug. |
| Keystore `*.jks` | Tu clave de firma | Genéralo tú (abajo). **No** subir nunca. |

### Compilar (debug)
```bash
flutter pub get
flutter build apk --release   # firma con clave debug si no hay key.properties
```

### Firmar para publicar
```bash
keytool -genkey -v -keystore tessera-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tessera
cp android/key.properties.example android/key.properties
# edita key.properties con tus datos, y luego:
flutter build apk --release
```

> **Releases:** se publican vía **GitHub Actions** (`.github/workflows/release.yml`): al hacer push de un tag `vX.Y.Z`, compila el APK firmado en un entorno limpio y lo adjunta a la release automáticamente.

---

## Aviso legal

Proyecto independiente, sin relación con la Junta de Andalucía ni con Séneca. Usa los mismos endpoints públicos que la app oficial iSéneca con tus propias credenciales. Úsalo de forma responsable y conforme a tus obligaciones laborales.
