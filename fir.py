"""Helper for the FIR filter: generate the input, check the VHDL output, draw figures.

    python fir.py gen      write input.txt for the testbench
    python fir.py verify   compare output.txt with a bit-accurate model
    python fir.py plots    save fig_time.png and fig_spectrum.png
"""
import sys
import numpy as np
from scipy.signal import firwin, freqz, lfilter

FS, N_TAPS, CUTOFF, SCALE = 8000, 8, 1500, 128   # Hz, taps, Hz, Q1.7


def coefficients():
    return np.round(firwin(N_TAPS, CUTOFF, fs=FS) * SCALE).astype(int)


def stimulus(n=200):
    rng = np.random.default_rng(1)
    k = np.arange(n)
    x = (0.6 * np.sin(2 * np.pi * 500 * k / FS)
         + 0.25 * np.sin(2 * np.pi * 3200 * k / FS)
         + 0.05 * rng.standard_normal(n))
    return np.clip(np.round(x * 127), -128, 127).astype(int)


def model(x, q):
    """Output register after each clock edge: uses x[k-1] ... x[k-8]."""
    y = np.zeros(len(x), dtype=int)
    for k in range(len(x)):
        acc = sum(int(q[i]) * int(x[k - 1 - i]) for i in range(N_TAPS) if k - 1 - i >= 0)
        y[k] = min(127, max(-128, acc >> 7))
    return y


def gen():
    np.savetxt("input.txt", stimulus(), fmt="%d")
    print("coefficients:", coefficients().tolist())


def verify():
    x = np.loadtxt("input.txt", dtype=int)
    y = np.loadtxt("output.txt", dtype=int)
    n = min(len(x), len(y))
    diff = int(np.count_nonzero(model(x, coefficients())[:n] != y[:n]))
    yf = np.concatenate(([0.0], (lfilter(firwin(N_TAPS, CUTOFF, fs=FS), 1, x / SCALE) * SCALE)[:-1]))
    print(f"samples compared      : {n}")
    print(f"VHDL vs fixed point   : {diff} differences")
    print(f"max deviation vs float: {np.max(np.abs(y[:n] - yf[:n])):.2f} LSB")
    return 1 if diff else 0


def plots():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    x = np.loadtxt("input.txt"); y = np.loadtxt("output.txt")
    t = np.arange(80) / FS * 1000
    plt.figure(figsize=(8, 3.5), dpi=150)
    plt.plot(t, x[:80], color="#6B7794", label="noisy input")
    plt.plot(t, y[:80], color="#2563EB", lw=2, label="VHDL output")
    plt.xlabel("Time, ms"); plt.legend(frameon=False); plt.tight_layout()
    plt.savefig("fig_time.png")
    w, h = freqz(coefficients() / SCALE, worN=1024, fs=FS)
    plt.figure(figsize=(8, 3.5), dpi=150)
    plt.plot(w, 20 * np.log10(np.abs(h) + 1e-9), color="#BE185D", lw=2)
    plt.ylim(-50, 5); plt.xlabel("Frequency, Hz"); plt.ylabel("Gain, dB")
    plt.tight_layout(); plt.savefig("fig_spectrum.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "gen": gen()
    elif cmd == "verify": sys.exit(verify())
    elif cmd == "plots": plots()
    else: print(__doc__)
