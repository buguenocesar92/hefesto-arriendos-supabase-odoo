import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {validateTransfer} from '../../lib/transfer.ts';
import {isDeepStrictEqual} from 'node:util';
import {storageFromEnv} from '../storage.mjs';
const [command,file]=process.argv.slice(2);if(!['import','export','validate'].includes(command)||!file){console.error('Uso: node portable/tools/transfer.mjs validate|import|export /ruta/archivo.json');process.exit(1)}
if(command==='validate'){const s=validateTransfer(JSON.parse(readFileSync(file,'utf8')));console.log(JSON.stringify({valid:true,rentals:s.rentals.length,customers:s.customers.length}));process.exit(0)}
if(process.env.STORAGE_BACKEND!=='supabase')mkdirSync(process.env.DATA_DIR||'/data',{recursive:true});
const store=storageFromEnv();try{const current=await store.read();
if(command==='export'){if(!current)throw new Error('No hay datos');writeFileSync(file,JSON.stringify({format:'hefesto-arriendos',version:1,exportedAt:new Date().toISOString(),state:current.state},null,2),{mode:0o600});console.log('Exportación terminada');}
else{const incoming=validateTransfer(JSON.parse(readFileSync(file,'utf8')));if(current){const s=current.state;if(s.rentals?.length||s.customers?.length||s.assets?.length||s.audit?.length)throw new Error('La instancia tiene datos. Importa con un WORKSHOP_ID nuevo o volumen nuevo para no sobrescribirlos.');if(!await store.save(incoming,current.revision))throw new Error('La instancia cambió durante la importación. Revisa el destino.');}else{await store.initialize(incoming);const actual=await store.read();if(!isDeepStrictEqual(actual.state,incoming))throw new Error('El destino cambió o fue inicializado por otro proceso. Revisa el destino.');}console.log('Importación validada y aplicada. Identificadores conservados.');}}finally{store.close()}
