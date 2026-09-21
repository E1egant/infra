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

\`\`\`bash
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# reinstalar sesión SSH para aplicar el grupo docker

sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \\
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
\`\`\`

## 3. Levantar

\`\`\`bash
git clone <repo>
cd Cloud-Native-1/infra
cp .env.example .env   # editar con valores reales
docker compose -f docker-compose.base.yml up -d
\`\`\`

## 4. API Gateway (JWT Authorizer)

- Tipo: **HTTP API** o **REST API** (según caso).
- Authorizer: **JWT** con:
  - Issuer: `https://login.microsoftonline.com/<tenant>/v2.0`
  - Audience: `api://rutaexpress`
- Rutas protegidas → adjuntar el authorizer y reenviar a `ms-rutaexpress-bff` (Fase 5/7).

## 5. Recomendaciones

- Un `.env` distinto por entorno (dev/EC2). Nunca commitear.
- Logs: `docker compose logs -f <servicio>`.
- Backup de `rabbitmq-data` y `kafka-data` con snapshot de volumen.