# The netlist

One YAML file, `netlist.yaml`, and it is the design. Everything else is drawn from it or checked
against it.

## A worked example

An ESP32 reading a DHT22 on GPIO4 and switching a 5V relay module from GPIO23.

```yaml
title: ESP32 with a DHT22 and a relay
mode: wiring                       # wiring or schematic
parts:
  U1:
    kind: module
    name: ESP32 DevKit
    pins:
      3V3:    {role: power_out, v: 3.3}
      GPIO4:  {role: io, v: 3.3, accepts: [0, 3.3]}
      GPIO23: {role: output, v: 3.3}
      VIN:    {role: power_out, v: 5}
      GND:    {role: ground}
  U2:
    kind: module
    name: DHT22
    pins:
      VCC:  {role: power_in, accepts: [3.3, 5]}
      DATA: {role: io, v: 3.3, accepts: [3.3, 5]}
      GND:  {role: ground}
  K1:
    kind: module
    name: Relay module 5V
    pins:
      VCC: {role: power_in, accepts: [5, 5]}
      IN:  {role: input, accepts: [5, 5]}
      GND: {role: ground}
nets:
  3V3:      [U1.3V3, U2.VCC]
  DHT_DATA: [U1.GPIO4, U2.DATA]
  RELAY_IN: [U1.GPIO23, K1.IN]
  5V:       [U1.VIN, K1.VCC]
  GND:      [U1.GND, U2.GND, K1.GND]
wires:                             # optional, wiring mode only
  RELAY_IN: {color: GN}
```

The check passes this with one warning, and it is the right one: a 3.3V GPIO driving a 5V relay input
may not register as high. That is a real trade-off with this module, and the hand-back says so.

## Parts

A designator, then the part. `R1`, `C1`, `D1`, `Q1`, `U1`, `K1` for a relay, `S1` for a switch,
`BT1` for a battery, `J1` for a connector.

`kind` gives a part its pins when you do not list them:

| Kind | Pins |
|---|---|
| resistor, capacitor, inductor, switch, button, fuse | `1`, `2` |
| led, diode, zener | `A`, `K` |
| battery, polarized_capacitor | `+`, `-` |
| module, or anything else | listed under `pins`, always |

`name` labels it in the drawing. `value` is the resistance, capacitance or rating.

## Pins

Each pin can carry:

| Key | Means |
|---|---|
| `role` | `power_out`, `power_in`, `ground`, `output`, `input`, `io`, `passive`, `nc` |
| `v` | the voltage the pin **drives**, for a supply or an output |
| `accepts` | the range the pin **accepts**, `[low, high]`, for a supply input or an input |
| `mains` | `true` for anything at mains voltage |
| `assumed` | `true`, or the reason, when this fact did not come from a datasheet or the user |

**`v` and `accepts` are different questions.** A DHT22's data pin accepts 3.3 to 5V but drives at
whatever it is powered from. One number cannot say both, and using one produced a false over-voltage
error while this skill was built.

`role: nc` marks a pin deliberately left unconnected, so the check stops warning about it.

## Nets

A net is a name and the pins tied together: `[U1.GPIO4, U2.DATA]`. Name nets for what they carry,
`DHT_DATA` rather than `NET3`, because the names reach the wires in the drawing and the table.

A pin belongs to one net. The same pin in two nets shorts them together, and the check says so.

## Traps

**Quote pin names YAML reads as booleans.** An unquoted `NO`, `ON`, `OFF`, `Y` or `N` becomes true or
false, so a relay's normally open pin turns into a pin called `False` and every reference to it misses.
Write `"NO": {}`. The check names this when it happens rather than reporting a missing pin.

**A pin's voltage is the part's, not the board's.** An ESP32 is not 5V tolerant on its GPIOs, so
`accepts: [0, 3.3]` belongs on them even when the board is powered from 5V. This is the line that
catches a 5V sensor wired straight to a GPIO.

**Mark what you did not verify.** Pinouts written from memory are the likeliest error in a design like
this, and the most expensive. `assumed: pinout from memory` costs nothing and puts it in front of the
person before they solder.

## What the check looks for

| Finding | Severity |
|---|---|
| A pin in two nets | error |
| A supply and a ground on one net | error, a short |
| Two supplies at different voltages on one net | error |
| A driver above what a receiver accepts | error, it can destroy the part |
| A net or pin that does not exist | error |
| A ground with nowhere to return | error |
| A driver below what a receiver needs | warning |
| An LED with no resistor on either side | warning |
| A pin connected to nothing | warning, unless `nc` |
| A net with one pin | warning |
| Anything assumed | listed, never clean |
| Anything at mains voltage | notice, never clean |

Exit 0 is clean, 1 is warnings, assumptions or mains, 2 is errors, 3 is a setup problem.
