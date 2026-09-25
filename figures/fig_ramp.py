import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np

BLUE, ORANGE, PURPLE = "#0073BA", "#D95319", "#6A3D9A"
INK, GREY, MUTED, GRID = "#1A1A1A", "#4A4A4A", "#6E7681", "#E6E9EC"
SURF = "#FCFCFB"

ramps = np.array([800, 1400, 2000, 3000, 4500, 6500, 9000], float)
S = {
 "Dry":      dict(c=BLUE,   m="o",
                  dist=[52.224,43.840,42.353,42.522,43.235,44.385,46.187],
                  sd=[.035431,.065932,.067874,.078450,.085363,.088268,.111110],
                  tabs=[3.32,1.96,1.40,0.96,0.67,0.48,0.36]),
 "Wet":      dict(c=ORANGE, m="s",
                  dist=[74.597,75.800,76.544,77.991,80.836,83.613,88.533],
                  sd=[.060214,.074191,.077706,.084829,.101320,.109080,.128530],
                  tabs=[2.00,1.20,0.87,0.61,0.44,0.32,0.25]),
 "Mu-split": dict(c=PURPLE, m="^",
                  dist=[69.756,70.067,71.239,72.725,74.664,78.103,81.092],
                  sd=[.058973,.065539,.077260,.085753,.097807,.112610,.125320],
                  tabs=[2.12,1.27,0.92,0.65,0.46,0.34,0.26]),
}
for v in S.values():
    v["lost"] = np.array(v["dist"]) - min(v["dist"])

fig = plt.figure(figsize=(13.2, 5.6), dpi=140)
fig.patch.set_facecolor("white")

fig.text(.052,.955,"What the pressure build-up rate costs",
         fontsize=20,weight="bold",color=INK,va="center")
fig.text(.052,.906,"Same driver, same car, same brake. Only the road changes. "
                   "21 runs, pressure ceiling fixed at 6000.",
         fontsize=11.5,color=GREY,va="center")

handles=[Line2D([],[],color=v["c"],lw=2,marker=v["m"],ms=6.5,mec="white",mew=1.2,label=k)
         for k,v in S.items()]
lg = fig.legend(handles=handles, loc="upper left", bbox_to_anchor=(.048,.868),
                ncol=3, frameon=False, fontsize=10.5, handlelength=1.6, columnspacing=2.2)
for t in lg.get_texts(): t.set_color(GREY)

def style(ax, title, ylab, sub):
    ax.set_facecolor(SURF)
    for s in ("top","right"): ax.spines[s].set_visible(False)
    for s in ("left","bottom"):
        ax.spines[s].set_color("#C2C8CE"); ax.spines[s].set_linewidth(.9)
    ax.grid(True, color=GRID, linewidth=.9); ax.set_axisbelow(True)
    ax.tick_params(colors=MUTED, labelsize=9.5, length=3)
    ax.set_xscale("log"); ax.set_xticks(ramps)
    ax.set_xticklabels([f"{int(r)}" for r in ramps], fontsize=9)
    ax.minorticks_off()
    ax.set_xlabel("pressure build-up rate", fontsize=10, color=GREY, labelpad=7)
    ax.set_ylabel(ylab, fontsize=10, color=GREY, labelpad=7)
    ax.text(0, 1.105, title, transform=ax.transAxes, fontsize=12.5,
            weight="bold", color=INK, va="baseline")
    ax.text(0, 1.030, sub, transform=ax.transAxes, fontsize=9.5,
            color=MUTED, va="baseline")

L, W, B, H = .052, .262, .205, .515
axes = [fig.add_axes([L+i*.318, B, W, H]) for i in range(3)]

def mark(ax, y, lbl=None):
    ax.axvline(4500, color=INK, lw=1, ls=(0,(4,3)), alpha=.45, zorder=1)
    if lbl: ax.text(4700, y, lbl, fontsize=9.5, color=INK, ha="left", va="center")

ax = axes[0]
style(ax, "Metres lost", "metres behind that surface's best",
      "measured against the best stop on the same surface")
for k,v in S.items():
    ax.plot(ramps, v["lost"], color=v["c"], lw=2, marker=v["m"], ms=6.5,
            mec="white", mew=1.2, zorder=3)
ax.set_ylim(-1.0, 15.2); mark(ax, 13.6, "ramp 4500")

ax = axes[1]
style(ax, "Slow ramp wastes time", "seconds before the ABS first acts",
      "what it costs on the left of the dip")
for k,v in S.items():
    ax.plot(ramps, v["tabs"], color=v["c"], lw=2, marker=v["m"], ms=6.5,
            mec="white", mew=1.2, zorder=3)
ax.set_ylim(0, 3.75); mark(ax, 3.35)
ax.annotate("half the stop spent\nunder-braked", xy=(900, 3.22), xytext=(1550, 3.30),
            fontsize=9.5, color=GREY, va="center",
            arrowprops=dict(arrowstyle="-|>", color="#AEB6BD", lw=1.2, shrinkA=2, shrinkB=4))

ax = axes[2]
style(ax, "Fast ramp shakes the loop", "spread of slip while the ABS works",
      "what it costs on the right of the dip")
for k,v in S.items():
    ax.plot(ramps, v["sd"], color=v["c"], lw=2, marker=v["m"], ms=6.5,
            mec="white", mew=1.2, zorder=3)
ax.set_ylim(0, .145); mark(ax, .1355)
ax.text(830, .026, "rises in every one of the 21 runs", fontsize=9.5, color=GREY, va="center")

fig.text(.052,.062,
  "The two right-hand panels pull in opposite directions, and where they cross is the dip on the left.",
  fontsize=10.5, color=INK, va="center")
fig.text(.052,.026,
  "Ramp 4500 is not the shortest stop. It is the one where the ABS still reacts inside half a second, "
  "which costs under a metre on dry and about six on wet.",
  fontsize=10, color=GREY, va="center")

fig.savefig("ramp_sweep.png", facecolor="white")
print("ok")
