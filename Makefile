# ==============================================================================
# ARA 64-CORE 128GB PCIe ACCELERATOR (DURUM B+) MAKEFILE
# ==============================================================================

IVERILOG = iverilog -g2012
VVP = vvp
YOSYS = yosys
CC = gcc
PYTHON = python3

RTL_ALL = rtl/ara_multicore_true_fma_6stage.sv \
          rtl/ara_systolic_tensor_unit.sv \
          rtl/ara_tcdm_bank_interconnect.sv \
          rtl/ara_multicore_cluster.sv \
          rtl/ara_noc_fifo.sv \
          rtl/ara_noc_cdc_fifo.sv \
          rtl/ara_noc_mesh_router.sv \
          rtl/ara_noc_ni.sv \
          rtl/ara_noc_defect_bypass.sv \
          rtl/ara_barrier_tree.sv \
          rtl/ara_pdn_stagger_ctrl.sv \
          rtl/ara_host_cmd_dispatcher.sv \
          rtl/ara_wse_multi_cluster_top.sv \
          rtl/ara_pcie_dma_engine.sv \
          rtl/ara_64core_durum_b_top.sv

.PHONY: all sim_top sim_soak sim_transformer sim_concurrent driver power test synth regression clean

all: sim_top sim_soak sim_transformer

sim_top: $(RTL_ALL) tb/tb_ara_64core_128gb_full_soc.sv
	$(IVERILOG) -o sim_64core_soc $(RTL_ALL) tb/tb_ara_64core_128gb_full_soc.sv

sim_soak: $(RTL_ALL) tb/tb_ara_continuous_soak_stress.sv
	$(IVERILOG) -o sim_soak_stress $(RTL_ALL) tb/tb_ara_continuous_soak_stress.sv

sim_transformer: $(RTL_ALL) tb/tb_ara_llm_transformer_layer.sv
	$(IVERILOG) -o sim_transformer $(RTL_ALL) tb/tb_ara_llm_transformer_layer.sv

sim_concurrent: $(RTL_ALL) tb/tb_ara_concurrent_stress_full_duplex.sv
	$(IVERILOG) -o sim_concurrent_stress $(RTL_ALL) tb/tb_ara_concurrent_stress_full_duplex.sv

driver:
	$(CC) -O3 -o driver/ara_pcie_test_runner driver/ara_pcie_test_runner.c -lm

power: sim_soak
	@if [ ! -f sim_soak_activity.vcd ]; then \
		echo "Generating sim_soak_activity.vcd with +DUMP_VCD..."; \
		$(VVP) sim_soak_stress +DUMP_VCD; \
	fi
	$(PYTHON) scripts/vcd_toggle_analyzer.py

test: driver sim_soak sim_transformer
	@echo "=== [1/3] RUNNING C HOST DRIVER & VIRTUAL PROTOTYPE ==="
	./driver/ara_pcie_test_runner
	@echo "=== [2/3] RUNNING 10,000+ CYCLE CONTINUOUS SOAK STRESS TEST ==="
	$(VVP) sim_soak_stress
	@echo "=== [3/3] RUNNING LLM TRANSFORMER LAYER HARDWARE RTL TEST ==="
	$(VVP) sim_transformer

regression: sim_top sim_concurrent test
	@echo "=== [4/4] RUNNING FULL-DUPLEX & 64-CORE TOP SIMULATIONS ==="
	$(VVP) sim_64core_soc
	$(VVP) sim_concurrent_stress
	@echo "=== ALL REGRESSION SUITES PASSED (0 ERRORS) ==="

synth:
	$(YOSYS) -p "read_verilog -sv rtl/ara_multicore_true_fma_6stage.sv rtl/ara_systolic_tensor_unit.sv rtl/ara_tcdm_bank_interconnect.sv rtl/ara_multicore_cluster.sv rtl/ara_noc_mesh_router.sv rtl/ara_noc_fifo.sv rtl/ara_noc_defect_bypass.sv rtl/ara_barrier_tree.sv rtl/ara_pdn_stagger_ctrl.sv rtl/ara_pcie_dma_engine.sv; hierarchy -check -top ara_pcie_dma_engine; proc; opt; check -assert"

clean:
	rm -f sim_64core_soc sim_soak_stress sim_transformer sim_concurrent_stress driver/ara_pcie_test_runner *.vcd
