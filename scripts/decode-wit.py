# Decodes the WIMSE WIT claims embedded in a workload SVID (otherName SAN, Solo OID 1.3.6.1.4.1.65865.1.1).
# stdin: `istioctl ztunnel-config certificate <pod> -o json`; env: NS, POD (exact running pod name).
import sys, json, base64, subprocess, re, os
ns, pod = os.environ['NS'], os.environ['POD']
d = json.load(sys.stdin)
pem = next(base64.b64decode(e['certChain'][0]['pem']).decode()
           for e in d if ('/Pod/%s/%s' % (ns, pod)) in e['identity'] and e.get('certChain'))
txt = subprocess.run(['openssl', 'x509', '-noout', '-text'], input=pem, capture_output=True, text=True).stdout
m = re.search(r'65865\.1\.1:([A-Za-z0-9_.-]+)', txt)
seg = m.group(1); seg = seg.split('.')[1] if seg.count('.') >= 2 else seg; seg += '=' * (-len(seg) % 4)
c = json.loads(base64.urlsafe_b64decode(seg))
print('  SPIFFE id :', c['sub'])
sc=(c.get('solo.io') or {}).get('security-claims') or {}
print('  CLAIMS    :', json.dumps(sc) if sc else '(none — identity only)')
