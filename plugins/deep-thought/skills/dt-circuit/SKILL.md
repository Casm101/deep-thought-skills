---
name: dt-circuit
description: 'Design a circuit or a wiring setup from a plain description, and draw it. Turns an explanation or a rough plan into a connection list, interviews for whatever the description leaves open, checks the design for shorts, missing grounds, mismatched voltages and LEDs with nothing limiting their current, then draws a proper schematic with real symbols, or a pin-to-pin wiring diagram with every wire labelled at both ends. Reads the drawing back and fails it if it shows anything the connection list does not say. Hands back the image, a table to wire from, and every assumption made. Use when asked for "dt circuit" or "deep thought circuit", or to design, draw or wire up a circuit, a schematic, a wiring diagram, or how to connect a sensor, a relay, a module or a microcontroller.'
argument-hint: "What it should do, and whatever you already know: the parts, the supply, the pins."
---

# dt-circuit

Turn a description into a design someone could wire without hurting themselves or the parts.

## What decides success

Not whether the picture looks tidy. A wiring diagram can render cleanly and short a supply to ground,
and nothing in the picture says so: drawn by hand, two wires sharing a trunk read as one, and a
junction dot a fraction off its wire reads as joined to whatever it covers. Both happened while this
skill was being built.

So the **connection list is the design**. Every check reads it, the drawing is generated from it or
compared against it, and the person wiring the thing gets the list as a table as well as the picture.

**Nothing at mains voltage is ever reported as checked.** It is drawn, it is marked, and the hand-back
says a qualified electrician must review it before anything is wired, whatever else the check found.

## Phase 1. Find out what is actually being asked

Read the description and list what the design depends on: the supply and its voltage, each part and
its exact variant, which pins connect to what, and anything protective it needs, such as a flyback
diode across a relay coil or a resistor in series with an LED.

Where those are open, run `dt-grilling` on the design, invoking it with the Skill tool. A module's
pinout is the decision most worth asking about, because a confident wrong answer there destroys
hardware. When nobody is there to ask, as in an unattended run, take the most common choice, mark it
`assumed` in the netlist, and the hand-back lists it.

**Never invent a pinout or a voltage.** It comes from the user, a datasheet, or it is marked assumed.

## Phase 2. Choose the drawing

**A schematic** for circuits built from components: resistors, capacitors, transistors, diodes, LEDs,
switches, a regulator, an op-amp. Drawn with SchemDraw, with real symbols.

**A wiring diagram** for connecting modules and boards pin to pin: a microcontroller to a sensor, a
relay module, a display, a motor driver. Drawn with WireViz, which routes every wire on its own and
labels each with both ends, so two wires are never drawn as one.

A design that is both, such as a sensor board wired to a microcontroller, is a wiring diagram, with
the board as one part.

## Phase 3. Write the netlist

Under `~/diagrams/<slug>/`, as `netlist.yaml`. Never inside a repository.

Parts, each with its pins, their roles and voltages, then nets, each a list of the pins tied together.
`references/netlist.md` has the format, every role, the difference between the voltage a pin drives
and the range it accepts, and a worked example. Read it before writing one, because a few of its
rules are not guessable: a relay's `NO` pin has to be quoted, or YAML reads it as false.

## Phase 4. Check it before drawing anything

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-circuit/scripts/circuit.sh check ~/diagrams/<slug>
```

Exit 2 means errors. Fix every one before going further, because a drawing of a broken design is a
well-presented broken design. Exit 1 means warnings, assumptions or mains: carry them to the hand-back
and change nothing silently, because a warning such as a 3.3V pin driving a 5V input is a trade-off
the person deciding should see.

## Phase 5. Draw it

**Wiring** needs nothing more written: the drawing is generated from the netlist.

**Schematic** needs `schematic.py` beside the netlist, written with the small helper in the scripts
directory that records which terminal is which pin. `references/drawing.md` covers it, and the routing
traps that produced the two dangerous drawings above.

```bash
${CLAUDE_PLUGIN_ROOT}/skills/dt-circuit/scripts/circuit.sh render ~/diagrams/<slug>
```

For a schematic, render also reads the nets back out of the drawing the way a person would and
compares them with the netlist. An error naming a net the drawing joins or breaks means the picture
says something the design does not. Fix the drawing and render again.

## Phase 6. Look at it

Open the PNG and read it. The check sees connections, not legibility: a label sitting on a ground
symbol, a value hidden under a wire, or two parts crowded into one another all pass it. Fix what you
see and render again.

## Phase 7. Hand it back

The PNG, the table from `circuit.sh table`, and the check result, with every warning and assumption
written out. Lead with the mains notice when there is one. Then say what it does in two or three
sentences, and which choices the person may want to change.

Run `dt-unslop` over that prose before it goes out, leaving part names, pin names and values alone.

## Never

- Never draw before the netlist exists. The drawing is checked against it, so it comes first.
- Never hand back a design whose check failed as something to wire.
- Never present anything at mains voltage as checked or safe, and never leave out the notice.
- Never invent a pinout or a voltage. Ask, read the datasheet, or mark it assumed and say so.
- Never route pin-to-pin module wiring by hand in a schematic. Use a wiring diagram.
- Never fix a warning by quietly changing the design. Report it and let the person choose.
- Never install a system package. Name what is missing, the way the script does.
- Never write a design inside a repository.

---

If this run taught something general about how this skill should work, fold it in with
`dt-auto-improve-skill`.
