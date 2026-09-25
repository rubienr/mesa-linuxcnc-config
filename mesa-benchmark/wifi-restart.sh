#!/usr/bin/env bash
set -euo pipefail

wifi_interface="${WIFI_INTERFACE:-wlp2s0}"
wifi_connection="${WIFI_CONNECTION_NAME:?Set WIFI_CONNECTION_NAME to the NetworkManager connection name}"

nmcli device disconnect "$wifi_interface"
sleep 15
nmcli connection up "$wifi_connection" ifname "$wifi_interface"
