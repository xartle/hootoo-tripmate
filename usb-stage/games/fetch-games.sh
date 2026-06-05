#!/usr/bin/env bash
# Populate the games/ tree. Run on a LAPTOP or acorn (needs curl + TLS) --
# NOT on the TripMate (its busybox wget is HTTP-only). Then copy games/ to the
# stick root: cp -a <slug...> /media/<stick>/games/
#
# Downloaded payloads are gitignored. This script only fetches; it commits nothing.
#
# A game is "shipped" only when fetch produces a working, FULLY-OFFLINE
# <slug>/index.html (build-stick.sh gates on that file existing). Games that
# need a hand-built WASM toolchain print manual instructions and fetch nothing,
# so they never ship a broken/online page.
set -u
cd "$(dirname "$0")"
have(){ command -v "$1" >/dev/null 2>&1; }
have curl || { echo "need curl"; exit 1; }

# Pinned versions so a re-fetch is reproducible.
JQUERY_URL="https://code.jquery.com/jquery-3.6.0.min.js"
CB_VER="1.0.0"
CB_JS="https://cdn.jsdelivr.net/npm/@chrisoakman/chessboardjs@${CB_VER}/dist/chessboard-${CB_VER}.min.js"
CB_CSS="https://cdn.jsdelivr.net/npm/@chrisoakman/chessboardjs@${CB_VER}/dist/chessboard-${CB_VER}.min.css"
CB_IMG_BASE="https://raw.githubusercontent.com/oakmac/chessboardjs/master/website/img/chesspieces/wikipedia"
CHESSJS_URL="https://cdn.jsdelivr.net/npm/chess.js@0.10.3/chess.js"
SF_VER="18.0.7"
SF_JS="https://unpkg.com/stockfish@${SF_VER}/bin/stockfish-18-lite-single.js"
SF_WASM="https://unpkg.com/stockfish@${SF_VER}/bin/stockfish-18-lite-single.wasm"
# Brogue: prebuilt asm.js browser build (freethenation/broguejs, gh-pages).
# Pure JS (no WASM/threads), no server, no special headers -> runs on busybox httpd.
BROGUE_BASE="https://raw.githubusercontent.com/freethenation/broguejs/gh-pages"

get(){ # get <url> <dest>  -> returns nonzero on failure
  curl -fsSL "$1" -o "$2"
}

# ---- Chess: REAL offline game = chessboard.js (UI) + chess.js (rules) +
#      Stockfish 18 lite-single (engine). The "-single" build is single-threaded,
#      so it needs no SharedArrayBuffer and runs over plain HTTP (busybox httpd,
#      no COOP/COEP headers). Glue index.html is generated here. ~7.5 MB total. ----
fetch_chess(){
  echo "== chess =="
  mkdir -p chess/vendor/img/chesspieces/wikipedia
  cd chess
  ok=1
  get "$JQUERY_URL"  vendor/jquery.min.js        || ok=0
  get "$CB_JS"       vendor/chessboard.min.js     || ok=0
  get "$CB_CSS"      vendor/chessboard.min.css    || ok=0
  get "$CHESSJS_URL" vendor/chess.js              || ok=0
  echo "  fetching piece images..."
  for p in wP wN wB wR wQ wK bP bN bB bR bQ bK; do
    get "$CB_IMG_BASE/$p.png" "vendor/img/chesspieces/wikipedia/$p.png" || ok=0
  done
  echo "  fetching Stockfish 18 lite-single (engine, ~7.3 MB wasm)..."
  get "$SF_JS"   vendor/stockfish.js   || ok=0
  get "$SF_WASM" vendor/stockfish.wasm || ok=0

  if [ "$ok" != 1 ]; then
    echo "  !! a download failed -- NOT writing index.html so chess won't ship broken."
    rm -f index.html
    cd ..
    return 1
  fi

  cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Chess vs Stockfish</title>
<link rel="stylesheet" href="vendor/chessboard.min.css">
<style>
  body{font:15px system-ui,sans-serif;margin:0;background:#1b1b1d;color:#eee;
       display:flex;flex-direction:column;align-items:center;gap:14px;padding:18px}
  #board{width:min(92vw,480px)}
  .bar{display:flex;gap:10px;align-items:center;flex-wrap:wrap;justify-content:center}
  button,select{font:14px system-ui;padding:6px 12px;border-radius:6px;border:1px solid #555;
       background:#2b2b30;color:#eee;cursor:pointer}
  #status{min-height:1.2em;font:14px monospace;color:#9fd}
  a{color:#7bf}
</style>
<h2 style="margin:.2em 0">Chess vs Stockfish</h2>
<div id="board"></div>
<div class="bar">
  <button id="new">New game</button>
  <button id="flip">Flip</button>
  <label>Strength
    <select id="level">
      <option value="2">Easy</option>
      <option value="6" selected>Medium</option>
      <option value="12">Hard</option>
      <option value="18">Brutal</option>
    </select>
  </label>
</div>
<p id="status">Loading engine…</p>
<script src="vendor/jquery.min.js"></script>
<script src="vendor/chess.js"></script>
<script src="vendor/chessboard.min.js"></script>
<script>
(function(){
  var game = new Chess();
  var thinking = false, engineReady = false;
  var $status = document.getElementById('status');
  var depth = function(){ return parseInt(document.getElementById('level').value,10); };

  // Single-threaded Stockfish as a Web Worker (no SharedArrayBuffer needed).
  var engine = new Worker('vendor/stockfish.js');
  engine.onmessage = function(e){
    var line = (typeof e.data === 'string') ? e.data : (e.data && e.data.data);
    if (typeof line !== 'string') return;
    if (line === 'uciok') { engine.postMessage('isready'); }
    else if (line === 'readyok') { engineReady = true; updateStatus(); }
    else if (line.lastIndexOf('bestmove', 0) === 0) {
      var mv = line.split(/\s+/)[1];
      if (mv && mv !== '(none)') {
        game.move({ from: mv.slice(0,2), to: mv.slice(2,4), promotion: mv.slice(4,5) || 'q' });
        board.position(game.fen());
      }
      thinking = false;
      updateStatus();
    }
  };
  engine.postMessage('uci');

  function engineMove(){
    if (game.game_over()) { updateStatus(); return; }
    thinking = true; updateStatus();
    engine.postMessage('position fen ' + game.fen());
    engine.postMessage('go depth ' + depth());
  }

  function onDragStart(src, piece){
    if (!engineReady || thinking || game.game_over()) return false;
    if (game.turn() !== 'w') return false;          // player is White
    if (piece.search(/^b/) !== -1) return false;
  }
  function onDrop(src, tgt){
    var move = game.move({ from: src, to: tgt, promotion: 'q' });
    if (move === null) return 'snapback';
    updateStatus();
    window.setTimeout(engineMove, 250);
  }
  function onSnapEnd(){ board.position(game.fen()); }

  function updateStatus(){
    var s;
    if (!engineReady) s = 'Loading engine…';
    else if (game.in_checkmate()) s = (game.turn()==='w'?'Black':'White') + ' wins — checkmate';
    else if (game.in_draw())      s = 'Draw';
    else if (thinking)            s = 'Stockfish is thinking…';
    else s = (game.turn()==='w'?'Your move (White)':'Black to move') + (game.in_check()?' — check!':'');
    $status.textContent = s;
  }

  var board = Chessboard('board', {
    draggable: true,
    position: 'start',
    pieceTheme: 'vendor/img/chesspieces/wikipedia/{piece}.png',
    onDragStart: onDragStart, onDrop: onDrop, onSnapEnd: onSnapEnd
  });
  window.addEventListener('resize', board.resize);

  document.getElementById('new').onclick  = function(){ game.reset(); board.start(); thinking=false; updateStatus(); };
  document.getElementById('flip').onclick = function(){ board.flip(); };
})();
</script>
</html>
HTML
  cd ..
  echo "  OK -> chess/index.html (chessboard.js + chess.js + Stockfish 18, fully offline)."
}

# ---- FreeCell / Sudoku / Wordle: BUNDLED self-contained games (tracked in repo) ----
fetch_freecell(){
  echo "== freecell =="
  echo "  bundled: freecell/index.html is committed in this repo (self-contained,"
  echo "  no deps). Nothing to fetch -- just copy freecell/ to the stick as-is."
}

# ---- Brogue: REAL offline game = freethenation/broguejs asm.js build.
#      A hidden iframe (brogue.html) runs the engine; the parent index.html draws
#      glyphs to a canvas and forwards keyboard/mouse via postMessage. asm.js =
#      pure JS, so no WASM/threads/headers -> serves fine off busybox httpd.
#      ~5 MB. (This is classic Brogue, not Brogue CE -- the CE web port needs a
#      node websocket server and can't run as static files.) ----
fetch_brogue(){
  echo "== brogue =="
  mkdir -p brogue/vendor
  cd brogue
  ok=1
  get "$JQUERY_URL"            vendor/jquery.min.js || ok=0   # index.html pulls jQuery off a CDN; vendor it
  get "$BROGUE_BASE/index.html"      index.html      || ok=0
  get "$BROGUE_BASE/brogue.html"     brogue.html     || ok=0
  get "$BROGUE_BASE/brogue.html.mem" brogue.html.mem || ok=0
  get "$BROGUE_BASE/brogue.js"       brogue.js       || ok=0

  if [ "$ok" != 1 ]; then
    echo "  !! a download failed -- NOT keeping index.html so brogue won't ship broken."
    rm -f index.html
    cd ..
    return 1
  fi

  # Point the launcher at the vendored jQuery instead of the cdnjs URL (offline).
  sed -i 's#https://cdnjs.cloudflare.com/ajax/libs/jquery/[0-9.]*/jquery.js#vendor/jquery.min.js#' index.html
  if grep -q 'cdnjs.cloudflare.com' index.html; then
    echo "  !! failed to localize jQuery in index.html -- removing so it won't ship online-dependent."
    rm -f index.html; cd ..; return 1
  fi
  # Hide the upstream demo banner (we launch this from our own portal). Hidden via
  # CSS rather than deleted, because the launcher's init still references #request-fullscreen.
  sed -i 's|</head>|<style>#project-info{display:none!important}</style></head>|' index.html
  # Force text (non-emoji) glyph rendering: some symbol codepoints (e.g. Virgo U+264D)
  # get swapped for color emoji on canvas. Appending VS15 (U+FE0E) forces a text glyph.
  sed -i 's|String.fromCharCode(char), x, y|String.fromCharCode(char,0xFE0E), x, y|' index.html
  cd ..
  echo "  OK -> brogue/index.html (asm.js Brogue, fully offline). Arrow keys / mouse to play."
}

# ---- Mindustry Classic: TODO, needs a build (can't just be fetched) ----
# The GWT browser build (minidogg/mindustry-browser) loads art at runtime but
# ships it as 0-byte stubs. Upstream Anuken/Mindustry-Classic has the real art,
# but only as ~376 raw PNGs under assets-raw/ that must be packed into a sprite
# atlas (sprites.png + sprites.atlas) by libgdx's Gradle TexturePacker. So this
# needs a Java/Gradle build, not a download -- left as a TODO.
fetch_mindustry(){
  echo "== mindustry (TODO -- needs a Gradle/TexturePacker build, nothing fetched) =="
  echo "  GWT code (assets stubbed): https://github.com/minidogg/mindustry-browser"
  echo "  Raw art + source:          https://github.com/Anuken/Mindustry-Classic"
  echo "  Pack assets-raw/ -> sprites.atlas via libgdx TexturePacker, overlay onto the"
  echo "  GWT build's assets/, then drop the result as mindustry/index.html."
}

# ---- OpenTTD: TODO, needs an emscripten build (can't just be fetched) ----
# No prebuilt static web build is published to download. You compile it yourself
# with emscripten (emcc), bundle a baseset (OpenGFX) into the .data, and watch for
# a threads build that would demand COOP/COEP headers the busybox httpd can't send.
fetch_openttd(){
  echo "== openttd (TODO -- needs an emscripten build, nothing fetched) =="
  echo "  https://www.openttd.org / https://github.com/OpenTTD/OpenTTD"
  echo "  Build with emscripten (single-threaded!), bundle OpenGFX base graphics,"
  echo "  then drop the static output as openttd/index.html."
}

case "${1:-all}" in
  chess) fetch_chess;; freecell) fetch_freecell;; brogue) fetch_brogue;;
  mindustry) fetch_mindustry;; openttd) fetch_openttd;;
  all) fetch_chess; fetch_freecell; fetch_brogue; fetch_mindustry; fetch_openttd;;
  *) echo "usage: $0 [all|chess|freecell|brogue|mindustry|openttd]"; exit 1;;
esac

echo
echo "done. Games that now have an index.html will ship; the rest are skipped."
echo "Populate the stick with:  ./build-stick.sh /path/to/mounted/FAT32/stick"
echo "  (or, for the WSL/no-USB workflow:  ./build-stick.sh ~/trippy-out  then copy in Explorer)"
