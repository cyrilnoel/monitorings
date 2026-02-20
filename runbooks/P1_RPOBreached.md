# Runbook — P1_RPOBreached

## Description
RPO dépassé : `time() - medassist_backup_last_success_timestamp > 1800` pendant 5 min.

## Impact
- Données médicales non protégées au niveau attendu.
- Risque conformité (sensibilité données de santé).

## Diagnostic
1. Vérifier Pushgateway : http://localhost:9091/metrics
2. Vérifier métriques backup dans Prometheus (Graph):
   - `medassist_backup_success`
   - `medassist_backup_last_success_timestamp`
3. Lancer un backup manuel :
   - `docker compose run --rm backup`
4. Vérifier espace disque dans le volume (host) + dossier `backup/data`.

## Résolution
- Corriger accès DB (credentials, MySQL up)
- Rejouer un backup OK
- Si DB indispo : basculer procédure de sauvegarde alternative

## Escalade
- P1 immédiat (SRE + RSSI/DSI selon org)
- Noter l'écart de conformité dans le rapport

## Post-mortem checklist
- Pourquoi l'échec était silencieux ?
- Alertes suffisantes ?
- Procédure de restauration testée ?
