"""Prepara CSV para mapear en Odoo; no conecta ni escribe en el ERP."""
import csv,json,sys
from pathlib import Path
if len(sys.argv)!=3:raise SystemExit('Uso: python3 migration/prepare_odoo.py respaldo.json salida')
p=json.loads(Path(sys.argv[1]).read_text());s=p.get('state',p)
if s.get('format')!='hefesto-arriendos':raise SystemExit('Formato incompatible')
out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
def save(name,columns,rows):
 with (out/name).open('w',newline='',encoding='utf-8-sig') as f:
  w=csv.writer(f);w.writerow(columns);w.writerows(rows)
save('01_contactos.csv',['ID externo','Nombre','Contacto','RUT referencia','Correo','Teléfono','Dirección'],[['hefesto_customer_'+c['id'],c['name'],c['contact'],c['rut'],c['email'],c['phone'],c['address']] for c in s['customers']])
save('02_equipos_revision.csv',['ID externo','Código','Nombre','Categoría','Marca','Serie','Precio día CLP','Garantía CLP','Estado','Accesorios'],[['hefesto_asset_'+a['id'],a['code'],a['name'],a['category'],a['brand'],a['serial'],a['dailyRate'],a['deposit'],a['status'],a['accessories']] for a in s['assets']])
save('03_arriendos_revision.csv',['ID externo','Cliente referencia','Equipo referencia','Inicio incluido','Fin incluido','Estado','Precio día fijado','Base CLP','Garantía requerida CLP','Condiciones'],[['hefesto_rental_'+r['id'],'hefesto_customer_'+r['customerId'],'hefesto_asset_'+r['assetId'],r['start'],r['end'],r['status'],r['dailyRate'],r['baseTotal'],r['deposit'],r['terms']] for r in s['rentals']])
save('04_movimientos_conciliacion.csv',['ID','Arriendo referencia','Fecha ISO','Concepto','Monto CLP','Método','Referencia'],[[p['id'],'hefesto_rental_'+r['id'],p['date'],p['kind'],p['amount'],p['method'],p['reference']] for r in s['rentals'] for p in r['payments']])
save('05_cargos_revision.csv',['ID','Arriendo referencia','Monto CLP','Motivo','Acuerdo referencia'],[[c['id'],'hefesto_rental_'+r['id'],c['amount'],c['reason'],c['reference']] for r in s['rentals'] for c in r['charges']])
(out/'respaldo_completo.json').write_text(json.dumps(s,ensure_ascii=False,indent=2))
(out/'LEEME.txt').write_text('CSV de preparación. Mapear campos, estados, productos/equipos físicos y relaciones según edición y módulos disponibles en Odoo. No incluye addon ni sincronización. Precios registrados son valores comerciales finales, sin desglose tributario: revisar tratamiento en destino. Garantías separadas de ingreso. Movimientos solo para conciliación, no crean asientos. Datos históricos, entrega, retorno e historial completos en JSON. Un equipo físico por arriendo, fechas inclusivas; adaptar horarios de destino. Validar en una base de ensayo.\n')
print('Exportación preparada:',out)
