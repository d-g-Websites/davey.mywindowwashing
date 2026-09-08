#!/usr/bin/env bash
#
# Copies img/ into public/img/ before publishing.
#
# Images are uploaded to img/ at the repository root because that is the
# easiest place to drop files into from the GitHub web UI, but only public/
# is published. Both deploy paths call this first.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$ROOT/public/img"
if [ -d "$ROOT/img" ]; then
    cp -R "$ROOT/img/." "$ROOT/public/img/"
    # The folder's own README explains where to put files; it is not content.
    rm -f "$ROOT/public/img/README.md"
fi

printf 'Images staged: %s\n' \
    "$(find "$ROOT/public/img" -type f ! -name '.gitkeep' | wc -l)"
