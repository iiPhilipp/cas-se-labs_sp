#!/usr/bin/env bash
# Runs once after the codespace is created: make sure Docker can start, then show the tool versions
# so problems are visible early.
set -u

# The docker-in-docker feature selects the legacy iptables backend. Some kernels have no legacy nat
# table, and dockerd then exits on startup. Switch to the nft backend only on those hosts.
fix_docker_iptables() {
  iptables --version | grep -q legacy || return 0
  sudo iptables-legacy -t nat -L -n >/dev/null 2>&1 && return 0
  if ! sudo iptables-nft -t nat -L -n >/dev/null 2>&1; then
    echo "docker: neither iptables backend has a nat table, dockerd cannot start"
    return 0
  fi

  echo "== docker: legacy iptables unavailable, switching to nft =="
  sudo update-alternatives --set iptables /usr/sbin/iptables-nft >/dev/null
  sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-nft >/dev/null

  # The init script from container start may still be retrying and picks up the new backend by
  # itself. Start the daemon here only after it has given up, so the two never compete.
  for _ in $(seq 45); do
    docker info >/dev/null 2>&1 && return 0
    sleep 1
  done
  /usr/local/share/docker-init.sh
}

fix_docker_iptables

echo "== tool versions =="
dotnet --version
terraform version | head -1
az version --query '"azure-cli"' -o tsv
docker --version
func --version 2>/dev/null || echo "func: not installed"
