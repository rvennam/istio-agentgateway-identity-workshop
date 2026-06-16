#!/usr/bin/env bash
# show-svid.sh <context> <namespace> <deployment>
# Decodes the attested claims (WIT) embedded in the running workload's SVID certificate.
set -euo pipefail
unset DEBUG   # silence kubectl spdystream stream debug if DEBUG is set in the env
ctx=$1; ns=$2; dep=$3
pod=$(kubectl --context="$ctx" -n "$ns" get pod -l app="$dep" \
      --field-selector=status.phase=Running --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{.items[-1].metadata.name}')
node=$(kubectl --context="$ctx" -n "$ns" get pod "$pod" -o jsonpath='{.spec.nodeName}')
zt=$(kubectl --context="$ctx" -n istio-system get pod -l app=ztunnel \
     --field-selector spec.nodeName="$node" -o jsonpath='{.items[0].metadata.name}')
istioctl --context="$ctx" ztunnel-config certificate "$zt" -n istio-system -o json 2>/dev/null \
  | NS="$ns" POD="$pod" python3 "$(dirname "$0")/decode-wit.py"
