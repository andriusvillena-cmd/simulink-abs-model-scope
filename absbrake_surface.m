function r = absbrake_surface(surface, rampGain)
%ABSBRAKE_SURFACE  Configure and run sldemo_absbrake for one road surface.
%
%   r = absbrake_surface("splitmu")
%   r = absbrake_surface("dry", 100)     % original ramp of the shipped example
%
% Surfaces, given by the peak of the friction curve:
%   "dry"      1.00   uniform dry asphalt
%   "wet"      0.56   uniform wet asphalt
%   "splitmu"  0.60   two wheels on ice, two on dry asphalt
%   "ice"      0.20   uniform ice
%
% rampGain is the numerator of the Hydraulic Lag block, i.e. how fast brake
% pressure builds up. 1400 makes ABS engage before 0.5 s; 100, the value
% shipped with the example, takes about 7 s.
%
% Returns a struct with the fitted deceleration, the braking distance, the
% instant ABS first engages, and the vehicle speed trace.
%
% Scope limit: this is a single-wheel model. On "splitmu" it reproduces the
% DISTANCE of an asymmetric stop by averaging the two friction coefficients,
% but it cannot represent the yaw moment, which is the real hazard.

    if nargin < 2
        rampGain = 1400;
    end

    factors = struct("dry", 1.00, "wet", 0.56, "splitmu", 0.60, "ice", 0.20);

    key = char(string(surface));
    if ~isfield(factors, key)
        error("Unknown surface: %s. Use dry, wet, splitmu or ice.", key);
    end

    model = "sldemo_absbrake";
    load_system(model);

    % --- friction curve ---------------------------------------------------
    % The original curve is stored on first call so every run is scaled from
    % the same baseline instead of stacking one scaling on top of another.
    if ~evalin("base", "exist('mu_base','var')")
        evalin("base", "mu_base = mu;");
    end
    evalin("base", sprintf("mu = mu_base * %.4f;", factors.(key)));

    % --- four wheels, not one ---------------------------------------------
    % The shipped example computes tyre force from m*g/4, the load on one
    % wheel, and then divides by m, the mass of the whole car. That caps it
    % at a quarter of the achievable deceleration. With m*g the other three
    % wheels do what this one does, which is the correct assumption in a
    % straight line.
    set_param(findBlock(model, "Gain", "Weight"), "Gain", "m*g");

    % --- pressure build-up rate -------------------------------------------
    set_param(findBlock("sldemo_wheelspeed_absbrake", "TransferFcn", ""), ...
              "Numerator", sprintf("[%g]", rampGain));

    % --- run ---------------------------------------------------------------
    % ReturnWorkspaceOutputs is required. This model has the single-output
    % format switched off, so a bare sim(model) behaves the legacy way and
    % returns the time vector instead of the logged signals, and nothing is
    % written to the base workspace either. With it on, sim returns a
    % Simulink.SimulationOutput holding sldemo_absbrake_output.
    evalin("base", "clear sldemo_absbrake_output");
    out = sim(model, "ReturnWorkspaceOutputs", "on");

    try
        ds = out.sldemo_absbrake_output;
    catch
        ds = evalin("base", "sldemo_absbrake_output");
    end

    Sd  = ds.get("Sd").Values;
    slp = ds.get("slp").Values;
    v0  = evalin("base", "v0");

    % --- measure ------------------------------------------------------------
    % The derivative of travelled distance is the vehicle speed. The model
    % does not publish speed directly.
    v = gradient(Sd.Data, Sd.Time);

    % The slope is fitted on the full-braking window only. Ramp-up and the
    % tail are discarded: the model never comes to a complete stop, so
    % "initial speed over total time" is not a valid estimator.
    window = v < 0.9*v0 & v > 0.3*v0;
    p = polyfit(Sd.Time(window), v(window), 1);

    r.surface    = string(key);
    r.mu_peak    = max(evalin("base", "mu"));
    r.rampGain   = rampGain;
    r.decel      = -p(1);
    r.decel_g    = r.decel / 9.81;
    r.distance   = v0^2 / (2 * r.decel);
    r.t_abs      = firstCrossing(slp, 0.2);
    r.slip_mean  = mean(slp.Data(slp.Time < 0.5 * Sd.Time(end)));
    r.v0         = v0;
    r.t          = Sd.Time;      % s
    r.v          = v;            % m/s
    r.slip       = slp.Data;

    fprintf("\n%-8s  mu %.2f  ramp %5g  |  %5.2f m/s2 = %.2f g  |  %5.1f m  |  ABS at %4.0f ms\n", ...
            r.surface, r.mu_peak, r.rampGain, r.decel, r.decel_g, ...
            r.distance, r.t_abs * 1000);
end


function path = findBlock(model, type, name)
% Find a block by type, optionally filtered by part of its name.
% Blocks are located by type rather than by path because several blocks in
% this model carry a trailing space in their name, which breaks literal paths.
    load_system(model);
    b = find_system(model, "LookUnderMasks", "all", "FollowLinks", "on", ...
                    "BlockType", type);
    if ~isempty(name)
        b = b(contains(b, name));
    end
    if isempty(b)
        error("No block of type %s found in %s.", type, model);
    end
    path = b{1};
end


function t = firstCrossing(signal, target)
% First instant at which the signal reaches the target.
    k = find(signal.Data >= target, 1);
    if isempty(k)
        t = NaN;
    else
        t = signal.Time(k);
    end
end
