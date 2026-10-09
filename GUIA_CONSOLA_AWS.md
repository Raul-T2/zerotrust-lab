# Guia de la consola AWS - Actividad 1 Zero Trust
Nombres sugeridos (puedes cambiarlos, pero usa los mismos en todas las capturas).
Todo en la MISMA region (la que muestre la consola arriba a la derecha).

Antes de empezar: abre en pestanas separadas -> esta guia, tu archivo de notas, DuckDNS, GitHub (zerotrust-lab).
Plan de tiempo (90 min):  0-15 red | 15-25 SG y EC2 | 25-40 backend | 40-60 frontend+DNS | 60-70 HTTPS | 70-85 Fail2Ban y SecurityHeaders | 85-90 capturas finales

## FASE 0 - Entrar (el reloj corre desde "Start Lab")
1. Abre el ejercicio de laboratorio -> "Load ... in a new window" -> pulsa Start Lab.
2. Espera a que el indicador junto a "AWS" se ponga verde y pulsa "AWS" (abre la consola).
3. Anota la REGION. En la barra de busqueda escribe "VPC" y abre el servicio.
4. PRUEBA RAPIDA DE PERMISOS: si mas adelante AWS te niega crear el Peering, avisa al profesor.

## FASE 1 - VPCs y subredes (min 0-8)
1. VPC -> "Your VPCs" -> Create VPC.
   - Resources to create: **VPC only**
   - Name: `vpc-frontend`   IPv4 CIDR (manual input): `10.0.0.0/25`   IPv6: No   Tenancy: Default -> Create VPC.
2. Repite: `vpc-backend`  CIDR `10.0.1.0/25`  (CONFIRMA con tu tabla que no se traslapa con la VPC 1).
3. Subnets -> Create subnet.
   - VPC: vpc-frontend | Name: `subnet-frontend` | AZ: la misma para las dos (ej. la primera) | CIDR: `10.0.0.0/25` -> Create.
   - Otra: VPC vpc-backend | `subnet-backend` | misma AZ | CIDR `10.0.1.0/25`.
4. Selecciona `subnet-frontend` -> Actions -> Edit subnet settings -> marca **Enable auto-assign public IPv4 address** -> Save.
> CAPTURA 1: lista de VPCs con sus CIDR.   CAPTURA 2: lista de subredes.

## FASE 2 - Internet del frontend y rutas (min 8-12)
1. Internet gateways -> Create -> Name `igw-frontend` -> Create -> Actions -> **Attach to VPC** -> vpc-frontend.
2. Route tables: busca la que tenga VPC = vpc-frontend (la "Main"). Ponle nombre `rt-frontend`.
   - Routes -> Edit routes -> Add route: Destination `0.0.0.0/0`, Target: Internet Gateway -> igw-frontend -> Save.
   - Subnet associations -> Edit subnet associations -> marca subnet-frontend -> Save.
3. Igual para la VPC del backend: renombra su tabla `rt-backend` y asocia `subnet-backend` (aun sin rutas).

## FASE 3 - VPC Peering (min 12-16)
1. Peering connections -> Create peering connection.
   - Name `peer-front-back` | Requester: vpc-frontend | Account: My account | Region: This Region | Accepter: vpc-backend -> Create.
2. Selecciona el peering -> Actions -> **Accept request** -> Accept. Debe quedar **Active**. Anota el ID `pcx-...`.
3. `rt-frontend` -> Edit routes -> Add route: Destination `10.0.1.0/25`, Target: Peering Connection -> pcx -> Save.
4. `rt-backend`  -> Edit routes -> Add route: Destination `10.0.0.0/25`, Target: Peering Connection -> pcx -> Save.
> CAPTURA 3: peering Active.   CAPTURA 4: rutas de rt-frontend y rt-backend (se ve el pcx).

## FASE 4 - Internet TEMPORAL del backend (solo para instalar)
1. Internet gateways -> Create `igw-backend` -> Attach to vpc-backend.
2. `rt-backend` -> agrega `0.0.0.0/0` -> igw-backend.
(Al terminar la instalacion del backend, esta ruta se ELIMINA - ver Fase 10.)

## FASE 5 - Security Groups (min 16-20)  EC2 -> Security Groups -> Create
**sg-frontend** (VPC: vpc-frontend)
- Inbound: HTTP 80 desde 0.0.0.0/0 | HTTPS 443 desde 0.0.0.0/0 | SSH 22 desde 0.0.0.0/0 (TEMPORAL, se restringe en Fase 10)
- Outbound: dejar el predeterminado.
**sg-backend** (VPC: vpc-backend)
- Inbound: Custom TCP **3000** desde `10.0.0.0/25` | All ICMP-IPv4 desde `10.0.0.0/25` (para ping) | SSH 22 desde 0.0.0.0/0 (TEMPORAL)
- No agregues el puerto 3000 al publico.
> CAPTURA 5: reglas de entrada de ambos SG (al final repite esta captura con las reglas definitivas).

## FASE 6 - Instancias EC2 (min 20-25)  EC2 -> Launch instance
Frontend:
- Name `ec2-frontend` | AMI: **Ubuntu Server 22.04 LTS** | Type: t2.micro o t3.micro
- Key pair: usa el que te ofrezca el lab, o crea `zerotrust-key` (.pem) y guardalo; o "Proceed without a key pair" si vas a usar el boton Connect del navegador.
- Network settings -> Edit: VPC vpc-frontend | Subnet subnet-frontend | Auto-assign public IP: Enable | Select existing SG: sg-frontend
- Launch.
Backend: igual con `ec2-backend`, vpc-backend, subnet-backend, **Auto-assign public IP: Enable (temporal)**, sg-backend.
Cuando esten "Running": anota en tus notas la IP privada del backend y la IP publica del frontend.
> CAPTURA 6: lista de instancias con IPs.

## FASE 7 - Backend (min 25-40)
1. Selecciona ec2-backend -> Connect -> EC2 Instance Connect -> Connect (abre una terminal en el navegador).
2. `git clone https://github.com/Raul-T2/zerotrust-lab.git && cd zerotrust-lab`
3. `nano backend/backend-setup.sh` -> revisa CONFIG (ya trae tu repo) -> Ctrl+O, Enter, Ctrl+X.
4. `bash backend/backend-setup.sh`  -> al final debe mostrar {"status":"ok"}.

## FASE 8 - Probar el peering (min 40-43)
Desde la terminal de **ec2-frontend** (Connect igual que antes):
   `ping -c 3 IP_PRIVADA_BACKEND`
   `curl http://IP_PRIVADA_BACKEND:3000/api/health`
> CAPTURA 7: ping y curl exitosos = conectividad PRIVADA entre VPCs.

## FASE 9 - Frontend, DuckDNS y HTTPS (min 43-70)
1. En ec2-frontend: `git clone https://github.com/Raul-T2/zerotrust-lab.git && cd zerotrust-lab`
2. `nano frontend-setup.sh` -> edita **DUCK_TOKEN** (tu token) y **BACKEND_IP** (IP privada del backend). Guarda.
3. `bash frontend-setup.sh` (tarda unos minutos). Debe aparecer "OK" de DuckDNS y `Status for the jail: nginx-login`.
4. En tu PC: `ping raul-zerotrust.duckdns.org` debe mostrar la IP publica de ec2-frontend. Abre http://raul-zerotrust.duckdns.org y prueba el login.
5. Ensayo: `sudo certbot --nginx -d raul-zerotrust.duckdns.org --dry-run`
6. Real (solo cuando el ensayo salga bien): `sudo certbot --nginx -d raul-zerotrust.duckdns.org`
   Cuando pregunte el correo pon el tuyo; acepta los terminos; si ofrece redireccion HTTP->HTTPS elige redirigir.
> CAPTURA 8: salida de certbot.   CAPTURA 9: https://... con el candado y detalles del certificado.
> CAPTURA 10: login y Dashboard en el navegador.
> CAPTURA 11: DevTools (F12) -> Network -> peticion `login` (https) y `dashboard` con el encabezado Authorization: Bearer ... = credenciales y token viajan cifrados.
> CAPTURA 12: Thunder Client / curl: dashboard sin token = 401, con token = 200.

## FASE 10 - Fail2Ban y SecurityHeaders (min 70-85)
1. Antes: `sudo fail2ban-client status nginx-login`   (CAPTURA 13: sin bloqueos)
2. En el navegador, con el sitio HTTPS, intenta login con contrasena incorrecta 3-4 veces.
3. `sudo fail2ban-client status nginx-login`   (CAPTURA 14: aparece tu IP en "Banned IP list")
   Despues del bloqueo el sitio ya no te responde (CAPTURA 15). Para desbloquear: `sudo fail2ban-client set nginx-login unbanip TU_IP`
4. Entra a securityheaders.com, escribe https://raul-zerotrust.duckdns.org y escanea. (CAPTURA 16: resultado con la calificacion)
   Si no sale A: copia aqui los encabezados que faltan y los ajustamos.

## FASE 11 - Cerrar la seguridad y evidencias finales (min 85-90)
1. **Backend privado:** `rt-backend` -> elimina la ruta 0.0.0.0/0. Internet gateways -> igw-backend -> Detach -> (opcional) Delete.
   Quita tambien la regla SSH 22 de sg-backend. Prueba desde tu PC: `curl http://IP_PUBLICA_BACKEND:3000/api/health` -> no responde. (CAPTURA 17)
2. **SSH del frontend:** en sg-frontend cambia SSH 22 de 0.0.0.0/0 a "My IP" (ya no uses el boton Connect despues de esto).
3. Repite CAPTURA 5 (reglas definitivas) y CAPTURA 4 (rutas).
4. Que el backend siga funcionando por el peering: abre otra vez el sitio y entra al Dashboard (CAPTURA 18).

## Despues del lab
- Cada captura necesita su descripcion: que demuestra, que configuracion hiciste y el resultado.
- Todo se borra al reiniciar el lab: guarda capturas y notas en tu PC, no en AWS.
- Regenera tu token de DuckDNS al terminar.
