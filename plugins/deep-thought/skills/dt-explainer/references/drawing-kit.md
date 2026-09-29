# Drawing a scene

A scene is `{ id, title, caption, dur, sfx?, draw(p, t) }`. `p` runs 0 to 1 through the scene and `t`
is seconds into it. Coordinates are centre based in a 1920x1080 space, and colours come from `C.*`.

## The rules `draw` has to obey

These are not style. The export seeks to a time and screenshots, so a scene that breaks one of them
plays correctly and exports wrong, which is the hardest failure here to diagnose.

**`draw(p, t)` is a pure function of time.** No state kept between frames, no `Math.random` (use
`rng(seed)`), no timers, no `Date.now`, no CSS transitions or animations. Seeking to any `t` twice has
to give the same frame twice.

**Colours come from `C.*` only.** A hard-coded hex looks right in whichever theme it was written
against and wrong in the other.

**Text stays 22px or larger** in the 1920x1080 space, and the bottom 16% stays clear because the
caption sits there.

**One idea per scene.** Stagger entrances with `seg` windows, and hold the finished state for the last
quarter of the scene so it can be read.

## The kit

| Call | For |
|---|---|
| `box({x, y, w, h, label, sub, mono, stroke, fill, scale, alpha})` | a component, a service, a store |
| `arrow({from, to, p, color, dashed, label})` | a relationship, drawn in as `p` advances |
| `travel({path, p, color, text, hideAtEnd})` | a dot along a polyline, for a request or an event |
| `pulse({x, y, p, color, r1})` | something happened here |
| `codeBlock({x, y, lines, highlight, p, w})` | top left anchored, lines reveal with `p` |
| `label(text, x, y, {size, weight, color, align, mono, alpha})` | free text |

Timing helpers: `seg(p, a, b)`, `appear(p, a, b)`, `ease.out`, `ease.inOut`, `ease.back`, `lerp`,
`clamp`, `rng(seed)`.

Where the kit has no shape for something, write a scene-local helper above `SCENES` and keep it pure.
Adding to the template itself is how one explainer's need becomes every explainer's problem.

## Sound

`sfx: [[secondsIntoScene, name]]`, with names from `tick`, `blip`, `pop`, `whoosh`, `chime`, `thud`.

One to four cues a scene, each marking a real event: a request sent, a cache hit, an error. `thud` for
a failure, `chime` for the resolved state. A cue that only decorates makes the rest mean less.

Sound is off unless the user asked for it, and every cue name has to be one of the six above.

## Exporting

```bash
explainer-export.sh <file.html> --stills <dir> [--theme light|dark]
explainer-export.sh <file.html> [--out x.mp4] [--fps 30] [--scale 2] [--no-audio]
```

Stills write one PNG per scene at 75% through it, need no ffmpeg, and are the verification step.

MP4 steps `window.explainer.seek(i / fps)` and screenshots each frame, so frames are exact and never
dropped. `--scale 2` gives 3840x2160 and is slower. Expect roughly real time at 1080p30, so a minute
of video takes about a minute. Run a long export in the background and report when it lands.

With audio on, the soundtrack renders offline through `OfflineAudioContext` from the same schedule and
muxes as AAC, so there is nothing separate to check beyond the cue names.

**Playwright comes from `dt-browser-run`'s cache** at `~/.cache/dt-browser-run`, installed once
against the chromium already on the machine. The wrapper seeds it when it is missing, so this skill
needs no global playwright install of its own. A global copy is still used when one exists.

**ffmpeg is checked before rendering**, because finding out after a minute of frames that nothing can
be muxed is a minute wasted. It is not installed on this machine.

## When it looks wrong

**A blank scene** means `alpha` or `scale` sat at 0 for the whole window. Check the `seg` ranges
against `p`.

**A frame that differs between playing and exporting** means the scene reads state or a random value.
That is the purity rule, and it is the only cause.

**Sound that only starts after a click** is the browser requiring a gesture first. The Play button is
that gesture, and this is expected rather than a fault.

**A caption covering the drawing** means content sits below y 900. Move it up.

**Text that reads fine on screen and is unreadable in the still** is text under 22px. The page scales
to the viewport and the export does not.
