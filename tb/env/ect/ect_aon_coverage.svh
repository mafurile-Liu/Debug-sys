`ifndef ECTAONCOVERAGE_SVH
`define ECTAONCOVERAGE_SVH

  class ect_aon_coverage extends uvm_component;
    uvm_analysis_imp#(ect_aon_item, ect_aon_coverage) analysis_export;

    local ect_aon_item       cov_item;
    local ect_aon_pair_e     cov_pair;
    local ect_aon_item       pending_requests[$];

    covergroup cg_ect_event;
      cp_op : coverpoint cov_item.op;
      cp_loc : coverpoint cov_item.loc;
      cp_value : coverpoint cov_item.value {
        bins low  = {1'b0};
        bins high = {1'b1};
      }
      cp_group : coverpoint ect_aon_ack_exists(cov_item.loc, cov_item.index) {
        bins request = {1'b0};
        bins ack     = {1'b1};
      }
      op_loc   : cross cp_op, cp_loc;
      loc_value : cross cp_loc, cp_value;
      group_value : cross cp_group, cp_value;
    endgroup

    covergroup cg_ect_req_ack_pair;
      cp_pair : coverpoint cov_pair;
    endgroup

    `uvm_component_utils(ect_aon_coverage)

    function new(string name = "ect_aon_coverage", uvm_component parent = null);
      super.new(name, parent);
      analysis_export = new("analysis_export", this);
      cov_pair = ECT_PAIR_AON_CTI_HIFI_CTI_OUT;
      cg_ect_event = new();
      cg_ect_req_ack_pair = new();
    endfunction

    local function void process_request(ect_aon_item item);
      // Monitor request transitions are available before the driver finishes
      // a handshake item, so queue the request from the observed edge.
      if (item.value === 1'b1 &&
          ect_aon_ack_exists(item.loc, item.index)) begin
        pending_requests.push_back(item);
      end
    endfunction

    local function void process_ack(ect_aon_item item);
      ect_aon_pair_e ack_pair;

      if (item.value !== 1'b1 ||
          item.loc < ECT_AON_ACK_HIFI_CTI_OUT ||
          item.loc > ECT_AON_ACK_TBU) return;

      ack_pair = ect_aon_pair_for_ack(item.loc);
      foreach (pending_requests[i]) begin
        ect_aon_pair_e req_pair;
        req_pair = ect_aon_pair_for_request(
          pending_requests[i].loc,
          pending_requests[i].index
        );

        if (req_pair == ack_pair) begin
          cov_item = pending_requests[i];
          cov_pair = ack_pair;
          cg_ect_req_ack_pair.sample();
          pending_requests.delete(i);
          return;
        end
      end
    endfunction

    virtual function void write(ect_aon_item item);
      if (item == null) return;

      cov_item = item;
      cg_ect_event.sample();

      if (item.op == ECT_OP_LEVEL) begin
        process_request(item);
        process_ack(item);
      end
    endfunction
  endclass

`endif
