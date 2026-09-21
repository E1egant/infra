# Guía de despliegue — RutaExpress (AWS + Azure)

Paso a paso para llevar la plataforma de local a producción en EC2 con Azure AD como IdP y
AWS API Gateway como front-door del API.

## 0. Topología objetivo

```
                         ┌─────────────── Azure AD (IDaaS) ───────────────┐
                         │  rutaexpress-api (API + App roles)             │
                         │  rutaexpress-spa (SPA + MSAL)                  │
                         └───────────────────────────────────────────────┘
                                        ▲ JWT
Usuario ──► ALB (HTTP :80) ──► EC2 (Docker Compose)
   │           │  /*      ──► frontend nginx :3000  (sirve el SPA)
   │           │  /api/*  ──► BFF :8080 ──► microservicios
   │
   └──► API Gateway (HTTP API + JWT Authorizer) ──► ALB /api/* ──► BFF
```

- **Azure AD**: emite el JWT (scope `api://rutaexpress/access_as_user`) con los roles `Operador`/`Bodega`/`Admin`.
- **API Gateway**: valida el JWT en el borde y enruta `/api/*` al ALB.
- **ALB**: sirve el SPA (`/*`) y enruta el API (`/api/*`) al BFF.
- **EC2**: corre el stack completo con Docker Compose (frontend, 6 servicios, RabbitMQ, Kafka, PostgreSQL).
- Los microservicios también validan el JWT (perfil Spring `secure`): defensa en profundidad.

## 1. Prerrequisitos

- Cuenta de AWS con permisos para EC2, ELBv2, CloudFormation y (opcional) Route 53/ACM.
- **AWS CLI** configurada: `aws configure` (Access Key, Secret, región).
- Un **tenant de Azure AD** (Entra ID) con permisos de administrador de aplicaciones.
- Opcional: **Azure CLI** (`az login`) para automatizar el paso 2.
- Local: `git`.

> Orden recomendado: **2 (Azure) → 3 (EC2) → 4 (ALB) → 5 (API Gateway) → 6 (frontend)**.
> Azure primero porque necesitas el tenant/client IDs para el `.env` y para el authorizer.

## 2. Azure AD (identidad)

### 2.1 App Registration del API (`rutaexpress-api`)

1. **Azure Portal → Microsoft Entra ID → App registrations → New registration**.
   - Nombre: `rutaexpress-api`.
   - Account types: *Single tenant*.
2. Anota **Application (client) ID** y **Directory (tenant) ID**.
3. **Expose an API**:
   - Application ID URI: `api://rutaexpress`.
   - Add a scope: `access_as_user` (Admins and users consent).
4. **App roles** (Create app role), member type *Users/Groups*:
   - `Operador`, `Bodega`, `Admin`.
   - Estos roles llegan en el claim `roles` del token; los servicios los mapean a `ROLE_*`.

### 2.2 App Registration del SPA (`rutaexpress-spa`)

1. **New registration** → nombre `rutaexpress-spa`.
2. Platform: **Single-page application**.
3. Redirect URIs: `http://localhost:3000` (dev) y `http://<alb-dns>` (prod).
4. **API permissions** → Add permission → My APIs → `rutaexpress-api` → scope `access_as_user`.
5. **Grant admin consent**.

### 2.3 Asignar usuarios a roles

En **Entra ID → Enterprise applications → rutaexpress-api → Users and groups**, asigna cada
usuario al rol correspondiente (`Operador`/`Bodega`/`Admin`). Sin asignación, el token no trae roles.

### 2.4 Valores a anotar

| Variable | Valor |
|---|---|
| `AZURE_TENANT_ID` | Directory (tenant) ID |
| `AZURE_CLIENT_ID` | Application (client) ID de **rutaexpress-api** |
| `VITE_AZURE_TENANT_ID` | Igual que `AZURE_TENANT_ID` |
| `VITE_AZURE_CLIENT_ID` | Application (client) ID de **rutaexpress-spa** |
| `VITE_AZURE_API_SCOPE` | `api://rutaexpress/access_as_user` |

## 3. AWS — EC2

### 3.1 Key pair

Crea o usa un key pair existente (`aws ec2 create-key-pair --key-name rutaexpress --query 'KeyMaterial' --output text > rutaexpress.pem`).

### 3.2 Security group del EC2

- **Inbound**: 22 (tu IP). El 8080 y 3000 los abre el ALB (paso 4); no los expongas al mundo.
- **Outbound**: all.

### 3.3 Instancia

- AMI: **Amazon Linux 2023**.
- Tipo: **t3.medium** (mínimo para RabbitMQ + Kafka + microservicios + PostgreSQL).
- Security group: el del paso 3.2.
- (Opcional) IP elástica para que no cambie.

### 3.4 Preparar la instancia

```bash
ssh -i rutaexpress.pem ec2-user@<ec2-ip>

sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
exit   # reconectar para aplicar el grupo docker
```

### 3.5 Clonar y configurar

```bash
git clone <repo-url> Cloud-Native-1
cd Cloud-Native-1
cp infra/.env.example infra/.env
```

Editar `infra/.env`:

```ini
RABBITMQ_USER=rutaexpress
RABBITMQ_PASS=<password-fuerte>
POSTGRES_USER=rutaexpress
POSTGRES_PASSWORD=<password-fuerte>
SPRING_PROFILES_ACTIVE=prod,secure
AZURE_TENANT_ID=<tenant-id>
AZURE_CLIENT_ID=<api-client-id>
```

### 3.6 Levantar

```bash
chmod +x infra/ec2/deploy.sh
./infra/ec2/deploy.sh --secure
```

Verifica: `docker compose -f infra/docker-compose.base.yml -f infra/docker-compose.apps.yml ps`
y el health local: `curl http://localhost:8080/actuator/health`.

## 4. AWS — ALB

Desde tu máquina (con AWS CLI), obtén los IDs necesarios:

```bash
VPC_ID=$(aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].VpcId' --output text)
SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[?MapPublicIpOnLaunch].SubnetId' --output text | tr '\t' ',')
SG_ID=$(aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

aws cloudformation deploy \
  --stack-name rutaexpress-alb \
  --template-file infra/ec2/alb.yml \
  --parameter-overrides \
      VpcId=$VPC_ID \
      PublicSubnetIds=$SUBNETS \
      InstanceId=<instance-id> \
      InstanceSecurityGroupId=$SG_ID
```

Anota el DNS del ALB:

```bash
aws cloudformation describe-stacks --stack-name rutaexpress-alb \
  --query 'Stacks[0].Outputs[?OutputKey==`AlbDnsName`].OutputValue' --output text
```

Comprueba: `curl http://<alb-dns>/` (debe devolver el SPA) y `curl http://<alb-dns>/api/bff/shipments`.

## 5. AWS — API Gateway (JWT Authorizer)

```bash
aws cloudformation deploy \
  --stack-name rutaexpress-api \
  --template-file infra/api-gateway/template.yml \
  --parameter-overrides \
      AzureTenantId=<tenant-id> \
      AzureClientId=<api-client-id> \
      BackendHost=<alb-dns> \
      AllowedOrigin=http://<alb-dns>

aws cloudformation describe-stacks --stack-name rutaexpress-api \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' --output text
```

Prueba (sin token debe dar 401; con token válido, 200):

```bash
curl -i https://<api-endpoint>/api/bff/shipments
```

## 6. Frontend apuntando al API Gateway

Para que el SPA llame al API Gateway (JWT validado en el borde), reconstruye el frontend con:

```ini
# infra/.env
VITE_BFF_URL=https://<api-endpoint>/api/bff
```

y vuelve a levantar:

```bash
./infra/ec2/deploy.sh --secure
```

> Alternativa sin API Gateway en el camino del SPA: dejar `VITE_BFF_URL=/api/bff`
> (mismo origen vía ALB). Los microservicios igual validan el JWT.

## 7. Verificación

```bash
./infra/smoke-test.sh
# con secure:
BASE_URL=https://<api-endpoint>/api/bff TOKEN=<jwt> ./infra/smoke-test.sh
```

Flujo esperado: crear envío → listar → cambiar estado → (Kafka) aparece en Auditoría y sube el KPI →
(RabbitMQ) aparece la Notificación.

## 8. Teardown

```bash
aws cloudformation delete-stack --stack-name rutaexpress-api
aws cloudformation delete-stack --stack-name rutaexpress-alb
# y terminar la instancia EC2 + borrar el key pair
```

## Notas de seguridad / producción

- Restringir el security group del EC2: 22 a tu IP; 3000/8080 solo desde el SG del ALB.
- Para HTTPS: certificado en ACM + listener 443 en el ALB, y dominio en Route 53.
- Los secretos de `infra/.env` no se versionan. En producción, migrar a **AWS Secrets Manager**
  (o SSM Parameter Store) e inyectarlos como variables de entorno en el compose.
- Considerar migrar las bases H2/PostgreSQL locales a **Amazon RDS** para HA y backups.
