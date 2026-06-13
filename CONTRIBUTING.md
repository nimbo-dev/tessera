# Contribuir a Tessera

¡Gracias por tu interés! Tessera es una app Android (Flutter) que automatiza el
control de presencia del profesorado en Séneca.

## Entorno de desarrollo

Requisitos: Flutter 3.x y Android SDK (API 34).

```bash
flutter pub get
flutter run            # en un emulador o dispositivo
```

Tras clonar, hay ficheros que **no** están en el repo y debes crear (ver el
README, sección «Compilar desde el código fuente»): `android/local.properties`
(se genera solo) y, si vas a firmar releases, `android/key.properties`.

## Estilo

- Sigue el estilo del código existente (ver `.editorconfig`).
- Antes de abrir el PR, deja `flutter analyze` **sin errores**.

## Flujo de trabajo (PR)

1. Crea una rama desde `main` (p. ej. `feat/historial-horas` o `fix/fichaje-401`).
2. Haz tus cambios. Antes de abrir el PR comprueba en local que pasa:
   ```bash
   flutter analyze
   flutter build apk --debug
   ```
3. Abre un PR **contra `main`** con la plantilla. La **CI** repetirá analyze +
   build; debe estar en verde para fusionar.
4. Revisión → fusión a `main`.

### Mensajes de commit

Usamos [Conventional Commits](https://www.conventionalcommits.org/): `feat:`,
`fix:`, `docs:`, `refactor:`, `chore:`… Ayuda a agrupar las notas de versión.

## Releases

Las hace quien mantiene el proyecto, mediante tag:

```bash
git tag v1.1.0 && git push origin v1.1.0
```

El workflow de release compila el APK firmado en un entorno limpio y publica una
**GitHub Release** con el APK adjunto.

## Reglas de oro

- **Nunca** subas secretos: el keystore (`*.jks`), `key.properties`, tokens ni
  credenciales. Están en `.gitignore`.
- Las credenciales del usuario solo viven **cifradas en el dispositivo**; no se
  envían a ningún servidor ajeno a Séneca.

## Reportar problemas

Abre un *issue* con las plantillas. Para temas de seguridad, ver
[`SECURITY.md`](SECURITY.md) (no lo reportes como issue público).
