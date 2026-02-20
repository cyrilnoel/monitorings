# Rapport — Monitoring MedAssist 

# MedAssist — Rapport de Monitoring (Partie 1)


---

## 1) Objectif de la Partie 1
Mettre en place un monitoring d’infrastructure et applicatif pour MedAssist afin de :
- Collecter des métriques (API + infrastructure + conteneurs)
- Visualiser l’état et les performances (USE / RED)
- Détecter rapidement les dégradations (pannes, latence, erreurs)

---

## 2) Composants déployés
### 2.1 Stack Monitoring
- **Prometheus** : collecte et stockage des métriques
- **Grafana** : visualisation (dashboards USE et RED)
- **cAdvisor** : métriques par conteneur Docker (CPU/RAM/Network)
- **Node Exporter** : métriques système (CPU/RAM/Disque/Network)

### 2.2 Cibles scrapées par Prometheus
| Job Prometheus | Source | Rôle |
|---|---|---|
| `api` | API Flask | métriques applicatives `/metrics` |
| `cadvisor` | cAdvisor | métriques conteneurs |
| `node` | Node Exporter | métriques OS/hôte |
| `prometheus` | Prometheus | auto-monitoring |

---

## 3) Validation des livrables (Partie 1)

### 3.1 Prometheus accessible et scrappe toutes les cibles
- **URL :** `http://localhost:9090`
- **Page de contrôle :** `Status → Targets`
- **Critère de réussite :** Tous les jobs attendus sont en **UP**





---

### 3.2 Grafana accessible avec Prometheus comme datasource
- **URL :** `http://localhost:3000`
- **Identifiants :** TODO (ex: admin / admin)
- **Datasource :** Prometheus configuré sur `http://prometheus:9090`
- **Critère de réussite :** “Data source is working” (ou dashboards affichent des données)





---

### 3.3 cAdvisor et Node Exporter déployés et fonctionnels
- **cAdvisor** : visible dans Prometheus Targets (`job="cadvisor"`)
- **Node Exporter** : visible dans Prometheus Targets (`job="node"`)
- **Critère de réussite :** `up{job="cadvisor"}` = 1 et `up{job="node"}` = 1




---

## 4) Dashboard USE — Infrastructure (6 panneaux minimum)
### 4.1 Principe USE
La méthode **USE** (Utilisation, Saturation, Erreurs) permet d’évaluer rapidement :
- **CPU** : utilisation + saturation (load)
- **Mémoire** : utilisation + mémoire disponible
- **Réseau** : trafic + erreurs/drops

### 4.2 Panneaux inclus (exemple)
| Ressource | Panneau 1 | Panneau 2 |
|---|---|---|
| CPU | Utilisation (%) | Saturation (Load/CPU) |
| Mémoire | Mémoire utilisée (%) | Mémoire disponible (GiB) |
| Réseau | RX/TX (Mb/s) | Errors/Drops (par seconde) |




---

## 5) Dashboard RED — API (3 panneaux minimum)
### 5.1 Principe RED
La méthode **RED** (Rate, Errors, Duration) permet de suivre l’API :
- **Rate** : requêtes par seconde (RPS)
- **Errors** : taux d’erreurs (notamment 5xx)
- **Duration** : latence (p95 recommandé)

### 5.2 Panneaux inclus
| Indicateur | Description |
|---|---|
| Rate | volume de requêtes |
| Errors | proportion d’erreurs 5xx |
| Duration | latence p95 |




---

## 6) Tests réalisés (preuve de fonctionnement)
### 6.1 Génération de trafic
Objectif : faire varier les courbes RED (Rate/Errors/Duration).

Commande utilisée (exemple) :
```bash
# Exemple PowerShell
1..200 | % { iwr http://localhost:5000/api/payment -UseBasicParsing | Out-Null }


lien utiles 

Prometheus : http://localhost:9090

Grafana : http://localhost:3000

Targets Prometheus : http://localhost:9090/targets



Partie 2 : Centralisation des logs (ELK + Filebeat)

> **Objectif :** mettre en place une chaîne de logs complète (collecte → stockage → visualisation) avec **Filebeat**, **Elasticsearch** et **Kibana**, puis prouver le bon fonctionnement via vérifications et captures.

---

## 1. Contexte & périmètre

Cette partie du TP vise à :
- **Collecter** les logs des conteneurs Docker (stack MedAssist)
- **Expédier** ces logs vers **Elasticsearch**
- **Explorer / visualiser** les logs dans **Kibana** (Discover + Dashboards)

**Composants utilisés :**
- Elasticsearch (stockage + indexation)
- Kibana (exploration + dashboards)
- Filebeat (collecte et envoi des logs Docker)

---

## 2. Déploiement et configuration

### 2.1 Services déployés
Les services suivants ont été démarrés via Docker Compose :
- `elasticsearch`
- `kibana`
- `filebeat`




# Partie 3 — Monitoring des sauvegardes MySQL (MedAssist)

## 1. Objectif

Mettre en place un monitoring complet des sauvegardes MySQL avec :
- **collecte de métriques** via **Pushgateway** (jobs batch),
- **scraping Prometheus**,
- **alertes Prometheus** sur :
  - échec de sauvegarde,
  - dépassement du **RPO 30 min**,
  - anomalie de taille,
- **dashboard Grafana** dédié (≥ 5 panneaux),
- **test d’échec** avec preuve (alerte FIRING).

RPO cible MedAssist : **30 minutes (1800s)**.

---

## 2. Architecture mise en place

### 2.1 Composants
- **MySQL** : base applicative `medassist`
- **Backup job** : conteneur `backup` exécuté à la demande (`docker compose run --rm backup`)
- **Pushgateway** : reçoit les métriques du job batch
- **Prometheus** : scrape Pushgateway + évalue règles d’alerting
- **Grafana** : visualisation des métriques de sauvegarde via datasource Prometheus

### 2.2 Flux
1. Le job `backup` exécute `mysqldump` → génère un fichier `.sql.gz`
2. Le job calcule :
   - durée d’exécution,
   - taille du fichier,
   - statut success/fail + exit_code,
   - timestamps dernière exécution / dernier succès,
   - cible RPO (1800s)
3. Le job pousse ces métriques vers Pushgateway
4. Prometheus scrape Pushgateway → stocke séries temporelles
5. Grafana affiche un dashboard “Monitoring Backups”
6. Prometheus déclenche alertes si conditions vraies

---

## 3. Déploiement Docker

### 3.1 Pushgateway
Service déployé via `docker-compose.yml` :
- Port exposé : `9091:9091`
- Vérification :
```bash
curl -s http://127.0.0.1:9091/metrics




# Partie 4 --- Monitoring de la Haute Disponibilité & Simulation PCA/PRA



Objectifs : - Déployer l'API en 3 replicas - Mettre en place HAProxy -
Monitorer via Prometheus & Grafana - Mesurer le MTTD (Mean Time To
Detect) - Simuler panne partielle et panne totale - Documenter la
restauration

------------------------------------------------------------------------

## 2. Architecture Haute Disponibilité

### 2.1 API scalée

Déploiement :

``` powershell
docker compose up -d --scale api=3 api
```

Vérification :

``` powershell
docker ps --format "table {{.Names}} {{.Status}}"
```

Résultat attendu : - 3 replicas healthy

------------------------------------------------------------------------

### 2.2 HAProxy

Configuration backend :

``` haproxy
backend api_back
  balance roundrobin
  option httpchk GET /health
  http-check expect status 200
  server-template api 3 api:5000 check resolvers docker
```

Fonctionnalités : - Load balancing round-robin - Health checks
automatiques - Export métriques via /metrics - Page stats accessible

------------------------------------------------------------------------

## 3. Monitoring Grafana

voir capture ecran partie 4
```

------------------------------------------------------------------------

## 4. Simulation 1 --- Panne Partielle

Arrêt d'un replica :

``` powershell
docker stop medassist-api-2
```

Test utilisateur :

``` powershell
curl http://127.0.0.1:15000/api/doctors
```

Résultat : HTTP 200 → Service disponible.

Alerte déclenchée : - P2_APIReplicasDegraded

MTTD observé : ≈ 30 secondes.

------------------------------------------------------------------------

## 5. Simulation 2 --- Panne Totale

Arrêt API + MySQL + Redis :

``` powershell
docker compose stop api mysql redis
```

Impact : - HTTP 503 / timeout - Alerte P1_APIAllDown - Alerte Redis down

------------------------------------------------------------------------

## 6. Restauration

Ordre critique :

``` powershell
docker compose up -d mysql redis
docker compose up -d --scale api=3 api
docker compose up -d haproxy
```

Validation : - HTTP 200 - sum(up{job="api"}) = 3 - Alertes résolues

------------------------------------------------------------------------





