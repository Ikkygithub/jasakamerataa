#!/usr/bin/env bash
# Membuat paket frontend statis untuk diunggah ke public_html Hostinger.
# Pemakaian: bash deploy/build_hostinger.sh https://URL-BACKEND-ANDA
# URL backend = alamat API yang sedang aktif (sementara: aplikasi Emergent yang sudah di-deploy).
set -euo pipefail
API_URL="${1:?Isi URL backend, contoh: bash deploy/build_hostinger.sh https://contoh.emergent.host}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/deploy/hostinger/public_html"
rm -rf "$OUT" && mkdir -p "$(dirname "$OUT")"
cd "$ROOT/frontend"
REACT_APP_BACKEND_URL="$API_URL" BUILD_PATH="$OUT" GENERATE_SOURCEMAP=false yarn build
python3 - "$OUT/index.html" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = re.sub(r'<script src="https://assets\.emergent\.sh/[^"]*"[^>]*></script>', "", s)
s = re.sub(r"<script>!function\([a-z],[a-z]\)\{var [a-z,]+;[a-z]\.__SV.*?</script>", "", s, flags=re.S)
open(p, "w", encoding="utf-8").write(s)
EOF
cp "$ROOT/deploy/hostinger/htaccess.txt" "$OUT/.htaccess"
cd "$ROOT/deploy/hostinger" && rm -f jasakamerata_public_html.zip && (cd public_html && zip -qr ../jasakamerata_public_html.zip .)
echo "Selesai: $ROOT/deploy/hostinger/jasakamerata_public_html.zip"
grep -c "emergent" "$OUT/index.html" || echo "index.html bersih dari skrip platform"
