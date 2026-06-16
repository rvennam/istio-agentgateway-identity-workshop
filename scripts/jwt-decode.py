#!/usr/bin/env python3
# jwt-decode.py — pretty-print a JWT's header + payload (x5c summarized for readability),
# or emit its x5c root cert for offline-verification checks.
#   jwt-decode.py <file|->              pretty header + payload
#   jwt-decode.py --x5c-root <file|->   print the last x5c cert (the root) as one base64 line
import sys, json, base64

args = sys.argv[1:]
mode = "pretty"
if args and args[0] == "--x5c-root":
    mode, args = "x5c-root", args[1:]
src = args[0] if args else "-"
tok = (sys.stdin.read() if src == "-" else open(src).read()).strip()

dec = lambda s: json.loads(base64.urlsafe_b64decode(s + "=="))
hdr, pld = tok.split(".")[0], tok.split(".")[1]

if mode == "x5c-root":
    print(dec(hdr)["x5c"][-1])
    sys.exit()

h = dec(hdr)
if "x5c" in h:
    h["x5c"] = f"[{len(h['x5c'])} certs — omitted; full token in the .jwt file]"
print("== HEADER =="); print(json.dumps(h, indent=2))
print("\n== PAYLOAD =="); print(json.dumps(dec(pld), indent=2))
