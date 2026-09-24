#!/usr/bin/env bash
#
# Despliegue de RutaExpress con repos hermanos (ver Cloud-Native-1/REPOS.md).
# Uso (desde infra/):
#   ./ec2/deploy.sh              # prod (PostgreSQL, sin JWT)
#   ./ec2/deploy.sh --secure     # prod,secure (JWT obligatorio; producción)
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."  # -> infra/
BASE_DIR="$(pwd)/.."

for r in ms-rutaexpress-shipments ms-rutaexpress-catalog ms-rutaexpress-notify \
         ms-rutaexpress-report ms-rutaexpress-audit ms-rutaexpress-bff frontend-rutaexpress; do
  [[ -d "$BASE_DIR/$r" ]] || { echo "falta $BASE_DIR/$r: clónalo al lado de infra/"; exit 1; }
done

[[ -f .env ]] || { cp .env.example .env; echo "Se creó .env: complétalo y vuelve a ejecutar."; exit 1; }

# shellcheck disable=SC1091
set -a; source .env; set +a
export SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-prod}"
if [[ "${1:-}" == "--secure" ]]; then
  export SPRING_PROFILES_ACTIVE="prod,secure"
fi
if [[ "$SPRING_PROFILES_ACTIVE" == *secure* ]]; then
  [[ -n "${AZURE_TENANT_ID:-}" && -n "${AZURE_API_AUDIENCE:-}" ]] \
    || { echo "Con perfil secure define AZURE_TENANT_ID y AZURE_API_AUDIENCE en .env"; exit 1; }
fi

docker compose -f docker-compose.base.yml -f docker-compose.apps.yml up -d --build
docker compose -f docker-compose.base.yml -f docker-compose.apps.yml ps
