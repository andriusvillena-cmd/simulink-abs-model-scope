# ABS braking: model scope, not model validation

A single-wheel ABS model (MathWorks `sldemo_absbrake`) compared against a
reference braking run, to find out **which questions the model can answer and
which it cannot**.

This is not a validation. Read [Scope and honesty](#scope-and-honesty) before
using any number from here.

![model against reference](model_vs_reference_splitmu.png)

---

## What was found

### 1. The shipped example computes one wheel's share, not the vehicle

Reading the block diagram rather than the documentation:

```
wheel slip  ->  mu-slip friction curve  ->  x m*g/4  ->  tyre force
                                            (load on ONE wheel)

tyre force  ->  x 1/m  ->  vehicle deceleration
                (mass of the WHOLE car)
```

The normal load is one wheel's. The mass it is divided by is the whole car's.
Follow the path and the ceiling is `mu*g/4`, which is 2.45 m/s2 (0.25 g) on dry
asphalt.

The example is not wrong. It is a single-wheel model and its output is one
wheel's contribution to the whole vehicle. Nothing in the documentation says
so, and reading that output as "vehicle deceleration" produces a number that is
four times too small while still carrying the right units.

`absbrake_surface.m` sets the load term to `m*g` instead, which assumes the
other three wheels do what this one does. That is the correct assumption in a
straight line and it is wrong in a turn.

### 2. Actuator and controller are coupled

With the shipped Hydraulic Lag numerator of 100, ABS first engages about 7 s
into the stop, which is longer than the stop itself. The controller cannot
correct faster than the hydraulics can raise pressure.

**This is a knob, not a result.** The value used here (1400) was raised until
ABS engaged inside the braking window. No measurement supports that number, and
the transient of the model therefore cannot be compared against anything.

### 3. The model has no yaw degree of freedom

On a mu-split surface the single-wheel model reproduces the stopping distance
by averaging the two friction coefficients. It cannot produce the yaw moment
that is the actual hazard, because there is no equation in it from which a yaw
rate could come. The lower panel of the figure shows what the model is blind
to, not what it gets wrong.

### 4. The scalar error is not the error in metres

| | model | reference |
|---|---|---|
| deceleration | 5.59 m/s2 (0.57 g) | 5.89 m/s2 (0.60 g) |
| stopping distance | 70.1 m | 65.3 m |
| rise to full deceleration | 1.27 s | within one 10 ms sample |
| peak yaw rate | not modelled | 8.1 deg/s |
| steering correction | not modelled | 12.9 deg |

A deceleration 4.9 % low becomes a distance 7.3 % long. Distance goes with
`v0^2 / 2a`, so the deceleration gap (+5.2 % of distance) compounds with the
2.9 % difference in initial speed, squared. 1.052 x 1.031 = 1.085.
Nothing else is hidden in that gap.

---

### 5. On dry asphalt the ABS never intervenes

A three-surface sweep with the shipped pressure ceiling (`PBmax = 2000`):

| surface | mu | deceleration | distance | ABS engages | mean slip | peak slip |
|---|---|---|---|---|---|---|
| dry | 1.00 | 7.51 m/s2 | 52.2 m | 3540 ms | 0.075 | 0.103 |
| wet | 0.56 | 5.17 m/s2 | 75.8 m | 1200 ms | 0.171 | 0.324 |
| mu-split | 0.60 | 5.59 m/s2 | 70.1 m | 1270 ms | 0.165 | 0.302 |

Divide the deceleration by mu and wet gives 9.23, mu-split gives 9.32 — the same
machine seen through two friction levels. Dry gives 7.51. It breaks the pattern.

The reason is a saturation. Brake pressure is an integrator limited to `PBmax`,
and on dry asphalt that ceiling is reached before the torque is enough to make
the tyre slip. Slip stays at 0.075 and never exceeds 0.10, against a controller
target of 0.20.

**The ABS does not notice there is a stop happening.** The tyre works on the
rising part of the friction curve and delivers 0.77 instead of 1.00.

This is not a bug: 2000 may be a realistic hydraulic limit. It is a scope limit.
**The example as shipped cannot exercise ABS on high-grip surfaces**, so nothing
it says about dry-road ABS behaviour is worth anything. On wet and mu-split it
is fine.

With `PBmax` raised to 6000, dry becomes 8.94 m/s2 (0.91 g) over 43.8 m, ABS
engaging at 1960 ms, slip cycling at 0.124 mean and 0.305 peak — the same regime
as wet.

Raising the pressure ramp instead does nothing (7.51 to 7.57 m/s2 when the ramp
goes from 1400 to 4000). The ramp decides *when* you reach the ceiling, not
*where* the ceiling is.

### 6. There is an optimum ramp, and it is a crutch

Ramp sweep on dry, with the ceiling raised so ABS can work:

| ramp | ABS engages | deceleration | distance |
|---|---|---|---|
| 1400 | 1960 ms | 8.94 m/s2 | 43.8 m |
| **3000** | **960 ms** | **9.22 m/s2 (0.94 g)** | **42.5 m** |
| 5000 | 610 ms | 8.95 m/s2 | 43.8 m |
| 8000 | 400 ms | 8.66 m/s2 | 45.2 m |
| 11000 | 310 ms | 8.36 m/s2 | 46.9 m |
| 15000 | 240 ms | 7.94 m/s2 | 49.4 m |

Past 3000 every increase makes the stop worse. Between 3000 and 15000 you lose
seven metres. **You are buying ABS reaction time with braking distance.**

The tempting conclusion — "the optimal hydraulic ramp is 3000" — is misleading.
What is really happening is that a slow actuator is covering for a poor
controller.

The bang-bang in this example has **zero dead band**: its comparator constant is
0, so it is a pure sign function with no hysteresis. The only thing stopping it
from overshooting is how slowly the hydraulics respond. Speed them up and it is
exposed.

A real ABS does not brake worse for having fast hydraulics, rather the opposite.
A real ABS is not a relay: it watches wheel angular acceleration, holds pressure
in phases, and anticipates.

### 7. You cannot make the actuator faster than the loop that commands it

Overshoot scales roughly as *pressure rate x loop delay*. Only the rate had been
changed, so the valve time constant was cut from 10 ms to 3 ms at a ramp of
11000, expecting less overshoot.

**The wheel locked.** Mean slip 0.883, peak 1.000, and a deceleration of
6.90 m/s2 — that is 0.70 g, which is exactly the locked-wheel friction value in
the model's own mu-slip table. Two independent signals saying the same thing.

The hydraulic lag was not only an obstacle: it was smoothing the command. Remove
it and the other delay in the loop is exposed, the one from sampling. The
control loop runs at **10 ms** (measured by compiling the model and reading the
propagated sample time on the Unit Delay and the Rate Transition blocks).

They are not two pieces but three: **actuator, controller and sample rate.**

### 8. An empirical law, from the measurements

The tyre starts to slip at about 2740 pressure units (measured: a ramp of 1400
reached the slip threshold at 1.96 s). If pressure rises at N units per second,
ABS should engage at 2740/N:

| ramp N | 2740/N | measured | difference |
|---|---|---|---|
| 3000 | 0.91 s | 0.96 s | 0.05 |
| 5000 | 0.55 s | 0.61 s | 0.06 |
| 8000 | 0.34 s | 0.40 s | 0.06 |
| 11000 | 0.25 s | 0.31 s | 0.06 |
| 15000 | 0.18 s | 0.24 s | 0.06 |

**t_ABS = 2740/N + 0.06 s.** Five points, a constant offset. Those 60 ms are the
valve lag plus the time slip needs to build to the threshold.

And the floor it implies. With 10 ms sampling, each interval delivers a pressure
step of N x 0.01:

| ramp | step per sample | % of 2740 | ABS engages | cost in distance |
|---|---|---|---|---|
| 3000 | 30 | 1.1 % | 0.96 s | — |
| 8000 | 80 | 2.9 % | 0.40 s | 2.7 m |
| 11000 | 110 | 4.0 % | 0.31 s | 4.4 m |
| 15000 | 150 | 5.5 % | 0.24 s | 6.9 m |

**With this loop, going below 0.3 s costs more than four metres, and no amount
of hydraulic tuning avoids it.** The lever that would work is the sample rate: a
1 ms loop would give steps ten times finer, allowing both a fast entry and
precise modulation. That costs ECU compute, but that is where the margin is.

### 9. There is no driver

The block inventory contains no brake pedal input. The controller receives
*target minus actual slip* and, from t = 0, commands maximum pressure build-up.

So the ramp N is doing two jobs that are physically different in a car: the
driver's application, which takes 150-300 ms, and the ABS modulation, which
works in tens of milliseconds. One number cannot be slow and smooth for the
first and fast and fine for the second.

That is the underlying reason a realistic emergency-braking application cannot
be configured in this model: there is nowhere to put it.

---

## Method notes

- **The model does not publish vehicle speed.** It publishes travelled distance
  `Sd`, and the derivative of distance is speed. Checked against the initial
  condition: `v(1) = 28.0000` exactly.
- **The slope is fitted on the full-braking window only** (`0.3*v0 < v <
  0.9*v0`), discarding pressure build-up and the tail. The model never comes to
  a complete stop, so "initial speed over total time" is not a valid estimator
  and gives nonsense.
- **The same estimator and the same window are applied to both sides.**
  Comparing a fitted slope against a total-time average would flatter one of
  them.
- **Times below the sampling interval are not reported as numbers.** The
  reference run reaches full deceleration inside one 10 ms sample; that is the
  measurement resolution, not a measured 0 ms.

---

## Scope and honesty

- **The reference run is synthetic and is not redistributed.** It comes from a
  data generator, not from a vehicle, and it is listed in `.gitignore`. Its ABS ripple is a fixed sinusoid rather than
  a controller reacting to slip, its friction coefficient is constant, and
  there is no load transfer. Its yaw channel is written, not computed.
- Comparing a computation against generated data **validates nothing about a
  real vehicle**. What it does is expose the scope of the model.
- The Hydraulic Lag value is unjustified, as stated above. So is the
  generator's instantaneous deceleration step. Neither transient is anchored to
  a measurement, so the difference between them is not a finding.
- What would make this a validation: one real braking run, logged from the
  vehicle bus.

---

## Files

| file | what it does |
|---|---|
| `absbrake_surface.m` | configures and runs the model for one surface (`dry`, `wet`, `splitmu`, `ice`), sets the load term to `m*g`, fixes the pressure ramp, and measures deceleration, distance and ABS engagement |
| `compare_splitmu.m` | runs the model on mu-split, loads the reference run, aligns both on brake onset, and produces the figure |
| `sweep_ramp.m` | ramp sweep on one surface, with the pressure ceiling as an input. Restores the ceiling on the way out, including on error |
| `run01_splitmu.csv` | synthetic reference run, 100 Hz, 12 s, 11 channels. **Not in this repository** |

## Reproducing

MATLAB Online (free tier) with Simulink.

**Everything that matters here reproduces without the reference run.** The
scope finding, the measurement method and the model figures come from the
shipped MathWorks example alone:

```matlab
bdclose all; clear;
sldemo_absbrake;
absbrake_surface("dry")        % and "wet", "splitmu", "ice"
```

The ramp sweep of findings 6 and 8, which needs the pressure ceiling raised so
that ABS can work at all on dry:

```matlab
T = sweep_ramp("dry", [1400 3000 5000 8000 11000 15000], 6000)
```

Beware of `clear` on its own: the model keeps its parameters (`m`, `g`, `mu`,
`v0`, `ctrl`) in the base workspace, and wiping them leaves the model unusable
until it is closed with `bdclose all` and reopened by name. For the same reason,
do not use `m` as a variable name: it is the vehicle mass.

Compare the printed deceleration with and without the `m*g` correction and the
factor of four is there, on any surface.

`compare_splitmu` additionally needs `run01_splitmu.csv`, which is not
published. The figure it produces is committed as
`model_vs_reference_splitmu.png` so the result can be read without rerunning
it.

`sim` is called with `"ReturnWorkspaceOutputs", "on"`: without it this model
returns the time vector instead of the logged signals.
