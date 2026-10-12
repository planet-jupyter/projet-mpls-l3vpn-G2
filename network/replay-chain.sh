#!/usr/bin/env bash
# J3a - Reproductibilite : destroy + deploy + rejeu complet + checkup.
# Zero geste manuel sur un equipement : tout passe par ce script.
set -euo pipefail

TOPO="topology-mpls.yml"
ANSIBLE_DIR="ansible"
MAX_ATTEMPTS=24   # 24 x 5s = 2 minutes max

echo "== 1/4 - Destruction complete du lab =="
containerlab destroy -t "$TOPO" --cleanup

echo "== 2/4 - Reconstruction complete du lab =="
containerlab deploy -t "$TOPO" --max-workers 2

cd "$ANSIBLE_DIR"

echo "== 3/4 - Attente que les equipements repondent (show version) =="
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

echo "== 4/4 - Rejeu de la chaine Ansible puis checkup =="
ansible-playbook site.yml
ansible-playbook checkup.yml

echo "== Termine : lab reconstruit, chaine rejouee, checkup lance. =="