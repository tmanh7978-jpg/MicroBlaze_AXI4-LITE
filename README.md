# MicroBlaze AXI SoC

A **MicroBlaze-based FPGA SoC** developed in **AMD Vivado 2025.1** and **AMD Vitis**. This project explores an AXI4-Lite memory-mapped peripheral that controls four user LEDs on a **ZedBoard (Zynq-7000 XC7Z020-CLG484-1)**.

## Overview

The project combines:
- A MicroBlaze system assembled with Vivado IP Integrator.
- An AXI4-Lite slave interface for software-controlled registers.
- Custom Verilog modules for LED register access and LED output behavior.
- A Vitis standalone application that exercises six register-write/readback scenarios.
- HDL testbenches for peripheral-level verification.

### LED peripheral data path

    AXI4-Lite master
         |
         v
    AXI4-Lite slave IP
         |
         v
    led_reg_bridge
         |
         v
    led_controller ----> LED[3:0]

The diagram above describes the **peripheral-level test setup**. The complete MicroBlaze integration is defined in the Vivado Block Design.

## Hardware configuration

| Item | Configuration |
| --- | --- |
| Target board | ZedBoard |
| FPGA part | `xc7z020clg484-1` |
| Design tools | Vivado 2025.1; Vitis |
| Language | Verilog (RTL and testbenches), C (software) |
| LED outputs | 4 bits, `led[3:0]` |
| Clock constraint | 100 MHz (`sys_clock`) |
| Reset constraint | `sys_reset_n[0]` (see `main.xdc`) |

### Register map

The Verilog register bridge implements these two offsets. The Vitis application currently uses **base address `0x44A00000`**; verify the current address map in Vivado if the Block Design changes.

| Offset | Register | Bits | Function |
| --- | --- | --- | --- |
| `0x00` | `LED_DATA` | `[3:0]` | Four-bit LED pattern |
| `0x04` | `LED_CTRL` | `[0]` | `enable`: 1 = enabled, 0 = off |
| `0x04` | `LED_CTRL` | `[1]` | `blink_mode`: 1 = blink when enabled |

When `enable=0`, the LEDs remain off even if `blink_mode=1`. With `enable=1` and `blink_mode=0`, the output follows `LED_DATA`. With both bits set, the LED pattern alternates with zero.

The `led_controller` RTL defaults to `HALF_PERIOD=50_000_000` clock cycles; at 100 MHz, the blink state toggles every 0.5 seconds. The testbenches shorten this interval for simulation.

## Software test sequence

The Vitis application at `vitis/microblaze_led_test/src/main.c` performs six test cases:

| Case | `LED_DATA` | `LED_CTRL` | Expected output behavior |
| --- | --- | --- | --- |
| 1 | `0000` | `0000` | All LEDs off |
| 2 | `0101` | `0001` | LEDs follow `0101` |
| 3 | `1011` | `0010` | All LEDs off (enable is 0) |
| 4 | `1010` | `0011` | Blink between `1010` and `0000` |
| 5 | `1111` | `0001` | All four LEDs on |
| 6 | `1111` | `0000` | All LEDs off |

**Important:** The C program checks **register readback**. A successful readback alone does not prove the physical LED output or blink timing; those require simulation or board-level observation.

## Repository layout

    .
    ├── soc/
    │   ├── soc.xpr
    │   ├── Microblaze_Controller_wrapper.xsa
    │   └── soc.srcs/
    │       ├── sources_1/new/
    │       │   ├── led_controller.v
    │       │   └── led_reg_bridge.v
    │       ├── sources_1/bd/Microblaze_Controller/
    │       ├── sim_1/new/
    │       │   ├── tb_axi_led_system.v
    │       │   └── tb_microblaze_led_system.v
    │       └── constrs_1/new/main.xdc
    ├── vitis/
    │   ├── microblaze_led_platform/
    │   └── microblaze_led_test/src/main.c
    ├── .gitignore
    └── README.md

## Open and work with the project

1. Clone the repository:

       git clone https://github.com/tmanh7978-jpg/MicroBlaze_AXI_SoC.git

2. In **Vivado 2025.1**, open `soc/soc.xpr`.
3. Inspect `Microblaze_Controller.bd` in IP Integrator. Check the IP catalog and regenerate IP output products if needed.
4. Review `main.xdc` and confirm the target device and board pin constraints before implementation or FPGA programming.
5. Select the appropriate simulation top and run **Behavioral Simulation**.
6. For software development, open the Vitis platform/application in `vitis/`; regenerate or update the platform from the current `.xsa` if the hardware design changes.

**Portability note:** The current `soc.xpr` contains references to external/local IP repository paths. On another computer, those custom IP sources may need to be supplied and their repositories configured in Vivado.

**Simulation note:** The two supplied testbench files both declare a module named `tb_axi_led_system`. They should not be compiled as simultaneous top-level definitions without first resolving that duplicate. The testbenches exercise the AXI peripheral directly, **not** execution of a MicroBlaze ELF.

## Verification status

The repository contains RTL, testbench logic, and Vitis readback tests. **Passing simulations, implementation timing, and physical FPGA behavior are not claimed here without corresponding run logs or measurements.**

Suggested evidence to add later:
- [ ] Block Design screenshot and AXI address map
- [ ] Simulation console results and waveforms
- [ ] Synthesis/implementation utilization and timing reports
- [ ] Photos or video of verified ZedBoard LED behavior

## Version control

Generated Vivado caches, runs, and other intermediate artifacts are excluded by `.gitignore`. Keep the editable RTL, Block Design sources, constraints, software, and documentation under version control.
