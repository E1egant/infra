#!/usr/bin/env bash
#
# Smoke test end-to-end del stack (BFF + microservicios + brokers).
# Requiere el stack levantado. Uso:
#   ./infra/smoke-test.sh
#   BASE_URL=http://<alb-dns>/api/bff TOKEN=<jwt> ./infra/smoke-test.sh   # con perfil secure
#
set -euo pipefail

BASE="${BASE_URL:-http://localhost:8080/api/bff}"
TOKEN="${TOKEN:-}"
AUTH=()
if [[ -n "$TOKEN" ]]; then
  AUTH=(-H "Authorization: Bearer $TOKEN")
fi

say() { printf '\n== %s ==\n' "$1"; }
fail() { echo "FALLO: $1"; exit 1; }

say "Health de servicios"
for port in 8080 8081 8082 8083 8084 8085; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/actuator/health" || true)
  echo "  :$port -> $code"
done

say "Crear envío vía BFF"
CREATE=$(curl -s "${AUTH[@]}" -X POST "$BASE/shipments" \
  -H 'Content-Type: application/json' \
  -d '{"origin":"Bogota","destination":"Medellin","courierId":null,
       "recipient":{"name":"Ana","phone":"300","email":"ana@example.com","address":"Calle 1"},
       "packageInfo":{"weightKg":2.5,"volumeM3":0.01,"description":"caja"}}')
echo "$CREATE"
ID=$(printf '%s' "$CREATE" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
[[ -n "$ID" ]] || fail "no se pudo crear el envío"

say "Listar envíos"
curl -s "${AUTH[@]}" "$BASE/shipments" | head -c 400; echo

say "Cambiar estado a ASSIGNED"
curl -s "${AUTH[@]}" -X PATCH "$BASE/shipments/$ID/status" \
  -H 'Content-Type: application/json' -d '{"status":"ASSIGNED"}' | head -c 300; echo

say "Esperando propagación (Kafka/RabbitMQ)"
sleep 5

say "Auditoría del envío $ID"
curl -s "${AUTH[@]}" "$BASE/audit?shipmentId=$ID" | head -c 400; echo

say "KPIs"
curl -s "${AUTH[@]}" "$BASE/reports/kpis"; echo

say "Notificaciones"
curl -s "${AUTH[@]}" "$BASE/notifications" | head -c 400; echo

echo
echo "Smoke test completado."
