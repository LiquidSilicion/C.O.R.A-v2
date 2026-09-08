# C.O.R.A v2 — Neuromorphic Keyword Spotting on FPGA

**C**ochlear-**O**riented **R**ecurrent **A**rchitecture (v2)

A resource-efficient, FPGA-accelerated neuromorphic keyword spotting (KWS) 
system targeting the **ZedBoard (Xilinx Zynq-7020)**. This project implements 
an end-to-end bio-inspired audio pipeline—from a 64-channel cochlear filterbank 
through leaky integrate-and-fire (LIF) spike encoding to spiking neural network 
(SNN) inference—entirely in synthesizable Verilog.

This is a ground-up redesign of the original [C.O.R.A v1](https://github.com/LiquidSilicion/C.O.R.A), 
re-architected to fit within the strict resource constraints (140 BRAMs, 220 DSPs) 
of the Zynq-7020 while scaling the auditory frontend from 16 to 64 channels.

---

## Motivation

The original C.O.R.A v1 targeted the ZCU104 (Zynq UltraScale+) and used a 
brute-force parallel architecture (16 parallel processing engines, 16× weight 
memory replication). While functionally correct in simulation, the design 
exceeded the resource budget of smaller edge FPGAs, suffered from clock-domain 
crossing bugs, and contained several critical synthesis-blocking issues 
(undefined signals, incorrect clock divider math, reset polarity mismatches).

**C.O.R.A v2** addresses all of these through architectural redesign rather 
than patching:

| Aspect              | v1 (ZCU104)         | v2 (ZedBoard)              |
|---------------------|----------------------|----------------------------|
| Cochlear Channels   | 16                   | **64**                     |
| Parallel Engines    | 16                   | **4** (time-multiplexed)   |
| Weight BRAM Replicas| 16 copies (~114 BRAM)| **4 copies (~29 BRAM)**    |
| Spike×Weight Mult   | DSP48 multiplier     | **DSP-free (conditional shift)** |
| SNN Training        | On-chip STDP (planned)| **Offline (PyTorch/snnTorch)** |
| Clock Domains       | 125 MHz → 50 MHz CDC | **Single 100 MHz domain**  |
| Target Board        | ZCU104               | **ZedBoard (XC7Z020)**     |

---

## Architecture

### 1. Cochlear Audio Frontend (100 MHz)
- **64-band ERB-spaced FIR/Biquad filterbank** (200 Hz – 8 kHz, logarithmic scale)
- **Meddis-inspired inner hair cell (IHC) model** with adaptation
- **Leaky Integrate-and-Fire (LIF)** spike encoder per channel
- 1 µs timestamp precision, Address-Event Representation (AER) output

### 2. Event-Driven Spike Pipeline
- **AER Encoder**: Packets of `{channel_id[5:0], timestamp[19:0]}`
- **Ping-Pong BRAM Window Accumulator**: Dual-buffered spike-count 
  histogram (64 channels × 64 time bins) with shadow-register forwarding 
  for single-cycle read-modify-write
- **Overlap Voter**: Sliding-window decision fusion across consecutive frames

### 3. SNN Inference Engine (Time-Multiplexed)
- **4 Parallel Processing Engines (PEs)** iterating over 128 hidden neurons 
  and 2 output classes
- **Three-phase weight access**: Input weights → Recurrent weights → Output weights
- **DSP-free recurrent multiplication**: Since spikes are 1-bit, 
  `weight × spike` is implemented as a conditional left-shift, eliminating 
  100% of DSP usage for recurrent and output layers
- **Offline-trained weights** loaded from `.mem` files (quantized 16-bit fixed-point)

### 4. Output
- Keyword class prediction via first-to-spike or population rate coding
- Result transmitted over UART (hex-encoded) or indicated via on-board LEDs

---

## Project Structure

```
C.O.R.A-v2/
│
├── README.md
├── LICENSE
├── .gitignore
│
├── src/                          # All source code
│   ├── rtl/                      # Verilog/SystemVerilog RTL
│   │   ├── top/                  # Top-level modules
│   │   │   ├── top_layer.sv
│   │   │   └── snn_top_with_rom.sv
│   │   ├── frontend/             # Audio DSP pipeline
│   │   │   ├── audio_rom.sv
│   │   │   ├── pm_filter.sv
│   │   │   ├── fft_filterbank.sv
│   │   │   └── biquad_df2t.sv
│   │   ├── ihc/                  # Inner hair cell models
│   │   │   ├── ihc_top.sv
│   │   │   ├── ihc_channel.sv
│   │   │   ├── nonlinear_compression.sv
│   │   │   ├── adaptation_filter.sv
│   │   │   ├── half_wave_rectifier.sv
│   │   │   ── lowpass_filter.sv
│   │   ├── lif/                  # LIF neurons
│   │   │   ├── lif_top.sv
│   │   │   └── lif_neuron.sv
│   │   ├── aer/                  # Address-Event Representation
│   │   │   ├── aer_encoder.sv
│   │   │   ├── aer_encoder_model.sv
│   │   │   ├── input_from_aer.sv
│   │   │   └── timestamp_manager.sv
│   │   ├── snn/                  # SNN accelerator
│   │   │   ├── mac_engine.sv
│   │   │   ├── weight_router.sv
│   │   │   ├── weight_bank.sv
│   │   │   ├── lif_array.sv
│   │   │   ├── s10_window_accumulator.sv
│   │   │   ├── window_acc_bram.sv
│   │   │   └── overlap_voter.sv
│   │   ├── common/               # Reusable components
│   │   │   ├── fifo.sv
│   │   │   ├── clock_divider.sv
│   │   │   ├── cdc_sync.sv
│   │   │   ── uart_tx.sv
│   │   ── include/              # Header files, packages
│   │       └── erb_coefficients.vh
│   │
│   ├── python/                   # Python scripts
│   │   ├── train_snn.py          # SNN training (PyTorch/snnTorch)
│   │   ├── gen_audio_rom.py      # Convert WAV to .mem
│   │   ├── gen_coefficients.py   # Generate ERB filter coeffs
│   │   ├── gen_weights.py        # Export trained weights
│   │   ├── verify_model.py       # Python reference model
│   │   └── utils/
│   │       ├── dataset.py
│   │       ── quantize.py
│   │
│   ├── constraints/              # XDC constraint files
│   │   ├── zedboard.xdc
│   │   ├── zcu104.xdc
│   │   └── timing_constraints.xdc
│   │
│   ├── tcl/                      # TCL scripts for Vivado
│   │   ├── create_project.tcl
│   │   ├── run_synthesis.tcl
│   │   ├── run_implementation.tcl
│   │   └── generate_bitstream.tcl
│   │
│   └── testbenches/              # Simulation testbenches
│       ├── tb_top_layer.sv
│       ├── tb_filterbank.sv
│       ├── tb_mac_engine.sv
│       └── cocotb/               # Python-based testbenches
│           └── test_aer_encoder.py
│
├── mem/                          # Memory initialization files
│   ├── audio/
│   │   ├── on.mem
│   │   ├── off.mem
│   │   └── yes.mem
│   ├── weights/
│   │   ├── win.mem
│   │   ├── wrec.mem
│   │   └── wout.mem
│   ├── lookup/
│   │   └── ni_lut.mem
│   └── aer/
│       └── aer_input.mem
│
├── docs/                         # Documentation
│   ├── README.md                 # Detailed documentation
│   ├── architecture/
│   │   ├── system_overview.md
│   │   ├── dsp_pipeline.md
│   │   ├── snn_accelerator.md
│   │   └── block_diagrams/
│   │       ├── frontend.pdf
│   │       └── backend.pdf
│   ├── papers/
│   │   ├── draft_v1.tex
│   │   ├── figures/
│   │   ── references.bib
│   ├── reports/
│   │   ├── midterm_report.pdf
│   │   └── final_report.pdf
│   ── changelog.md
│
── logs/                         # Build and simulation logs
│   ├── synthesis/
│   ├── implementation/
│   ├── simulation/
│   └── power_estimation/
│
├── results/                      # Experimental results
│   ├── vivado_reports/
│   │   ├── utilization.rpt
│   │   ├── timing.rpt
│   │   └── power.rpt
│   ├── measurements/
│   │   ├── accuracy_results.csv
│   │   └── latency_measurements.csv
│   └── waveforms/
│       ── *.vcd
│
├── scripts/                      # Utility scripts
│   ├── setup_env.sh
│   ├── clean_build.sh
│   ├── run_simulation.sh
│   └── parse_reports.py
│
├── hardware/                     # Hardware-specific files
│   ├── zedboard/
│   │   ├── constraints.xdc
│   │   └── pin_mapping.md
│   └── zcu104/
│       ├── constraints.xdc
│       └── pin_mapping.md
│
└── notebooks/                    # Jupyter notebooks for exploration
    ├── 01_data_exploration.ipynb
    ├── 02_model_training.ipynb
    └── 03_results_analysis.ipynb
```

---

## Key Design Decisions

### Why 64 Channels but Only 4 PEs?
The cochlear frontend requires **precise temporal alignment** across all 
frequency bands—every sample must pass through all 64 filters simultaneously 
to preserve spike timing. Hence, the frontend is **fully parallel**.

The SNN backend, however, processes discrete time windows and is tolerant 
of latency. By reducing parallelism to 4 PEs, we trade a modest increase 
in inference latency (~4× more clock cycles) for a **75% reduction in BRAM 
usage**, freeing resources for the larger frontend. This hybrid 
parallel/time-multiplexed approach is a core contribution of this work.

### Why No On-Chip Learning?
Implementing STDP in RTL requires per-synapse timestamp storage, 
bidirectional weight updates, and complex arbitration logic. For edge 
deployment, **offline training with quantized weights** achieves comparable 
accuracy while dramatically simplifying the hardware. The trained weights 
are exported from Python as 16-bit fixed-point values and loaded into 
on-chip BRAM at configuration time.

### Why DSP-Free Spike Multiplication?
In an SNN, neuron outputs are binary (spike or no spike). Multiplying a 
16-bit weight by a 1-bit spike is mathematically equivalent to:
```
result = spike ? (weight << 8) : 0;
```
This is a multiplexer and a wire concatenation—not a multiplication. 
Replacing DSP48 multipliers with conditional shifts in the recurrent and 
output layers saves up to 16 DSPs and reduces routing congestion, with 
zero impact on numerical accuracy.

---

## Target Hardware

| Resource        | ZedBoard (XC7Z020) | v2 Estimated Usage |
|-----------------|---------------------|--------------------|
| LUTs            | 53,200              | ~35%               |
| Flip-Flops      | 106,400             | ~15%               |
| BRAMs (36 Kb)   | 140                 | ~40 (~29 weights + ~8 accum + ~3 FIFO) |
| DSP48 Slices    | 220                 | ~64 (frontend biquads only) |
| Clock           | 100 MHz (Y9)       | Single domain      |

---

## Getting Started

### Prerequisites
- **Xilinx Vivado** (2023.2 or later recommended)
- **Python 3.9+** with `torch`, `snntorch`, `numpy`, `scipy`
- **ZedBoard** (Xilinx Zynq-7020) with PDM/I2S MEMS microphone

### Build Flow
1. Generate weights and audio ROM in Python:
   ```bash
   cd python
   python train_snn.py      # Train SNN, export weights to ../mem/
   python gen_audio_rom.py  # Convert .wav to ../mem/audio.mem
   python gen_coefficients.py  # Export ERB filter coefficients
   ```
2. Open Vivado, add all `rtl/` sources, `constraints/zedboard.xdc`, 
   and `mem/` files.
3. Run Synthesis → Implementation → Generate Bitstream.
4. Program the ZedBoard. Speak a keyword into the microphone.
5. Observe prediction on LEDs or UART terminal (115200 baud).

---

## Paper / Research

This project supports research into **hardware-efficient neuromorphic 
computing for edge audio processing**. Planned contributions:

1. **Hybrid parallel/time-multiplexed architecture** for fitting large-scale 
   neuromorphic pipelines on resource-constrained FPGAs
2. **DSP-free SNN inference** via conditional-shift accumulation
3. **Scalability analysis**: Power, accuracy, and resource trade-offs 
   when scaling from 16 → 64 cochlear channels
4. **End-to-end characterization**: Latency, throughput, and power 
   measurements on real hardware

Target venues: IEEE BioCAS, FPL, ISCAS, or neuromorphic computing workshops.

---

## Status

🔨 **Active Redesign** — Frontend modules are being ported to 64-channel 
with `generate` loops. SNN inference engine has been refactored for 
`N_PE=4` and DSP-free operation. Full system integration and on-board 
validation in progress.
---
