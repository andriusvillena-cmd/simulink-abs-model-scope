# ABS braking: model scope, not model validation

A single-wheel ABS model (MathWorks `sldemo_absbrake`) put through a series of
runs to find out which questions it can answer and which it cannot.

This is not a validation. Read [Scope and honesty](#scope-and-honesty) before
you take any number from here.

![model against reference](model_vs_reference_splitmu.png)

---

## What was found

### 1. The example computes one wheel's share, not the vehicle

This came from reading the block diagram, not the documentation:

```
wheel slip  ->  mu-slip friction curve  ->  x m*g/4  ->  tyre force
                                            (load on ONE wheel)

tyre force  ->  x 1/m  ->  vehicle deceleration
                (mass of the WHOLE car)
```

The tyre force uses the load on one wheel. The deceleration divides by the mass
of the whole car. Follow that path and the ceiling is `mu*g/4`, which on dry
asphalt is 2.45 m/s2, or 0.25 g.

There is no bug here. It is a single-wheel model, and its output is one wheel's
contribution to the vehicle. The documentation never says so, and if you read
that output as "vehicle deceleration" you get a number four times too small
that still carries the right units.

`absbrake_surface.m` uses `m*g` instead, which assumes the other three wheels
do what this one does. Correct in a straight line, wrong in a turn.

### 2. The actuator and the controller go together

With the Hydraulic Lag numerator as shipped, 100, ABS first engages about 7 s
into a stop that lasts less than 4. The controller cannot correct faster than
the hydraulics can raise pressure.

The 1400 used here is a knob, not a result. It was raised until ABS engaged
inside the braking window, and no measurement supports that particular value.
The model's transient is therefore not something to compare against anything.

### 3. The model has no yaw

On mu-split the model reproduces the stopping distance by averaging the two
friction coefficients. It cannot produce the yaw moment, which is the actual
hazard, because there is no equation in it a yaw rate could come from.

The lower panel of the figure shows what the model is blind to, not what it
gets wrong.

### 4. A small error in deceleration is a bigger one in metres

| | model | reference |
|---|---|---|
| deceleration | 5.59 m/s2 (0.57 g) | 5.89 m/s2 (0.60 g) |
| stopping distance | 70.1 m | 65.3 m |
| rise to full deceleration | 1.27 s | within one 10 ms sample |
| peak yaw rate | not modelled | 8.1 deg/s |
| steering correction | not modelled | 12.9 deg |

Deceleration is 4.9 % low, distance comes out 7.3 % long. Distance goes with
`v0^2 / 2a`, so the deceleration gap (worth +5.2 % of distance) compounds with
the 2.9 % difference in initial speed, squared: 1.052 x 1.031 = 1.085. There is
nothing else hidden in that gap.

---

### 5. On dry asphalt the ABS never intervenes

Three surfaces, with the pressure ceiling as shipped (`PBmax = 2000`):

| surface | mu | deceleration | distance | ABS engages | mean slip | peak slip |
|---|---|---|---|---|---|---|
| dry | 1.00 | 7.51 m/s2 | 52.2 m | 3540 ms | 0.075 | 0.103 |
| wet | 0.56 | 5.17 m/s2 | 75.8 m | 1200 ms | 0.171 | 0.324 |
| mu-split | 0.60 | 5.59 m/s2 | 70.1 m | 1270 ms | 0.165 | 0.302 |

Divide deceleration by mu: wet gives 9.23, mu-split 9.32. Same machine, two
friction levels. Dry gives 7.51 and breaks the pattern.

The cause is a saturation. Brake pressure is an integrator limited to `PBmax`,
and on dry that ceiling arrives before the torque is enough to make the tyre
slip. Slip sits at 0.075 and never passes 0.10, against a target of 0.20.

**The ABS never notices there is a stop happening.** The tyre works on the
rising part of the friction curve and gives 0.77 instead of 1.00.

Again, not a bug: 2000 may well be a realistic hydraulic limit. It is a limit of
scope. The example as shipped cannot exercise ABS on high-grip surfaces, so
whatever it says about dry-road ABS is worthless. On wet and mu-split it holds
up.

Raise `PBmax` to 6000 and dry becomes 8.94 m/s2 (0.91 g) over 43.8 m, ABS
engaging at 1960 ms, slip cycling at 0.124 mean and 0.305 peak. The same regime
as wet.

Raising the pressure ramp instead changes nothing: 7.51 to 7.57 m/s2 when the
ramp goes from 1400 to 4000. The ramp decides when you reach the ceiling, not
where the ceiling is.

### 6. The optimum ramp is hiding a weak controller

Ramp sweep on dry, with the ceiling raised so ABS can work at all:

| ramp | ABS engages | deceleration | distance |
|---|---|---|---|
| 1400 | 1960 ms | 8.94 m/s2 | 43.8 m |
| **3000** | **960 ms** | **9.22 m/s2 (0.94 g)** | **42.5 m** |
| 5000 | 610 ms | 8.95 m/s2 | 43.8 m |
| 8000 | 400 ms | 8.66 m/s2 | 45.2 m |
| 11000 | 310 ms | 8.36 m/s2 | 46.9 m |
| 15000 | 240 ms | 7.94 m/s2 | 49.4 m |

Past 3000, every increase makes the stop worse. From 3000 to 15000 you lose
seven metres. You are buying ABS reaction time with braking distance.

It would be easy to write "the optimal hydraulic ramp is 3000" and move on. That
would miss the point. What the sweep is really showing is a slow actuator
covering for a poor controller.

The bang-bang here has no dead band at all: its comparator constant is 0, so it
is a pure sign function with no hysteresis. The only thing keeping it from
overshooting is how slowly the hydraulics respond. Speed them up and it has
nowhere to hide.

A real ABS does not brake worse for having fast hydraulics. A real ABS is not a
relay: it watches wheel angular acceleration, holds pressure in phases, and
anticipates.

### 7. You cannot make the actuator faster than the loop commanding it

Overshoot scales roughly as pressure rate times loop delay, and only the rate
had been touched. So the valve time constant went from 10 ms to 3 ms at a ramp
of 11000, expecting less overshoot.

The wheel locked. Mean slip 0.883, peak 1.000, deceleration 6.90 m/s2. That is
0.70 g, which is exactly the locked-wheel friction value in the model's own
mu-slip table. Two independent signals saying the same thing.

The hydraulic lag was not only getting in the way, it was smoothing the command.
Take it out and the other delay in the loop shows up: the sampling. The control
loop runs at 10 ms, measured by compiling the model and reading the propagated
sample time on the Unit Delay and Rate Transition blocks.

So it is not two pieces but three: actuator, controller and sample rate.

### 8. An empirical law out of the measurements

The tyre starts to slip at around 2740 pressure units. That is measured: a ramp
of 1400 reached the slip threshold at 1.96 s. If pressure rises at N units per
second, ABS should engage at 2740/N:

| ramp N | 2740/N | measured | difference |
|---|---|---|---|
| 3000 | 0.91 s | 0.96 s | 0.05 |
| 5000 | 0.55 s | 0.61 s | 0.06 |
| 8000 | 0.34 s | 0.40 s | 0.06 |
| 11000 | 0.25 s | 0.31 s | 0.06 |
| 15000 | 0.18 s | 0.24 s | 0.06 |

**t_ABS = 2740/N + 0.06 s.** Five points, and the offset stays put. Those 60 ms
are the valve lag plus the time slip needs to build up to the threshold.

That fixes the floor. With 10 ms sampling, each interval delivers a pressure
step of N x 0.01:

| ramp | step per sample | % of 2740 | ABS engages | cost in distance |
|---|---|---|---|---|
| 3000 | 30 | 1.1 % | 0.96 s | — |
| 8000 | 80 | 2.9 % | 0.40 s | 2.7 m |
| 11000 | 110 | 4.0 % | 0.31 s | 4.4 m |
| 15000 | 150 | 5.5 % | 0.24 s | 6.9 m |

With this loop, getting ABS in under 0.3 s costs more than four metres, and no
hydraulic tuning gets around it. The lever that would work is the sample rate.
A 1 ms loop gives steps ten times finer, and you could have both a fast entry
and precise modulation. It costs processing in the ECU, but that is where the
margin is.

### 9. There is no driver

The block inventory has no brake pedal input anywhere. The controller receives
target slip minus actual slip and, from t = 0, commands maximum pressure
build-up.

Which means N is doing two jobs that are different things in a car: the driver's
application, 150 to 300 ms, and the ABS modulation, tens of milliseconds. One
number cannot be slow and smooth for the first and fast and fine for the second.

That is why a realistic emergency-braking application cannot be configured here.
There is nowhere to put it.

---

## Method notes

- The model does not publish vehicle speed. It publishes travelled distance
  `Sd`, and the derivative of distance is speed. Checked against the initial
  condition: `v(1) = 28.0000` exactly.
- The slope is fitted on the full-braking window only (`0.3*v0 < v < 0.9*v0`),
  leaving out the pressure build-up and the tail. The model never comes to a
  complete stop, so "initial speed over total time" is not a valid estimator and
  gives nonsense.
- The same estimator and the same window go on both sides. Fitting a slope on
  one and averaging over total time on the other would flatter whichever you
  chose.
- Times below the sampling interval are not reported as numbers. The reference
  run reaches full deceleration inside one 10 ms sample, which is the resolution
  of the measurement, not a measured 0 ms.

---

## Scope and honesty

- The reference run is synthetic and is not redistributed. It comes from a data
  generator, not a vehicle, and it sits in `.gitignore`. Its ABS ripple is a
  fixed sinusoid rather than a controller reacting to slip, its friction
  coefficient is constant, and there is no load transfer. Its yaw channel is
  written, not computed.
- Comparing a computation against generated data validates nothing about a real
  vehicle. What it does is expose the scope of the model.
- The Hydraulic Lag value is unjustified, as said above. So is the generator's
  instantaneous deceleration step. Neither transient is anchored to a
  measurement, so the difference between them is not a finding.
- What would turn this into a validation: one real braking run, logged off the
  vehicle bus.

---

## Files

| file | what it does |
|---|---|
| `absbrake_surface.m` | configures and runs the model for one surface (`dry`, `wet`, `splitmu`, `ice`), sets the load term to `m*g`, fixes the pressure ramp, and measures deceleration, distance and ABS engagement |
| `compare_splitmu.m` | runs the model on mu-split, loads the reference run, aligns both on brake onset, and produces the figure |
| `sweep_ramp.m` | ramp sweep on one surface, with the pressure ceiling as an input. Puts the ceiling back on the way out, including when a run fails |
| `run01_splitmu.csv` | synthetic reference run, 100 Hz, 12 s, 11 channels. **Not in this repository** |

## Reproducing

MATLAB Online (free tier) with Simulink.

Everything that matters reproduces without the reference run. The scope finding,
the measurement method and the model figures come from the shipped MathWorks
example alone:

```matlab
bdclose all; clear;
sldemo_absbrake;
absbrake_surface("dry")        % and "wet", "splitmu", "ice"
```

Compare the printed deceleration with and without the `m*g` correction and the
factor of four is there, on any surface.

The ramp sweep behind findings 6 and 8 needs the pressure ceiling raised, or ABS
will not work on dry at all:

```matlab
T = sweep_ramp("dry", [1400 3000 5000 8000 11000 15000], 6000)
```

Two things that will bite you. A bare `clear` wipes the model's parameters
(`m`, `g`, `mu`, `v0`, `ctrl`), which live in the base workspace, and leaves the
model unusable until you close it with `bdclose all` and reopen it by name. For
the same reason, never name a variable `m`: that is the vehicle mass.

`compare_splitmu` also needs `run01_splitmu.csv`, which is not published. The
figure it produces is committed as `model_vs_reference_splitmu.png` so the
result can be read without rerunning it.

`sim` is called with `"ReturnWorkspaceOutputs", "on"`. Without it this model
returns the time vector instead of the logged signals.
