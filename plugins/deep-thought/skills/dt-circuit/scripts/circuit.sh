#!/usr/bin/env bash
# Check a circuit design, draw it, and check the drawing against the design.
#
# Usage: circuit.sh check  <dir>     the netlist alone
#        circuit.sh render <dir>     draw it, then check the netlist and the drawing
#        circuit.sh table  <dir>     the connections as a markdown table, to wire from
#
# <dir> holds netlist.yaml, and schematic.py when the netlist says mode: schematic.
# Everything it writes lands in <dir>, named after the directory.
#
# Exit 0 clean, 1 warnings or mains, 2 errors, 3 the setup or the input is broken.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { printf 'circuit: %s\n' "$1" >&2; exit 3; }

CMD="${1:-}"; DIR="${2:-}"
case "$CMD" in check|render|table) ;; *) die "usage: circuit.sh check|render|table <dir>" ;; esac
[ -n "$DIR" ] && [ -d "$DIR" ] || die "no design directory at '$DIR'"
DIR="$(cd "$DIR" && pwd)"
NET="$DIR/netlist.yaml"
[ -f "$NET" ] || die "no netlist.yaml in $DIR. The netlist is the design, and is written first."
STEM="$(basename "$DIR")"

# A private environment, made once, so no run installs anything into the user's Python
# or into the project the circuit belongs to.
VENV="${DT_CIRCUIT_VENV:-$HOME/.cache/dt-circuit/venv}"
if [ ! -x "$VENV/bin/python" ] || ! "$VENV/bin/python" -c 'import schemdraw, wireviz, yaml' 2>/dev/null; then
  command -v python3 >/dev/null 2>&1 || die "python3 is not on PATH."
  printf 'circuit: setting up %s (once)\n' "$VENV" >&2
  python3 -m venv "$VENV" >/dev/null 2>&1 || die "could not create $VENV"
  "$VENV/bin/pip" install -q schemdraw wireviz pyyaml >/dev/null 2>&1 \
    || die "could not install schemdraw, wireviz and pyyaml into $VENV"
fi
PY() { PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$HERE" "$VENV/bin/python" "$@"; }

MODE=$(PY -c "import yaml,sys; print((yaml.safe_load(open(sys.argv[1])) or {}).get('mode','schematic'))" "$NET") \
  || die "netlist.yaml does not parse as YAML"

if [ "$CMD" = "check" ]; then
  PY "$HERE/check_circuit.py" "$NET"
  exit $?
fi
if [ "$CMD" = "table" ]; then
  PY "$HERE/check_circuit.py" "$NET" --table
  exit $?
fi

cd "$DIR" || die "cannot enter $DIR"
case "$MODE" in
  wiring)
    # WireViz shells out to Graphviz. Name the missing piece rather than failing inside it.
    command -v dot >/dev/null 2>&1 || die "Graphviz is not installed, and wiring mode needs it.
            Ask the user to install it: brew install graphviz"
    PY "$HERE/to_wireviz.py" "$NET" "$DIR/$STEM.yml" || die "could not turn the netlist into WireViz input"
    "$VENV/bin/wireviz" "$DIR/$STEM.yml" >/dev/null 2>&1 || die "WireViz could not draw $STEM.yml. Run it by hand to see why."
    echo "drew $DIR/$STEM.png, $STEM.svg and the parts list $STEM.bom.tsv"
    echo "the drawing is generated from the netlist, so it cannot disagree with it"
    echo
    PY "$HERE/check_circuit.py" "$NET"
    exit $?
    ;;
  schematic)
    [ -f "$DIR/schematic.py" ] || die "mode is schematic, but there is no schematic.py in $DIR"
    command -v rsvg-convert >/dev/null 2>&1 || die "rsvg-convert is missing. It comes with Graphviz: brew install graphviz"
    rm -f "$DIR/$STEM.geometry.json"
    DTC_STEM="$STEM" PY "$DIR/schematic.py" || die "schematic.py failed. Its error is above."
    [ -f "$DIR/$STEM.geometry.json" ] || die "schematic.py did not end with dtc.done(d), so there is nothing to check"
    rsvg-convert -b white -z 2 "$DIR/$STEM.svg" -o "$DIR/$STEM.png" || die "could not turn $STEM.svg into a PNG"
    echo "drew $DIR/$STEM.png and $STEM.svg"
    echo
    PY "$HERE/check_circuit.py" "$NET" --geometry "$DIR/$STEM.geometry.json"
    exit $?
    ;;
  *) die "mode '$MODE' is neither schematic nor wiring" ;;
esac
