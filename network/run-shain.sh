#!/usr/bin/env bash
# Lancement complet
# deploy + rejeu de la chaine + checkup, en une seule commande.
set -euo pipefail

TOPO="topology-mpls.yml"
ANSIBLE_DIR="ansible"
MAX_ATTEMPTS=24   # 24 x 5s = 2 minutes max

echo "== 1/3 - Deploiement du lab =="
containerlab deploy -t "$TOPO" --max-workers 2

cd "$ANSIBLE_DIR"

echo "== 2/3 - Attente que les equipements repondent (show version) =="
attempt=0
until ansible core:pe:ce -m arista.eos.eos_command -a "commands='show version'" > /dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
    echo "ERREUR : les equipements ne repondent pas apres $((MAX_ATTEMPTS * 5))s"
    exit 1
  fi
  sleep 5
done
echo "  Tous les equipements repondent."

echo "== 3/3 - Rejeu de la chaine Ansible puis checkup =="
ansible-playbook site.yml
ansible-playbook checkup.yml

echo "== Termine : lab deploye, chaine jouee, checkup lance. =="