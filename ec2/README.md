# Despliegue en EC2

Notas para levantar la plataforma en una instancia EC2 (Fase 7).

## 1. Instancia

- AMI: Amazon Linux 2023.
- Tipo: `t3.medium` (mínimo para RabbitMQ + Kafka + microservicios).
- Security Group:
  - **Inbound**: 22 (tu IP), 80/443 (mundo), 15672 (tu IP, solo admin RabbitMQ).
  - **No exponer**: 5672, 9092, 9093 → quedan en la red interna del compose.
  - **Outbound**: all.

## 2. Preparación

```bash
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# reinstalar sesión SSH para aplicar el grupo docker

sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## 3. Levantar

```bash
git clone <repo>
cd Cloud-Native-1
cp infra/.env.example infra/.env   # editar con valores reales
./infra/ec2/deploy.sh              # brokers + apps + frontend
# o con seguridad JWT obligatoria:
./infra/ec2/deploy.sh --secure
```

El script `infra/ec2/deploy.sh` hace `git pull`, levanta `docker-compose.base.yml` +
`docker-compose.apps.yml` y, con `--secure`, activa el perfil Spring `secure` (JWT obligatorio)
en todos los servicios.

## 4. API Gateway (JWT Authorizer)

La plantilla IaC está en `infra/api-gateway/template.yml` (HTTP API + JWT Authorizer de Azure AD,
ruta `ANY /api/{proxy+}` → BFF). Despliegue:

```bash
aws cloudformation deploy \
  --stack-name rutaexpress-api \
  --template-file infra/api-gateway/template.yml \
  --parameter-overrides \
      AzureTenantId=<tenant> \
      AzureClientId=<client> \
      BackendHost=<ec2-dns> \
      AllowedOrigin=https://<dominio-frontend>
```

Ver `infra/api-gateway/README.md` para detalles.

## 5. Recomendaciones

- Un `.env` distinto por entorno (dev/EC2). Nunca commitear.
- Logs: `docker compose logs -f <servicio>`.
- Backup de `rabbitmq-data` y `kafka-data` con snapshot de volumen.
- En producción, poner un ALB delante del EC2 y restringir el puerto 8080 al security group del ALB/gateway.
