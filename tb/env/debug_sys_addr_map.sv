`ifndef DEBUG_SYS_ADDR_MAP_SV
`define DEBUG_SYS_ADDR_MAP_SV

// Logical ports in the debug subsystem. Used by the address map and predictor
// to describe routing independent of the physical VIP agent names.
typedef enum int {
  DEBUG_SYS_PORT_NONE  = 0,
  DEBUG_SYS_PORT_DEBUG = 1, // JTAG/SWD debug link (entry)
  DEBUG_SYS_PORT_APB   = 2, // APB (entry or exit)
  DEBUG_SYS_PORT_AXI   = 3, // AXI (entry or exit)
  DEBUG_SYS_PORT_ATB   = 4  // ATB (entry or exit)
} debug_sys_port_e;

// One route: a transaction entering `entry_port` with address in
// [addr_lo, addr_hi] exits on `exit_port` at (addr + addr_offset).
// `terminates=1` marks a register space consumed inside the DUT (no exit xact).
class debug_sys_route extends uvm_object;
  debug_sys_port_e entry_port = DEBUG_SYS_PORT_NONE;
  bit [63:0] addr_lo    = 64'h0;
  bit [63:0] addr_hi    = 64'hffff_ffff_ffff_ffff;
  debug_sys_port_e exit_port = DEBUG_SYS_PORT_NONE;
  bit [63:0] addr_offset = 64'h0;
  bit        terminates  = 1'b0;

  `uvm_object_utils_begin(debug_sys_route)
    `uvm_field_enum(debug_sys_port_e, entry_port, UVM_DEFAULT)
    `uvm_field_int(addr_lo, UVM_DEFAULT)
    `uvm_field_int(addr_hi, UVM_DEFAULT)
    `uvm_field_enum(debug_sys_port_e, exit_port, UVM_DEFAULT)
    `uvm_field_int(addr_offset, UVM_DEFAULT)
    `uvm_field_int(terminates, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "debug_sys_route");
    super.new(name);
  endfunction
endclass

// Ordered list of routes; first match wins. Swappable per test / DUT.
class debug_sys_addr_map extends uvm_object;
  debug_sys_route routes[$];

  `uvm_object_utils(debug_sys_addr_map)

  function new(string name = "debug_sys_addr_map");
    super.new(name);
  endfunction

  // Add a fully-formed route.
  function void add_route(debug_sys_route r);
    routes.push_back(r);
  endfunction

  // Convenience: add a route by fields.
  function void add(input debug_sys_port_e ep,
                    input bit [63:0] lo,
                    input bit [63:0] hi,
                    input debug_sys_port_e xp,
                    input bit [63:0] off = 64'h0,
                    input bit term = 1'b0);
    debug_sys_route r = debug_sys_route::type_id::create("route");
    r.entry_port = ep; r.addr_lo = lo; r.addr_hi = hi;
    r.exit_port  = xp; r.addr_offset = off; r.terminates = term;
    routes.push_back(r);
  endfunction

  // Returns 1 if mapped and fills outputs; 0 if unmapped.
  function bit lookup(input  debug_sys_port_e ep,
                      input  bit [63:0] addr,
                      output debug_sys_port_e exit_port,
                      output bit [63:0] exit_addr,
                      output bit terminates);
    foreach (routes[i]) begin
      if (routes[i].entry_port == ep &&
          addr >= routes[i].addr_lo && addr <= routes[i].addr_hi) begin
        exit_port  = routes[i].exit_port;
        exit_addr  = addr + routes[i].addr_offset;
        terminates = routes[i].terminates;
        return 1'b1;
      end
    end
    exit_port  = DEBUG_SYS_PORT_NONE;
    exit_addr  = 64'h0;
    terminates = 1'b0;
    return 1'b0;
  endfunction

  // Default standalone map: identity routes so the predictor reproduces the
  // old per-fabric in==out loopback behavior. Replace with DUT routing on hookup.
  function void configure_standalone();
    routes.delete();
    add(DEBUG_SYS_PORT_APB,   64'h0, 64'hffff_ffff_ffff_ffff, DEBUG_SYS_PORT_APB);
    add(DEBUG_SYS_PORT_DEBUG, 64'h0, 64'hffff_ffff_ffff_ffff, DEBUG_SYS_PORT_DEBUG);
    add(DEBUG_SYS_PORT_ATB,   64'h0, 64'hffff_ffff_ffff_ffff, DEBUG_SYS_PORT_ATB);
    // AXI has no traffic in standalone; intentionally no route.
  endfunction
endclass

`endif
