function T = sweep_target(surface, targets, rampGain, PBmax)
%SWEEP_TARGET  Sweep the controller's slip setpoint on one surface.
%
%   T = sweep_target("splitmu")
%   T = sweep_target("dry", [0.12 0.16 0.20 0.25], 4500, 6000)
%
% The setpoint lives in a Constant block whose name contains real newline
% characters, so it is located by type and name fragment rather than by a
% literal path. The original value is restored even if a run errors.
%
% Why this sweep exists. The friction table shipped with the example peaks at
% slip = 0.20, and the controller's setpoint is also 0.20, so the setpoint sits
% exactly on the peak. That looks optimal and is not, because the peak is also
% where the sign of the slope flips:
%
%   left of the peak   more slip gives more grip, which brakes the runaway
%   right of the peak  more slip gives less grip, which feeds it
%
% A bang-bang controller with no dead band and a 10 ms sample rate cannot hold
% a setpoint sitting on that boundary, so half of every oscillation lands in
% the unstable region. Moving the setpoint down puts the whole cycle on the
% self-correcting side.

    if nargin < 2 || isempty(targets)
        targets = [0.12 0.14 0.16 0.18 0.20 0.22 0.25];
    end
    if nargin < 3 || isempty(rampGain), rampGain = 4500; end
    if nargin < 4,                      PBmax    = 6000; end

    model = "sldemo_absbrake";
    load_system(model);

    blk = find_system(model, "LookUnderMasks", "all", "FollowLinks", "on", ...
                      "BlockType", "Constant");
    blk = blk(contains(blk, "Desired"));
    if isempty(blk)
        error("Cannot find the desired-slip constant in %s.", model);
    end
    blk = blk{1};

    orig = get_param(blk, "Value");
    cleaner = onCleanup(@() set_param(blk, "Value", orig));  %#ok<NASGU>

    n        = numel(targets);
    target   = targets(:);
    decel    = zeros(n, 1);
    distance = zeros(n, 1);
    t_abs    = zeros(n, 1);
    slip_abs = zeros(n, 1);
    slip_sd  = zeros(n, 1);

    for k = 1:n
        set_param(blk, "Value", sprintf("%g", targets(k)));
        row = sweep_ramp(surface, rampGain, PBmax);
        decel(k)    = row.decel;
        distance(k) = row.distance;
        t_abs(k)    = row.t_abs;
        slip_abs(k) = row.slip_abs;
        slip_sd(k)  = row.slip_sd;
    end

    efficiency = decel ./ (max(evalin("base", "mu")) * 9.81);

    T = table(target, decel, distance, t_abs, slip_abs, slip_sd, efficiency);
    T.Properties.VariableUnits = {'', 'm/s^2', 'm', 's', '', '', ''};
    disp(T)
end
