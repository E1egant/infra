# infra

Infraestructura de RutaExpress: Docker Compose (RabbitMQ, Kafka KRaft, PostgreSQL, apps), API Gateway (CloudFormation con JWT Authorizer de Azure AD), plantilla ALB, guías de Azure AD y despliegue en EC2.

Responsable: compañero / opencode.

## Contenido

- `docker-compose.base.yml`: red, volúmenes, RabbitMQ y Kafka.
- `docker-compose.apps.yml`: los microservicios y el frontend.
- `api-gateway/`, `ec2/`: plantillas CloudFormation, `deploy.sh`.
- `azure-ad/`: guía de App Registration y MSAL.
- `postgres/`: `init.sql` (una BD por servicio).
- `DESPLIEGUE.md`, `smoke-test.sh`.

## Pendiente tras separar los repos

`docker-compose.apps.yml` y `Dockerfile.service` fueron escritos para el monorepo (`context: ..`, ruta `infra/Dockerfile.service`). Ahora cada servicio vive en su propio repo (`E1egant/ms-rutaexpress-*`, `E1egant/frontend-rutaexpress`), así que hay que cambiar el `build` para que use el repo de cada servicio (por ejemplo `context: https://github.com/E1egant/<repo>.git`, o clonar los repos junto a `infra/` y apuntar a `../<repo>`), y ajustar `deploy.sh` y el CI.

Coordinación entre repos, contratos y reglas: repositorio `Cloud-Native-1`.
