#!/usr/bin/env bash
#
# Despliegue de RutaExpress en EC2 (Amazon Linux 2023).
#
# Uso:
#   ./deploy.sh              # sin seguridad (perfil dev)
#   ./deploy.sh --secure     # con JWT obligatorio (perfil Spring "secure")
#
# Requisitos: docker + docker compose instalados, repo clonado, infra/.env presente.

set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/Cloud-Native-1}"
COMPOSE_FILES=(-f infra/docker-compose.base.yml -f infra/docker-compose.apps.yml)

cd "$REPO_DIR"

if [[ ! -f infra/.env ]]; then
  cp infra/.env.example infra/.env
  echo "Se creó infra/.env a partir del ejemplo. Edítalo (brokers, Azure AD) y vuelve a ejecutar."
  exit 1
fi

if [[ "${1:-}" == "--secure" ]]; then
  # shellcheck disable=SC1091
  set -a; source infra/.env; set +a
  export SPRING_PROFILES_ACTIVE="prod,secure"
  if [[ -z "${AZURE_TENANT_ID:-}" || -z "${AZURE_CLIENT_ID:-}" ]]; then
    echo "Para --secure, define AZURE_TENANT_ID y AZURE_CLIENT_ID en infra/.env"
    exit 1
  fi
fi

git pull --ff-only

docker compose "${COMPOSE_FILES[@]}" up -d --build
docker compose "${COMPOSE_FILES[@]}" ps
