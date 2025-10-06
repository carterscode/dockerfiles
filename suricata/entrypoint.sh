#!/bin/bash
set -e

# Default interface (can be overridden)
IFACE=${IFACE:-eth0}
CONFIG=${CONFIG:-/etc/suricata/suricata.yaml}

echo "[INFO] Starting Suricata on $IFACE with config $CONFIG"
exec suricata -i "$IFACE" -c "$CONFIG" --af-packet
