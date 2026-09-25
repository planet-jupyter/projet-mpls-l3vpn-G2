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
