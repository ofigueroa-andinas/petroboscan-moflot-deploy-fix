# Paso 1
Definir los parámetros como variables de entorno. Ejemplo (reemplazar con los valores reales):
```sh
export MOFLOT_DIR=/home/moflot
export PB_PROXY=http://<proxyuser>:<proxypassword>@<proxy.server.com>:<port>
export GIT_TOKEN=github_pat_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```
Definición:
- `MOFLOT_DIR`: Directorio de instalación donde se encuentran los directorios de los repositorios: `web`, `api`, `async`, `deployment`.
- `PB_PROXY`: Proxy a utilizar. Ejemplo: `http://usuario:contrasenia@proxy.servidor.com:8000`
- `GIT_TOKEN`: Token de acceso personal o contraseña de Github como parte de las credenciales para recuperar los repositorios Git

# Paso 2
1. Descargar el script `deploy-fix.sh` en este repositorio
2. Hacer el archivo ejecutable
3. Ejecutar el script

Ejemplo:
```sh
wget https://raw.githubusercontent.com/ofigueroa-andinas/petroboscan-moflot-deploy-fix/refs/heads/main/deploy-fix.sh
chmod +x deploy-fix.sh
./deploy-fix.sh
```
