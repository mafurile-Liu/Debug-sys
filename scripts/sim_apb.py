#!/usr/bin/env python3
"""
APB Master-Slave 自闭环仿真器 (无 DUT) — v2
  - 周期精确 APB4 协议建模
  - UVM 风格: sequence / driver / monitor / scoreboard
  - 输出 VCD 波形 + log + 波形 PNG
"""
from __future__ import annotations
import sys, random
from dataclasses import dataclass
from enum import Enum
from collections import deque
from pathlib import Path

# ── 事务类型 ───────────────────────────────────────────────
class XactType(Enum):
    WRITE = 1; READ = 2

@dataclass
class ApbTransaction:
    xact_type: XactType
    addr: int = 0
    data: int = 0       # write data (write) 或 0 (read)
    strb: int = 0xF
    prot: int = 0
    rdata: int = 0      # read data
    slverr: int = 0
    def __repr__(self):
        t = "WR" if self.xact_type == XactType.WRITE else "RD"
        if self.xact_type == XactType.WRITE:
            return f"[{t}] addr=0x{self.addr:04X} data=0x{self.data:08X}"
        return f"[{t}] addr=0x{self.addr:04X} rdata=0x{self.rdata:08X}"

# ── APB 信号 ──────────────────────────────────────────────
@dataclass
class ApbSignals:
    clk: int = 0; resetn: int = 0
    psel: int = 0; penable: int = 0; pwrite: int = 0
    paddr: int = 0; pwdata: int = 0; prdata: int = 0
    pstrb: int = 0; pprot: int = 0
    pready: int = 1; pslverr: int = 0

# ── VCD 写入器 ─────────────────────────────────────────────
class VcdWriter:
    def __init__(self, path):
        self.f = open(path, "w", encoding="ascii")
        self.sigs = {}; self._nid = 33; self._t = 0
    def _id(self):
        c = chr(self._nid); self._nid += 1; return c
    def add_signal(self, name, width=1):
        self.sigs[name] = (self._id(), width)
        w = f"[{width-1}:0]" if width > 1 else ""
        self.f.write(f"$var wire {width} {self.sigs[name][0]} {name}{w} $end\n")
    def header(self):
        self.f.write("$timescale 1ns $end\n$scope module apb_tb $end\n")
    def end_header(self):
        self.f.write("$upscope $end\n$enddefinitions $end\n#0\n$dumpvars\n")
    def set_time(self, t):
        if t != self._t: self.f.write(f"#{t}\n"); self._t = t
    def dump(self, sig):
        for name, val in [("PCLK",sig.clk),("PRESETn",sig.resetn),
            ("PSEL",sig.psel),("PENABLE",sig.penable),("PWRITE",sig.pwrite),
            ("PREADY",sig.pready),("PSLVERR",sig.pslverr)]:
            sid, w = self.sigs[name]; self.f.write(f"{val}{sid}\n")
        for name, val, w in [("PADDR",sig.paddr,16),("PWDATA",sig.pwdata,32),
            ("PRDATA",sig.prdata,32),("PSTRB",sig.pstrb,4),("PPROT",sig.pprot,3)]:
            sid, _ = self.sigs[name]
            self.f.write(f"b{val:0{w}b} {sid}\n")
    def finish(self):
        self.f.write("$end\n"); self.f.close()

# ── Scoreboard ────────────────────────────────────────────
class Scoreboard:
    def __init__(self, log):
        self.log = log
        self.master_q = deque(); self.slave_q = deque()
        self.matches = 0; self.mismatches = 0
    def add_master(self, t):
        self.master_q.append(t); self._compare()
    def add_slave(self, t):
        self.slave_q.append(t); self._compare()
    def _compare(self):
        while self.master_q and self.slave_q:
            m = self.master_q.popleft(); s = self.slave_q.popleft()
            ok = (m.xact_type == s.xact_type and m.addr == s.addr and
                  m.data == s.data and m.rdata == s.rdata)
            if ok:
                self.matches += 1
                self.log(f"  SCOREBOARD MATCH #{self.matches}: {m}")
            else:
                self.mismatches += 1
                self.log(f"  SCOREBOARD MISMATCH #{self.mismatches}:")
                self.log(f"    Master: {m}")
                self.log(f"    Slave:  {s}")
    def report(self):
        self.log(f"\n{'='*60}")
        self.log(f"SCOREBOARD REPORT")
        self.log(f"  Matches:    {self.matches}")
        self.log(f"  Mismatches: {self.mismatches}")
        pending = len(self.master_q) + len(self.slave_q)
        if pending: self.log(f"  Pending:    {pending}")
        self.log(f"{'='*60}")
        return self.mismatches == 0 and pending == 0

# ── 仿真引擎 ──────────────────────────────────────────────
class ApbSim:
    def __init__(self, out_dir):
        self.out = Path(out_dir); self.out.mkdir(parents=True, exist_ok=True)
        self.sig = ApbSignals()
        self.cycle = 0; self.logs = []
        self.mem = bytearray(65536)
        self.master_obs = deque(); self.slave_obs = deque()
        self.scoreboard = Scoreboard(self._log)
        # VCD
        self.vcd = VcdWriter(str(self.out / "apb_waveform.vcd"))
        self.vcd.header()
        for n, w in [("PCLK",1),("PRESETn",1),("PSEL",1),("PENABLE",1),
            ("PWRITE",1),("PADDR",16),("PWDATA",32),("PRDATA",32),
            ("PSTRB",4),("PPROT",3),("PREADY",1),("PSLVERR",1)]:
            self.vcd.add_signal(n, w)
        self.vcd.end_header()
        self._cur_xact = None  # monitor 正在跟踪的事务

    def _log(self, msg):
        ts = f"[{self.cycle*10:5d}ns]"
        line = f"{ts} {msg}"; self.logs.append(line); print(line)

    def _vcd_dump(self, half):
        """写 VCD: half=0 negedge, half=5 posedge"""
        self.vcd.set_time(self.cycle * 10 + half)
        self.vcd.dump(self.sig)

    def _posedge(self):
        """posedge: slave 采样记录, monitor 采样记录"""
        s = self.sig
        if s.resetn and s.psel and s.penable and s.pready:
            # ACCESS 完成: slave 记录
            if s.pwrite:
                for i in range(4):
                    if s.pstrb & (1 << i):
                        self.mem[(s.paddr + i) % len(self.mem)] = (s.pwdata >> (i*8)) & 0xFF
                self._log(f"  SLAVE  WR addr=0x{s.paddr:04X} data=0x{s.pwdata:08X} -> STORED")
                self.slave_obs.append(ApbTransaction(XactType.WRITE, s.paddr, s.pwdata, s.pstrb, s.pprot))
            else:
                rd = int.from_bytes(self.mem[s.paddr % len(self.mem):s.paddr % len(self.mem)+4], "little")
                self._log(f"  SLAVE  RD addr=0x{s.paddr:04X} -> data=0x{rd:08X}")
                self.slave_obs.append(ApbTransaction(XactType.READ, s.paddr, rdata=rd, strb=s.pstrb, prot=s.pprot))
            # monitor: ACCESS 完成
            if self._cur_xact:
                if self._cur_xact.xact_type == XactType.READ:
                    self._cur_xact.rdata = s.prdata
                self._cur_xact.slverr = s.pslverr
                self.master_obs.append(self._cur_xact)
                self._cur_xact = None
        if s.resetn and s.psel and not s.penable and self._cur_xact is None:
            # SETUP: monitor 开始跟踪
            self._cur_xact = ApbTransaction(
                XactType.WRITE if s.pwrite else XactType.READ,
                s.paddr, s.pwdata if s.pwrite else 0, s.pstrb, s.pprot)

    def _comb(self):
        """组合逻辑: slave 驱动 pready, prdata"""
        s = self.sig
        if not s.resetn:
            s.pready = 1; s.prdata = 0; s.pslverr = 0; return
        if s.psel and not s.penable:
            # SETUP: 准备读数据
            if not s.pwrite:
                s.prdata = int.from_bytes(
                    self.mem[s.paddr % len(self.mem):s.paddr % len(self.mem)+4], "little")
            s.pready = 1; s.pslverr = 0
        elif s.psel and s.penable:
            # ACCESS: 读数据已在 SETUP 准备好
            if not s.pwrite:
                s.prdata = int.from_bytes(
                    self.mem[s.paddr % len(self.mem):s.paddr % len(self.mem)+4], "little")
            s.pready = 1; s.pslverr = 0

    def clock(self):
        """一个完整时钟周期 (negedge -> posedge)"""
        # negedge
        self.sig.clk = 0; self._comb(); self._vcd_dump(0)
        # posedge
        self.sig.clk = 1; self._posedge(); self._vcd_dump(5)
        self.cycle += 1
        # 收集到 scoreboard
        while self.master_obs: self.scoreboard.add_master(self.master_obs.popleft())
        while self.slave_obs: self.scoreboard.add_slave(self.slave_obs.popleft())

    # ── Master Driver ─────────────────────────────────
    def master_write(self, addr, data, strb=0xF, prot=0):
        s = self.sig
        # SETUP
        s.psel=1; s.penable=0; s.pwrite=1; s.paddr=addr; s.pwdata=data; s.pstrb=strb; s.pprot=prot
        self.clock()
        # ACCESS
        s.penable=1; self.clock()
        while not s.pready: self.clock()
        s.psel=0; s.penable=0
        self._log(f"  MASTER WR addr=0x{addr:04X} data=0x{data:08X} -> OK")

    def master_read(self, addr, prot=0):
        s = self.sig
        s.psel=1; s.penable=0; s.pwrite=0; s.paddr=addr; s.pprot=prot
        self.clock()
        s.penable=1; self.clock()
        while not s.pready: self.clock()
        rd = s.prdata
        s.psel=0; s.penable=0
        self._log(f"  MASTER RD addr=0x{addr:04X} -> data=0x{rd:08X}")
        return rd

    def idle(self, n=1):
        s = self.sig; s.psel=0; s.penable=0; s.pwrite=0; s.paddr=0; s.pwdata=0
        for _ in range(n): self.clock()

    def reset(self):
        self._log("--- RESET START ---")
        s = self.sig; s.resetn=1; s.psel=0; s.penable=0
        for _ in range(3): self.clock()
        s.resetn=0
        for _ in range(3): self.clock()
        s.resetn=1
        for _ in range(2): self.clock()
        self._log("--- RESET DONE ---")

    def run(self):
        self.reset()
        self._log("\n--- APB TRANSFER SEQUENCE START ---\n")
        test_data = [
            (0x0000, 0xDEADBEEF),(0x0100, 0xCAFEBABE),(0x0200, 0x12345678),
            (0x0300, 0xAABBCCDD),(0x0400, 0x0000FFFF),(0x0500, 0xFFFF0000),
            (0x0600, 0x89ABCDEF),(0x0700, 0x0F0F0F0F),
        ]
        # Phase 1: 写
        self._log("=== Phase 1: WRITE transactions ===")
        for addr, data in test_data:
            self.master_write(addr, data)
        self.idle(1)
        # Phase 2: 读回验证
        self._log("\n=== Phase 2: READ-BACK verification ===")
        for addr, expected in test_data:
            rd = self.master_read(addr)
            ok = "OK" if rd == expected else "FAIL"
            self._log(f"  READ-BACK {ok}: addr=0x{addr:04X} expected=0x{expected:08X} got=0x{rd:08X}")
        self.idle(1)
        # Phase 3: 随机混合
        self._log("\n=== Phase 3: Random WR/RD mix ===")
        random.seed(42)
        for _ in range(10):
            addr = random.randint(0,15) * 0x100
            if random.random() > 0.5:
                data = random.randint(0, 0xFFFFFFFF)
                self.master_write(addr, data)
            else:
                self.master_read(addr)
        self.idle(2)
        self._log("\n--- APB TRANSFER SEQUENCE END ---\n")

    def finish(self):
        passed = self.scoreboard.report()
        # 写 log
        (self.out / "apb_sim.log").write_text("\n".join(self.logs), encoding="utf-8")
        # VCD
        self.vcd.set_time(self.cycle * 10); self.vcd.dump(self.sig)
        self.vcd.finish()
        self._log(f"VCD: {self.out / 'apb_waveform.vcd'}")
        self._log(f"Log: {self.out / 'apb_sim.log'}")
        self._log(f"SIMULATION {'PASSED' if passed else 'FAILED'}")
        return passed

def main():
    out = r"C:\Users\t16-21\Documents\Debug SYS验证\sim_out"
    sim = ApbSim(out)
    sim.run()
    passed = sim.finish()
    print(f"\nResult: {'PASSED' if passed else 'FAILED'}")
    sys.exit(0 if passed else 1)

if __name__ == "__main__":
    main()
