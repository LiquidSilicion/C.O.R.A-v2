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
├── rtl/
│   ├── frontend/          # audio_rom, fft_filterbank, biquad, pm_filter
│   ├── ihc/               # ihc_channel, ihc_top, adaptation_filter, lowpass
│   ├── lif/               # lif_neuron, lif_top
│   ├── aer/               # aer_encoder, aer_encoder_model, timestamp_manager
│   ├── snn/               # mac_engine, weight_router, weight_bank, 
│   │                      # window_acc_bram, s10_window_accumulator, 
│   │                      # lif_array, input_from_aer, overlap_voter
│   ├── common/            # clock_divider, fifo, cdc_sync
│   └── top/               # top_layer, snn_top_with_rom
├── constraints/
│   └── zedboard.xdc       # ZedBoard pin mappings (Y9 clock, P16 reset)
├── mem/                   # Pre-generated .mem files (weights, audio ROM, LUTs)
├── tb/                    # Verilog/Cocotb testbenches
├── python/                # Python reference model (cochlear + SNN training)
├── docs/                  # Block diagrams, timing diagrams, reports
└── README.md
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
