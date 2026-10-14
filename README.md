# projet-mpls-l3vpn-G2

# Network


## Jalon 1 — Le lab existe

### Objectif

Déployer la topologie MPLS dans Containerlab avec **13 conteneurs actifs** :

* **9 cEOS** : 2 P, 3 PE et 4 CE
* **4 hôtes Linux**

### Topologie

La topologie est entièrement décrite dans le fichier :

```text
typology-mpls
```

Le réseau de management utilise le sous-réseau :

```text
172.20.20.0/24
```

### Déploiement

Déployer le lab :

```bash
containerlab deploy -t topology-mpls.yml --max-workers 2
```

Vérifier les conteneurs :

```bash
containerlab inspect -t topology-mpls.yml
```

Vérifier également avec Docker :

```bash
docker ps
```

### Management des équipements Arista

Les 9 nœuds Arista sont accessibles via le réseau de management :

| Équipement | Adresse de management |
| ---------- | --------------------- |
| p1         | 172.20.20.11          |
| p2         | 172.20.20.12          |
| pe1        | 172.20.20.21          |
| pe2        | 172.20.20.22          |
| pe3        | 172.20.20.23          |
| ce1        | 172.20.20.31          |
| ce2        | 172.20.20.32          |
| ce3        | 172.20.20.33          |
| ce4        | 172.20.20.34          |

### Vérification de la version EOS

Exemple sur `p1` :

```bash
docker exec -it clab-mpls-tp-g2-p1 Cli
```

Puis :

```text
show version
```

Version EOS relevée : `4.36.1F`

### Destruction et reconstruction

Détruire entièrement le lab :

```bash
containerlab destroy -t topology-mpls.yml
```

Reconstruire le lab :

```bash
containerlab deploy -t topology-mpls.yml
```

### Validation

* [x] Fichier de topologie versionné
* [x] 13 conteneurs actifs
* [x] 9 cEOS + 4 hôtes Linux
* [x] Management des 9 équipements Arista
* [x] Version EOS relevée
* [x] Destruction complète du lab
* [x] Reconstruction complète du lab



## J2 - Le service tourne


### Pre-requis

```bash
pip install --break-system-packages ansible
ansible-galaxy collection install -r requirements.yml
```

L'inventaire n'est PAS ecrit a la main : il est genere par containerlab au
moment du `deploy`, dans `../clab-mpls-tp-g2/ansible-inventory.yml`. C'est ce
fichier que `ansible.cfg` pointe.

Verifie apres le deploy que les groupes existent bien :

```bash
cat ../clab-mpls-tp-g2/ansible-inventory.yml
```

 les groupes `core`, `pe`, `ce`, `host` (issus des labels
`ansible-group` du fichier .clab.yml), en plus des groupes automatiques
`ceos` et `linux`.

### graph ansible

```bash
ansible-inventory -i ansible-inventory.yml --graph
```
### Lancer la chaine complete

```bash
cd ansible
ansible-playbook site.yml
```

Cela joue dans l'ordre : coeur -> plan de controle VPN -> VRF/PE-CE -> CE.
Si une couche echoue (any_errors_fatal), les couches suivantes ne sont pas
jouees.

### Lancer une seule couche

```bash
ansible-playbook 01-core.yml
```

### Lancer le checkup

```bash
ansible-playbook checkup.yml
```

4 barreaux dans l'ordre : sous-jacent (OSPF/LDP) -> plan de controle
(BGP VPNv4) -> plan de donnees (LFIB MPLS + routes VRF) -> trafic
(ping inter-sites + test d'etancheite).

Les playbooks activent `ip routing` sur les routeurs P, PE et CE. Sur les
routeurs P et PE, MPLS doit aussi être activé globalement (`mpls ip`) et sur
chaque interface coeur (`mpls ip` et `mpls ldp interface`), en plus du
processus LDP. LDP utilise Loopback0 comme router-id et adresse de transport.

### Vérifier les couches MPLS L3VPN

### Accès au CLI pour un routeur

```bash
docker exec -it clab-mpls-tp-g2-p2 Cli
```
### Accès au CLI pour un host

```bash
docker exec -it clab-mpls-tp-g2-host-a1 sh
docker exec -it clab-mpls-tp-g2-host-a2 sh
docker exec -it clab-mpls-tp-g2-host-b1 sh
docker exec -it clab-mpls-tp-g2-host-b2 sh
```
### Pings entre les hosts

Depuis `host-a1` (`192.168.11.10`) :

```bash
docker exec clab-mpls-tp-g2-host-a1 ping -c 2 -W 1 192.168.12.10  # host-a2 : OK
docker exec clab-mpls-tp-g2-host-a1 ping -c 2 -W 1 192.168.21.10  # host-b1 : bloque
docker exec clab-mpls-tp-g2-host-a1 ping -c 2 -W 1 192.168.22.10  # host-b2 : bloque
```

Depuis `host-a2` (`192.168.12.10`) :

```bash
docker exec clab-mpls-tp-g2-host-a2 ping -c 2 -W 1 192.168.11.10  # host-a1 : OK
docker exec clab-mpls-tp-g2-host-a2 ping -c 2 -W 1 192.168.21.10  # host-b1 : bloque
docker exec clab-mpls-tp-g2-host-a2 ping -c 2 -W 1 192.168.22.10  # host-b2 : bloque
```

Depuis `host-b1` (`192.168.21.10`) :

```bash
docker exec clab-mpls-tp-g2-host-b1 ping -c 2 -W 1 192.168.22.10  # host-b2 : OK
docker exec clab-mpls-tp-g2-host-b1 ping -c 2 -W 1 192.168.11.10  # host-a1 : bloque
docker exec clab-mpls-tp-g2-host-b1 ping -c 2 -W 1 192.168.12.10  # host-a2 : bloque
```

Depuis `host-b2` (`192.168.22.10`) :

```bash
docker exec clab-mpls-tp-g2-host-b2 ping -c 2 -W 1 192.168.21.10  # host-b1 : OK
docker exec clab-mpls-tp-g2-host-b2 ping -c 2 -W 1 192.168.11.10  # host-a1 : bloque
docker exec clab-mpls-tp-g2-host-b2 ping -c 2 -W 1 192.168.12.10  # host-a2 : bloque
```

### OSPF — P et PE

```bash
show ip interface brief
show ip ospf neighbor
show ip route ospf
```

### LDP — P et PE

```bash
show mpls ldp neighbor
show mpls ldp interface
show mpls ldp bindings (labels)
show mpls lfib route (actions)
```

### MP-BGP VPNv4 — P1 et PE

```bash
show bgp vpn-ipv4 summary
show bgp vpn-ipv4
show bgp vpn-ipv4 detail (labels)
```

### VRF et routes — PE

```bash
show ip route vrf TENANT_1
show ip route vrf TENANT_2
```

### BGP PE-CE — PE

```bash
show ip bgp vrf TENANT_1 summary
show ip bgp vrf TENANT_2 summary
```

### BGP PE-CE — CE

```bash
show ip bgp summary
show ip route bgp
```

### Transfert MPLS — P

```bash
show mpls route
show mpls ldp bindings
```

### Ping inter-sites — terminal Linux

```bash
docker exec clab-mpls-tp-g2-host-a1 ping -c 2 192.168.12.10
docker exec clab-mpls-tp-g2-host-b1 ping -c 2 192.168.22.10
```

### Vérification complète — dossier `network/ansible`

```bash
ansible-playbook checkup.yml
```

### Ce que fait chaque fichier

| Fichier | Role |
|---|---|
| `requirements.yml` | Declare la dependance a la collection `arista.eos` |
| `ansible.cfg` | Pointe vers l'inventaire genere, desactive host_key_checking |
| `group_vars/all.yml` | Connexion eAPI (httpapi, port 443) et mode privilegie `enable` pour les cEOS |
| `group_vars/core.yml`, `pe.yml`, `ce.yml`, `host.yml` | Variables communes a un groupe |
| `host_vars/*.yml` | Ce qui varie par equipement : loopback, interfaces, VRF, RD/RT, AS |
| `ansible/01-core.yml` | Loopback, interfaces coeur, OSPF, LDP — via `eos_config: lines/parents` |
| `02-vpn-control-plane.yml` | iBGP VPNv4, p1 en route reflector — via `eos_config: lines/parents` |
| `03-vrf-pe-ce.yml` | VRF, RD/RT, interface cliente, eBGP PE-CE — via `eos_config: lines/parents` |
| `ansible/04-ce.yml` | Interfaces + eBGP vers le PE — via `eos_config: lines/parents` |
| `ansible/site.yml` | Enchaine les 4 couches |
| `ansible/checkup.yml` | Verifie les 4 couches, s'arrete au premier barreau casse |


## Jalon J3a — Reproductibilité

### Objectif

Prouver que le lab, détruit intégralement puis reconstruit, revient au même état fonctionnel, sans aucun geste manuel sur un équipement. Aucun nouvel outil : c'est une propriété de J1 (containerlab) et J2 (Ansible).

### Procédure

Destruction complète :

```bash
containerlab destroy -t topology-mpls.yml --cleanup
```

Reconstruction complète :

```bash
containerlab deploy -t topology-mpls.yml --max-workers 2
```

Rejeu complet de la chaîne Ansible, dans l'ordre (cœur → plan de contrôle VPN → VRF/PE-CE → CE) :

```bash
cd ansible
ansible-playbook site.yml
```

Checkup final :

```bash
ansible-playbook checkup.yml
```

### Script de rejeu

L'ensemble (destroy + deploy + attente eAPI + site.yml + checkup.yml) est rejoué en une seule commande, sans étape manuelle entre temps :

```bash
 bash replay-chain.sh
```

### Résultat attendu

- Les 13 conteneurs repartent de zéro (`containerlab inspect`).
- Les 4 playbooks de `site.yml` passent sans intervention manuelle sur un équipement.
- `checkup.yml` finit vert sur les 4 barreaux : sous-jacent, plan de contrôle, plan de données, trafic.
- Les pings inter-sites et le test d'étanchéité redonnent le même résultat qu'au premier déploiement.

### Validation

* [ ] `destroy` puis `deploy` joués en direct
* [ ] Rejeu complet de `site.yml`, sans commande tapée à la main sur un routeur
* [ ] `checkup.yml` vert sur les 4 barreaux à l'arrivée
* [ ] Même comportement de trafic qu'au déploiement initial (pings OK/bloqués identiques)



## Jalon J3b — Idempotence

### Objectif

Prouver que rejouer la chaîne Ansible sur un lab **déjà configuré** ne change rien. Aucun nouvel outil : propriété distincte de J3a, à démontrer et à nommer séparément.

### Procédure

Rejouer la chaîne complète sur le lab déjà configuré, sans détruire ni redéployer :

```bash
cd ansible
ansible-playbook site.yml
```

### Signal mesurable : `changed=0`

À la fin de l'exécution, le `PLAY RECAP` doit afficher `changed=0` sur chaque équipement 



Ce signal se nomme **l'idempotence** : rejouer la même chaîne sur un état déjà conforme ne produit aucun effet de bord, qu'on la joue une fois ou cent fois.

### Idempotence ≠ conformité

Ce sont deux notions distinctes :

| Notion | Ce qu'elle garantit |
|---|---|
| **Idempotence** | Rejouer ne modifie rien (`changed=0`) |
| **Conformité** | L'équipement correspond exactement aux fichiers versionnés |

Une ligne posée à la main sur un équipement, en dehors des fichiers Ansible, **n'est jamais retirée** par un rejeu : Ansible ne gère que ce qu'il connaît dans ses propres variables, il ne nettoie pas ce qui existe en dehors.

### Démonstration de la distinction

Ajouter une ligne à la main, hors de tout fichier versionné :
```bash
    docker exec -it clab-mpls-tp-g2-ce1 Cli
    enable
    configure
    interface Ethernet2
    description Lien vers le routeur Internet
    end
    write
```

Rejouer la chaîne :
```bash
    ansible-playbook site.yml
```
Constater que :
- `changed=0` reste vrai sur ce1 pour les tâches gérées par Ansible → **idempotent**.
- La ligne manuelle est toujours présente après le rejeu → **non conforme**, car absente de `host_vars/ce1.yml`.

Vérification :
```bash
    docker exec clab-mpls-tp-g2-ce1 Cli -c "show running-config interfaces Ethernet2"
```
### Validation

* [ ] Second passage complet de `site.yml` sur lab déjà configuré, sans destruction
* [ ] `changed=0` sur les 9 équipements, signal identifié et nommé (idempotence)
* [ ] Démonstration qu'une ligne posée à la main n'est pas retirée par un rejeu
* [ ] Distinction expliquée entre idempotence (rejouer ne change rien) et conformité (l'équipement correspond aux fichiers)



# Observability

## Jalon O1 — Collecte de télémétrie gNMI

### Objectif

Déployer un collecteur **gnmic** sur VM Tools qui se connecte aux 9 routeurs Arista via le protocole gNMI et expose les métriques en temps réel sur un endpoint Prometheus.

### Architecture

Routeurs Arista (gNMI :6030) → gnmic (collecteur :9804) → Prometheus → Grafana


### Protocole gNMI

gNMI (gRPC Network Management Interface) est le protocole natif d'Arista EOS pour la télémétrie réseau. Il est exposé par défaut sur le **port 6030** de chaque routeur. Rien n'est installé sur les équipements — gnmic est uniquement installé sur la VM Tools.

Le mode choisi est **stream / sample** : les routeurs envoient automatiquement leurs données toutes les **10 secondes**.

### Données collectées

| Chemin | Données |
| ------ | ------- |
| `/interfaces/interface/state/counters` | Compteurs de trafic (octets, paquets, erreurs) |
| `/interfaces/interface/state/oper-status` | État opérationnel des interfaces (up/down) |




### Vérification gNMI — test direct

Vérifier que gNMI répond sur un routeur :

```bash
gnmic -a 172.20.20.21:6030 -u admin -p admin --insecure capabilities
```

Consulter les métriques d'interface en direct sur pe1 :

```bash
gnmic -a 172.20.20.21:6030 -u admin -p admin --insecure \
  get --path /interfaces/interface/state/counters
```

### Cibles — Routeurs Arista

| Équipement | Adresse gNMI |
| ---------- | ------------ |
| p1  | 172.20.20.11:6030 |
| p2  | 172.20.20.12:6030 |
| pe1 | 172.20.20.21:6030 |
| pe2 | 172.20.20.22:6030 |
| pe3 | 172.20.20.23:6030 |
| ce1 | 172.20.20.31:6030 |
| ce2 | 172.20.20.32:6030 |
| ce3 | 172.20.20.33:6030 |
| ce4 | 172.20.20.34:6030 |

### Prérequis réseau

Les routeurs tournent sur la VM Lab (10.200.2.120). Pour que la VM Tools puisse les joindre :

```bash
sudo ip route add 172.20.20.0/24 via 10.200.2.120
```



### Installation de gnmic

```bash
bash -c "$(curl -sL https://get-gnmic.openconfig.net)"
gnmic version
```

Version installée : `0.49.0`

### Configuration

Fichier : `observability/gnmic/gnmic.yml`

### Service systemd

Fichier de service : `observability/systemd/gnmic.service`

```bash
sudo systemctl daemon-reload
sudo systemctl enable gnmic
sudo systemctl start gnmic
sudo systemctl status gnmic
```

### Journalisation

```bash
journalctl -u gnmic -f
```

### Vérification de l'endpoint

```bash
curl http://localhost:9804/metrics | grep "in_octets"
```

Afficher les métriques en temps réel (rafraîchissement toutes les 2 secondes) :

```bash
watch -n 2 'curl -s http://localhost:9804/metrics | grep "in_octets"'
```

### Validation

* [x] gnmic installé (v0.49.0)
* [x] Fichier de configuration versionné (`observability/gnmic/gnmic.yml`)
* [x] Fichier service versionné (`observability/systemd/gnmic.service`)
* [x] Route réseau configurée vers 172.20.20.0/24 via VM Lab
* [x] gNMI activé sur les 9 routeurs Arista
* [x] Service systemd actif et activé au démarrage
* [x] Endpoint Prometheus exposé sur `:9804/metrics`

---
## Jalon O2 — Stockage avec Prometheus

### Objectif

Déployer **Prometheus** via Docker Compose pour scraper les métriques gnmic et les stocker dans le temps.

### Fichiers

docker-compose.yml` 
prometheus.yml` 

### Démarrage

```bash
cd observability
docker compose up -d
docker ps
```

### Vérification

Ouvrir : `http://localhost:9090`

Aller dans **Status → Targets** → le target `gnmic` doit être en état **UP**.

```bash
curl -s "http://localhost:9090/api/v1/query?query=interfaces_interface_state_counters_out_unicast_pkts" \
  | python3 -m json.tool | grep value
```

### Requêtes PromQL utiles

> gnmic convertit les chemins gNMI en noms Prometheus en remplaçant `/` et `-` par `_`.  
> Exemple : `out-unicast-pkts` → `out_unicast_pkts`

| Objectif | Requête |
|----------|---------|
| Toutes les interfaces | `interfaces_interface_state_counters_out_unicast_pkts` |
| Filtrer par interface | `interfaces_interface_state_counters_out_unicast_pkts{interface_name="Management0"}` |
| Routeurs PE uniquement | `interfaces_interface_state_counters_out_unicast_pkts{source=~"pe.*"}` |
| Trafic entrant | `interfaces_interface_state_counters_in_unicast_pkts` |
| Toutes les métriques | `{subscription_name="interfaces"}` |

### Observations

- Interfaces **Ethernet** → `0` : pas de trafic unicast, uniquement du multicast (OSPF, LDP)
- Interface **Management0** → valeurs croissantes : trafic de gestion actif
- Légère différence entre un `curl` direct sur le routeur et Prometheus : normal, scrape toutes les 15s

### Validation

* [x] Docker Compose versionné (`observability/docker-compose.yml`)
* [x] Configuration Prometheus versionnée (`observability/prometheus/prometheus.yml`)
* [x] Conteneur Prometheus actif (`prom/prometheus:v2.53.0`)
* [x] Target gnmic en état **UP** dans Prometheus
* [x] Métriques visibles dans l'interface Graph
* [x] Données enregistrées dans le temps (courbe visible)



## Jalon O3 — Visualisation avec Grafana

> 🚧 En cours




