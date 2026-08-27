# ==========================================
# Debug Subsystem Verification Filelist
# ==========================================
# Compilation Order:
#   tb/configs/*.sv    (VIP custom configurations)
#   tb/ral/debug_sys_ral.sv
#   tb/sequences/debug_seq_pkg.sv
#   tb/env/debug_env_pkg.sv
#   tests/debug_test_pkg.sv
#   tb/debug_port_top.sv
# ==========================================

# SVT VIP packages
+incdir+$SVT_HOME/svt_jtag
+incdir+$SVT_HOME/svt_swd
+incdir+$SVT_HOME/svt_apb
+incdir+$SVT_HOME/svt_axi
+incdir+$SVT_HOME/svt_atb

# Project custom VIP configurations (cust_*_cfg.sv)
+incdir+tb/configs

# Interface directory
+incdir+tb/interfaces

# Loopback directory
+incdir+tb/loopbacks

# RAL directory
+incdir+tb/ral

# Sequence package directory
+incdir+tb/sequences

# Environment package directory (with subdirs for protocol-specific envs)
+incdir+tb/env
+incdir+tb/env/common
+incdir+tb/env/jtag
+incdir+tb/env/apb
+incdir+tb/env/atb

# Test package directory
+incdir+tests

# ==========================================
# Compilation Order - DO NOT REORDER
# ==========================================

# Step 0: Custom VIP Configurations (first - before env_pkg uses them)
tb/configs/cust_apb_cfg.sv
tb/configs/cust_jtag_cfg.sv
tb/configs/cust_swd_cfg.sv
tb/configs/cust_axi_cfg.sv
tb/configs/cust_atb_cfg.sv

# Step 1: RAL Model
tb/ral/debug_sys_ral.sv

# Step 2: Sequence Package
tb/sequences/debug_seq_pkg.sv

# Step 3: Environment Package
tb/env/debug_env_pkg.sv

# Step 4: Test Package
tests/debug_test_pkg.sv

# Step 5: Top Module
tb/debug_port_top.sv
