"""Turn a netlist into WireViz input, so a wiring diagram is drawn from the design.

Usage: to_wireviz.py <netlist.yaml> <out.yml>

Every part becomes a connector and every connection a wire. WireViz routes each
wire on its own, so two wires are never drawn as one, and it labels each wire
with both of its ends. A net touching several parts becomes one wire from its
source to each of the others, which is how it gets wired.
"""
import sys
from collections import defaultdict

import yaml

GROUND, SUPPLY = "BK", "RD"
PALETTE = ["BU", "GN", "YE", "VT", "OG", "WH", "GY", "BN", "PK", "TQ"]


def pin_list(part):
    pins = part.get("pins")
    if pins is None:
        from check_circuit import DEFAULT_PINS
        return [str(p) for p in DEFAULT_PINS.get(part.get("kind", ""), [])], {}
    if isinstance(pins, list):
        return [str(p) for p in pins], {}
    return [str(p) for p in pins], {str(k): (v or {}) for k, v in pins.items()}


def main():
    src, out = sys.argv[1], sys.argv[2]
    doc = yaml.safe_load(open(src))
    parts, nets = doc["parts"], doc["nets"]
    colours = {n: (w or {}).get("color") for n, w in (doc.get("wires") or {}).items()}

    connectors, attrs = {}, {}
    for ref, p in parts.items():
        p = p or {}
        names, a = pin_list(p)
        attrs[ref] = a
        label = p.get("name") or " ".join(str(x) for x in (p.get("kind"), p.get("value")) if x)
        connectors[ref] = {"type": label or ref, "pinlabels": names}
        if p.get("mains"):
            connectors[ref]["notes"] = "MAINS"

    def role(pin):
        ref, name = pin.split(".", 1)
        return attrs.get(ref, {}).get(name, {}).get("role")

    wires = []                    # (from pin, to pin, colour, net)
    spare = iter(PALETTE * 4)
    for net, members in nets.items():
        members = [str(m) for m in members]
        if len(members) < 2:
            continue
        # The source is where the signal or supply comes from, so the star starts there.
        order = {"power_out": 0, "ground": 1, "output": 2, "io": 3}
        source = min(members, key=lambda m: order.get(role(m), 9))
        kinds = {role(m) for m in members}
        colour = colours.get(net) or (GROUND if "ground" in kinds else SUPPLY if "power_out" in kinds else next(spare))
        for m in members:
            if m != source:
                wires.append((source, m, colour, net))

    # One cable per pair of parts, so a bundle reads as the wires that run together.
    cables, connections = {}, []
    bundles = defaultdict(list)
    for a, b, c, net in wires:
        pa, pb = a.split(".", 1)[0], b.split(".", 1)[0]
        key = tuple(sorted((pa, pb)))
        if (pa, pb) != key:
            a, b = b, a
        bundles[key].append((a, b, c, net))
    for i, (key, ws) in enumerate(sorted(bundles.items()), 1):
        name = f"W{i}"
        cables[name] = {"wirecount": len(ws), "colors": [w[2] for w in ws], "category": "bundle",
                        "wirelabels": [w[3] for w in ws]}
        for n, (a, b, _, _) in enumerate(ws, 1):
            ra, pa = a.split(".", 1)
            rb, pb = b.split(".", 1)
            connections.append([{ra: [pa]}, {name: [n]}, {rb: [pb]}])

    # safe_dump quotes a pin called NO or ON, so WireViz does not read it back as a boolean.
    with open(out, "w") as f:
        yaml.safe_dump({"connectors": connectors, "cables": cables, "connections": connections},
                       f, sort_keys=False, allow_unicode=True)
    print(f"wrote {out}: {len(connectors)} connectors, {len(wires)} wires in {len(cables)} cables")


if __name__ == "__main__":
    main()
