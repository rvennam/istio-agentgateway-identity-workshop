#!/usr/bin/env python3
# mint-user-jwt.py <user-email> <may_act-sub> [role]
# The IdP: issue a signed user JWT with a `may_act` claim (pre-authorizes the actor agent)
# and an optional `role` claim. Signed by the demo IdP key.
# (For `role` to survive the OBO exchange, the STS must list it in tokenExchange.allowedSubjectClaims.)
import sys, time, os, jwt
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".obo")
sub, may_act = sys.argv[1], sys.argv[2]
role = sys.argv[3] if len(sys.argv) > 3 else None
now = int(time.time())
claims = {"iss": "https://idp.example.com", "sub": sub, "aud": "agentgateway-sts",
          "iat": now, "exp": now + 3600, "may_act": {"sub": may_act}}
if role:
    claims["role"] = role
print(jwt.encode(claims, open(os.path.join(D, "idp-private.pem")).read(),
                 algorithm="RS256", headers={"kid": "demo-idp"}), end="")
