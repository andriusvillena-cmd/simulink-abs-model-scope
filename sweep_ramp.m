function T = sweep_ramp(surface, ramps, PBmax)
%SWEEP_RAMP  Ramp sweep on one surface, with the pressure ceiling as an input.
%
%   T = sweep_ramp("dry")
%   T = sweep_ramp("dry", [1400 3000 5000 8000 11000 15000], 6000)
%
% Runs absbrake_surface once per ramp value and returns one row per run:
% deceleration, stopping distance, ABS engagement time, and four slip
% statistics.
%
% On the slip columns, in the order they were found useful:
%
%   slip_mean  mean over the whole braking window. Useless for calibration.
%              A slow ramp spends a long time at low slip before the ABS ever
%              acts, so this number mostly measures how long the build-up was.
%   slip_peak  the single highest sample. Fragile: one outlier moves it, and
%              on dry it went DOWN between two runs whose distance went up.
%   slip_abs   mean once the ABS is active. Came out 0.21 in 21 runs spanning
%              a 13x range of ramp and three surfaces, while stopping distance
%              varied by 12%. It says the loop closes on its setpoint and
%              nothing else.
%   slip_sd    spread once the ABS is active. This is the one that works. It
%              rises monotonically with ramp in every run, and it tracks the
%              efficiency loss.
%
% Two things worth knowing before reading the code.
%
% PBmax lives in the MODEL workspace of the referenced model, not in the base
% workspace. Assigning it in the base workspace does nothing: when a name exists
% in both, the model workspace wins. That cost three failed experiments to find.
%
% The sweep changes a shipped example in memory only. onCleanup guarantees the
% original ceiling is put back even if a run errors halfway through.

    if nargin < 2 || isempty(ramps)
        ramps = [1400 3000 5000 8000 11000 15000];
    end

    % The referenced model is not loaded just because the top model is open.
    % Without this, the first call in a fresh session fails with
    % "The block diagram is not loaded".
    load_system("sldemo_wheelspeed_absbrake");

    mw = get_param("sldemo_wheelspeed_absbrake", "ModelWorkspace");
    PBmax_orig = mw.getVariable('PBmax');
    cleaner = onCleanup(@() mw.assignin('PBmax', PBmax_orig));  %#ok<NASGU>

    if nargin >= 3 && ~isempty(PBmax)
        mw.assignin('PBmax', PBmax);
    end

    n         = numel(ramps);
    ramp      = ramps(:);
    decel     = zeros(n, 1);
    distance  = zeros(n, 1);
    t_abs     = zeros(n, 1);
    slip_mean = zeros(n, 1);
    slip_peak = zeros(n, 1);
    slip_abs  = zeros(n, 1);
    slip_sd   = zeros(n, 1);

    for k = 1:n
        r = absbrake_surface(surface, ramps(k));

        % Full-braking window only: the model never stops completely, and the
        % slip definition (v - wR)/v goes to 1 as v goes to zero, which is an
        % artefact and not a locked wheel.
        sel = r.v > 0.3 * r.v0;

        decel(k)     = r.decel;
        distance(k)  = r.distance;
        t_abs(k)     = r.t_abs;
        slip_mean(k) = mean(r.slip(sel));
        slip_peak(k) = max(r.slip(sel));

        % Column vectors on both sides. A row-vs-column mismatch here does not
        % error, it broadcasts into a matrix and the run fails much later with
        % a port dimension message that says nothing about this line.
        act = sel(:) & (r.t(:) > r.t_abs);
        s   = r.slip(:);
        if any(act)
            slip_abs(k) = mean(s(act));
            slip_sd(k)  = std(s(act));
        else
            slip_abs(k) = NaN;
            slip_sd(k)  = NaN;
        end
    end

    T = table(ramp, decel, distance, t_abs, slip_mean, slip_peak, slip_abs, slip_sd);
    T.Properties.VariableUnits = {'', 'm/s^2', 'm', 's', '', '', '', ''};
    disp(T)
end
