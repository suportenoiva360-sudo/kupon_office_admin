#!/usr/bin/env bash
# Build web otimizado do KupON Admin.
#
# Uso:
#   ./scripts/build_web.sh              # Vercel / domínio raiz (base "/")
#   ./scripts/build_web.sh github       # GitHub Pages em /kupon_office_admin/
#
# Requisitos: Flutter 3.47+ em PATH.

set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-vercel}"

FLAGS=(
  --release
  --tree-shake-icons
  --no-web-resources-cdn
)

case "$TARGET" in
  github)
    FLAGS+=(--base-href /kupon_office_admin/)
    ;;
  vercel)
    FLAGS+=(--base-href /)
    ;;
  *)
    echo "Alvo inválido: $TARGET (use 'vercel' ou 'github')" >&2
    exit 1
    ;;
esac

echo "==> flutter build web (${FLAGS[*]})"
flutter build web "${FLAGS[@]}"

if [[ "$TARGET" == "github" ]]; then
  touch build/web/.nojekyll
  echo "==> .nojekyll criado para GitHub Pages"
fi

echo "==> Build concluído em build/web/"
du -sh build/web