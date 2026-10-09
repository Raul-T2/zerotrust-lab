# Guia v2 - Consola AWS - Actividad 1 Zero Trust (Ubuntu 22.04)

## LECCIONES DE LA PRIMERA SESION (ya corregidas aqui)
1. Al lanzar la EC2 elige **Ubuntu Server 22.04 LTS**. La opcion por defecto era Ubuntu 26.04 y los scripts no la soportan.
2. Los grupos de seguridad NO pueden llamarse `sg-...`. Usa `grupo-backend` y `grupo-frontend`.
3. Revisa SIEMPRE que "Instancias" muestre DOS instancias (ec2-backend y ec2-frontend) antes de seguir.
4. En la terminal pega SOLO lo que esta dentro de los cuadros de codigo, nunca el texto explicativo.
5. IPs privadas fijas: backend 10.0.1.10, frontend 10.0.0.10 (asi el script ya trae BACKEND_IP listo).

## VALORES (no los cambies)
| Recurso | Nombre | Valor |
|---|---|---|
| VPC 1 | vpc-frontend | 10.0.0.0/25 |
| VPC 2 | vpc-backend | 10.0.1.0/25 |
| Subred 1 | subnet-frontend | 10.0.0.0/25, us-east-1a, IP publica automatica ACTIVADA |
| Subred 2 | subnet-backend | 10.0.1.0/25, us-east-1a |
| IGW 1 | igw-frontend | asociado a vpc-frontend |
| IGW 2 (temporal) | igw-backend | asociado a vpc-backend |
| Peering | peer-front-back | vpc-frontend <-> vpc-backend |
| Tabla 1 | rt-frontend | 0.0.0.0/0 -> igw-frontend ; 10.0.1.0/25 -> pcx ; subnet-frontend |
| Tabla 2 | rt-backend | 0.0.0.0/0 -> igw-backend (temporal) ; 10.0.0.0/25 -> pcx ; subnet-backend |
| Grupo 1 | grupo-frontend | 22 (cualquier lugar, temporal), 80, 443 (cualquier lugar) |
| Grupo 2 | grupo-backend | 22 (cualquier lugar, temporal), TCP 3000 desde 10.0.0.0/25, ICMP desde 10.0.0.0/25 |
| EC2 1 | ec2-backend | Ubuntu 22.04, t3.micro, vpc-backend, IP privada 10.0.1.10 |
| EC2 2 | ec2-frontend | Ubuntu 22.04, t3.micro, vpc-frontend, IP privada 10.0.0.10, 10 GiB |

## FASE 0 - Entrar (min 0-3)
1. Ejercicio de laboratorio -> Load in a new window -> Start Lab. Espera el punto verde junto a AWS y pulsa AWS.
2. Region: Norte de Virginia (us-east-1). No la cambies.
3. REVISA SI ALGO SOBREVIVIO: VPC -> Sus VPC. Si ya existen vpc-frontend y vpc-backend, NO las vuelvas a crear; salta a la Fase 3 y revisa EC2 -> Instancias (si estan detenidas: Estado de la instancia -> Iniciar). Las IP publicas cambian: repite el paso de DuckDNS.

## FASE 1 - Red (min 3-18)
VPC -> Sus VPC -> Crear VPC -> **Solo la VPC** (no "VPC y mas").
1. vpc-frontend / Entrada manual de CIDR IPv4 / 10.0.0.0/25 / sin IPv6 / predeterminado.
2. vpc-backend / 10.0.1.0/25.
3. Subredes -> Crear subred:
   - VPC vpc-frontend, nombre subnet-frontend, zona us-east-1a, CIDR 10.0.0.0/25 (borra el /28 sugerido).
   - VPC vpc-backend, nombre subnet-backend, zona us-east-1a, CIDR 10.0.1.0/25.
4. subnet-frontend -> Acciones -> Editar la configuracion de la subred -> Habilitar IPv4 publicas automaticas -> Guardar.
5. Puertas de enlace de Internet -> Crear `igw-frontend` -> Asociar a una VPC -> vpc-frontend.
   Repite: `igw-backend` -> vpc-backend.
6. Interconexiones -> Crear interconexion: nombre peer-front-back, solicitante vpc-frontend, Mi cuenta, Esta region, aceptante vpc-backend.
   Despues: Acciones -> Aceptar solicitud (estado Activo). Anota el pcx-...
7. Tablas de enrutamiento (usa el filtro con vpc-071a... / vpc-02d5... segun tus IDs nuevos):
   - Tabla principal de vpc-frontend: ponle nombre rt-frontend (lapiz en la columna Name) -> Rutas -> Editar rutas:
     0.0.0.0/0 -> Puerta de enlace de Internet igw-frontend ; 10.0.1.0/25 -> Interconexion pcx-... -> Guardar.
     Asociaciones de subredes -> Editar -> subnet-frontend -> Guardar.
   - Tabla principal de vpc-backend: nombre rt-backend -> Editar rutas:
     0.0.0.0/0 -> igw-backend (TEMPORAL) ; 10.0.0.0/25 -> pcx-... -> Guardar.
     Asociaciones de subredes -> subnet-backend -> Guardar.
> CAPTURAS: 01 VPCs (con CIDR) | 02 subredes | 03 peering Activo | 04 rutas de cada tabla (con el pcx)

## FASE 2 - Las dos instancias (min 18-28)  EC2 -> Instancias -> Lanzar instancias
### ec2-backend (primero)
1. Nombre: ec2-backend.
2. AMI: pestana Ubuntu -> abre el desplegable de la imagen -> **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type** (sin "with SQL Server").
   Si no aparece: "Buscar mas AMI" -> escribe `ubuntu 22.04` -> pestana Quick Start -> "Ubuntu Server 22.04 LTS (HVM), SSD Volume Type" -> Seleccionar.
   Verifica en el Resumen (derecha): "Canonical, Ubuntu, 22.04 LTS".
3. Tipo de instancia: t3.micro. Par de claves: vockey.
4. Configuraciones de red -> Editar:
   - VPC: vpc-backend (elige esta PRIMERO) | Subred: subnet-backend | Asignacion automatica de IP publica: Habilitar
   - Crear un grupo de seguridad | Nombre: `grupo-backend` | Descripcion: `SG backend`
   - Regla 1: Tipo ssh, origen Cualquier lugar. Regla 2: TCP personalizado, puerto 3000, origen Personalizado 10.0.0.0/25.
     Regla 3: Todos los ICMP - IPv4, origen Personalizado 10.0.0.0/25.
5. Abre **Configuracion de red avanzada** (al final de Configuraciones de red) -> Interfaz de red 1 -> **IP principal**: `10.0.1.10`.
   (Si no aparece ese campo, sigue sin el: anota la IP privada real y usala en BACKEND_IP.)
6. Lanzar instancia.
### ec2-frontend (inmediatamente despues)
1. Nombre: ec2-frontend. Misma AMI Ubuntu 22.04, t3.micro, vockey.
2. Red -> Editar: VPC vpc-frontend | subnet-frontend | IP publica Habilitar | grupo nuevo `grupo-frontend`.
   Reglas: ssh (Cualquier lugar), HTTP puerto 80 (Cualquier lugar), HTTPS puerto 443 (Cualquier lugar).
3. Configuracion de red avanzada -> IP principal: `10.0.0.10`.
4. Almacenamiento: 10 GiB. Lanzar instancia.
### Comprobar
EC2 -> Instancias debe mostrar **2 instancias** en ejecucion. Si ves una sola, lanza la que falta ahora.
> CAPTURA 06: instancias con IPs | CAPTURA 05: Grupos de seguridad (reglas de cada uno)

## FASE 3 - Backend (min 28-35)
1. ec2-backend -> Conectar -> Conexion de instancias EC2 -> Conectar.
2. Pega (todo el bloque):
```
git clone https://github.com/Raul-T2/zerotrust-lab.git
cd zerotrust-lab
bash backend/backend-setup.sh
```
3. Tarda ~3 min. Al final debe verse {"status":"ok"}. Ahi termino el backend.

## FASE 4 - Probar el peering y montar el frontend (min 35-50)
1. ec2-frontend -> Conectar -> Conectar. Pega:
```
ping -c 3 10.0.1.10
curl http://10.0.1.10:3000/api/health
```
   Debe responder el ping y {"status":"ok"}.  > CAPTURA 07 (peering privado)
2. Pega (cambia solo el texto TU-TOKEN por tu token de DuckDNS, copiado de la pagina ese dia):
```
git clone https://github.com/Raul-T2/zerotrust-lab.git
cd zerotrust-lab
DUCK_TOKEN="TU-TOKEN" bash frontend-setup.sh
```
3. Debe mostrar OK de DuckDNS y "Status for the jail: nginx-login". Tarda ~4 min. (Tapa el token en cualquier captura.)
4. En tu PC verifica el DNS:  `nslookup raul-zerotrust.duckdns.org` -> debe mostrar la IP publica de ec2-frontend.

## FASE 5 - HTTPS (min 50-58)
En la terminal del frontend:
```
sudo certbot --nginx -d raul-zerotrust.duckdns.org
```
Correo propio, Y (terminos), N (compartir correo), y si pregunta por redireccion elige redirigir HTTP a HTTPS.
> CAPTURA 08 (salida certbot) | CAPTURA 09 (candado en https://raul-zerotrust.duckdns.org y detalles del certificado)

## FASE 6 - Pruebas (min 58-75)
1. Login con admin y el Dashboard en el navegador.  > CAPTURA 10
2. F12 -> Network: peticion login (https) y dashboard con Authorization: Bearer.  > CAPTURA 11
3. JWT con Thunder Client apuntando a https://raul-zerotrust.duckdns.org/api/dashboard : sin token 401, con token 200.  > CAPTURA 12
4. Fail2Ban: antes `sudo fail2ban-client status nginx-login` (CAPTURA 13). 3-4 logins incorrectos en el sitio. Despues el mismo comando (CAPTURA 14) y la pagina ya no responde (CAPTURA 15).
   Desbloquear: `sudo fail2ban-client set nginx-login unbanip TU_IP`
5. securityheaders.com -> https://raul-zerotrust.duckdns.org -> escanear.  > CAPTURA 16

## FASE 7 - Cerrar el backend (min 75-85)
1. rt-backend -> Editar rutas -> elimina 0.0.0.0/0 -> Guardar.
2. Puertas de enlace de Internet -> igw-backend -> Acciones -> Desasociar de la VPC (y opcional Eliminar).
3. grupo-backend -> Editar reglas de entrada -> elimina la regla SSH.
4. grupo-frontend -> regla SSH: cambia Cualquier lugar por Mi IP.
5. Prueba desde tu PC: `curl http://IP_PUBLICA_DEL_BACKEND:3000/api/health` -> sin respuesta.  > CAPTURA 17
6. Vuelve a entrar al sitio https y al Dashboard (sigue funcionando por el peering).  > CAPTURA 18
7. Repite CAPTURA 04 (rutas) y CAPTURA 05 (reglas definitivas).

## Despues
- Guarda TODAS las capturas en tu PC. Regenera tu token de DuckDNS al terminar.
