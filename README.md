# fir-filter-vhdl

An 8-tap low-pass FIR filter in VHDL, simulated with GHDL and checked against a bit-accurate Python model.

## Specification

| Item | Value |
|---|---|
| Taps | 8 |
| Coefficients | `[-1, 1, 18, 46, 46, 18, 1, -1]`, Q1.7, sum 128 |
| Input / output | 8-bit signed |
| Products / accumulator | 16-bit / 19-bit |
| Scaling | Shift right by 7, saturation to -128 and 127 |
| Latency | 2 clock cycles |
| Design | 8 kHz sampling, 1.5 kHz cutoff, `scipy.signal.firwin` |

## Files

- `fir8.vhd`: the filter, followed by its testbench `tb_fir8`.
- `fir.py`: generates the test input, checks the result, draws the figures.

## Requirements

GHDL with VHDL-2008 support. Python 3 with `numpy` and `scipy`, plus `matplotlib` for the figures.

## Run

```bash
python fir.py gen                 # writes input.txt
ghdl -a --std=08 fir8.vhd
ghdl -e --std=08 tb_fir8
ghdl -r --std=08 tb_fir8          # reads input.txt, writes output.txt
python fir.py verify              # compares with the Python model
python fir.py plots               # optional figures
```

## Results

On the 200-sample test input, a 500 Hz tone with a 3.2 kHz interferer and noise:

- The VHDL output matches the Python fixed-point model exactly, with 0 differences.
- The maximum deviation from the ideal floating-point filter is about 1.29 LSB.
- Gain of the quantised filter: -0.5 dB at 500 Hz and -32.8 dB at 3.2 kHz.

## Limitations

- Behavioural simulation only. No synthesis and no FPGA test, so no timing or resource figures.
- An educational filter, with a gentle transition band.
- The testbench does not check anything itself. The check is done by `fir.py verify`.

## License

MIT
