# infra

Infraestructura de RutaExpress: Docker Compose (RabbitMQ, Kafka KRaft, PostgreSQL, apps), API Gateway (CloudFormation con JWT Authorizer de Azure AD), plantilla ALB, guías de Azure AD y despliegue en EC2.

Responsable: compañero / opencode.

## Layout (repos separados)

Los 9 repos se clonan como hermanos en una misma carpeta (ver `Cloud-Native-1/REPOS.md`).
Todo lo de este repo asume esa estructura (`../ms-rutaexpress-*`, `../frontend-rutaexpress`).

## Contenido

- `docker-compose.base.yml`: red, volúmenes, RabbitMQ (con topología del caso), Kafka y PostgreSQL.
- `docker-compose.apps.yml`: los microservicios y el frontend desde repos hermanos.
- `docker/`: Dockerfiles genéricos (`Dockerfile.jvm`, `Dockerfile.frontend`, `nginx-spa.conf`) para los repos que aún no traen el suyo.
- `rabbitmq/`: `rabbitmq.conf` + `definitions.json` (exchanges, colas, DLQ, bindings) y README.
- `api-gateway/`, `ec2/`: plantillas CloudFormation, `deploy.sh`.
- `azure-ad/`: guía de App Registration y MSAL.
- `postgres/`: `init.sql` (una BD por servicio).
- `DESPLIEGUE.md`, `smoke-test.sh`.

## Perfiles

`docker compose up` usa `prod` (PostgreSQL, sin JWT). Producción: `./ec2/deploy.sh --secure`
(`prod,secure`, JWT obligatorio) con `AZURE_TENANT_ID` y `AZURE_API_AUDIENCE` en `.env`.

Coordinación entre repos, contratos y reglas: repositorio `Cloud-Native-1`.
