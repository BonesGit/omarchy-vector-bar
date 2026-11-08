#!/usr/bin/env bash
# Copy this repo into the Omarchy user plugin dir.
# The toggle (bin/vector-toggle) floats the window and sets its size and
# position at launch — no Hyprland config file of ours is needed. For
# installs that still have the old managed window-rule block, this script
# removes it.
# Live bar instances do not pick this up until:
#   omarchy restart shell
# Do not restart the shell from this script.
set -euo pipefail

src="$(cd "$(dirname "$0")" && pwd)"
dest="${HOME}/.config/omarchy/plugins/io.github.bonesgit.omarchy-vector-bar"
hyprland_conf="${HOME}/.config/hypr/hyprland.lua"

mkdir -p "$dest"
rsync -a --delete --exclude .git --exclude .hermes "$src/" "$dest/"
chmod +x "$dest/bin/vector-toggle" "$dest/bin/vector-esc"
omarchy plugin validate "$dest"
echo "Installed $dest"

# Hyprland: remove the old managed block (o.window rule + require), if present.
if grep -q "omarchy-vector: begin" "$hyprland_conf" 2>/dev/null; then
  python3 - "$hyprland_conf" <<'EOF'
import sys
p = sys.argv[1]
lines = open(p).readlines()
out, skip = [], False
for ln in lines:
    if "omarchy-vector: begin" in ln:
        skip = True
        continue
    if "omarchy-vector: end" in ln:
        skip = False
        continue
    if not skip:
        out.append(ln)
open(p, "w").writelines(out)
EOF
  rm -f "${HOME}/.config/hypr/vector.lua"
  echo "Removed managed Hyprland block from $hyprland_conf (then: hyprctl reload)"
else
  echo "No managed Hyprland block to remove"
fi

echo
echo "Then: omarchy restart shell"
echo "Enable once: omarchy plugin enable io.github.bonesgit.omarchy-vector-bar --section right --after omarchy.tray"
echo
echo "If you previously enabled io.github.bonesgit.omarchy-vector, disable that"
echo "entry and enable the new id above (settings migrate automatically)."
echo
echo "Optional Escape bind — add to ~/.config/hypr/bindings.lua:"
echo "  o.bind(\"ESCAPE\", \"Hide Vector if focused (Vector Bar)\","
echo "    os.getenv(\"HOME\") .. \"/.config/omarchy/plugins/io.github.bonesgit.omarchy-vector-bar/bin/vector-esc\")"
echo
echo "Vector binary: set PATH, install a Vector.desktop, drop an AppImage in"
echo "~/Applications, or set the Vector Bar \`command\` setting. See README.md."
