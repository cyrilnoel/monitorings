# Runbook — P2_HighErrorRate_API_5xx

## Description
Taux d'erreurs 5xx > 2% sur 5 minutes.

## Impact
- Dégradation utilisateur (paiements, consultations).
- Pertes financières possibles (paiement).

## Diagnostic
1. Dashboard RED Grafana : erreurs 5xx
2. Kibana (Partie 2) : filtre `status:>=500`
3. Logs API :
   - `docker compose logs --tail=500 api`
4. Vérifier santé MySQL/Redis :
   - `curl http://localhost:5000/health`
5. Isoler endpoint fautif :
   - `/api/payment` (erreurs simulées ~5% dans le TD)

## Résolution
- Si uniquement /api/payment => attendu partiellement, ajuster seuil/route (P3/P4) si besoin
- Si erreurs globales => redémarrer API + vérifier dépendances
- Ajouter retry/circuit breaker (recommandation)

## Escalade
- Si impact paiements prolongé => P1 (financier + patient)

## Post-mortem checklist
- Ajuster SLO/SLI ?
- Revoir alert thresholds / window ?
