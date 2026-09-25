function T = sweep_ramp(surface, ramps, PBmax)
%SWEEP_RAMP  Ramp sweep on one surface, with the pressure ceiling as an input.
%
%   T = sweep_ramp("dry")
%   T = sweep_ramp("dry", [1400 3000 5000 8000 11000 15000], 6000)
%
% Runs absbrake_surface once per ramp value and returns one row per run:
% deceleration, stopping distance, ABS engagement time, and the slip statistics
% over the full-braking window.
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
    end

    T = table(ramp, decel, distance, t_abs, slip_mean, slip_peak);
    T.Properties.VariableUnits = {'', 'm/s^2', 'm', 's', '', ''};
    disp(T)
end
