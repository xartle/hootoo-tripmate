#!/usr/bin/env bash
# Populate the games/ tree. Run on a LAPTOP or acorn (needs curl/git + TLS) --
# NOT on the TripMate (its busybox wget is HTTP-only). Then copy games/ to the
# stick root: cp -a <slug...> /media/<stick>/games/
#
# Downloaded payloads are gitignored. This script only fetches; it commits nothing.
set -u
cd "$(dirname "$0")"
have(){ command -v "$1" >/dev/null 2>&1; }
have git || { echo "need git"; exit 1; }
have curl || { echo "need curl"; exit 1; }

# ---- Chess: chessboard.js + stockfish.js, with a generated glue index.html ----
fetch_chess(){
  echo "== chess =="
  mkdir -p chess/vendor
  git clone --depth 1 https://github.com/oakmac/chessboardjs chess/vendor/chessboardjs
  git clone --depth 1 https://github.com/nmrugg/stockfish.js chess/vendor/stockfish
  # glue page is generated here (not committed) so the repo stays payload-free
  cat > chess/index.html <<'HTML'
<!doctype html><meta charset=utf-8><title>Chess vs Stockfish</title>
<link rel=stylesheet href="vendor/chessboardjs/www/css/chessboard.css">
<div id=board style="width:480px;margin:24px auto"></div>
<p style="text-align:center;font:14px monospace" id=status></p>
<script src="https://unpkg.com/jquery@3.6/dist/jquery.min.js"></script>
<script src="vendor/chessboardjs/www/js/chessboard.js"></script>
<!-- wire chess.js + stockfish worker here; see vendor/stockfish examples -->
<script>document.getElementById('status').textContent='board loaded -- wire stockfish worker (see vendor/stockfish/example)';</script>
HTML
  echo "  note: jquery is on a CDN above -- vendor it for fully-offline play."
}

# ---- FreeCell: lightweight static JS implementation ----
fetch_freecell(){
  echo "== freecell =="
  mkdir -p freecell
  # pick a small static implementation; example placeholder clone:
  git clone --depth 1 https://github.com/shlomif/fc-solve freecell/fc-solve \
    && echo "  (fc-solve is the SOLVER; add a static JS FreeCell UI as index.html)"
  echo "  TODO: drop a single-file JS FreeCell index.html here (<1 MB)."
}

# ---- Brogue CE: needs a maintained WASM web build (manual) ----
fetch_brogue(){
  echo "== brogue (manual) =="
  echo "  Source game: https://github.com/tmewett/BrogueCE"
  echo "  Find/clone a maintained 'Brogue CE Web' WASM build into brogue/ as index.html + .wasm."
}

# ---- Mindustry Classic: itch build is a manual download ----
fetch_mindustry(){
  echo "== mindustry (manual) =="
  echo "  Browser build: https://anuke.itch.io/mindustry-classic (download via itch, unzip into mindustry/)"
  echo "  Source: https://github.com/Anuken/Mindustry-Classic"
}

# ---- OpenTTD: use an Emscripten/WASM web build + OpenGFX (manual) ----
fetch_openttd(){
  echo "== openttd (manual) =="
  echo "  https://www.openttd.org / https://github.com/OpenTTD/OpenTTD"
  echo "  Use a WASM/Emscripten web build; include OpenGFX base graphics. Unzip into openttd/."
}

# ---- Freeciv Web (complex) OR Micropolis (static, recommended for an appliance) ----
fetch_freeciv(){
  echo "== freeciv / micropolis =="
  echo "  Freeciv-web (complex, needs server): https://github.com/freeciv/freeciv-web"
  echo "  Static alternative -> Micropolis (SimCity classic):"
  git clone --depth 1 https://github.com/SimHacker/micropolis freeciv/micropolis-src \
    && echo "  (see micropolis web/ build; serve its static output as freeciv/index.html)"
}

case "${1:-all}" in
  chess) fetch_chess;; freecell) fetch_freecell;; brogue) fetch_brogue;;
  mindustry) fetch_mindustry;; openttd) fetch_openttd;; freeciv) fetch_freeciv;;
  all) fetch_chess; fetch_freecell; fetch_brogue; fetch_mindustry; fetch_openttd; fetch_freeciv;;
  *) echo "usage: $0 [all|chess|freecell|brogue|mindustry|openttd|freeciv]";;
esac
echo
echo "done. review each <slug>/index.html, then copy populated dirs to the stick:"
echo "  cp -a brogue mindustry openttd freeciv chess freecell /media/<stick>/games/"
