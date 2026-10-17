# Hefesto Arriendos — instalación y traspaso

## Supabase / Coolify
1. Crea o selecciona un proyecto Supabase.
2. Ejecuta `supabase/migrations/202610130001_hefesto_taller.sql`. El nombre heredado no afecta las tablas exclusivas: hefesto_arriendos_states y hefesto_arriendos_sessions.
3. Copia `.env.example` a `.env`. Completa SUPABASE_URL, SUPABASE_SECRET_KEY (sb_secret o service_role), WORKSHOP_ID, ADMIN_PASSWORD (16 caracteres mínimo), PUBLIC_ORIGIN (dominio HTTPS), COOKIE_SECURE=true.
4. Ejecuta `docker compose -f compose.supabase.yaml up -d --build`. En Coolify selecciona ese Compose y asigna dominio al puerto interno 3000.
5. Accede con contraseña de administración. Clave Supabase exclusiva servidor.

El servicio Compose conserva el nombre técnico `taller` por compatibilidad del adaptador. Las tablas son exclusivas de Arriendos. Cambia el puerto de host 3080 si ya lo ocupa otra app y asigna dominios separados a cada producto.

## SQLite
`docker compose -f compose.yaml up -d --build`. Usa volumen persistente. En prueba local PUBLIC_ORIGIN=http://localhost:3080 y COOKIE_SECURE=false. En producción usa HTTPS. Instalación portable empieza sin clientes, equipos ni reservas; revisa nombre y condiciones predeterminados.

## Migrar datos
Exporta JSON desde Portabilidad. El ZIP incluye código y demo, no datos reales.

```
docker compose -f compose.supabase.yaml cp hefesto-arriendos.json taller:/data/import.json
docker compose -f compose.supabase.yaml exec taller node portable/tools/transfer.mjs validate /data/import.json
docker compose -f compose.supabase.yaml exec taller node portable/tools/transfer.mjs import /data/import.json
```

Preserva IDs y rechaza sobrescribir destinos con registros. Usa WORKSHOP_ID nuevo o volumen vacío. Pausa operaciones durante migración. Exporta con `node portable/tools/transfer.mjs export /data/respaldo.json` dentro del servicio y copia fuera con docker compose cp. Conserva respaldos independientes protegidos.

## Odoo
`python3 migration/prepare_odoo.py hefesto-arriendos.json salida-odoo`

Genera CSV de contactos, equipos físicos, arriendos, movimientos y cargos, más JSON íntegro. Requiere mapear campos, relaciones, impuestos y módulos según versión/edición destino. Garantías separadas de ingresos, movimientos solo para conciliación. No incluye addon, asientos automáticos ni sincronización. Probar en base de ensayo.

## Operación
Un arriendo corresponde a un equipo físico con código único. Para varios equipos crea varias reservas. Inicio y fin son inclusivos: dos reservas no comparten el mismo día mientras estén reservadas/entregadas. Máximo 365 días. No hay tramos horarios ni cantidades agrupadas.

Crear cliente y equipo, consultar disponibilidad, reservar, registrar cobros de arriendo y garantía, entregar con nombre/estado/confirmación, recibir con revisión, devolver garantía y cerrar. Una reserva pagada solo se reprograma después de registrar devoluciones de sus cobros. Tarifa diaria original se conserva al reprogramar. Entrega requiere fecha dentro del período y equipo físicamente disponible. Equipos atrasados bloquean nuevas reservas futuras hasta registrar retorno. Reservas ya existentes requieren coordinación manual si un retorno se retrasa.

Una devolución anticipada libera equipo al registrar retorno y no recalcula precio. No hay extensión de fechas después de entregar ni recargo automático por atraso. Cargos adicionales solo por acuerdo registrado, no descuentan garantía. Retorno con problemas pone equipo en mantenimiento y bloquea nuevas entregas; revisar reservas existentes. Cambiar precios/nombres no modifica valores históricos del arriendo.

## Dinero y garantías
Cobros y devoluciones son registros manuales; no hay dinero procesado por la app. Arriendo y garantía se mantienen en cuentas conceptuales separadas. Garantía no se considera ingreso. Cancelar libera fechas pero conserva cobros pendientes de devolución. Cerrar exige retorno, saldo de arriendo cero y garantía completamente devuelta. No hay retención/aplicación automática de garantía ni reembolso parcial del arriendo ya entregado. Si hay daños, registrar cargo acordado, cobrarlo por separado y devolver garantía según lo acordado fuera de la app.

Precios en CLP finales registrados; no se desglosa o añade impuesto. No emite documentos tributarios ni determina tratamiento legal/contable. La ficha imprimible es registro administrativo, no contrato firmado electrónicamente.

## Alcance y verificación
- Administración privada única; sin roles, portal público, pasarela, firma, correo, WhatsApp, GPS o integración Odoo conectada.
- Sin fotos/adjuntos, checklist por componente, múltiples bodegas o depreciación.
- Supabase usa JSON por instancia y sesiones con RLS y acceso exclusivo servidor, no Supabase Auth ni tablas normalizadas por entidad.
- API GET/POST /api/service con revisión para evitar sobrescrituras concurrentes.
- Siete pruebas automáticas aprobadas, tipos y compilaciones verificados. Docker y un Supabase real requieren prueba en destino. QA visual y paginación de ficha en navegador pendientes.
