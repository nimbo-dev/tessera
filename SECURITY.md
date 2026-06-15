# Política de seguridad

## Reportar una vulnerabilidad

Si encuentras un problema de seguridad **no lo abras como issue público**. Usa
los *GitHub Security Advisories* del repositorio (pestaña **Security → Report a
vulnerability**) o escribe en privado a **nimbo.dev@proton.me**. Intentaremos
responder lo antes posible.

## Manejo de credenciales

Tessera maneja las credenciales de Séneca del usuario. Reglas que el proyecto
respeta:

- **Nunca** se versionan secretos: keystore (`*.jks`), `key.properties`, tokens
  ni contraseñas. Están en `.gitignore`.
- El usuario, la contraseña y el token de dispositivo de confianza se guardan
  **cifrados en el dispositivo** mediante `flutter_secure_storage` (Keystore de
  Android), nunca en el repositorio ni en ningún servidor de terceros.
- Las credenciales solo viajan a la **API oficial de Séneca**
  (`seneca.juntadeandalucia.es`), exactamente igual que la app oficial iSéneca.
- Las releases se firman en CI con un keystore guardado como *secret* del
  repositorio; el keystore nunca se sube al código.

## Qué datos salen del dispositivo

Ver la sección de privacidad del [`README`](README.md): solo se comunica con
Séneca; no hay analítica ni envío de datos a terceros.
