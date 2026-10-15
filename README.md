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



## Jalon 2 - Le service tourne


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
show ip bgp summary vrf TENANT_1
show ip bgp summary vrf TENANT_2
show ip bgp vrf TENANT_1 (table bgp avec next hop)
show ip bgp vrf TENANT_2 
```

### E-BGP PE-CE — CE

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


## Jalon J4 — La configuration est un artefact

### Objectif

La configuration voulue d'un équipement existe comme un texte qu'on peut regarder, indépendamment de son application. Les couches de J2 (cœur, plan de contrôle VPN, VRF/PE-CE, CE) sont reconstruites avec des gabarits Jinja2 au lieu de `lines`/`parents`, sans toucher au checkup.

### Gabarits Jinja2

La structure de la configuration est portée par 4 fichiers, dans `templates/` :

| Gabarit | Couche | Utilisé par |
|---|---|---|
| `core.j2` | Loopback, interfaces cœur, OSPF, LDP | `01-core.yml` |
| `vpn_control_plane.j2` | iBGP VPNv4, p1 en route reflector | `02-vpn-control-plane.yml` |
| `vrf_pe.j2` | VRF, RD/RT, interface cliente, eBGP PE-CE | `03-vrf-pe-ce.yml` |
| `ce.j2` | Interfaces + eBGP vers le PE | `04-ce.yml` |

Chaque playbook est réduit à une seule tâche :

```yaml
- name: Pousser la config coeur (loopback + interfaces + OSPF + LDP)
  arista.eos.eos_config:
    src: templates/core.j2
```

### Données séparées

Rien ne change ici par rapport à J2 : `group_vars/` et `host_vars/` portent toujours ce qui varie d'un équipement à l'autre (loopback, interfaces, VRF, RD/RT, AS). Les gabarits lisent ces mêmes variables, ils ne les redéfinissent pas.

### Afficher le rendu d'un gabarit sans l'appliquer

Le module `template` (au lieu de `eos_config`) et l'option `-c local` permettent de générer le texte d'une configuration sans ouvrir aucune connexion vers l'équipement.

Exemple pour ce3 :

```bash
ansible clab-mpls-tp-g2-ce3 -m template -a "src=templates/ce.j2 dest=tmp/ce3.txt" -c local
```

Lire le résultat :

```bash
cat /tmp/ce3.txt
```

Le fichier `/tmp/ce3.txt` est écrit **sur la machine locale**, jamais sur l'équipement. `changed: true` signifie que le fichier local a été créé, pas qu'une config a été poussée sur ce3.

Même principe pour n'importe quel équipement et n'importe quel gabarit, par exemple : pe1

```bash
ansible clab-mpls-tp-g2-pe1 -m template -a "src=templates/vrf_pe_ce.j2 dest=tmp/pe1-vrf.txt" -c local
```

### Contrainte forte : checkup.yml non modifié

`checkup.yml` n'a reçu aucune modification depuis J2. Preuve par l'historique Git :

```bash
git log --follow -- ansible/checkup.yml
```

Les commits affichés s'arrêtent à J2 ; aucun commit lié aux gabarits de J4 ne touche ce fichier.

### Validation

* [ ] 4 gabarits Jinja2 écrits (`core.j2`, `vpn_control_plane.j2`, `vrf_pe.j2`, `ce.j2`)
* [ ] Les 4 playbooks (`01` à `04`) utilisent `src:` au lieu de `lines`/`parents`
* [ ] `host_vars/` et `group_vars/` inchangés depuis J2
* [ ] Rejeu de `site.yml` sur lab déjà configuré → `changed=0` partout (preuve que les gabarits produisent le même résultat qu'avant)
* [ ] Rendu d'un gabarit affiché sans application (exemple ce3)
* [ ] `checkup.yml` inchangé depuis J2, prouvé par `git log`

# Observability


## Jalon O1 — Collecte de télémétrie gNMI

### Objectif

Déployer un collecteur **gnmic** sur VM Tools qui se connecte aux 9 routeurs Arista via le protocole gNMI et expose les métriques en temps réel sur un endpoint Prometheus.

### Architecture

Routeurs Arista (gNMI :6030) → gnmic (collecteur :9804) → Prometheus → Grafana

### Protocole gNMI — modèle push

gNMI (gRPC Network Management Interface) est le protocole natif d'Arista EOS pour la télémétrie réseau. Il est exposé par défaut sur le **port 6030** de chaque routeur.

Le mode choisi est **stream / sample** : les routeurs **poussent** automatiquement leurs données vers gnmic toutes les **10 secondes**, sans que gnmic ait besoin de les interroger à chaque fois.

> **Rien n'est installé sur les équipements** : le serveur gNMI est intégré directement dans EOS. gnmic est uniquement installé sur la VM Tools.

### Données collectées

| Chemin gNMI | Données |
| ------ | ------- |
| `/interfaces/interface/state/counters` | Compteurs de trafic (octets, paquets, erreurs) |
| `/interfaces/interface/state/oper-status` | État opérationnel des interfaces (UP/DOWN) |

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

Les routeurs tournent sur la VM Lab (10.200.2.120). Pour que la VM Tools puisse les joindre, il faut ajouter une route statique :

```bash
sudo ip route add 172.20.20.0/24 via 10.200.2.120
```

Cette commande indique à la VM Tools que le réseau de management `172.20.20.0/24` est accessible via la VM Lab. Sans cette route, gnmic ne peut pas atteindre les routeurs.

### Installation de gnmic

```bash
bash -c "$(curl -sL https://get-gnmic.openconfig.net)"
gnmic version
```

Version installée : `0.49.0`

### Vérification gNMI — test direct

Vérifier que gNMI répond sur un routeur :

```bash
gnmic -a 172.20.20.21:6030 -u admin -p admin --insecure capabilities
```

Cette commande interroge pe1 et retourne les modèles de données supportés. Si elle répond, la connectivité gNMI est établie.

Consulter les métriques d'interface en direct sur pe1 :

```bash
gnmic -a 172.20.20.21:6030 -u admin -p admin --insecure \
  get --path /interfaces/interface/state/counters
```

### Configuration par fichier versionné

> **Exigence O1** : configuration par fichier versionné, pas par une commande jetable.

La configuration complète de gnmic est dans un fichier YAML versionné dans le dépôt. Aucune option n'est passée en ligne de commande au démarrage — tout est déclaré dans ce fichier.

Fichier : `observability/gnmic/gnmic.yml`

Ce fichier déclare les 9 cibles (routeurs), les chemins gNMI à collecter, l'intervalle de collecte (10s) et le port d'exposition des métriques (9804).

### Service systemd — survie à la fermeture de session

> **Exigence O1** : survit à la fermeture de la session — service systemd.

gnmic tourne comme un service systemd. Cela garantit qu'il redémarre automatiquement au boot et continue de fonctionner même si la session SSH est fermée. Un processus lancé directement dans un terminal s'arrêterait à la fermeture de la session.

Fichier de service : `observability/systemd/gnmic.service`

```bash
sudo systemctl daemon-reload      # recharge la liste des services
sudo systemctl enable gnmic       # active le démarrage automatique au boot
sudo systemctl start gnmic        # démarre le service maintenant
sudo systemctl status gnmic       # vérifie que le service est actif
```

### Journalisation active

> **Exigence O1** : journalisation active — un service non diagnosticable n'est pas livrable.

Les logs de gnmic sont accessibles via journalctl. En cas de problème (routeur injoignable, erreur de configuration), les logs permettent de diagnostiquer sans redémarrer le service.

```bash
journalctl -u gnmic -f
```

`-f` affiche les logs en temps réel (mode "follow"), comme un `tail -f`.

### Vérification de l'endpoint

Vérifier que gnmic expose bien les métriques au format Prometheus :

```bash
curl http://localhost:9804/metrics | grep "in_octets"
```

Afficher les métriques en temps réel (rafraîchissement toutes les 2 secondes) :

```bash
watch -n 2 'curl -s http://localhost:9804/metrics | grep "in_octets"'
```

Si les valeurs changent entre chaque rafraîchissement, la collecte gNMI fonctionne.

### Validation

* [x] gnmic installé (v0.49.0)
* [x] Configuration par fichier versionné — pas de commande jetable (`observability/gnmic/gnmic.yml`)
* [x] Service systemd actif et activé au démarrage — survit à la fermeture de session (`observability/systemd/gnmic.service`)
* [x] Journalisation active via journalctl
* [x] Rien n'installé sur les équipements — gNMI intégré à EOS
* [x] Route réseau configurée vers 172.20.20.0/24 via VM Lab
* [x] Endpoint Prometheus exposé sur `:9804/metrics`
* [x] 9 routeurs collectés en mode stream/sample toutes les 10s

---

## Jalon O2 — Stockage avec Prometheus

### Objectif

Déployer **Prometheus** via Docker Compose pour scraper les métriques gnmic et les stocker dans le temps.

### Architecture

gnmic (:9804) → Prometheus (:9090) — modèle pull

> **Prometheus — modèle pull** : contrairement à gNMI où les routeurs poussent les données, Prometheus va lui-même chercher les métriques en interrogeant l'endpoint de gnmic toutes les 15 secondes. C'est Prometheus qui décide quand collecter.

### Déploiement par Docker Compose dans un projet séparé

> **Exigence O2** : déploiement par Docker Compose, dans un projet séparé de tout ce qui existe déjà sur la VM.

Prometheus est déployé dans le dossier `observability/` via Docker Compose. Ce projet est indépendant de tout autre service Docker qui tournerait sur la VM — il n'interfère pas avec les conteneurs Containerlab.

### Versions épinglées — latest interdit

> **Exigence O2** : versions épinglées — latest interdit.

Les images Docker utilisent des versions fixes. `latest` est interdit car il rendrait le déploiement non reproductible : deux déploiements à des dates différentes pourraient utiliser des versions différentes et avoir des comportements différents.

Exemple dans `docker-compose.yml` :
```yaml
image: prom/prometheus:v2.53.0   # version fixe, pas latest
```

### Vérification du port entre les deux VM

> **Exigence O2** : vérifier au préalable que le port traverse bien entre les deux VM.

Avant de configurer Prometheus, vérifier que le port 9804 de la VM Tools est accessible :

```bash
curl http://localhost:9804/metrics | head -5
```

Si gnmic répond, Prometheus pourra scraper l'endpoint.

### Fichiers

```
observability/docker-compose.yml      # déclare les services Prometheus et Grafana
observability/prometheus/prometheus.yml  # configuration du scrape
```

### Démarrage

```bash
cd observability
docker compose up -d    # démarre tous les conteneurs en arrière-plan
docker ps               # vérifie que les conteneurs sont bien actifs
```

### Vérification

Ouvrir : `http://localhost:9090`

Aller dans **Status → Targets** → le target `gnmic` doit être en état **UP**.

```bash
curl -s "http://localhost:9090/api/v1/query?query=interfaces_interface_state_counters_out_unicast_pkts" \
  | python3 -m json.tool | grep value
```

Si cette commande retourne des valeurs, Prometheus stocke bien les métriques.

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
* [x] Projet Docker séparé de tout ce qui existe sur la VM
* [x] Version épinglée — latest interdit (`prom/prometheus:v2.53.0`)
* [x] Port 9804 vérifié entre les deux VM avant configuration
* [x] Conteneur Prometheus actif
* [x] Target gnmic en état **UP** dans Prometheus
* [x] Métriques visibles dans l'interface Graph
* [x] Données enregistrées dans le temps (courbe visible)

---

## Jalon O3 — Visualisation avec Grafana

### Objectif

Déployer **Grafana** via Docker Compose et créer un tableau de bord de supervision MPLS entièrement **provisionné par fichier** : source de données et dashboard chargés automatiquement au démarrage, sans aucun clic dans l'interface.

### Architecture

gnmic (:9804) → Prometheus (:9090) → Grafana (:3000)

### Source de données ET dashboard provisionnés par fichier — zéro clic

> **Exigence O3** : source de données ET tableau de bord provisionnés par fichier, sans un seul clic.

Grafana supporte le provisionnement automatique via des fichiers placés dans un dossier monté dans le conteneur. Au démarrage, Grafana lit ces fichiers et crée automatiquement la source de données et le dashboard. Aucune action manuelle dans l'interface n'est nécessaire.

```
observability/grafana/provisioning/
├── datasources/
│   └── prometheus.yml      # déclare Prometheus comme source de données
└── dashboards/
    ├── dashboard.yml        # indique à Grafana où lire les fichiers JSON
    └── network.json         # définition complète du tableau de bord
```

**Source de données** — `provisioning/datasources/prometheus.yml`

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: PBFA97CFB590B2093
    url: http://prometheus:9090
    access: proxy
    isDefault: true
```

L'`uid` est fixé manuellement (`PBFA97CFB590B2093`) pour que tous les panels du dashboard puissent le référencer de façon stable, sans dépendre d'un ID auto-généré par Grafana.

**Provider de dashboards** — `provisioning/dashboards/dashboard.yml`

```yaml
apiVersion: 1
providers:
  - name: default
    folder: ''
    type: file
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

`allowUiUpdates: true` permet de modifier le dashboard via l'API REST sans être bloqué par le mode provisionné.

### Démarrage

Grafana est inclus dans le même Docker Compose que Prometheus :

```bash
cd observability
docker compose up -d
docker ps
```

Ouvrir : `http://localhost:3000`
Identifiants par défaut : `admin / admin`

### Redémarrer Grafana

Après une modification des fichiers de provisionnement (`datasources/` ou `dashboard.yml`), redémarrer le conteneur pour que Grafana recharge tout :

```bash
docker restart grafana
```

Pour appliquer uniquement une modification de `network.json` sans redémarrer le conteneur :

```bash
curl -s -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat ~/Tp/projet-mpls-l3vpn-G2/observability/grafana/provisioning/dashboards/network.json), \"overwrite\": true, \"folderId\": 0}"
```

### Afficher un débit, pas un compteur brut — avec une unité juste

> **Exigence O3** : afficher un débit (rate), pas un compteur brut, avec une unité juste.

Les métriques collectées (`in_octets`, `out_octets`) sont des **compteurs cumulatifs** qui ne font qu'augmenter depuis le démarrage du routeur. Afficher leur valeur brute donnerait une courbe toujours croissante — illisible et sans signification opérationnelle.

La fonction `rate()` de PromQL calcule la **variation par seconde** sur une fenêtre glissante :

```promql
rate(interfaces_interface_state_counters_in_octets{source=~"$router", interface_name=~"$interface"}[1m])
```

- `[1m]` : fenêtre de calcul de 1 minute
- Résultat : **octets par seconde** → unité `Bps` dans Grafana
- Grafana convertit automatiquement en Kbps ou Mbps selon l'ordre de grandeur

### Courbes identifiables : nom de l'équipement et de l'interface

> **Exigence O3** : courbes identifiables — nom de l'équipement et de l'interface.

Chaque courbe est labellisée grâce au `legendFormat` qui utilise les labels Prometheus injectés par gnmic :

```json
"legendFormat": "{{source}} / {{interface_name}}"
```

Résultat affiché dans Grafana : `pe1 / Ethernet1`, `ce2 / Ethernet2`, etc.

`source` = nom du routeur, `interface_name` = nom de l'interface — deux informations essentielles pour identifier une courbe sur un réseau multi-équipements.

### Contenu du tableau de bord

**Résumé global** — 4 tuiles stat :

| Tuile | Ce qu'elle mesure | Requête PromQL |
|---|---|---|
| Interfaces DOWN | Nombre d'interfaces actuellement DOWN | `count(interfaces_interface_state_oper_status == 0) or vector(0)` |
| Interfaces UP | Nombre d'interfaces actuellement UP | `count(interfaces_interface_state_oper_status == 1) or vector(0)` |
| Total interfaces | Total des interfaces supervisées | `count(interfaces_interface_state_oper_status)` |
| Routeurs supervisés | Nombre de routeurs actifs | `count(count by (source) (interfaces_interface_state_oper_status))` |

**Débit en temps réel** — 2 courbes (In / Out) :

```promql
rate(interfaces_interface_state_counters_in_octets{source=~"$router", interface_name=~"$interface"}[1m])
rate(interfaces_interface_state_counters_out_octets{source=~"$router", interface_name=~"$interface"}[1m])
```

**État actuel des interfaces** — tableau :

```promql
interfaces_interface_state_oper_status{source=~"$router", interface_name=~"$interface"}
```

La valeur `1` s'affiche `UP ✅` (fond vert), la valeur `0` s'affiche `DOWN ❌` (fond rouge).
Ces valeurs numériques sont produites par le processeur `event-strings` de gnmic qui convertit les chaînes `UP`/`DOWN` reçues via gNMI en entiers `1`/`0` avant l'envoi à Prometheus (Prometheus ne stocke que des nombres).

---

### Expérience 1 — Test de panne (prédire par écrit, puis mesurer)

> **Exigence O3** : test de panne — prédire par écrit, puis mesurer.

#### Contexte réseau

Dans cette topologie, tous les liens sont **point-à-point** entre routeurs supervisés. Couper une interface fait donc toujours tomber **2 extrémités simultanément** : les deux routeurs aux bouts du lien voient leur interface passer DOWN. C'est le comportement réel et attendu d'un réseau MPLS — le dashboard détecte correctement les deux pannes.

#### Prédiction (écrite avant le test)

Si l'interface `Ethernet1` de `p1` est désactivée :
- La tuile **Interfaces DOWN** passe à **2** (les deux extrémités du lien point-à-point)
- Les deux lignes concernées passent au rouge **DOWN ❌** dans le tableau État
- Les courbes de débit des deux interfaces tombent à **0 Bps** en moins de 30 secondes

#### Vérifier l'état avant la panne

```bash
curl -s 'http://localhost:9090/api/v1/query?query=interfaces_interface_state_oper_status{source="p1"}' \
  | python3 -m json.tool
```

Résultat attendu : toutes les valeurs à `"1"` (interfaces UP)

#### Simuler la panne via gNMI

```bash
gnmic -a 172.20.20.11:6030 -u admin -p admin --insecure set \
  --update-path "/interfaces/interface[name=Ethernet1]/config/enabled" \
  --update-value "false"
```

Cette commande utilise `gnmic set` pour désactiver l'interface `Ethernet1` de `p1` **directement via gNMI**, sans passer par le CLI du routeur. C'est la même voie que la collecte — gNMI permet à la fois de lire et d'écrire la configuration.

#### Vérifier après la panne (~15 secondes)

```bash
curl -s 'http://localhost:9090/api/v1/query?query=interfaces_interface_state_oper_status{source="p1",interface_name="Ethernet1"}' \
  | python3 -m json.tool
```

Résultat attendu : `"value": "0"` — le dashboard affiche **DOWN:2** (les deux bouts du lien).

#### Restaurer l'interface

```bash
gnmic -a 172.20.20.11:6030 -u admin -p admin --insecure set \
  --update-path "/interfaces/interface[name=Ethernet1]/config/enabled" \
  --update-value "true"
```

---

### Expérience 2 — Test du chemin Grafana → Prometheus (PromQL vers Prometheus)

> **Exigence O3** : test de chemin Grafana — PromQL vers Prometheus, avec chaque commande et son utilité.

Cette expérience reproduit manuellement ce que Grafana fait en arrière-plan, maillon par maillon, pour prouver que toute la chaîne fonctionne.

**Étape 1 — gnmic expose bien les métriques**

```bash
curl -s http://localhost:9804/metrics | grep interfaces_interface_state_counters_in_octets | head -5
```

Vérifie que gnmic collecte les compteurs depuis les routeurs et les publie au format Prometheus sur `:9804`. Si cette commande retourne des lignes avec des valeurs numériques, gnmic fonctionne correctement.

**Étape 2 — Prometheus scrape bien gnmic**

```bash
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep -A3 "health"
```

Vérifie que Prometheus contacte bien gnmic régulièrement et que le statut du target est `"up"`. Si le statut est `"down"`, Prometheus ne stocke pas les métriques.

**Étape 3 — Requête PromQL instantanée (équivalent d'une tuile Grafana)**

```bash
curl -s 'http://localhost:9090/api/v1/query?query=rate(interfaces_interface_state_counters_in_octets{source="pe1"}[1m])' \
  | python3 -m json.tool
```

Exécute exactement la même requête que le panel "Débit entrant" de Grafana. Si cette commande retourne des valeurs, Grafana les affichera aussi. C'est la façon de vérifier une requête PromQL sans ouvrir Grafana.

**Étape 4 — Requête sur une plage de temps (équivalent d'un graphique Grafana)**

```bash
curl -s "http://localhost:9090/api/v1/query_range?\
query=rate(interfaces_interface_state_counters_in_octets{source=\"pe1\"}[1m])\
&start=$(date -d '5 minutes ago' +%s)\
&end=$(date +%s)&step=10" | python3 -m json.tool
```

Retourne les points de données sur 5 minutes avec un pas de 10 secondes. C'est exactement ce que Grafana utilise pour tracer les courbes — chaque point de la courbe correspond à une valeur retournée par cette requête.

**Étape 5 — Vérifier dans Grafana**

Ouvrir `http://localhost:3000` → les valeurs affichées dans les panels correspondent aux résultats des requêtes curl des étapes 3 et 4.

---

### Validation

* [x] Docker Compose mis à jour avec le service Grafana, version épinglée (`observability/docker-compose.yml`)
* [x] Source de données provisionnée par fichier — zéro clic (`observability/grafana/provisioning/datasources/prometheus.yml`)
* [x] Provider de dashboards versionné (`observability/grafana/provisioning/dashboards/dashboard.yml`)
* [x] Dashboard versionné (`observability/grafana/provisioning/dashboards/network.json`)
* [x] Débit affiché avec `rate()` en Bps — pas un compteur brut
* [x] Courbes identifiables : `{{source}} / {{interface_name}}`
* [x] État des interfaces UP/DOWN avec couleurs (event-strings processor gnmic)
* [x] Expérience 1 : test de panne via `gnmic set` — prédiction écrite + mesure + DOWN:2 expliqué
* [x] Expérience 2 : test du chemin PromQL — chaque commande avec son utilité
