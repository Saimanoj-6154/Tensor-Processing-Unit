# Tensor-Processing-Unit


A synthesizable, minimal tensor processing unit built around a systolic array datapath — targeting the dense matmul and convolution kernels that dominate neural network inference — with a host-facing instruction interface, on-chip weight/activation buffering, and a quantized (INT8) execution pipeline.


## Overview

- **Systolic array core**: parametrized N×N MAC grid, weight-stationary
  dataflow — weights loaded once and held stationary while activations
  stream through, minimizing memory bandwidth per MAC
- **Quantized datapath**: INT8 multiply, INT32 accumulate, with a
  configurable requantization stage (scale + zero-point) back to INT8
  for the next layer
- **On-chip memory**: unified buffer (activation SRAM) + weight FIFO,
  sized to hold a full weight tile and a working activation window
  without external memory round-trips per MAC
- **Instruction interface**: a small, host-issued instruction set —
  LOAD_WEIGHTS, MATMUL, LOAD_ACT, ACTIVATE (ReLU/quantize), STORE —
  enough to run a full convolution or dense layer as a sequence of
  ops rather than a single monolithic operation
- **Activation pipeline**: post-matmul functional unit for ReLU,
  requantization, and optional bias-add, fused into the pipeline exit
  stage rather than requiring a separate pass
- **Host integration**: memory-mapped control/status registers and a
  simple DMA-style streaming interface for weight/activation load and
  result readback
- **Verification**: layer-level correctness checked against a NumPy/
  TensorFlow-Lite-style quantized reference implementation


## Architecture Overview

```
   Host ──▶ ┌─────────────────────┐
            │  Instruction Queue   │  LOAD_WEIGHTS / MATMUL / LOAD_ACT /
            │  (host-issued ops)   │  ACTIVATE / STORE
            └──────────┬──────────┘
                       ▼
   ┌───────────────────┴────────────────────┐
   │              Control FSM                 │
   └──────┬───────────────────────┬──────────┘
          ▼                       ▼
 ┌─────────────────┐    ┌─────────────────────┐
 │  Weight FIFO      │   │  Unified Buffer       │  activation SRAM
 │  (stationary load) │  │  (streams activations)│
 └────────┬──────────┘   └──────────┬───────────┘
          ▼                          ▼
   ┌────────────────────────────────────────┐
   │        Systolic MAC Array (N x N)         │  weight-stationary,
   │   ┌────┐┌────┐┌────┐         ┌────┐      │  INT8 x INT8 -> INT32
   │   │ PE ││ PE ││ PE │   ...   │ PE │      │
   │   └────┘└────┘└────┘         └────┘      │
   └───────────────────┬──────────────────────┘
                        ▼
           ┌─────────────────────────┐
           │  Activation Pipeline      │  bias-add, ReLU,
           │  (post-matmul functional  │  requantize -> INT8
           │   unit)                   │
           └────────────┬─────────────┘
                        ▼
                ┌───────────────┐
                │  Result Store  │──▶ Host readback / next layer
                └───────────────┘
```
---


## Repository Structure

```
tensor-processing-unit/
├── README.md
├── LICENSE
├── .gitignore
├── Makefile                         
├── docs/
│   ├── microarchitecture.md         
│   ├── instruction_set.md           
│   ├── quantization_scheme.md       
│   └── verification_plan.md         
│
├── rtl/
│   ├── array/
│   │   ├── systolic_array.sv        
│   │   ├── pe.sv                     
│   │   └── array_ctrl.sv            
│   ├── memory/
│   │   ├── weight_fifo.sv
│   │   ├── unified_buffer.sv         
│   │   └── result_buffer.sv
│   ├── datapath/
│   │   ├── activation_pipeline.sv    
│   │   └── requantize_unit.sv       
│   ├── ctrl/
│   │   ├── instr_decoder.sv          
│   │   └── instr_queue.sv
│   ├── host_if/
│   │   ├── csr_block.sv             
│   │   └── dma_stream_if.sv
│   ├── common/
│   │   └── pkg_tpu_params.sv
│   └── top/
│       └── tpu_top.sv
│
├── verif/
│   ├── ref_model/
│   │   ├── numpy_quant_ref.py       
│   │   └── layer_test_gen.py       
│   ├── tb/
│   │   ├── pe_tb.sv                 
│   │   ├── systolic_array_tb.sv      
│   │   ├── requantize_tb.sv
│   │   └── system_tb.sv             
│   ├── sva/
│   │   ├── array_ctrl_assertions.sv  
│   │   └── instr_queue_assertions.sv
│   └── layers/
│       └── sample_conv_layer/       
│
├── sim/
│   └── verilator/
│       ├── Makefile
│       └── sim_main.cpp
│
├── analysis/
│   └── accuracy_report.py            
│
├── scripts/
│   └── run_regression.py
│
└── .github/
    └── workflows/
        └── ci.yml                   
```

---


### Tools

- Verilator ≥ 5.0
- Python 3.10+ with NumPy (reference model, accuracy analysis)
- GTKWave for waveform debug
