# CourtLine Round Switch — native OBS demo 0.1.0

This first Windows x64 sample uses **simulated rounds**, two fixed color sources,
and a fixed two-second delay. It does not yet connect to Scoreholio. There are no
network requests, stats, vMix commands, saved settings, or edits to existing scenes.

Use a separate **OBS 31.1.1 portable copy** for this candidate. Extract the plugin
ZIP into that portable OBS root (the folder containing `bin` and `obs-plugins`).
Launch `bin/64bit/obs64.exe --portable --multi`. Do not install into your live OBS
for the first test. The candidate blocks operation while streaming, recording,
replay buffer or virtual camera is active.

1. Open **Tools → CourtLine Round Switch Demo**.
2. Click **Create new demo scene** and confirm. This adds a new scene; it does not
   select it or alter an existing scene. A name collision refuses creation.
3. Select **CourtLine Round Demo** in OBS Program. A is blue; B is orange.
4. Leave **Dry Run** checked, click **Start**, then **Submit next simulated round**.
   After two seconds the log reports B, but the preview stays blue.
5. Uncheck Dry Run and click Start again. Submit one round, wait two seconds: B
   becomes visible. Submit the next, wait: A returns. Transforms do not change.
6. Repeat current round: nothing switches. Submit then Stop or Pause: the pending
   switch is canceled. Resume baselines the current round, skipping paused events.
7. Submit then select a different Program scene: monitoring stops with no switch.

**Test LIVE once** is a separate, confirmed, immediate real swap, even in Dry Run.
It stops monitoring and cancels the queue first. Closing the dialog stops monitoring.
Keep exactly one demo source visible. Manual visibility changes stop automation.
After restarting OBS, rename/delete the previous demo before creating a fresh one;
this sample intentionally does not adopt or modify existing scenes by name.

The delay uses a monotonic clock. Reconnect, restart, mode changes and round
discontinuities clear pending work and rebaseline. Backlogged events are dropped
rather than rapidly flipping on air. Production widget reconnect semantics remain
to be integrated; a simulation is not evidence of live Scoreholio detection.

## Next stage (agreed requirements)

Scoreholio HTTPS widget URL; scene and two scene-item instance selectors; adjustable
delay; Dry Run / Test / Start / Stop / Pause / Resume; live round detection using
CourtLine's rendered `Round: N` monitoring. First observation is baseline; duplicate
and replayed events must not switch. Source IDs and scene UUID identify instances.
Only the chosen pair's visibility will change; no scene transitions or stats.

## Source evidence and build

Existing CourtLine `test47/source/desktop-web/engine.js`, lines 21, 40, 55–67,
93 and 146: HTTPS widget restriction, baseline, rendered Round parser, match-name
resets, first-observation suppression, Pause/Resume. `desktop.cjs` line 119 reads
`document.body.innerText` from the rendered browser. A plain HTTP fetch would not
faithfully replace that browser. New demo deliberately does not claim that path.

OBS API references: https://docs.obsproject.com/reference-scenes and
https://docs.obsproject.com/reference-frontend-api. Uses instance IDs, UUID checks,
Program scene checks and `obs_scene_atomic_update`; no source transforms.

Windows workflow downloads OBS's official plugin template at commit
`3e7d7ac3b5342cd7d9b88890b9c70b472d1520fc`, uses its hash-checked OBS 31.1.1
dependencies, compiles the plugin and engine tests, and runs an isolated portable
OBS self-test before uploading the installable ZIP. It never publishes a release.
The self-test environment variable is for isolated CI only: it creates/selects test
scenes, verifies actual scene-item visibility, and exits OBS.

License: GPL-2.0-or-later (see official template LICENSE).
