#!/usr/bin/env bash
# Write the mkcert CA, the leaf certificate, and the full chain under
# secrets/mkcert (git-crypt). Sops-encrypt only the leaf private key to
# secrets/koderup.yaml. Does not commit.
#
#   just certs
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

caroot=$root/secrets/mkcert
mkdir -p "$caroot"
export CAROOT=$caroot

mkcert -cert-file "$caroot/koderup.crt" -key-file "$caroot/koderup.key" koderup.dk "*.koderup.dk"

for f in rootCA.pem rootCA-key.pem koderup.crt koderup.key; do
  if [ ! -s "$caroot/$f" ]; then
    echo "missing $caroot/$f" >&2
    exit 1
  fi
done

# Leaf, then the CA. Traefik serves this chain.
cat "$caroot/koderup.crt" "$caroot/rootCA.pem" > "$caroot/koderup-fullchain.crt"

{
  echo "koderup-tls-key: |"
  sed 's/^/  /' "$caroot/koderup.key"
} > sops-certs
echo "Add sops-certs content to secrets/koderup.yaml"

echo "secrets/mkcert: rootCA.pem rootCA-key.pem koderup.crt koderup.key koderup-fullchain.crt"
echo "secrets/koderup.yaml: sops-encrypted leaf key only. Commit both yourself."
