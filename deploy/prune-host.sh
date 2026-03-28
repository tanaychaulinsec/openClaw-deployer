#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/opt/openclaw"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"
ENV_FILE="${ROOT_DIR}/openclaw.env"
PURGE_DATA="${PURGE_DATA:-0}"

if [[ -f "${COMPOSE_FILE}" && -f "${ENV_FILE}" ]]; then
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" down --remove-orphans || true
fi

docker system prune -af || true

if [[ "${PURGE_DATA}" == "1" ]]; then
  rm -rf /opt/openclaw/home
fi

df -h /

