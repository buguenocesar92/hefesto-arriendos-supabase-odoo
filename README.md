# Hefesto Arriendos
Gestión privada de equipos físicos individuales: clientes, inventario por código, disponibilidad por días, reservas, entregas, retornos, mantenimiento, garantías separadas, cobros/devoluciones manuales y fichas imprimibles.

[Instalación y traspaso](docs/INSTALACION.md).

Incluye código, cliente compilado, Docker/Coolify, SQLite/Supabase, SQL, importador/exportador, CSV de preparación Odoo y pruebas. Sitio usa D1; distribución portable usa acceso propio sin ChatGPT. No incluye secretos ni registros reales.

## Verificar
Node 24: `node --test tests/*.test.mjs`. package.json raíz corresponde a Sites. Para compilar portable en una copia separada usa portable/package.json como package.json raíz, instala dependencias y ejecuta `npm run build`. Docker realiza ese proceso; portable/dist incluye el cliente compilado.

## Comercialización
Una instancia por empresa de arriendos con instalación, carga de equipos, configuración y soporte mensual. No hay suscripciones ni cargos automáticos al cliente final.
