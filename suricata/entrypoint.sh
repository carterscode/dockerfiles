#!/usr/bin/env bash
set -euo pipefail

# Defaults (override with env)
IFACE="${SURICATA_IFACE:-${IFACE:-eth0}}"
CONFIG="${CONFIG:-/etc/suricata/suricata.yaml}"
OPTS="${SURICATA_OPTS:-}"
RUN_UPDATE="${RUN_RULE_UPDATE:-true}"      # set true to update rules on boot

echo "[INFO] Suricata starting on iface=${IFACE} config=${CONFIG}"

# Ensure runtime paths exist (important if mounted volumes are empty)
mkdir -p /var/log/suricata /var/run/suricata /var/lib/suricata/rules

# If running as a non-root user, these help avoid socket/log permission issues.
# Comment out if you prefer strict ownership from the host.
chown -R "$(id -u)":"$(id -g)" \
  /var/log/suricata /var/run/suricata /var/lib/suricata || true

# Optional: update rules on start (keeps container self-sufficient)
if [[ "${RUN_UPDATE}" == "true" ]]; then
  echo "[INFO] Running suricata-update..."
  # --no-test avoids trying to start Suricata during update
  suricata-update --suricata-conf "${CONFIG}" --no-test || {
    echo "[WARN] suricata-update failed; continuing without update"
  }
fi

# Strong defaults: fail hard on init errors; let YAML select AF_PACKET
exec suricata \
  -i "${IFACE}" \
  -c "${CONFIG}" \
  --init-errors-fatal \
  ${OPTS}

