# MedAssist — Monitoring 


## Démarrage
```bash
docker compose up -d --build
docker compose ps
```

## Accès
- Frontend: http://localhost/
- API (via HAProxy): http://localhost:5000/health
- Prometheus: http://localhost:9090/targets
- Grafana: http://localhost:3000 (admin/admin)
- Alertmanager: http://localhost:9093
- HAProxy stats: http://localhost:8404/ (metrics: http://localhost:8404/metrics)
- Kibana (Partie 2): http://localhost:5601
- Elasticsearch (Partie 2): http://localhost:9200

## Dashboards (Partie 1)
Provisioning automatique Grafana:
- MedAssist - USE (Infra)
- MedAssist - RED (API)

## Partie 3 (backup) — lancer un backup manuel
```bash
docker compose run --rm backup
```

## Anti-disque plein (IMPORTANT)
- Logs limités: 10MB x 3 fichiers par conteneur
- Prometheus rétention: 2 jours / 2GB
- Elasticsearch heap: 512MB
