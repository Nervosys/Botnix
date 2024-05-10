#!/usr/bin/env bash

set -euo pipefail

ip46tables() {
  iptables -w "$@"
  ip6tables -w "$@"

}

show_help() {
    echo "botnix-firewall-tool"
    echo ""
    echo "Can temporarily manipulate the Botnix firewall"
    echo ""
    echo "Open TCP port:"
    echo " botnix-firewall-tool open tcp 8888"
    echo ""
    echo "Show all firewall rules:"
    echo " botnix-firewall-tool show"
    echo ""
    echo "Open UDP port:"
    echo " botnix-firewall-tool open udp 51820"
    echo ""
    echo "Reset firewall configuration to system settings:"
    echo " botnix-firewall-tool reset"
}

if [[ -z ${1+x} ]]; then
  show_help
  exit 1
fi

case $1 in
  "open")
    protocol="$2"
    port="$3"

    ip46tables -I botnix-fw -p "$protocol" --dport "$port" -j botnix-fw-accept
  ;;
  "show")
    ip46tables --numeric --list botnix-fw
  ;;
  "reset")
    systemctl restart firewall.service
  ;;
  -h|--help|help)
    show_help
    exit 0
  ;;
  *)
    show_help
    exit 1
  ;;
esac
