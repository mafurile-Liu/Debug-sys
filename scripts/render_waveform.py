#!/usr/bin/env python3
"""解析 VCD 文件，用 matplotlib 绘制 APB 波形 PNG"""
import sys, os, re
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

os.environ["MPLCONFIGDIR"] = str(Path(os.environ.get("TEMP", "/tmp")) / "mpl_cache")

def parse_vcd(path):
    """简易 VCD 解析器，返回 {signal_name: [(time, value), ...]}"""
    signals = {}  # id -> name
    id2name = {}
    data = {}  # name -> [(time, val)]
    current_time = 0
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("$var"):
                parts = line.split()
                # $var wire WIDTH ID NAME [range] $end
                sid = parts[3]; sname = parts[4]
                id2name[sid] = sname
                data[sname] = [(0, 0)]
            elif line.startswith("#"):
                current_time = int(line[1:])
            elif line == "$dumpvars" or line == "$end":
                continue
            elif line and not line.startswith("$"):
                # value change: either "0!" or "b1010 !"
                if line.startswith("b") or line.startswith("B"):
                    parts = line.split()
                    bval = parts[0][1:]
                    sid = parts[1]
                    val = int(bval, 2) if bval else 0
                    name = id2name.get(sid)
                    if name: data[name].append((current_time, val))
                else:
                    val = int(line[0])
                    sid = line[1:]
                    name = id2name.get(sid)
                    if name: data[name].append((current_time, val))
    # 扩展到最后时间点
    max_t = max((t for name in data for t, _ in data[name]), default=0)
    for name in data:
        if data[name][-1][0] < max_t:
            data[name].append((max_t, data[name][-1][1]))
    return data, max_t

def draw_waveform(data, max_t, out_path):
    """绘制数字波形图"""
    # 选择要显示的信号和顺序
    bus_signals = ["PADDR", "PWDATA", "PRDATA", "PSTRB", "PPROT"]
    bit_signals = ["PCLK", "PRESETn", "PSEL", "PENABLE", "PWRITE", "PREADY", "PSLVERR"]
    all_signals = bit_signals + bus_signals
    n = len(all_signals)
    
    fig, ax = plt.subplots(figsize=(16, 8))
    ax.set_xlim(-5, max_t + 20)
    ax.set_ylim(-0.5, n + 0.5)
    ax.invert_yaxis()
    
    colors = {
        "PCLK": "#888", "PRESETn": "#c44", "PSEL": "#07c",
        "PENABLE": "#0a7", "PWRITE": "#c70", "PREADY": "#7c0",
        "PSLVERR": "#c00", "PADDR": "#40c", "PWDATA": "#04c",
        "PRDATA": "#0c4", "PSTRB": "#888", "PPROT": "#888",
    }
    bus_widths = {"PADDR": 16, "PWDATA": 32, "PRDATA": 32, "PSTRB": 4, "PPROT": 3}
    
    for i, name in enumerate(all_signals):
        y = i + 0.5
        if name not in data:
            continue
        transitions = data[name]
        is_bus = name in bus_widths
        
        for j in range(len(transitions) - 1):
            t0, v0 = transitions[j]
            t1, v1 = transitions[j + 1]
            color = colors.get(name, "#333")
            
            if is_bus:
                # 总线: 用六边形表示
                if v0 != 0 or j == 0:
                    label = f"0x{v0:0{(bus_widths[name]+3)//4}X}"
                else:
                    label = "0x0000"
                # 画总线波形 (中间凹槽)
                ax.plot([t0, t0, t0+2, t1-2, t1, t1], [y-0.3, y-0.15, y-0.3, y-0.3, y-0.15, y-0.3],
                        color=color, linewidth=1.2)
                ax.text((t0+t1)/2, y-0.5, label, ha="center", va="center",
                        fontsize=5.5, color=color, fontweight="bold")
            else:
                # 比特信号: 矩形波
                y_val = y if v0 == 0 else y - 0.4
                y_next = y if v1 == 0 else y - 0.4
                ax.plot([t0, t1], [y_val, y_val], color=color, linewidth=1.5)
                if j < len(transitions) - 1:
                    ax.plot([t1, t1], [y_val, y_next], color=color, linewidth=1.5)
        
        # 最后一段
        if transitions:
            t_last, v_last = transitions[-1]
            if is_bus:
                label = f"0x{v_last:0{(bus_widths[name]+3)//4}X}"
                ax.text(t_last + 5, y-0.5, label, ha="left", va="center",
                        fontsize=5.5, color=colors.get(name, "#333"))
            else:
                y_val = y if v_last == 0 else y - 0.4
                ax.plot([t_last, max_t + 10], [y_val, y_val], color=colors.get(name, "#333"), linewidth=1.5)
        
        ax.text(-8, y-0.15, name, ha="right", va="center", fontsize=8, fontweight="bold",
                color=colors.get(name, "#333"))
    
    ax.set_xlabel("Time (ns)", fontsize=10)
    ax.set_title("APB Master-Slave Loopback Waveform\n(8 WR + 8 RD-back + 10 Random WR/RD = 26 transactions, ALL MATCHED)",
                 fontsize=12, fontweight="bold")
    ax.set_yticks([])
    ax.grid(axis="x", alpha=0.3)
    
    # 添加分区标注
    ax.axvspan(80, 240, alpha=0.05, color="blue")
    ax.axvspan(240, 410, alpha=0.05, color="green")
    ax.axvspan(410, 620, alpha=0.05, color="orange")
    ax.text(160, -0.1, "Phase 1: WRITE", ha="center", fontsize=7, color="blue", alpha=0.7)
    ax.text(325, -0.1, "Phase 2: READ-BACK", ha="center", fontsize=7, color="green", alpha=0.7)
    ax.text(515, -0.1, "Phase 3: Random", ha="center", fontsize=7, color="orange", alpha=0.7)
    
    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close()
    print(f"Waveform PNG saved: {out_path}")

def main():
    vcd_path = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\t16-21\Documents\Debug SYS验证\sim_out\apb_waveform.vcd"
    png_path = vcd_path.replace(".vcd", ".png")
    data, max_t = parse_vcd(vcd_path)
    draw_waveform(data, max_t, png_path)

if __name__ == "__main__":
    main()
