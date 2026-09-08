#!/usr/bin/env bash
#
# Rebuilds public/sitemap.xml from the HTML files in public/.
#
# Runs automatically on every deploy, so adding a page to public/ is all it
# takes to get that page into the sitemap. Safe to run by hand too:
#
#   ./deploy/generate-sitemap.sh
#
set -euo pipefail

SITE_URL="${SITE_URL:-https://davey.mywindowwashing.com}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC="$ROOT/public"
OUT="$PUBLIC/sitemap.xml"

# Pages excluded from the sitemap: error pages and anything under a
# directory starting with an underscore (partials, drafts, includes).
is_excluded() {
  case "$1" in
    404.html|500.html) return 0 ;;
    _*|*/_*)           return 0 ;;
    *)                 return 1 ;;
  esac
}

# nginx serves /about from about.html, so the sitemap must list the
# extensionless form — otherwise the sitemap and the canonical URL disagree.
to_url() {
  local rel="$1"
  case "$rel" in
    index.html)   printf '%s/' "$SITE_URL" ;;
    */index.html) printf '%s/%s/' "$SITE_URL" "${rel%/index.html}" ;;
    *)            printf '%s/%s' "$SITE_URL" "${rel%.html}" ;;
  esac
}

# Last commit date for the file. Falls back to today when the file is new
# and not yet committed, or when history is unavailable.
last_modified() {
  local rel="$1" date=''
  if [ -d "$ROOT/.git" ]; then
    date="$(git -C "$ROOT" log -1 --format=%cs -- "public/$rel" 2>/dev/null || true)"
  fi
  printf '%s' "${date:-$(date -u +%F)}"
}

{
  printf '<?xml version="1.0" encoding="UTF-8"?>\n'
  printf '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'

  # Sorted so the file only changes when the pages actually change, which
  # keeps deploy diffs readable.
  while IFS= read -r rel; do
    is_excluded "$rel" && continue
    printf '  <url><loc>%s</loc><lastmod>%s</lastmod></url>\n' \
      "$(to_url "$rel")" "$(last_modified "$rel")"
  done < <(cd "$PUBLIC" && find . -name '*.html' -type f -printf '%P\n' | sort)

  printf '</urlset>\n'
} > "$OUT"

printf 'Wrote %s (%s URLs)\n' "$OUT" "$(grep -c '<url>' "$OUT" || true)"
