# trippy games portal

Offline browser games for the vacation box. The **portal page**
(`../extern_root/opt/portal.html`, bind-mounted over the stock `main.html`) shows
a button per game and probes each `index.html` to mark it installed / not.

## Where games live (on the device)
Games are **large** and are NOT part of the `extern_package` image. They live on
the **FAT stick root** at `/data/UsbDisk1/Volume1/games/<slug>/` and are served by
the stock `fileserv` on **:80** (verified: it serves files off the stick). The
portal links to each game's **`index.html` file** (linking a *directory* 401s on
this firmware; linking the file returns 200 with no auth).

```
/data/UsbDisk1/Volume1/games/
  brogue/index.html
  mindustry/index.html
  openttd/index.html
  freeciv/index.html      (or swap for micropolis/ -- pure static SimCity classic)
  chess/index.html
  freecell/index.html
```

## How to populate
The device's busybox `wget` is **HTTP-only (no TLS)** and most sources are HTTPS
(GitHub/itch), so **run `fetch-games.sh` on a laptop or acorn** (has curl+TLS),
then copy the populated `games/` tree onto the stick. Don't commit the payloads
(this dir's `.gitignore` keeps only scaffolding).

```
./fetch-games.sh           # downloads what it can into ./<slug>/
# then: cp -a brogue mindustry openttd freeciv chess freecell  /media/<stick>/games/
```

## Sources (see fetch-games.sh)
| game            | source | approx size | notes |
|-----------------|--------|-------------|-------|
| Brogue CE       | github.com/tmewett/BrogueCE (find a WASM web build) | 5-15 MB | deepest single-player pick |
| Mindustry Class.| anuke.itch.io/mindustry-classic ; github.com/Anuken/Mindustry-Classic | 20-60 MB | itch download is manual |
| OpenTTD         | github.com/OpenTTD/OpenTTD (use an Emscripten/WASM web build) | 30-80 MB | needs base graphics (OpenGFX) |
| Freeciv Web     | github.com/freeciv/freeciv-web | 50-150 MB | complex to self-host; Micropolis is the static alternative |
| Chess           | chessboardjs (github.com/oakmac/chessboardjs) + stockfish.js (github.com/nmrugg/stockfish.js) | <5 MB | fetch-games.sh assembles the glue index.html |
| FreeCell        | **bundled** -- `freecell/index.html` in this repo | ~10 KB | our own single-file static game; just copy to the stick |

## Hosting caveats
- **Threaded WASM** (SharedArrayBuffer) needs `Cross-Origin-Opener-Policy` +
  `Cross-Origin-Embedder-Policy` headers, which `fileserv` does NOT send. Prefer
  **single-threaded / asm.js** builds, or ones that don't require SAB.
- Set correct MIME for `.wasm` if a game misbehaves (fileserv may serve
  `application/octet-stream`); most loaders cope, some need `application/wasm`.
- Total target: ~150-350 MB optimized, comfortably under 500 MB with saves.
