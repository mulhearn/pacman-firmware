"""wave.py:  timing diagrams from a GHDL VCD, for the firmware description (pacman_docs/agents).

A diagram is a list of rows, top to bottom.  Each row is one signal of the VCD:

    bit(name, label)                         a single bit
    bus(name, label, fmt=..., show=...)      a vector:  a box per value, labelled with fmt(value)
                                             (show(value) False:  box drawn, no label)
    strobe(name, label)                      a single bit drawn as ticks (for dense one-clock pulses)

    plot("out.pdf", "file.vcd", rows, t0, t1, points=[(t, label, level)], unit="ns")

Callouts are drawn in LaTeX, over the included PDF (a tikzpicture with the figure at (0,0), anchor south
west).  points:  prints where time t at the level (0 or 1) of the row with that label lands on the page, in
cm from the lower left corner, to place them.  bit(..., count=True):  each high period numbered inside the pulse.

Names are full VCD names ("tb.uut.sig[7:0]"); a vector can also be cut with bits=(hi, lo).  Times in ns.

The figures are drawn at their printed size (the text width of the TRM and firmware.tex, letter paper with
0.75 in margins:  7.0 in) and typeset by LaTeX (pgf) in the document's font:  include them unscaled.
"""
import matplotlib
matplotlib.use("pgf")
import matplotlib.pyplot as plt
plt.rcParams.update({
    "pgf.texsystem": "pdflatex",
    "pgf.rcfonts": False,
    "pgf.preamble": r"\usepackage{lmodern}\usepackage[T1]{fontenc}",
    "font.family": "serif",
    "font.size": 12,
})
from vcdvcd import VCDVCD

_cache = {}
WIDTH = 7.0         # in:  \textwidth of the TRM and firmware.tex
LW = 1.0            # pt
LABEL = 12          # row labels and the axis label (pt):  the TRM's text size
SMALL = 12          # ticks, marks, notes, arrows, bus values (pt)


def _tex(s):
    return "".join("\\" + c if c in "_%&#$" else c for c in s)


def _vcd(path):
    if path not in _cache:
        _cache[path] = VCDVCD(path)
    return _cache[path]


def _series(vcd, name, t0, t1, bits=None):
    """(times_ns, values) of the changes in [t0, t1], starting with the value at t0."""
    tv = vcd[name].tv
    width = int(vcd[name].size)
    out = []
    for t_fs, v in tv:
        t = t_fs / 1e6
        if bits is not None:                # only the selected bits decide (others may be U)
            v = v.rjust(width, v[0] if v[0] in "xXzZuU" else "0")
            hi, lo = bits
            v = v[width - 1 - hi:width - lo]
        if any(c not in "01" for c in v):
            val = None                      # U / X / Z:  shown as unknown
        else:
            val = int(v, 2)
        if t <= t0:
            out = [(t0, val)]
        elif t <= t1:
            if out and out[-1][1] == val:
                continue
            out.append((t, val))
        else:
            break
    return out


class bit:
    def __init__(self, name, label, bits=None, count=False):
        self.name, self.label, self.bits, self.count, self.h = name, label, bits, count, 1.0


class strobe(bit):
    pass


class bus:
    def __init__(self, name, label, fmt=lambda v: "%X" % v, show=lambda v: True, bits=None, size=SMALL):
        self.name, self.label, self.fmt, self.show, self.bits, self.size, self.h = name, label, fmt, show, bits, size, 1.0


def plot(out, vcd_path, rows, t0, t1, points=None, unit="ns", width=WIDTH, row_h=0.26, slope=None):
    vcd = _vcd(vcd_path)
    scale = 1000.0 if unit == "us" else 1.0
    slope = (t1 - t0) / 400.0 if slope is None else slope
    n = len(rows)
    top = n * 1.6 - 0.2
    fig, ax = plt.subplots(figsize=(width, 0.5 + row_h * n * 1.6))
    yt, yl, fits = [], [], []
    for i, r in enumerate(rows):
        y = (n - 1 - i) * 1.6
        yt.append(y + 0.5)
        yl.append(_tex(r.label))
        s = _series(vcd, r.name, t0, t1, getattr(r, "bits", None))
        if isinstance(r, strobe):
            ax.plot([t0 / scale, t1 / scale], [y, y], "k-", lw=LW)
            for k, (t, v) in enumerate(s):
                if v == 1:
                    te = s[k + 1][0] if k + 1 < len(s) else t1
                    ax.plot([t / scale, t / scale, te / scale, te / scale], [y, y + 1, y + 1, y], "k-", lw=LW)
        elif isinstance(r, bit):
            xs, ys = [], []
            for k, (t, v) in enumerate(s):
                level = 0.5 if v is None else v
                if k:
                    xs.append(t / scale)
                    ys.append(ys[-1])
                xs.append(t / scale)
                ys.append(y + level)
            xs.append(t1 / scale)
            ys.append(ys[-1])
            ax.plot(xs, ys, "k-", lw=LW)
            if r.count:
                ones = [(t, s[k + 1][0] if k + 1 < len(s) else t1) for k, (t, v) in enumerate(s) if v == 1]
                for j, (a, b) in enumerate(ones):
                    ax.text((a + b) / 2 / scale, y + 0.45, "%d" % (j + 1), ha="center", va="center", fontsize=SMALL)
        else:
            for k, (t, v) in enumerate(s):
                te = s[k + 1][0] if k + 1 < len(s) else t1
                a = t + (slope / 2 if k else 0)
                b = te - (slope / 2 if k + 1 < len(s) else 0)
                if v is None:
                    ax.fill_between([a / scale, b / scale], y, y + 1, color="0.85", lw=0)
                ax.plot([a / scale, b / scale], [y + 1, y + 1], "k-", lw=LW)
                ax.plot([a / scale, b / scale], [y, y], "k-", lw=LW)
                if k + 1 < len(s):                       # the crossing to the next value
                    c0, c1 = (te - slope / 2) / scale, (te + slope / 2) / scale
                    ax.plot([c0, c1], [y, y + 1], "k-", lw=LW)
                    ax.plot([c0, c1], [y + 1, y], "k-", lw=LW)
                if v is not None and r.show(v):
                    fits.append((ax.text((a + b) / 2 / scale, y + 0.5, _tex(r.fmt(v)), ha="center",
                                         va="center", fontsize=r.size, clip_on=True), a / scale, b / scale))
    row_y = lambda label: (n - 1 - [r.label for r in rows].index(label)) * 1.6
    ax.set_yticks(yt)
    ax.set_yticklabels(yl, fontsize=LABEL)
    ax.tick_params(axis="y", length=0)
    ax.tick_params(axis="x", labelsize=SMALL)
    ax.set_ylim(-0.4, top)
    ax.set_xlim(t0 / scale, t1 / scale)
    ax.set_xlabel(r"Time ($\mu$s)" if unit == "us" else "Time (%s)" % unit, fontsize=LABEL)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    fig.tight_layout()
    rend = fig.canvas.get_renderer()
    for txt, a, b in fits:                                   # bus values wider than their cell
        x0, x1 = ax.transData.transform([(a, 0), (b, 0)])[:, 0]
        if txt.get_window_extent(rend).width > x1 - x0:
            print("%s:  \"%s\" at %g does not fit" % (out, txt.get_text(), a))
    for t, label, level in (points or []):                  # callout positions for LaTeX, cm
        x, y = fig.dpi_scale_trans.inverted().transform(ax.transData.transform((t / scale, row_y(label) + level)))
        print("%s:  %g %s, %s level %d:  (%.2f, %.2f)" % (out, t / scale, unit, label, level, x * 2.54, y * 2.54))
    fig.savefig(out)
    plt.close(fig)
