# Dual-Port RAM RTL Design with BIST, ECC and Collision Handling

## Overview

This project implements a **synchronous dual-port RAM** using **Verilog HDL**. The design supports independent read and write operations through two ports and includes additional reliability and test features.

### Key Features

* Dual-port RAM architecture
* Independent Port A and Port B access
* Built-In Self-Test (BIST)
* ECC-based single-bit error correction
* Double-bit error detection
* Write collision detection and resolution
* Parameterized data width, address width and memory depth
* Verilog RTL implementation
* Self-checking simulation testbench

## Architecture

The memory contains encoded data words instead of storing raw data directly.

```text
                 ┌──────────────────────────┐
                 │      Dual-Port RAM       │
                 │                          │
 Port A ────────►│                          │◄──────── Port B
                 │       ECC Memory         │
                 │                          │
                 └────────────┬─────────────┘
                              │
                    ┌─────────┴─────────┐
                    │   ECC Encoder /   │
                    │      Decoder      │
                    └───────────────────┘

                 ┌───────────────────────┐
                 │         BIST          │
                 │ Write → Read/Write →  │
                 │ Read/Write → Read     │
                 └───────────────────────┘
```

## Design Parameters

| Parameter    | Default Value | Description                       |
| ------------ | ------------: | --------------------------------- |
| `DATA_WIDTH` |             8 | Width of input/output data        |
| `ADDR_WIDTH` |             4 | Width of memory address           |
| `ECC_BITS`   |             4 | Number of Hamming ECC parity bits |
| `CODE_WIDTH` |            13 | Total stored codeword width       |
| `DEPTH`      |            16 | Number of memory locations        |

For the default configuration:

```text
Data width      = 8 bits
Address width   = 4 bits
Memory depth    = 16 locations
ECC bits        = 4 bits
Overall parity  = 1 bit
Stored width    = 13 bits
```

## Port Description

### Port A

| Signal   | Direction | Description         |
| -------- | --------- | ------------------- |
| `clk`    | Input     | Clock               |
| `rst_n`  | Input     | Active-low reset    |
| `addr_a` | Input     | Port A address      |
| `din_a`  | Input     | Port A write data   |
| `we_a`   | Input     | Port A write enable |
| `re_a`   | Input     | Port A read enable  |
| `dout_a` | Output    | Port A read data    |

### Port B

| Signal   | Direction | Description         |
| -------- | --------- | ------------------- |
| `addr_b` | Input     | Port B address      |
| `din_b`  | Input     | Port B write data   |
| `we_b`   | Input     | Port B write enable |
| `re_b`   | Input     | Port B read enable  |
| `dout_b` | Output    | Port B read data    |

### BIST and ECC Signals

| Signal                | Direction | Description                            |
| --------------------- | --------- | -------------------------------------- |
| `bist_start`          | Input     | Starts BIST operation                  |
| `bist_busy`           | Output    | Indicates BIST is running              |
| `bist_done`           | Output    | Indicates BIST completion              |
| `bist_pass`           | Output    | Indicates BIST result                  |
| `collision`           | Output    | Indicates simultaneous write collision |
| `corrected_error`     | Output    | Indicates ECC correction               |
| `uncorrectable_error` | Output    | Indicates an uncorrectable error       |

## ECC Implementation

The design uses a **SEC-DED style Hamming ECC scheme**.

ECC encoding adds:

* 4 Hamming parity bits
* 1 overall parity bit

For an 8-bit data word:

```text
8-bit Data
    │
    ▼
ECC Encoder
    │
    ▼
13-bit Codeword
    │
    ▼
Memory
```

During a read operation, the stored codeword is decoded.

### Single-Bit Error

A single-bit error produces a non-zero syndrome with valid overall parity.

```text
Stored data
     ↓
Single-bit error
     ↓
ECC Decoder
     ↓
Error location identified
     ↓
Bit corrected
     ↓
Original data recovered
```

The `corrected_error` signal is asserted when correction occurs.

### Double-Bit Error

A double-bit error produces an error condition that cannot be safely corrected.

The design asserts:

```text
uncorrectable_error = 1
```

This prevents the decoder from incorrectly correcting an invalid data word.

## BIST

The memory includes a Built-In Self-Test controller implemented using a finite-state machine.

### BIST Sequence

```text
B_IDLE
   │
   ▼
B_WRITE0
   │
   │ Write 0 to all locations
   ▼
B_R0W1
   │
   │ Read 0 and write 1
   ▼
B_R1W0
   │
   │ Read 1 and write 0
   ▼
B_READ0
   │
   │ Read 0 from all locations
   ▼
B_IDLE
```

The BIST checks whether the stored data matches the expected value at each stage.

### BIST Signals

```text
bist_start → Start test
bist_busy  → Test in progress
bist_done  → Test completed
bist_pass  → Test passed/failed
```

## Collision Handling

The two ports can access the memory independently.

If both ports attempt to write to the **same address during the same clock cycle**, a collision is detected.

```text
Port A Write ──┐
               ├── Same Address ──► Collision
Port B Write ──┘
```

The design asserts:

```text
collision = 1
```

For a collision, **Port A data takes priority** and is stored in memory.

## Testbench

The project includes a self-checking Verilog testbench that verifies the major functions of the design.

### Tests Included

| Test   | Function                         |
| ------ | -------------------------------- |
| Test 1 | Basic Port A write/read          |
| Test 2 | Basic Port B write/read          |
| Test 3 | Simultaneous dual-port operation |
| Test 4 | Write collision detection        |
| Test 5 | BIST operation                   |
| Test 6 | ECC single-bit correction        |
| Test 7 | ECC double-bit error detection   |

The testbench maintains:

```text
PASS COUNT
FAIL COUNT
```

and reports the final simulation result.

## Project Structure

```text
dual-port-ram/
│
├── top.v
├── dualport_tb.v
└── README.md
```

## Simulation

The design can be simulated using tools such as:

* Xilinx Vivado
* EDA Playground

## Example Output

```text
TEST 1 : BASIC PORT A
[PASS] Expected=a5 Actual=a5

TEST 2 : BASIC PORT B
[PASS] Expected=3c Actual=3c

TEST 3 : DUAL PORT
[PASS] Expected=55 Actual=55
[PASS] Expected=aa Actual=aa

TEST 4 : COLLISION
[PASS] Expected=1 Actual=1

TEST 5 : BIST
[PASS] Expected=1 Actual=1

TEST 6 : ECC SINGLE BIT
[PASS] Expected=5a Actual=5a
[PASS] Expected=1 Actual=1

TEST 7 : ECC DOUBLE BIT
[PASS] Expected=1 Actual=1

====================================
SIMULATION COMPLETE
PASS COUNT = XX
FAIL COUNT = 0
====================================
RESULT : ALL TESTS PASSED
```

## Technologies Used

* **Verilog HDL**
* **RTL Design**
* **Digital Memory Design**
* **Hamming ECC**
* **Built-In Self-Test**
* **Finite State Machine**
* **Dual-Port RAM**
* **Functional Verification**


This project was developed as an RTL design and verification project focusing on dual-port memory architecture.
