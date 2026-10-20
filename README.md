# Hefesto Arriendos
Gestión privada de equipos físicos individuales: clientes, inventario por código, disponibilidad por días, reservas, entregas, retornos, mantenimiento, garantías separadas, cobros/devoluciones manuales y fichas imprimibles.

[Instalación y traspaso](docs/INSTALACION.md).

Incluye código, cliente compilado, Docker/Coolify, SQLite/Supabase, SQL, importador/exportador, CSV de preparación Odoo y pruebas. Sitio usa D1; distribución portable usa acceso propio sin ChatGPT. No incluye secretos ni registros reales.

## Verificar
Node 24: `node --test tests/*.test.mjs`. package.json raíz corresponde a Sites. Para compilar portable en una copia separada usa portable/package.json como package.json raíz, instala dependencias y ejecuta `npm run build`. Docker realiza ese proceso; portable/dist incluye el cliente compilado.

## Comercialización
Una instancia por empresa de arriendos con instalación, carga de equipos, configuración y soporte mensual. No hay suscripciones ni cargos automáticos al cliente final.

## Despliegue en Coolify (MVP Hefesto)

Coolify (build pack Docker Compose) levanta la app con `compose.supabase.yaml` y enruta el dominio al servicio `taller` (Traefik pone TLS). Pasos previos al primer deploy:

1. **Migración inicial (manual).** Antes del primer deploy, aplicar `supabase/migrations/202610130001_hefesto_taller.sql` en el SQL Editor de Supabase como propietario del proyecto. Crea `hefesto_arriendos_states` y `hefesto_arriendos_sessions`.
2. **Variables de entorno en Coolify.** Definir (no se exponen los valores en este README):
   - `SUPABASE_URL` — URL del proyecto Supabase.
   - `SUPABASE_SECRET_KEY` — clave `sb_secret_…` (o service_role legacy). Nunca `anon`/`publishable`.
   - `ADMIN_PASSWORD` — contraseña del administrador (≥16 caracteres).
   - `PUBLIC_ORIGIN` — URL pública que servirá Coolify (ej. `https://arriendos.tu-dominio.cl`).
   - Opcionales: `WORKSHOP_ID` (default `main`), `COOKIE_SECURE` (default `true`).

El compose del repo (`compose.supabase.yaml`) no publica `ports:`; Traefik delega el tráfico al servicio `taller` por la red interna de Docker. La imagen se construye desde `portable/Dockerfile` con contexto en la raíz. El healthcheck viene en la propia imagen (`/health`).

`SUPABASE_URL` puede ser la URL pública `https://<proyecto>.supabase.co` o una interna `http://supabase-kong:8000` (la lista de hosts permitidos en `portable/storage.mjs` ya incluye `supabase-kong` y `kong`).
