# Runbook — P1_ServiceDown_API

## Description
L'alerte se déclenche quand `up{job="api"} == 0` pendant 30s.

## Impact
- Patients: impossibilité de consulter / prendre RDV / payer.
- Médecins: consultations interrompues.
- Risque réputation + perte de chiffre d'affaires.

## Diagnostic
1. Vérifier HAProxy : http://localhost:8404/
2. Vérifier Prometheus targets : http://localhost:9090/targets
3. Logs API :
   - `docker compose logs --tail=200 api`
4. Santé MySQL/Redis :
   - `curl http://localhost:5000/health`
   - `docker compose ps`

## Résolution
- Redémarrer API :
  - `docker compose restart api`
- Si incident persiste : redémarrer dépendances
  - `docker compose restart redis mysql`
- Si besoin: re-build API
  - `docker compose up -d --build api`

## Escalade
- P1: avertir Lead/SRE + direction produit.
- Si > 15 min : déclencher incident majeur + communication.

## Post-mortem checklist
- Cause racine identifiée ?
- Actions correctives (SLO, tests, alerting) ?
- Timeline + MTTD/MTTR documentés ?
