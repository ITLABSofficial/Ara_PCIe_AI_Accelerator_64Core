# Ara_PCIe_AI_Accelerator_64Core: Hardware Integration & Pinout Guide
**PCIe Gen5 x16 AI Accelerator Card (FCBGA-3136 Package, VRM & Thermal Design)**

---

## 1. Top-Level Module Instantiation

The top-level accelerator macro `ara_64core_durum_b_top` wraps the 4x4 cluster array, the PCIe DMA engine, and the 128 GB OpenHBM3 PIM memory controller.

### SystemVerilog Instantiation Template

```systemverilog
ara_64core_durum_b_top #(
    .NUM_CLUSTERS    (16),     // 4x4 mesh = 16 clusters
    .CORES_PER_CLUST (4),      // 4 Ara VPUs per cluster = 64 cores
    .TCDM_SIZE_KB    (512),    // 512 KB per cluster = 8 MB total L1
    .HBM_STACKS      (4),      // 4 physical HBM3 stacks
    .MEM_SIZE_GB     (128)     // 128 GB total memory
) u_pcie_accelerator (
    // Clock Domains
    .pcie_refclk_p_i (pcie_refclk_p),       // 100 MHz PCIe differential refclk
    .pcie_refclk_n_i (pcie_refclk_n),
    .clk_compute_i   (clk_compute_2000mhz), // 2.0 GHz Ara Vector Core Clock
    .clk_noc_i       (clk_noc_1250mhz),     // 1.25 GHz NoC Mesh Clock
    .rst_pcie_n      (pcie_perst_n),        // Standard PCIe fundamental reset

    // PCIe Gen5 x16 Physical Serial Links
    .pcie_rx_p_i     (pcie_rx_p[15:0]),     // 16-lane incoming differential RX
    .pcie_rx_n_i     (pcie_rx_n[15:0]),
    .pcie_tx_p_o     (pcie_tx_p[15:0]),     // 16-lane outgoing differential TX
    .pcie_tx_n_o     (pcie_tx_n[15:0]),

    // Voltage Regulator & Telemetry Signals
    .vrm_core_vid_o  (vrm_core_voltage_id[7:0]), // Dynamic voltage scaling VID bus
    .vrm_alert_i     (vrm_thermal_alert_n),      // Active-low VRM overload alert
    .fan_pwm_o       (chassis_fan_pwm),          // 4-wire fan PWM control
    .fan_tach_i      (chassis_fan_tach)          // Fan tachometer feedback
);
```

---

## 2. Packaging, Form Factor & Ball Map Specification

### Mechanical Form Factor
- **Dimensions**: Standard Dual-Slot Full-Height Full-Length (FHFL): $111.15\text{ mm} \times 312.0\text{ mm}$.
- **PCIe Interface**: Standard PCIe x16 edge connector compliant with PCI Express Base Specification 5.0.
- **Auxiliary Power Connector**: One 12V-2x6 / 12VHPWR (ATX 3.0) 16-pin power connector delivering up to $300\text{ W}$ continuous.

### Semiconductor Packaging (FCBGA-3136)
- **Package Type**: Flip-Chip Ball Grid Array (FCBGA).
- **Pin Count**: 3,136 balls in a $56 \times 56$ grid array with $0.80\text{ mm}$ ball pitch ($47.5\text{ mm} \times 47.5\text{ mm}$ substrate body).
- **Substrate Layers**: 14-layer build-up organic substrate (4-6-4 stackup) with CoWoS-S silicon interposer carrying the Ara SoC die and 4 HBM3 stacks.
- **Ball Assignment Breakdown**:
  * VDD_CORE Power Balls: 720 balls
  * VSS Ground Balls: 1,180 balls
  * VDD_HBM / VDD_PHY Balls: 440 balls
  * PCIe Gen5 Differential Pairs: 64 balls (16 TX + 16 RX differential pairs)
  * JTAG, I2C, SMBus, Telemetry: 48 balls
  * Reserved / Mechanical: 684 balls

---

## 3. Voltage Regulator Module (VRM) Architecture

The accelerator card converts incoming $12\text{V}$ auxiliary power to sub-1.0V clean rails via on-board multi-phase synchronous buck converters:

```
+─────────────────────────────────────────────────────────────────────────────+
|                    PCIe CARD POWER DELIVERY ARCHITECTURE                    |
|                                                                             |
|   12V_PCIe + 12V-2x6 Auxiliary Bus (12.0V +/- 8%)                           |
|         │                                                                   |
|         ├────────► [ 8-Phase Digital GaN VRM ] ───► VDD_CORE (0.75V, 180A)  |
|         │          - Renesas RAA229618 Controller                           |
|         │          - 70A Smart Power Stages (SPS)                           |
|         │                                                                   |
|         ├────────► [ 2-Phase Buck Converter ]  ───► VDD_PIM (0.80V, 45A)    |
|         │                                                                   |
|         ├────────► [ Low-Noise Synchronous ]   ───► VDD_PHY (0.90V, 20A)    |
|         │                                                                   |
|         └────────► [ High-Efficiency Buck ]    ───► VDD_DRAM (1.10V, 25A)   |
+─────────────────────────────────────────────────────────────────────────────+
```

### VRM Electrical Specifications

| Rail Name | Nominal Voltage | Transient Current | Max Voltage Ripple | Dynamic Load Step | Slew Rate Limit |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`VDD_CORE`** | **0.75 V** | **180 A Peak** | **$< 15\text{ mV}_{p-p}$** | **$10\text{A}$ to $140\text{A}$ in $20\text{ ns}$** | **$100\text{ A / }\mu\text{s}$** |
| **`VDD_PIM`** | **0.80 V** | **45 A Peak** | **$< 12\text{ mV}_{p-p}$** | **$5\text{A}$ to $35\text{A}$ in $15\text{ ns}$** | **$50\text{ A / }\mu\text{s}$** |
| **`VDD_PHY`** | **0.90 V** | **20 A Peak** | **$< 10\text{ mV}_{p-p}$** | **$2\text{A}$ to $16\text{A}$ in $10\text{ ns}$** | **$25\text{ A / }\mu\text{s}$** |
| **`VDD_DRAM`**| **1.10 V** | **25 A Peak** | **$< 15\text{ mV}_{p-p}$** | **$2\text{A}$ to $20\text{A}$ in $30\text{ ns}$** | **$30\text{ A / }\mu\text{s}$** |

---

## 4. Thermal Management & Cooling Design

- **Vapor Chamber Cold-Plate**: Direct copper vapor chamber contacting the SoC die and 4 HBM3 stacks via phase-change thermal interface material (Honeywell PTM7950, conductivity $8.5\text{ W/m}\cdot\text{K}$).
- **Active Dual-Blower Fan**: Pulse-Width Modulation (PWM) speed curve automatically adjusted by on-die Digital Thermal Sensors:
  * $T_j < 60^\circ\text{C}$: Fan idle / low speed ($30\%$ PWM, acoustic $< 28\text{ dBA}$).
  * $60^\circ\text{C} \le T_j < 85^\circ\text{C}$: Linear ramp from $30\%$ to $80\%$ PWM.
  * $T_j \ge 85^\circ\text{C}$: Maximum fan speed ($100\%$ PWM, maintaining junction temp $< 82^\circ\text{C}$ at $229\text{ W}$ dissipation).
  * $T_j \ge 105^\circ\text{C}$: Hardware automatic thermal throttle engages; vector issue rate cut by $50\%$.
  * $T_j \ge 115^\circ\text{C}$: Emergency hardware power cutoff protects silicon from damage.
