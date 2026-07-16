# Debug SYS standalone SVT UVM environment

该工程是不连接 DUT 的第一版 Debug SYS 验证环境。它不是单一 JTAG/SWD agent，而是以下复合环境：

```text
debug_sys_env
├─ JTAG Driver ↔ Controller       PORT=jtag
│  或 SWD Master ↔ Slave         PORT=swd
├─ APB Master ↔ Slave            UVM RAL + memory responder
├─ AXI master/slave passive monitor
├─ ATB Master ↔ Slave            trace 自闭环
├─ debug_sys_virtual_sequencer
├─ debug_sys_scoreboard          JTAG/SWD/APB/AXI/ATB 两端 transaction 比较
└─ reset / entry / reg / trace / full tests
```

由于当前没有 DUT，JTAG/SWD、APB、ATB 使用 VIP 对 VIP 的自闭环。AXI 是被动监听接口，等待未来连接 DUT，因此 standalone 默认关闭 AXI protocol checks。scoreboard 当前验证各 fabric 两端的一致性；JTAG/SWD 到 APB 的跨协议因果关联需要 DUT 的地址映射和桥接行为，接入 DUT 后再启用。

## 测试

| Test | 内容 |
|---|---|
| `debug_port_smoke_test` | 检查所有子环境均完成构建 |
| `debug_entry_test` | JTAG IDCODE IR/DR，或 SWD line-reset + DPIDR read |
| `debug_reg_access_test` | APB RAL control register write/read |
| `debug_trace_test` | ATB random system trace |
| `debug_full_test` | 顺序执行 entry、RAL、ATB；默认测试 |

## 主要文件

```text
tb/debug_port_top.sv
tb/debug_{jtag,swd,apb,atb}_loopback.sv
tb/env/debug_sys_env.sv
tb/env/debug_sys_virtual_sequencer.sv
tb/env/debug_sys_scoreboard.sv
tb/env/debug_sys_ral.sv
tb/env/debug_entry_sequence.sv
tb/tests/*.sv
```

## Linux/VCS 运行

需要合法安装的 Synopsys VIP、VCS 和 UVM：

```sh
export DESIGNWARE_HOME=/tools/synopsys/vip/2025

make PORT=jtag TEST=debug_full_test build
make PORT=jtag TEST=debug_full_test run

make clean
make PORT=swd TEST=debug_full_test build
make PORT=swd TEST=debug_full_test run
```

若安装树没有 `latest` 链接，可覆盖版本目录：

```sh
make PORT=jtag \
  SVT_COMMON=/path/vip/svt/common/X-2025.06 \
  JTAG_VIP=/path/vip/svt/jtag_svt/X-2025.06 \
  AMBA_VIP=/path/vip/svt/amba_svt/X-2025.06 build
```

SWD 使用 `SWD_VIP`。波形使用 `WAVES=1`。

## 检查状态与边界

- Windows 当前没有 VCS，不能在本机完成加密 VIP 的类型检查和 elaboration。
- `scripts/check_project.py` 检查 include、条件编译和结构配对。
- `.tools/pyslang` 用于分别解析 JTAG、SWD 两种源代码分支，不纳入版本库。
- 接入 DUT 时，应移除相应 loopback、把对端 responder 改成 passive，并补充真实寄存器模型、地址映射及跨协议 predictor。
