# projet-mpls-l3vpn-G2

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
