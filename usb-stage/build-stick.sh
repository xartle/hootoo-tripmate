#!/bin/bash
# Build a complete trippy USB stick. Run on a laptop with the new FAT32 stick
# already formatted and mounted. This does NOT format -- it just populates.
#
#   ./build-stick.sh /media/you/TRIPPY
#
# Result on the stick:
#   /extern_package            -> modern busybox + control panel + wardrive
#                                 (auto-loads at boot via the rc.local hook that
#                                  is persisted ON the device; see TRIPPY-PROGRESS.md)
#   /games/<slug>/index.html   -> each game that has been populated
#   (add your media anywhere on the stick; the stock Files/Media app serves it)
set -e
cd "$(dirname "$0")"
DEST="${1:?usage: build-stick.sh /path/to/mounted/FAT32/stick}"
[ -d "$DEST" ] || { echo "target is not a mounted directory: $DEST"; exit 1; }

echo "[1/3] building extern_package image..."
./build-image.sh

echo "[2/3] copying extern_package to stick root..."
cp -f extern_package "$DEST/extern_package"

echo "[3/3] copying games (only dirs that have an index.html)..."
mkdir -p "$DEST/games"
for d in games/*/; do
  name=$(basename "$d")
  if [ -f "games/$name/index.html" ]; then
    echo "  + $name"
    rm -rf "$DEST/games/$name"
    cp -a "games/$name" "$DEST/games/"
  else
    echo "  - $name (empty -- run ./games/fetch-games.sh to populate, then re-run)"
  fi
done

sync
echo
echo "Done. Eject and plug into the TripMate."
echo "Bundled games: freecell, sudoku, wordle (work out of the box)."
echo "Big games (brogue/mindustry/openttd/freeciv) need fetch-games.sh first."
echo "If this is a fresh device, persist the boot hook once (see TRIPPY-PROGRESS.md),"
echo "or just run the 3 manual mount commands to start it immediately."
