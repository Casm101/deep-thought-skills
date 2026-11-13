# Drawing, and the traps that make a drawing lie

## Wiring diagrams

Nothing to write. `circuit.sh render` turns the netlist into WireViz input and draws it.

Every part becomes a connector and every connection a wire. A net touching several parts becomes one
wire from its source to each of the others, which is how it gets wired: one ground wire from the
board to the sensor and another to the relay. Wires between the same two parts are bundled into one
cable.

Colours: ground is black, a supply is red, everything else takes the next colour in turn. Override a
net's colour under `wires:` in the netlist. Every wire is labelled with its net name and both ends,
`U1:3:GPIO23  GN:RELAY_IN  K1:2:IN`, so even where two wires cross the label says which goes where.

It writes the PNG, the SVG, an HTML page, and a parts list as `<slug>.bom.tsv`.

## Schematics

`schematic.py`, beside the netlist, built with `dtc`, the helper in this skill's scripts directory.
`render` puts it on the path.

```python
import dtc
import schemdraw.elements as elm

d = dtc.drawing(unit=3)
bat = dtc.part(d, elm.BatteryCell().up().label('BT1 9V', loc='bottom', ofst=0.6), 'BT1', start='-', end='+')
dtc.part(d, elm.Switch().right().label('S1'), 'S1')
dtc.part(d, elm.Resistor().right().label('R1\n470Ω'), 'R1')
dtc.part(d, elm.LED().down().label('D1\nred', loc='bottom'), 'D1', start='A', end='K')
d.add(elm.Line().left().tox(bat.start))
dtc.rail(d, elm.Ground().at(bat.start), 'GND')
dtc.done(d)
```

**Register every part with `dtc.part`**, giving its designator and naming its pins. A two-terminal
part defaults to `1` at its start and `2` at its end. Name the pins for anything with a polarity,
because the direction you draw it in decides which end is which: an LED drawn downward from the
resistor is `start='A', end='K'`.

**An `Ic` registers every pin by name.** Build it from `elm.IcPin(name=...)`, and the names must match
the netlist's.

**Wires need no registering.** `elm.Line` and `elm.Wire` are read as conductors.

**`dtc.rail` for ground and supply symbols.** Every rail with the same net name is one net, whether or
not a wire joins them, which is the schematic convention.

**`dtc.done(d)` last.** It writes the SVG and the geometry file the check reads. A part drawn without
`dtc.part` is invisible to the check, and `done` names any it finds.

## How the check reads a schematic

It rebuilds the nets the way a person reads the picture, then compares them with the netlist.

- Wires sharing an endpoint join.
- A wire ending on another wire's side is a T junction, and joins.
- A junction dot joins every wire its drawn circle covers.
- Two wires that only cross, with no dot, stay apart. That is the convention.
- Two wires drawn over each other, or so close they draw as one line, join.

All of it with a visual tolerance of about a line's width, because a reader judges by eye. Exact
geometry missed a real short: a dot whose centre was a tenth of a unit off a wire still covered it.

A short is reported with where it happens, dots and overlaps first: `It happens at: the junction dot
at (8.2, 0.5); two wires drawn over each other between (3.5, 0.5) and (8.2, 0.5)`.

## The routing traps

Each of these produced a drawing that looked fine and was wrong.

**`elm.Wire('-|')` runs to the target's x before turning.** Several wires heading to one column all
land on the same vertical and share it. That joined 3V3, a GPIO and the relay's ground into one net.

**`elm.Wire('z')` draws diagonals**, not right angles, and they cross other wires at points that look
like junctions.

**A junction dot is placed by its centre but read by its circle.** Put it exactly on the junction, or a
neighbouring wire inside its radius is joined to the net.

**Labels are placed automatically and can land on symbols.** A battery label put the voltage on the
ground symbol beneath it. The check cannot see that; looking at the PNG can.

All of which is why pin-to-pin module wiring belongs in a wiring diagram, where nothing is routed by
hand.

## Rendering

`circuit.sh` makes a private environment once, at `~/.cache/dt-circuit/venv`, holding SchemDraw,
WireViz and PyYAML. No run installs anything into the user's Python or the project.

Graphviz is the one system dependency. WireViz needs its `dot`, and `rsvg-convert`, which turns a
schematic's SVG into a PNG, comes with it. When either is missing the script stops and names the
install: `brew install graphviz`. It never installs it.

**The image has to be somewhere the caller can open it.** `~/diagrams` may be outside what an agent is
allowed to read. If the PNG cannot be opened, copy it somewhere that can be, look at it there, and
remove the copy.
