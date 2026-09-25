import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np

BLUE, ORANGE, PURPLE = "#0073BA", "#D95319", "#6A3D9A"
INK, GREY, MUTED, GRID = "#1A1A1A", "#4A4A4A", "#6E7681", "#E6E9EC"
SURF = "#FCFCFB"
RED  = "#C0392B"

slip = np.arange(0, 1.001, .05)
mu   = np.array([0,.24,.48,.582,.60,.588,.576,.564,.552,.540,.528,
                 .513,.498,.486,.474,.462,.450,.438,.432,.426,.420])/.60

T = {
 "Dry":      dict(c=BLUE,   m="o", t=[.15,.16,.17,.20],
                  eff=[.9387,.9472,.9515,.9242],
                  sd=[np.nan,.026226,.037643,.085363]),
 "Wet":      dict(c=ORANGE, m="s", t=[.15,.16,.17,.20],
                  eff=[.9147,.9169,.9155,.8826],
                  sd=[.035413,.045702,.056548,.10132]),
 "Mu-split": dict(c=PURPLE, m="^", t=[.12,.14,.15,.16,.17,.18,.20,.22,.25,.28,.32],
                  eff=[.8574,.9121,.9266,.9244,.9174,.9120,.8920,.8746,.8267,.7793,.7260],
                  sd=[np.nan,np.nan,.032496,.042771,.056175,.068451,.097807,
                      .12151,.18111,.24902,.30219]),
}

fig = plt.figure(figsize=(13.2, 5.6), dpi=140)
fig.patch.set_facecolor("white")

fig.text(.052,.955,"The friction peak is also the stability limit",
         fontsize=20,weight="bold",color=INK,va="center")
fig.text(.052,.906,"The shipped setpoint sits exactly on the peak. Moving it back to 0.16 "
                   "shortens every stop.",
         fontsize=11.5,color=GREY,va="center")

handles=[Line2D([],[],color=v["c"],lw=2,marker=v["m"],ms=6.5,mec="white",mew=1.2,label=k)
         for k,v in T.items()]
lg = fig.legend(handles=handles, loc="upper left", bbox_to_anchor=(.372,.868),
                ncol=3, frameon=False, fontsize=10.5, handlelength=1.6, columnspacing=2.2)
for t in lg.get_texts(): t.set_color(GREY)

def style(ax, title, xlab, ylab, sub):
    ax.set_facecolor(SURF)
    for s in ("top","right"): ax.spines[s].set_visible(False)
    for s in ("left","bottom"):
        ax.spines[s].set_color("#C2C8CE"); ax.spines[s].set_linewidth(.9)
    ax.grid(True, color=GRID, linewidth=.9); ax.set_axisbelow(True)
    ax.tick_params(colors=MUTED, labelsize=9.5, length=3)
    ax.set_xlabel(xlab, fontsize=10, color=GREY, labelpad=7)
    ax.set_ylabel(ylab, fontsize=10, color=GREY, labelpad=7)
    ax.text(0, 1.105, title, transform=ax.transAxes, fontsize=12.5,
            weight="bold", color=INK, va="baseline")
    ax.text(0, 1.030, sub, transform=ax.transAxes, fontsize=9.5,
            color=MUTED, va="baseline")

L, W, B, H = .052, .262, .205, .515
axes = [fig.add_axes([L+i*.318, B, W, H]) for i in range(3)]

# ---- panel 1 : the friction curve ---------------------------------------
ax = axes[0]
style(ax, "The model's tyre", "slip", "grip, as a share of its own peak",
      "one lookup table, the same shape on every surface")
ax.axvspan(0, .20, color=BLUE,  alpha=.055, zorder=0)
ax.axvspan(.20, 1., color=RED,  alpha=.055, zorder=0)
ax.plot(slip, mu, color=INK, lw=2.2, zorder=3)
ax.plot([.20],[1.0], "o", ms=9, color=INK, mec="white", mew=1.6, zorder=4)
ax.plot([.16],[np.interp(.16, slip, mu)], "o", ms=9, color="#1E8E3E",
        mec="white", mew=1.6, zorder=4)
ax.set_xlim(0,1); ax.set_ylim(0,1.20)
ax.set_xticks([0,.16,.20,.4,.6,.8,1.0])
ax.set_xticklabels(["0","","0.20","0.4","0.6","0.8","1.0"])
ax.text(.20,1.075,"peak 0.20", fontsize=10, weight="bold", color=INK, ha="center")
ax.annotate("0.16", xy=(.16,.973), xytext=(.335,.74), fontsize=10, weight="bold",
            color="#1E8E3E", ha="left", va="center",
            arrowprops=dict(arrowstyle="-|>", color="#1E8E3E", lw=1.3, shrinkA=2, shrinkB=4))
ax.text(.132,.30,"STABLE", fontsize=10, weight="bold", color=BLUE, ha="center", va="center")
ax.text(.132,.21,"more slip\nfinds more grip", fontsize=8.5, color=MUTED, ha="center",
        va="center", linespacing=1.55)
ax.text(.60,.30,"UNSTABLE", fontsize=10, weight="bold", color=RED, ha="center", va="center")
ax.text(.60,.21,"more slip\nfinds less grip", fontsize=8.5, color=MUTED, ha="center",
        va="center", linespacing=1.55)

# ---- panel 2 : oscillation ----------------------------------------------
ax = axes[1]
style(ax, "Past the peak the loop runs away", "slip setpoint",
      "spread of slip while the ABS works", "ramp 4500, ceiling 6000")
ax.axvspan(.20,.34, color=RED, alpha=.055, zorder=0)
for k,v in T.items():
    ax.plot(v["t"], v["sd"], color=v["c"], lw=2, marker=v["m"], ms=6.5,
            mec="white", mew=1.2, zorder=3)
ax.axvline(.20, color=INK, lw=1, ls=(0,(4,3)), alpha=.45, zorder=1)
ax.set_xlim(.11,.335); ax.set_ylim(0,.385)
ax.set_xticks([.12,.16,.20,.25,.32])
ax.text(.196,.358,"friction peak", fontsize=9.5, color=INK, ha="right", va="center")
ax.text(.210,.330,"by 0.28 it is all but locked",
        fontsize=9.5, color=RED, ha="left", va="center")

# ---- panel 3 : efficiency ------------------------------------------------
ax = axes[2]
style(ax, "And braking gets worse with it", "slip setpoint",
      "share of the available grip used", "ramp 4500, ceiling 6000")
ax.axvspan(.20,.34, color=RED, alpha=.055, zorder=0)
for k,v in T.items():
    ax.plot(v["t"], 100*np.array(v["eff"]), color=v["c"], lw=2, marker=v["m"],
            ms=6.5, mec="white", mew=1.2, zorder=3)
ax.axvline(.20, color=INK, lw=1, ls=(0,(4,3)), alpha=.45, zorder=1)
ax.axvline(.16, color="#1E8E3E", lw=1.4, zorder=1)
ax.set_xlim(.11,.335); ax.set_ylim(70,99.5)
ax.set_xticks([.12,.16,.20,.25,.32])
ax.text(.163,97.6,"0.16", fontsize=10, weight="bold", color="#1E8E3E",
        ha="left", va="center")
ax.text(.207,97.6,"shipped", fontsize=9.5, color=INK, ha="left", va="center")

fig.text(.052,.062,
  "Left of the peak, a wheel that slips too much finds more grip and pulls itself back. "
  "Right of it, more slip means less grip, which means still more slip.",
  fontsize=10.5, color=INK, va="center")
fig.text(.052,.026,
  "A bang-bang controller with no dead band and a 10 ms sample rate cannot hold a setpoint "
  "on that boundary. Backing it off to 0.16 gains 1 to 3 metres on every surface.",
  fontsize=10, color=GREY, va="center")

fig.savefig("slip_target.png", facecolor="white")
print("ok")
