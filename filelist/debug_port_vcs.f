# ==========================================
# VCS Compilation Filelist
# ==========================================
# For use with VCS:
#   vcs -f filelist/debug_port_vcs.f -sverilog -ntb_opts uvm-1.2
# ==========================================

# UVM home
+incdir+$UVM_HOME/src
$UVM_HOME/src/uvm_pkg.sv

# Include base filelist
-f filelist/debug_port.f