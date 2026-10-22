"""wave.py:  timing diagrams from a GHDL VCD, for the firmware description (pacman_docs/agents).

A diagram is a list of rows, top to bottom.  Each row is one signal of the VCD:

    bit(name, label)                         a single bit
    bus(name, label, fmt=..., show=...)      a vector:  a box per value, labelled with fmt(value)
                                             (show(value) False:  box drawn, no label)
    strobe(name, label)                      a single bit drawn as ticks (for dense one-clock pulses)

    plot("out.pdf", "file.vcd", rows, t0, t1, marks={time: text}, unit="ns")

Names are full VCD names ("tb.uut.sig[7:0]"); a vector can also be cut with bits=(hi, lo).  Times in ns.
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from vcdvcd import VCDVCD

_cache = {}


def _vcd(path):
    if path not in _cache:
        _cache[path] = VCDVCD(path)
    return _cache[path]


def _series(vcd, name, t0, t1, bits=None):
    """(times_ns, values) of the changes in [t0, t1], starting with the value at t0."""
    tv = vcd[name].tv
    out = []
    for t_fs, v in tv:
        t = t_fs / 1e6
        if any(c not in "01" for c in v):
            val = None                      # U / X / Z:  shown as unknown
        else:
            val = int(v, 2)
            if bits is not None:
                hi, lo = bits
                val = (val >> lo) & ((1 << (hi - lo + 1)) - 1)
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
    def __init__(self, name, label, bits=None):
        self.name, self.label, self.bits, self.h = name, label, bits, 1.0


class strobe(bit):
    pass


class bus:
    def __init__(self, name, label, fmt=lambda v: "%X" % v, show=lambda v: True, bits=None, size=9):
        self.name, self.label, self.fmt, self.show, self.bits, self.size, self.h = name, label, fmt, show, bits, size, 1.0


def plot(out, vcd_path, rows, t0, t1, marks=None, unit="ns", width=10.0, row_h=0.42, slope=None):
    vcd = _vcd(vcd_path)
    scale = 1000.0 if unit == "us" else 1.0
    slope = (t1 - t0) / 400.0 if slope is None else slope
    n = len(rows)
    fig, ax = plt.subplots(figsize=(width, 0.6 + row_h * n * 1.6))
    yt, yl = [], []
    for i, r in enumerate(rows):
        y = (n - 1 - i) * 1.6
        yt.append(y + 0.5)
        yl.append(r.label)
        s = _series(vcd, r.name, t0, t1, getattr(r, "bits", None))
        if isinstance(r, strobe):
            ax.plot([t0 / scale, t1 / scale], [y, y], "k-", lw=1)
            for k, (t, v) in enumerate(s):
                if v == 1:
                    te = s[k + 1][0] if k + 1 < len(s) else t1
                    ax.plot([t / scale, t / scale, te / scale, te / scale], [y, y + 1, y + 1, y], "k-", lw=1)
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
            ax.plot(xs, ys, "k-", lw=1)
        else:
            for k, (t, v) in enumerate(s):
                te = s[k + 1][0] if k + 1 < len(s) else t1
                a = t + (slope / 2 if k else 0)
                b = te - (slope / 2 if k + 1 < len(s) else 0)
                if v is None:
                    ax.fill_between([a / scale, b / scale], y, y + 1, color="0.85", lw=0)
                ax.plot([a / scale, b / scale], [y + 1, y + 1], "k-", lw=1)
                ax.plot([a / scale, b / scale], [y, y], "k-", lw=1)
                if k + 1 < len(s):                       # the crossing to the next value
                    c0, c1 = (te - slope / 2) / scale, (te + slope / 2) / scale
                    ax.plot([c0, c1], [y, y + 1], "k-", lw=1)
                    ax.plot([c0, c1], [y + 1, y], "k-", lw=1)
                if v is not None and r.show(v):
                    ax.text((a + b) / 2 / scale, y + 0.5, r.fmt(v), ha="center", va="center",
                            fontsize=r.size, clip_on=True)
    for t, txt in (marks or {}).items():
        ax.axvline(t / scale, color="0.5", ls="--", lw=0.8)
        ax.text(t / scale, n * 1.6 - 0.35, txt, ha="center", va="bottom", fontsize=9, color="0.25")
    ax.set_yticks(yt)
    ax.set_yticklabels(yl, fontsize=11)
    ax.tick_params(axis="y", length=0)
    ax.set_ylim(-0.4, n * 1.6 + (0.4 if marks else -0.2))
    ax.set_xlim(t0 / scale, t1 / scale)
    ax.set_xlabel("Time (%s)" % unit)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)
