#!/usr/bin/env bash
# tenant-to-cardholder.sh — from each cluster2 tenant, call the cardholder service on cluster1
# (cross-cluster, cross-trust-domain) and print the HTTP result + allow/deny verdict.
set -uo pipefail
unset DEBUG   # silence kubectl spdystream stream debug if DEBUG is set in the env
# optional $1 = a label for what's being tested (e.g. the policy in effect)
if [ $# -ge 1 ]; then echo ">>> $1"
else echo ">>> cluster2 (cluster2) tenants -> cardholder.tenant-payments.mesh.internal  (cluster1, cluster1)"; fi
printf '%s\n' "tenant-payments|payments-api-eu|sa:payments-api zone:PCI-DSS juris:eu" \
              "tenant-payments|payments-api-hk|sa:payments-api zone:PCI-DSS juris:hk" \
              "tenant-analytics|reporting|sa:reporting   zone:general juris:eu" \
| while IFS='|' read ns dep tag; do
    code=$(kubectl --context="${CLUSTER2}" -n "$ns" exec deploy/"$dep" -c curl -- \
      curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
      http://cardholder.tenant-payments.mesh.internal:8000/status/200 2>/dev/null)
    v=$([ "$code" = "200" ] && echo ALLOW || echo "DENY/unreachable")
    printf "  %-22s %-34s -> http %-3s [%s]\n" "$ns/$dep" "($tag)" "$code" "$v"
  done
