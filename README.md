# Reconfigurable Intelligent Traffic Management SoC

A Verilog HDL-based adaptive traffic management system integrating UART communication and an I²C sensor interface.

## Project Overview

This project implements a configurable traffic-light controller that adjusts green-light timing according to traffic-density levels.

The design integrates:
- A finite-state-machine-based traffic management controller.
- A configurable timer for traffic signal sequencing.
- UART transmitter and receiver for command communication.
- UART command decoder for density configuration and status requests.
- I²C master and traffic sensor interface for sensor communication.

## System Architecture

The system consists of the following major blocks:

1. **Traffic Management Core:** Controls North-South and East-West traffic signal sequences.
2. **Configurable Timer:** Generates programmable timing intervals.
3. **UART Interface:** Receives configuration commands and transmits status responses.
4. **UART Command Decoder:** Processes commands and updates traffic-density settings.
5. **I²C Master:** Provides communication with external sensor devices.
6. **Traffic Sensor Interface:** Processes sensor data and provides density information.

## Traffic Density Configuration

| Density Code | Traffic Level |
|---|---|
| 00 | Low |
| 01 | Medium |
| 10 | High |
| 11 | Very High |

The controller uses the configured density level to select the corresponding green-light duration.

## UART Command Protocol

| Command | Function |
|---|---|
| 0x10–0x13 | Configure North-South density |
| 0x20–0x23 | Configure East-West density |
| 0x30 | Request traffic status |

## Simulation and Verification

The project includes individual module testbenches and an integrated SoC testbench.

The reported integrated simulation checks include:

- I²C sensor integration checks.
- Traffic-light safety checks.
- UART status request and response.
- No simultaneous green signals.
- Sensor validity and error status.

**Reported simulation result:** All checks passed; total failures: 0.

## FPGA Design and Implementation

- **HDL:** Verilog
- **Design Tool:** AMD/Xilinx Vivado 2022.2
- **Target Device:** XC7Z020CLG400-1 (Zynq-7000)
- **Design Status:** Synthesis and implementation completed.

### Synthesis Resource Utilization

| Resource | Used | Utilization |
|---|---:|---:|
| Slice LUTs | 238 | 0.45% |
| Slice Registers | 264 | 0.25% |
| Block RAM | 0 | 0% |
| DSPs | 0 | 0% |
| Bonded IOB | 21 | 16.80% |

### Timing Analysis

The reported timing summary showed:
- WNS: +12.216 ns
- TNS: 0.000 ns
- WHS: +0.155 ns
- THS: 0.000 ns

Some input/output paths remain unconstrained. Board-specific pin assignments and I/O standards are also required before physical FPGA deployment.

## Repository Structure

```text
traffic_management_soc/
│
├── traffic_management_soc.xpr
│
└── traffic_management_soc.srcs/
    ├── sources_1/new/
    │   ├── traffic_management_soc.v
    │   ├── traffic_management_core.v
    │   ├── configurable_timer.v
    │   ├── i2c_master.v
    │   ├── traffic_sensor_interface.v
    │   ├── uart_command_decoder.v
    │   ├── uart_rx.v
    │   └── uart_tx.v
    │
    └── sim_1/new/
        ├── tb_traffic_management_soc.v
        ├── tb_i2c_master.v
        ├── tb_uart_command_decoder.v
        ├── tb_uart_loopback.v
        └── other module testbenches
```

## Future Improvements

- Complete independent I²C bus-level protocol verification.
- Add board-specific FPGA constraints.
- Perform physical FPGA testing with external sensors.
- Improve traffic-density detection and sensor integration.

## Author

**Manojit Das**

B.Tech – Electronics Engineering  
Specialization: VLSI Design and Technology  
Rashtriya Raksha University (RRU), Gandhinagar

## Tools and Technologies

Verilog HDL | AMD/Xilinx Vivado | UART | I²C | FPGA Design | Digital System Design
