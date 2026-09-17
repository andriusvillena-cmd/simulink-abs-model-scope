function c = compare_splitmu(csvFile)
%COMPARE_SPLITMU  Single-wheel ABS model against a synthetic mu-split run.
%
%   c = compare_splitmu                      % uses run01_splitmu.csv
%   c = compare_splitmu("run01_splitmu.csv")
%
% The reference run is SYNTHETIC: it comes from a data generator, not from
% a vehicle. It is used to check the scope of the model, not to validate it
% against reality.
%
% Produces model_vs_reference_splitmu.png, two panels:
%   top     the two speed traces. The fitted decelerations agree within a
%           few per cent, and the transients do not: the model carries a
%           first-order hydraulic lag, the reference run steps straight to
%           full deceleration.
%   bottom  yaw rate and steering angle in the reference run. A single-wheel
%           model has no yaw degree of freedom, so it cannot produce either.
%
% Both decelerations are fitted with the SAME estimator over the SAME speed
% window, so the scalar comparison is like for like.

    if nargin < 1
        csvFile = "run01_splitmu.csv";
    end

    % --- model --------------------------------------------------------------
    m = absbrake_surface("splitmu");

    % --- synthetic reference run --------------------------------------------
    T = readtable(csvFile);
    t    = T.time;                 % s
    v    = T.Vehicle_Speed;        % km/h
    p    = T.Brake_Pressure;       % bar
    ax   = abs(T.Long_Accel);      % g
    yaw  = T.Yaw_Rate;             % deg/s
    str  = T.Steering_Angle;       % deg

    % Brake onset = first rise of brake pressure, not an arbitrary level.
    i0 = find(p > 2, 1);
    if isempty(i0)
        error("No brake onset found in %s.", csvFile);
    end
    t   = t - t(i0);               % time from brake onset
    v0m = v(i0) / 3.6;             % m/s

    % Same window as the model: full braking only, no ramp-up, no tail.
    sel = t >= 0 & v/3.6 < 0.9*v0m & v/3.6 > 0.3*v0m;
    pm  = polyfit(t(sel), v(sel)/3.6, 1);

    c.decel_meas  = -pm(1);
    c.decel_model = m.decel;
    c.dist_meas   = v0m^2 / (2 * c.decel_meas);
    c.dist_model  = m.distance;
    c.err_decel   = 100 * (c.decel_model - c.decel_meas) / c.decel_meas;
    c.err_dist    = 100 * (c.dist_model  - c.dist_meas)  / c.dist_meas;
    c.yaw_peak    = max(abs(yaw));
    c.steer_peak  = max(abs(str));

    % --- how long each one takes to get there -------------------------------
    % Scalars agree; transients do not. These two numbers are the evidence.
    a_ss = median(ax(sel));                       % steady deceleration, g
    k    = find(t >= 0 & ax >= 0.9*a_ss, 1);
    c.t_rise_ref   = t(k);                        % s, reference
    c.dt           = median(diff(T.time));        % s, sampling interval
    c.t_press_ref  = t(find(t >= 0 & p >= 0.9*max(p), 1));   % s, its own pressure
    c.t_abs_model  = m.t_abs;                     % s, model
    c.model        = m;

    fprintf("\n                 model     reference    error\n");
    fprintf("decel        %8.2f %11.2f m/s2 %7.1f %%\n", c.decel_model, c.decel_meas, c.err_decel);
    fprintf("             %8.2f %11.2f g\n", c.decel_model/9.81, c.decel_meas/9.81);
    fprintf("distance     %8.1f %11.1f m    %7.1f %%\n", c.dist_model, c.dist_meas, c.err_dist);
    fprintf("rise to full %8.2f %11.3f s  (sampling %.0f ms)\n", ...
            c.t_abs_model, c.t_rise_ref, median(diff(T.time))*1000);
    fprintf("yaw          %8s %11.1f deg/s\n", "none", c.yaw_peak);
    fprintf("steering     %8s %11.1f deg\n\n", "none", c.steer_peak);

    % --- figure -------------------------------------------------------------
    % The theme is forced to light. MATLAB Online runs a dark theme and
    % exportgraphics carries it into the PNG, which is unusable for a report.
    blue   = [0.00 0.45 0.74];
    orange = [0.85 0.33 0.10];
    f = figure("Color", "w", "Position", [100 100 900 760], "InvertHardcopy", "off");
    if isprop(f, "Theme")          % R2025a and later: the figure carries a theme
        f.Theme = "light";          % and it overrides per-object colour settings
    end

    ax1 = subplot(2,1,1);
    plot(t, v, "Color", blue, "LineWidth", 1.8); hold on;
    plot(m.t, m.v * 3.6, "--", "Color", orange, "LineWidth", 1.8);
    xlim([-0.5 6]); ylim([0 110]);
    xlabel("time from brake onset (s)");
    ylabel("vehicle speed (km/h)");
    title("Same average deceleration, different transient");
    subtitle(sprintf(['model %.2f vs reference %.2f m/s^2 (%.1f %%)     ' ...
                      'stopping distance %.1f vs %.1f m (%.1f %%)'], ...
             c.decel_model, c.decel_meas, c.err_decel, ...
             c.dist_model, c.dist_meas, c.err_dist));
    lg = legend(["synthetic reference run", "single-wheel model"], ...
                "Location", "northeast");
    set(lg, "Color", "w", "TextColor", "k", "EdgeColor", [0.8 0.8 0.8]);
    % Never print "0 ms": that is the sampling interval, not a measurement.
    if c.t_rise_ref < c.dt
        riseTxt = sprintf('reference: full deceleration within one %.0f ms sample', c.dt*1000);
    else
        riseTxt = sprintf('reference: full deceleration in %.0f ms', c.t_rise_ref*1000);
    end
    text(-0.3, 26, sprintf('model: %.1f s of hydraulic pressure build-up\n%s', ...
         c.t_abs_model, riseTxt), ...
         "FontSize", 10, "Color", [0.25 0.25 0.25], ...
         "VerticalAlignment", "top", "HorizontalAlignment", "left");
    lightAxes(ax1);

    ax2 = subplot(2,1,2);
    yyaxis left;
    plot(t, yaw, "LineWidth", 1.5);
    ylabel("yaw rate (deg/s)");
    ax2.YAxis(1).Color = blue;
    yyaxis right;
    plot(t, str, "LineWidth", 1.5);
    ylabel("steering angle (deg)");
    ax2.YAxis(2).Color = orange;
    xlim([-0.5 6]);
    xlabel("time from brake onset (s)");
    title("What a single-wheel model cannot produce");
    subtitle(sprintf("%.1f deg/s of yaw, %.1f deg of steering correction to hold the lane", ...
             c.yaw_peak, c.steer_peak));
    lightAxes(ax2);

    annotation(f, "textbox", [0.13 0.005 0.8 0.035], "String", ...
        "Reference run is synthetic (generated data), not a vehicle measurement.", ...
        "EdgeColor", "none", "FontAngle", "italic", "FontSize", 9, ...
        "Color", [0.35 0.35 0.35]);

    % The export carries its own theme. Setting it on the figure is not
    % enough: exportgraphics re-applies the desktop theme unless told
    % otherwise. The older releases have no Theme option, hence the catch.
    outFile = "model_vs_reference_splitmu.png";
    try
        exportgraphics(f, outFile, "Resolution", 150, ...
                       "BackgroundColor", "white", "Theme", "light");
    catch
        exportgraphics(f, outFile, "Resolution", 150, "BackgroundColor", "white");
    end
    d = dir(outFile);
    fprintf("saved %s  (%s, %.0f kB)\n", outFile, d.date, d.bytes/1024);
end


function lightAxes(ax)
% Force a light, printable look regardless of the desktop theme.
    set(ax, "Color", "w", "GridColor", [0.75 0.75 0.75], "GridAlpha", 1, ...
            "XColor", [0.15 0.15 0.15], "FontSize", 10, "Box", "off", ...
            "XGrid", "on", "YGrid", "on");
    if numel(ax.YAxis) == 1
        ax.YColor = [0.15 0.15 0.15];
    end
    ax.Title.Color    = "k";
    ax.Subtitle.Color = [0.35 0.35 0.35];
    ax.XLabel.Color   = [0.15 0.15 0.15];
    ax.YLabel.Color   = [0.15 0.15 0.15];
end
