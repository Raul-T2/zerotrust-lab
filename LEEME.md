# Lab Zero Trust - guia rapida (Ubuntu 22.04)

Contenido:
- `frontend-setup.sh`      -> se ejecuta en la EC2 del FRONTEND (VPC 1)
- `backend/backend-setup.sh` -> se ejecuta en la EC2 del BACKEND (VPC 2)
- `nginx/zerotrust.conf`   -> la usa frontend-setup.sh (encabezados + proxy a la IP privada)
- `fail2ban/`              -> filtro y jail que usa frontend-setup.sh

## HOY, antes del lab
1. Subdominio y token de DuckDNS anotados (NO en GitHub).
2. Tus 2 repos en GitHub funcionando (ya los tienes) y sus URLs a la mano.
3. En un archivo local de notas, la tabla de datos que iras llenando en el lab:
   - CIDR VPC1 / VPC2, ID del peering (pcx-...), IP privada y publica del frontend, IP privada del backend.
4. Abre estos archivos en VS Code y lee cada uno una vez para saber que hace.

## EN EL LAB (orden sugerido)
1. Consola AWS: crear VPC1 (10.0.0.0/25) y VPC2 (CIDR sin traslape), una subred en cada una.
2. VPC1: Internet Gateway + ruta 0.0.0.0/0 al IGW.
3. VPC Peering VPC1 <-> VPC2, aceptarlo, y agregar la ruta del CIDR de la otra VPC en AMBAS tablas de rutas.
4. Security Groups:
   - Frontend: 80 y 443 desde 0.0.0.0/0; 22 solo desde tu IP.
   - Backend: 3000 desde el CIDR de VPC1; 22 desde el CIDR de VPC1 (y desde tu IP solo durante la instalacion).
5. Lanzar 2 EC2 Ubuntu 22.04 (frontend en VPC1 con IP publica, backend en VPC2).
6. BACKEND: el backend necesita internet SOLO para instalar. Opcion simple: agregar temporalmente un IGW a VPC2,
   ruta 0.0.0.0/0 y IP publica; ejecutar `backend-setup.sh`; al terminar, QUITAR la ruta 0.0.0.0/0 y la IP publica.
   (Pregunta al profesor como prefiere que se haga.)
7. Probar entre VPCs desde el frontend:  `curl http://IP_PRIVADA_BACKEND:3000/api/health`   <- evidencia del peering
8. FRONTEND: edita CONFIG y ejecuta `bash frontend-setup.sh`.
9. Certbot: primero `--dry-run`; el certificado real solo cuando vayas a tomar las evidencias.
10. SecurityHeaders.com: escanea https://TU_DOMINIO y captura el resultado.
11. Fail2Ban: 3 logins fallidos desde la pagina -> la 4a peticion ya no responde. Captura:
    `sudo fail2ban-client status nginx-login`

## Comandos utiles
- Ver baneados:      sudo fail2ban-client status nginx-login
- Desbloquear IP:    sudo fail2ban-client set nginx-login unbanip TU_IP
- Probar el filtro:  sudo fail2ban-regex /var/log/nginx/access.log /etc/fail2ban/filter.d/nginx-login.conf
- Logs de nginx:     sudo tail -f /var/log/nginx/access.log
- Backend:           sudo systemctl status zerotrust-backend   |   journalctl -u zerotrust-backend -f
- Reaplicar nginx:   sudo nginx -t && sudo systemctl reload nginx

## Si algo falla
- Certbot dice que no valida: revisa que el SG tenga el puerto 80 abierto y que `ping DOMINIO` muestre la IP publica NUEVA.
- 502 Bad Gateway: el backend no responde; revisa SG del backend, la ruta del peering y `BACKEND_IP` en nginx.
- Te bloqueaste tu propia IP con Fail2Ban: usa `unbanip` desde otra sesion SSH o espera 10 minutos.
