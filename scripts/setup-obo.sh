#!/usr/bin/env bash
# setup-obo.sh — idempotent setup for the OBO/token-exchange demo (Part 5).
# Creates the demo IdP keypair, points mock-idp's JWKS at it, and creates the agent identities.
# The agentgateway STS, mock-idp, mock-upstream and tx-wp (require-obo) are pre-provisioned platform infra.
set -euo pipefail
unset DEBUG   # silence kubectl spdystream stream debug if DEBUG is set in the env
CTX=${CLUSTER1:+--context=$CLUSTER1}
D="$(cd "$(dirname "$0")" && pwd)/.obo"; mkdir -p "$D"
if [ ! -f "$D/idp-private.pem" ]; then
  python3 - "$D" <<'PY'
import sys; from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization; import json,base64
D=sys.argv[1]; b=lambda x: base64.urlsafe_b64encode(x).rstrip(b"=").decode()
k=rsa.generate_private_key(public_exponent=65537,key_size=2048)
open(D+"/idp-private.pem","wb").write(k.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
n=k.public_key().public_numbers(); i2b=lambda v:v.to_bytes((v.bit_length()+7)//8,"big")
open(D+"/jwks.json","w").write(json.dumps({"keys":[{"kty":"RSA","use":"sig","alg":"RS256","kid":"demo-idp","n":b(i2b(n.n)),"e":b(i2b(n.e))}]}))
PY
fi
kubectl $CTX create configmap jwks-content -n tokenexchange-test --from-file=jwks.json="$D/jwks.json" --dry-run=client -o yaml | kubectl $CTX apply -f - >/dev/null
kubectl $CTX rollout restart deploy/mock-idp -n tokenexchange-test >/dev/null
kubectl $CTX create namespace agents --dry-run=client -o yaml | kubectl $CTX apply -f - >/dev/null
kubectl $CTX label ns agents istio.io/dataplane-mode=ambient --overwrite >/dev/null
for sa in agent-runtime rogue-agent; do kubectl $CTX create sa $sa -n agents --dry-run=client -o yaml | kubectl $CTX apply -f - >/dev/null; done
kubectl $CTX apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent
  namespace: agents
  labels:
    app: agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: agent
  template:
    metadata:
      labels:
        app: agent
      annotations:
        solo.io.security-claims/jurisdiction: "eu"
        solo.io.security-claims/zone: "PCI-DSS"
    spec:
      serviceAccountName: agent-runtime
      containers:
      - name: curl
        image: curlimages/curl:8.10.1
        command:
        - sleep
        - infinity
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rogue
  namespace: agents
  labels:
    app: rogue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rogue
  template:
    metadata:
      labels:
        app: rogue
    spec:
      serviceAccountName: rogue-agent
      containers:
      - name: curl
        image: curlimages/curl:8.10.1
        command:
        - sleep
        - infinity
YAML
# enable WIMSE workload-claim extraction on the tx-wp waypoint proxy
# (sets ENABLE_WORKLOAD_CLAIMS + POD_UID on the proxy → claims exposed as source.claims[...] in policy)
kubectl $CTX apply -f - >/dev/null <<YAML
apiVersion: enterpriseagentgateway.solo.io/v1alpha1
kind: EnterpriseAgentgatewayParameters
metadata:
  name: tx-wp-params
  namespace: tokenexchange-test
spec:
  workloadClaims:
    enabled: true
YAML
kubectl $CTX patch gateway tx-wp -n tokenexchange-test --type=merge \
  -p '{"spec":{"infrastructure":{"parametersRef":{"group":"enterpriseagentgateway.solo.io","kind":"EnterpriseAgentgatewayParameters","name":"tx-wp-params"}}}}' >/dev/null
kubectl $CTX rollout status deploy/agent -n agents --timeout=90s | tail -1
kubectl $CTX rollout status deploy/rogue -n agents --timeout=90s | tail -1
kubectl $CTX rollout status deploy/mock-idp -n tokenexchange-test --timeout=60s | tail -1
kubectl $CTX rollout status deploy/tx-wp -n tokenexchange-test --timeout=90s | tail -1
echo "OBO demo setup ready."
