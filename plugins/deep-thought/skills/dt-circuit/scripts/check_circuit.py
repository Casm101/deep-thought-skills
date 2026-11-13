"""Check a circuit's connection list, and check a drawing against it.

Usage: check_circuit.py <netlist.yaml> [--geometry <drawing.geometry.json>]

The netlist is the design. Every check here reads it, and a drawing is only
ever compared against it, never trusted on its own: a drawing can look tidy
and still join two wires a reader would wire together.

Exit 0 clean, 1 warnings only, 2 errors, 3 the input could not be read.
Mains anywhere in the design forces at least 1, because nothing at mains
voltage is ever reported as checked.
"""
import json, sys
from collections import defaultdict

try:
    import yaml
except ImportError:
    sys.exit("check_circuit: PyYAML is missing. Run circuit.sh, which sets up its own environment.")

# Pins a part of a known kind has when the netlist does not list them.
DEFAULT_PINS = {
    "resistor": ["1", "2"], "capacitor": ["1", "2"], "inductor": ["1", "2"],
    "switch": ["1", "2"], "button": ["1", "2"], "fuse": ["1", "2"],
    "led": ["A", "K"], "diode": ["A", "K"], "zener": ["A", "K"],
    "battery": ["+", "-"], "polarized_capacitor": ["+", "-"],
}
DRIVERS = {"power_out", "output", "io"}
RECEIVERS = {"power_in", "input", "io"}
MAINS_VOLTS = 50

errors, warnings, assumptions = [], [], []


def err(m): errors.append(m)
def warn(m): warnings.append(m)


def load(path):
    try:
        with open(path) as f:
            doc = yaml.safe_load(f) or {}
    except Exception as e:
        print(f"check_circuit: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(3)
    if not isinstance(doc.get("parts"), dict) or not isinstance(doc.get("nets"), dict):
        print("check_circuit: the netlist needs a 'parts' map and a 'nets' map.", file=sys.stderr)
        sys.exit(3)
    return doc


def volts(v):
    """A pin's voltage as (low, high). A number is exact; a list is a range it accepts."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return (float(v), float(v))
    if isinstance(v, (list, tuple)) and len(v) == 2:
        return (float(min(v)), float(max(v)))
    return None


def pins_of(parts):
    """Every pin, as 'REF.PIN' -> its attributes, defaulted from the part's kind."""
    out = {}
    for ref, p in parts.items():
        p = p or {}
        listed = p.get("pins")
        if listed is None:
            listed = {n: {} for n in DEFAULT_PINS.get(p.get("kind", ""), [])}
        elif isinstance(listed, list):
            listed = {str(n): {} for n in listed}
        if not listed:
            err(f"{ref} has no pins, and kind '{p.get('kind')}' has no default set. List them.")
        for name in list(listed):
            # YAML reads an unquoted NO, ON, OFF, Y or N as a boolean, so a relay's normally
            # open pin silently becomes a pin called False and every reference to it misses.
            if isinstance(name, bool):
                err(f"{ref} has a pin YAML read as {name}. A pin named NO, ON, OFF, Y or N must "
                    f"be quoted: \"NO\": {{}}.")
        if p.get("assumed"):
            assumptions.append(f"{ref}: {p['assumed'] if isinstance(p['assumed'], str) else 'the part itself'}")
        for name, attrs in listed.items():
            a = dict(attrs or {})
            if a.get("assumed"):
                assumptions.append(f"{ref}.{name}: {a['assumed'] if isinstance(a['assumed'], str) else 'pin and its voltage'}")
            a["_part"] = ref
            a["_kind"] = p.get("kind", "")
            if p.get("mains"):
                a["mains"] = True
            out[f"{ref}.{name}"] = a
    return out


def check_netlist(doc):
    parts, nets = doc["parts"], doc["nets"]
    pins = pins_of(parts)
    pin_net = {}

    for net, members in nets.items():
        if not isinstance(members, list) or not members:
            err(f"net {net} lists no pins")
            continue
        for m in members:
            m = str(m)
            if m not in pins:
                ref = m.split(".")[0]
                err(f"net {net}: {m} does not exist" + ("" if ref in parts else f", and there is no part {ref}"))
                continue
            if m in pin_net and pin_net[m] != net:
                err(f"{m} is in both {pin_net[m]} and {net}, which shorts those two nets together at that pin")
            pin_net[m] = net
        if len(members) == 1:
            warn(f"net {net} has one pin, {members[0]}, so it connects to nothing")

    # Every pin is either connected or marked nc.
    for pin, a in pins.items():
        if pin not in pin_net and a.get("role") != "nc":
            warn(f"{pin} is not connected. Mark it 'role: nc' if that is intended.")

    for net, members in nets.items():
        attrs = [(m, pins[m]) for m in map(str, members) if m in pins]
        roles = {m: a.get("role") for m, a in attrs}
        grounds = [m for m, r in roles.items() if r == "ground"]
        sources = [(m, a) for m, a in attrs if a.get("role") == "power_out"]

        # A supply and a ground on one net is a dead short.
        if grounds and sources:
            err(f"net {net} joins supply {sources[0][0]} to ground {grounds[0]}. That is a short circuit.")
        # Two supplies at different voltages on one net fight each other.
        vs = {m: volts(a.get("v")) for m, a in sources if volts(a.get("v"))}
        if len({v for v in vs.values()}) > 1:
            err(f"net {net} ties together supplies at different voltages: "
                + ", ".join(f"{m} at {v[0]:g}V" for m, v in vs.items()))

        # Voltage compatibility, driver against receiver. A pin drives at `v` and accepts
        # `accepts`, falling back to `v`. One number cannot say both: a DHT22's data pin
        # accepts 3.3 to 5V but drives at whatever it is powered from.
        for dm, da in attrs:
            if da.get("role") not in DRIVERS:
                continue
            dv = volts(da.get("v"))
            if not dv:
                continue
            for rm, ra in attrs:
                if rm == dm or ra.get("role") not in RECEIVERS:
                    continue
                rv = volts(ra.get("accepts", ra.get("v")))
                if not rv:
                    continue
                if dv[1] > rv[1] * 1.05:
                    err(f"net {net}: {dm} at {dv[1]:g}V drives {rm}, rated to {rv[1]:g}V. "
                        f"Over-voltage can destroy {ra['_part']}.")
                elif dv[1] < rv[0] * 0.95:
                    warn(f"net {net}: {dm} at {dv[1]:g}V drives {rm}, which expects {rv[0]:g}V. "
                         f"It may not register as high, or may not power up. A level shifter or "
                         f"a {rv[0]:g}V supply fixes it.")

    # An LED needs something to limit its current, on one side or the other.
    for ref, p in parts.items():
        if (p or {}).get("kind") != "led":
            continue
        sides = [pin_net.get(f"{ref}.A"), pin_net.get(f"{ref}.K")]
        limited = False
        for side in filter(None, sides):
            for m in nets.get(side, []):
                if pins.get(str(m), {}).get("_kind") == "resistor":
                    limited = True
        if not limited and all(sides):
            warn(f"{ref} has no series resistor on either side, so nothing limits its current. "
                 f"It will burn out, or take the pin driving it with it.")

    # A part with a ground pin needs that ground to go somewhere else.
    ground_nets = {pin_net[p] for p, a in pins.items() if a.get("role") == "ground" and p in pin_net}
    for net in ground_nets:
        gpins = [m for m in nets[net] if pins.get(str(m), {}).get("role") == "ground"]
        if len(gpins) == 1 and len(nets[net]) == 1:
            err(f"{gpins[0]} is the only ground on net {net}, so its part has no return path")

    mains = [p for p, a in pins.items() if a.get("mains") or (volts(a.get("v")) or (0, 0))[1] >= MAINS_VOLTS]
    return pins, pin_net, mains


# ---------------------------------------------------------------- the drawing

EPS = 1e-3
# How close two marks can be before a reader sees them as touching, in drawing units.
# A 2pt line is about 0.055 units wide, so wires nearer than this blur into one, and a
# wire ending this close to another reads as a junction. Exact geometry is the wrong
# test: a dot whose centre is 0.1 off a wire still covers it, and the reader wires it.
VIS = 0.1


def _key(p):
    return (round(p[0] / EPS) * EPS, round(p[1] / EPS) * EPS)


def _dist_to_segment(p, a, b):
    (px, py), (ax, ay), (bx, by) = p, a, b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    cx, cy = ax + t * dx, ay + t * dy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def _near(p, a, b, tol=VIS):
    return _dist_to_segment(p, a, b) <= tol


def _overlap(a, b, c, d):
    """True when segments ab and cd run side by side, closer than VIS, for a real stretch.

    Two wires meeting at a point, or crossing, do not overlap. Two that share a run of
    line, or sit so close they draw as one thick line, do.
    """
    ux, uy = b[0] - a[0], b[1] - a[1]
    vx, vy = d[0] - c[0], d[1] - c[1]
    lu, lv = (ux * ux + uy * uy) ** 0.5, (vx * vx + vy * vy) ** 0.5
    if lu < EPS or lv < EPS:
        return False
    if abs(ux * vy - uy * vx) / (lu * lv) > 0.02:      # not parallel
        return False
    if _dist_to_segment(c, a, b) > VIS and _dist_to_segment(d, a, b) > VIS \
            and _dist_to_segment(a, c, d) > VIS and _dist_to_segment(b, c, d) > VIS:
        return False
    # Shared length, measured along ab's direction.
    ex, ey = ux / lu, uy / lu
    proj = sorted([0.0, lu])
    q = sorted([(c[0] - a[0]) * ex + (c[1] - a[1]) * ey, (d[0] - a[0]) * ex + (d[1] - a[1]) * ey])
    shared = min(proj[1], q[1]) - max(proj[0], q[0])
    return shared > VIS


class DSU:
    def __init__(self): self.p = {}
    def find(self, x):
        self.p.setdefault(x, x)
        while self.p[x] != x:
            self.p[x] = self.p[self.p[x]]
            x = self.p[x]
        return x
    def union(self, a, b): self.p[self.find(a)] = self.find(b)


def nets_from_drawing(geo):
    """The nets a person reads off the picture, and where each join happened.

    Wires sharing an endpoint join. A wire ending on another wire's side is a T
    junction and joins. A dot joins every wire its drawn circle covers. Two wires
    that only cross, with no dot, stay apart, which is the schematic convention.
    Two wires running along the same stretch join, because a reader sees one wire.
    All of it with a visual tolerance, since a reader judges by eye.
    """
    segs = []
    for wi, w in enumerate(geo["wires"]):
        pts = w["path"]
        for i in range(len(pts) - 1):
            if _key(pts[i]) != _key(pts[i + 1]):
                segs.append((wi, tuple(pts[i]), tuple(pts[i + 1])))

    dsu = DSU()
    joins = []                      # (node a, node b, why)
    def join(a, b, why):
        # Record every join, including ones that change nothing because the two were
        # already connected. A second culprit hidden behind the first would only surface
        # on the next run, after the first was fixed.
        joins.append((a, b, why))
        dsu.union(a, b)

    for wi, _ in enumerate(geo["wires"]):
        dsu.find(("w", wi))
    endpoints = []
    for wi, a, b in segs:
        endpoints += [(wi, a), (wi, b)]

    for wi, p in endpoints:
        for wj, a, b in segs:
            if wj != wi and _near(p, a, b):
                join(("w", wi), ("w", wj), f"a wire ends on another at ({p[0]:.1f}, {p[1]:.1f})")

    for dot in geo.get("dots", []):
        pt, r = tuple(dot["at"]), dot.get("r", 0.075)
        hit = sorted({wi for wi, a, b in segs if _near(pt, a, b, r + VIS / 2)})
        for w in hit[1:]:
            join(("w", hit[0]), ("w", w), f"the junction dot at ({pt[0]:.1f}, {pt[1]:.1f})")

    for i in range(len(segs)):
        for j in range(i + 1, len(segs)):
            wi, a, b = segs[i]
            wj, c, d = segs[j]
            if wi != wj and _overlap(a, b, c, d):
                join(("w", wi), ("w", wj),
                     f"two wires drawn over each other between ({a[0]:.1f}, {a[1]:.1f}) and ({b[0]:.1f}, {b[1]:.1f})")

    terms = [(t["pin"], tuple(t["at"])) for t in geo["terminals"]]
    for pin, p in terms:
        dsu.find(("t", pin))
        for wi, a, b in segs:
            if _near(p, a, b):
                join(("t", pin), ("w", wi), f"{pin} touches a wire")
    for i in range(len(terms)):
        for j in range(i + 1, len(terms)):
            (pa, a), (pb, b) = terms[i], terms[j]
            if ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5 <= VIS:
                join(("t", pa), ("t", pb), f"{pa} and {pb} meet at ({a[0]:.1f}, {a[1]:.1f})")

    first = {}
    for r in geo.get("rails", []):
        node = ("t", f"rail:{r['net']}")
        dsu.find(node)
        p = tuple(r["at"])
        for wi, a, b in segs:
            if _near(p, a, b):
                join(node, ("w", wi), f"the {r['net']} symbol")
        for pin, q in terms:
            if ((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2) ** 0.5 <= VIS:
                join(node, ("t", pin), f"the {r['net']} symbol at {pin}")
        if r["net"] in first:
            join(node, first[r["net"]], f"two {r['net']} symbols, which are one net by name")
        first.setdefault(r["net"], node)

    groups, why = defaultdict(set), defaultdict(list)
    for pin, _ in terms:
        groups[dsu.find(("t", pin))].add(pin)
    for r in geo.get("rails", []):
        groups[dsu.find(("t", f"rail:{r['net']}"))].add(f"rail:{r['net']}")
    for a, b, reason in joins:
        why[dsu.find(a)].append(reason)
    return [(g, why[root]) for root, g in groups.items() if any(not m.startswith("rail:") for m in g)]


def compare(doc, pin_net, drawn):
    """Every drawn net must be exactly one netlist net, and the other way round."""
    nets = {n: set(map(str, ms)) for n, ms in doc["nets"].items()}
    drawn_pins = set()
    for g, _ in drawn:
        drawn_pins |= g
    for pin in sorted(set(pin_net) - drawn_pins):
        err(f"{pin} is in the netlist but not in the drawing")
    for g, reasons in drawn:
        real = {m for m in g if not m.startswith("rail:")}
        for pin in sorted(real - set(pin_net)):
            err(f"the drawing connects {pin}, which the netlist does not have on any net")
        which = {pin_net[m] for m in real if m in pin_net}
        which |= {m[5:] for m in g if m.startswith("rail:") and m[5:] in nets}
        if len(which) > 1:
            # Name the joins that are not ordinary pin-to-wire contacts: those are the culprits.
            # A dot or two wires drawn over each other is the likeliest mistake, so those lead.
            rank = lambda r: 0 if "dot" in r else 1 if "over each other" in r else 2
            suspects = sorted((r for r in dict.fromkeys(reasons) if "touches a wire" not in r), key=rank)
            err("the drawing joins nets the netlist keeps apart: " + ", ".join(sorted(which))
                + f" (through {', '.join(sorted(real))}). Wired as drawn, that is a short."
                + (" It happens at: " + "; ".join(suspects[:6]) + "." if suspects else ""))
    for net, members in nets.items():
        holding = [g for g, _ in drawn if members & g]
        if len(holding) > 1:
            err(f"net {net} is broken in the drawing into {len(holding)} pieces: "
                + " | ".join(", ".join(sorted(members & g)) for g in holding))


def table(doc):
    """The connections as a table, which is what someone wiring the thing works from."""
    parts = doc["parts"]
    print(f"| Net | Connects |\n|---|---|")
    for net, members in doc["nets"].items():
        cells = []
        for m in map(str, members):
            ref, pin = m.split(".", 1)
            name = (parts.get(ref) or {}).get("name") or (parts.get(ref) or {}).get("kind", "")
            cells.append(f"{ref} {pin}" + (f" ({name})" if name else ""))
        print(f"| {net} | {' to '.join(cells) if len(cells) == 2 else ', '.join(cells)} |")


def main():
    if len(sys.argv) >= 2 and "--table" in sys.argv:
        table(load(sys.argv[1]))
        return
    if len(sys.argv) < 2:
        sys.exit("usage: check_circuit.py <netlist.yaml> [--geometry <drawing.geometry.json>]")
    doc = load(sys.argv[1])
    pins, pin_net, mains = check_netlist(doc)

    geo_path = sys.argv[sys.argv.index("--geometry") + 1] if "--geometry" in sys.argv else None
    if geo_path:
        with open(geo_path) as f:
            geo = json.load(f)
        compare(doc, pin_net, nets_from_drawing(geo))

    print("=== CIRCUIT CHECK ===")
    print(f"design: {doc.get('title', sys.argv[1])}")
    print(f"parts:  {len(doc['parts'])}   nets: {len(doc['nets'])}   pins: {len(pins)}")
    print(f"drawing compared: {'yes' if geo_path else 'no'}")
    if mains:
        print()
        print("!!! MAINS VOLTAGE: " + ", ".join(sorted(mains)[:6]))
        print("    This design is NOT checked as safe, whatever follows says.")
        print("    A qualified electrician must review it before anything is wired.")
    if assumptions:
        print("\n--- ASSUMED, NOT FROM A DATASHEET OR THE USER ---")
        for m in assumptions:
            print("  " + m)
        print("  Check each of these against the part before wiring it.")
    for title, items in (("ERRORS", errors), ("WARNINGS", warnings)):
        if items:
            print(f"\n--- {title} ---")
            for m in dict.fromkeys(items):
                print("  " + m)
    print()
    if errors:
        print(f"{len(set(errors))} error(s). Do not wire this.")
    elif warnings or mains or assumptions:
        print(f"no errors, {len(set(warnings))} warning(s), {len(assumptions)} assumption(s).")
    else:
        print("clean.")
    print("=== END ===")
    sys.exit(2 if errors else 1 if (warnings or mains or assumptions) else 0)


if __name__ == "__main__":
    main()
