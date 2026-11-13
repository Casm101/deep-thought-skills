"""Draw a schematic with SchemDraw, and record what the drawing says is connected.

A schematic script imports this, registers each part with its designator and
pin names, and ends with done(). That writes the SVG and a geometry file
check_circuit.py reads, so the picture is checked against the netlist rather
than trusted.

    import dtc, schemdraw.elements as elm
    d = dtc.drawing()
    bt = dtc.part(d, elm.BatteryCell().up(), 'BT1', start='-', end='+')
    r1 = dtc.part(d, elm.Resistor().right().label('R1\\n470Ω'), 'R1')
    d.add(elm.Line().right())                     # wires need no registering
    dtc.rail(d, elm.Ground().at(bt.start), 'GND')
    dtc.done(d, 'circuit')

Two-terminal parts default to pins '1' at start and '2' at end. Name them
for anything with a polarity: start='A', end='K' for an LED drawn anode
first. An Ic registers every IcPin by its name.
"""
import json, os, sys
import schemdraw
import schemdraw.elements as elm
from schemdraw.segments import Segment

schemdraw.use('svg')

_PARTS = {}      # id(element) -> (ref, {anchor: pin})
_RAILS = {}      # id(element) -> net


def drawing(**config):
    d = schemdraw.Drawing(show=False)
    d.config(fontsize=config.pop('fontsize', 13), **config)
    return d


def part(d, element, ref, **pins):
    """Add a component and say which anchor is which pin."""
    e = d.add(element)
    if isinstance(e, elm.Ic):
        # `e.pins` is a dict whose keys are not the names, so iterating it registers
        # nothing and the check silently sees an Ic with no pins. `pinnames` is the list.
        names = [n for n in getattr(e, 'pinnames', []) if n]
        if not names:
            print(f'dtc: {ref} is an Ic with no named pins, so the check cannot see it', file=sys.stderr)
        _PARTS[id(e)] = (ref, {n: n for n in names}, e)
    else:
        _PARTS[id(e)] = (ref, {pins.get('start_anchor', 'start'): pins.get('start', '1'),
                               pins.get('end_anchor', 'end'): pins.get('end', '2')}, e)
    return e


def rail(d, element, net):
    """A ground or supply symbol. Every rail with the same net is one net, wired or not."""
    e = d.add(element)
    _RAILS[id(e)] = (net, e)
    return e


def _abs(e, pt):
    p = e.transform.transform(pt)
    return [round(float(p[0]), 4), round(float(p[1]), 4)]


def done(d, stem=None):
    # circuit.sh names the output after the design's directory, so a script need not.
    stem = stem or os.environ.get('DTC_STEM', 'schematic')
    d.draw(show=False)
    d.save(f'{stem}.svg')

    wires, dots, terminals, rails, loose = [], [], [], [], []
    for e in d.elements:
        if id(e) in _PARTS:
            ref, mapping, _ = _PARTS[id(e)]
            for anchor, pin in mapping.items():
                if anchor in e.absanchors:
                    a = e.absanchors[anchor]
                    terminals.append({'pin': f'{ref}.{pin}', 'at': [round(float(a[0]), 4), round(float(a[1]), 4)]})
                else:
                    print(f'dtc: {ref} has no anchor "{anchor}" for pin {pin}', file=sys.stderr)
        elif id(e) in _RAILS:
            net, _ = _RAILS[id(e)]
            a = e.absanchors['start']
            rails.append({'net': net, 'at': [round(float(a[0]), 4), round(float(a[1]), 4)]})
        elif isinstance(e, elm.Dot):
            # The radius matters: a dot joins every wire its drawn circle covers, not only
            # the ones through its exact centre.
            a = e.absanchors['center']
            r = float(e.params.get('radius', 0.075)) if hasattr(e, 'params') else 0.075
            dots.append({'at': [round(float(a[0]), 4), round(float(a[1]), 4)], 'r': r})
        elif isinstance(e, (elm.Line, elm.Wire)):
            for s in e.segments:
                if isinstance(s, Segment) and len(s.path) >= 2:
                    wires.append({'path': [_abs(e, p) for p in s.path]})
        elif not isinstance(e, (elm.Label, elm.Annotate, elm.Gap)) and type(e).__name__ not in ('Label', 'Tag'):
            loose.append(type(e).__name__)

    if loose:
        print('dtc: drawn but not registered as a part or rail, so the check cannot see them: '
              + ', '.join(loose), file=sys.stderr)
    with open(f'{stem}.geometry.json', 'w') as f:
        json.dump({'wires': wires, 'dots': dots, 'terminals': terminals, 'rails': rails,
                   'unregistered': loose}, f, indent=1)
    print(f'drew {stem}.svg: {len(terminals)} terminals, {len(wires)} wires, '
          f'{len(dots)} junction dots, {len(rails)} rails')
