# Communication Interference Simulation

MATLAB framework for simulating communication waveforms under jamming, controlling signal-to-interference ratio (SIR), and exporting datasets for machine-learning experiments.

## Overview

The project provides object-oriented jamming generators (targeted, barrage, and follower styles), an interference simulation engine, analysis helpers, and test scripts. It is intended for academic and research use in wireless / electronic-warfare coursework—not as a fielded operational system.

Reported coverage in the original documentation includes many waveform/jamming combinations (on the order of 100 waveforms × 8 jamming styles) and SIR control around a configurable target (commonly 10 dB). Treat those figures as design goals of this codebase; verify locally before citing them.

## Features / scope

- Eight jamming styles spanning targeted, barrage, and follower categories (single-tone, multi-tone, narrowband, noise FM, wideband, comb, sweep, frequency-hop follower)
- Waveform generation modules under `src/waveforms/`
- SIR combination helpers
- Simulation entry points for batch runs and dataset export
- Test scripts for jamming generation and end-to-end simulation

### Jamming styles (summary)

| ID | Category | Style | Notes |
|----|----------|-------|-------|
| 1 | Targeted | Single-tone CW | Continuous wave at one frequency |
| 2 | Targeted | Multi-tone CW | Multiple tones |
| 3 | Targeted | Narrowband digital | QPSK/16QAM-style narrowband |
| 4 | Targeted | Noise FM | Noise-modulated FM |
| 5 | Barrage | Wideband | Covers the communications band |
| 6 | Barrage | Comb spectrum | Filtered noise comb |
| 7 | Barrage | Sweep (LFM) | Configurable sweep period |
| 8 | Follower | Frequency-hop CW | Follows a hop pattern |

## Requirements

- MATLAB R2020a or newer
- Signal Processing Toolbox
- Communications Toolbox (recommended)

## Getting started

```bash
git clone https://github.com/AsaqeLee/CommofInterference.git
cd CommofInterference
```

In MATLAB:

```matlab
addpath(genpath('src'));

% Smoke-test jamming generators
run('test_all_jamming_signals.m');

% Full simulation entry (may be long-running)
run('run_complete_simulation.m');
```

### Example: generate and combine

```matlab
config = JammingConfigManager.get_config(1);  % single-tone
jamming = SingleToneJamming(config);
jamming_signal = jamming.generate_jamming_signal([], struct());

sir_controller = SIRController(10);  % target SIR in dB
[combined_signal, actual_sir] = sir_controller.combine_signals(comm_signal, jamming_signal);
```

### Example: simulation engine

```matlab
sim_engine = InterferenceSimulationEngine();
sim_engine.initialize(10, 1000, 100);  % SIR dB, bits, trials
dataset = sim_engine.run_full_simulation();
save('interference_dataset.mat', 'dataset');
```

## Project layout

```text
CommofInterference/
├── src/
│   ├── jamming/       # base, targeted, barrage, follower
│   ├── simulation/
│   ├── analysis/
│   └── waveforms/
├── tests/
├── examples/
├── data/
├── docs/
└── run_complete_simulation.m
```

## Outputs

Depending on the script run, outputs may include BER matrices, feature/label structures for ML, and plots (spectra, time-domain waveforms, heatmaps). Inspect `data/output/` and the saving conventions in the simulation scripts.

## Status / limitations

Research MATLAB codebase. “Industrial-grade” wording from earlier drafts is avoided here: validation is via included test scripts, not an independent certification. Clone URL and badges should point at `AsaqeLee/CommofInterference`.

## License

MIT. See [LICENSE](LICENSE).
