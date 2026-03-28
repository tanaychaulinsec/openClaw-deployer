#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/opt/openclaw"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"
ENV_FILE="${ROOT_DIR}/openclaw.env"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "Missing ${COMPOSE_FILE}" >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}" >&2
  exit 1
fi

mkdir -p "${ROOT_DIR}/home"

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" pull
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --remove-orphans
docker image prune -af --filter "until=168h" || true

echo
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
echo
df -h /

