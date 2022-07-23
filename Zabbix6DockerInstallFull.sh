# SCRIPT PARA DEPLOY DA SOLUÇÃO DE MAPAS DA TELIC
#AUTOR: Franco Ferraciolli 
#!/bin/bash
echo "Por favor insira o nome do Monitorando, entre aspas duplas: "
read NOMEZBX

apt -y remove docker docker-engine docker.io containerd runc 
apt-get -qq update -y

# Instalação das dependencias 
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Instalação das chaves
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
 
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
 
# Instalação do Deamon do Docker
apt-get -qq update -y
apt-get -qq install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y


#Confirma o sucesso da instalação
systemctl status docker
sleep 6

## Criação da Network
docker network create --subnet 172.20.0.0/16 --ip-range 172.20.240.0/20 zabbix-net

## Criação do banco de dados
docker run --name mysql-server -t \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix" \
      -e MYSQL_ROOT_PASSWORD="t3lic1330" \
      --network=zabbix-net \
      -d mysql:8.0 \
      --character-set-server=utf8 --collation-server=utf8_bin \
      --default-authentication-plugin=mysql_native_password
	  
	  
## Criação do java-gateway	  
docker run --name zabbix-java-gateway -t \
      --network=zabbix-net \
      --restart unless-stopped \
      -d zabbix/zabbix-java-gateway:alpine-6.2-latest
	  
## Criação do Deamon do Zabbix-server
docker run --name zabbix-server-mysql -t \
      -e DB_SERVER_HOST="mysql-server" \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix" \
	  -e ZBX_VALUECACHESIZE="16M" \
	  -e ZBX_CACHESIZE="64M" \
	  -e ZBX_STARTPINGERS="6" \
      -e MYSQL_ROOT_PASSWORD="t3lic1330" \
      -e ZBX_JAVAGATEWAY="zabbix-java-gateway" \
      --network=zabbix-net \
      -p 10051:10051 \
      --restart unless-stopped \
      -d zabbix/zabbix-server-mysql:ubuntu-6.2-latest
	  
## Criação do front-end
docker run --name zabbix-web-nginx-mysql -t \
      -e ZBX_SERVER_HOST="zabbix-server-mysql" \
      -e DB_SERVER_HOST="mysql-server" \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix" \
      -e MYSQL_ROOT_PASSWORD="t3lic1330" \
	  -e PHP_TZ="America/Sao_Paulo" \
	  -e ZBX_SERVER_NAME=$NOMEZBX \
	  -e ZBX_MEMORYLIMIT="256M" \
	  -e ZBX_UPLOADMAXFILESIZE="20M" \
	  -e ZBX_POSTMAXSIZE="40M" \
      --network=zabbix-net \
      -p 80:8080 \
      --restart unless-stopped \
      -d zabbix/zabbix-web-nginx-mysql:ubuntu-6.2-latest
	  
	  
# Confirma se os containers estão rodando
docker ps --all