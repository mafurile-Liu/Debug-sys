# Scoreboard 与地址路由架构

本次改动把 scoreboard 从"每条 fabric 各自 in/out 相等比较"重构为
"基于地址映射的跨端口路由预测比较",为后续接入带地址路由的 DUT
(从某口进、经地址路由后从另一口出)做准备。

## 为什么改

原 scoreboard 对每条 fabric 各开 `in_q`/`out_q`,pop-front 后直接 `.compare()`。
这隐含三个假设:**out 恒等于 in**、**同协议**、**保序**。一旦 DUT 做地址路由
(APB 进 -> AXI 出、SWD/JTAG 进 -> APB 出),这三条全部不成立:

- 跨协议:APB 的事务不会出现在 AXI 的比较队列里。
- 保序:多 outstanding + 不同路径延迟会乱序。
- 相等:协议翻译后字段不同,`.compare()` 永远不等。

## 数据流(新)

```
in-monitor ──► predictor ──► scoreboard.*_exp   (预期:该从哪个口出、长什么样)
                  ▲
              cfg.addr_map   (按地址路由)
out-monitor ──────────────► scoreboard.*_actual  (实际:出口观测)
scoreboard: 每个出口 exp_q vs act_q 比较
```

predictor 决定"一笔入口事务应该从哪个出口出现、预期字段是什么";
scoreboard 只做"出口实际 vs 预期"的比较。预测与比较解耦。

## 文件清单

| 文件 | 作用 |
|------|------|
| `tb/env/debug_sys_analysis_decls.svh` | 集中声明所有 analysis 端口宏 + `debug_port_transaction_t` |
| `tb/env/debug_sys_addr_map.sv` | 地址路由模型(路由表、`lookup`、standalone 默认) |
| `tb/env/debug_sys_predictor.sv` | 路由预测器(in->预期 out) |
| `tb/env/debug_sys_scoreboard.sv` | exp/actual 比较(替换原 in/out 比较) |
| `tb/env/debug_sys_env.sv` | 接线:in->predictor、predictor->scoreboard(exp)、out->scoreboard(actual) |
| `tb/env/debug_sys_cfg.sv` | 增加 `addr_map` 字段(默认 standalone identity) |

## 地址映射模型 (`debug_sys_addr_map`)

逻辑端口枚举:`DEBUG_SYS_PORT_DEBUG / APB / AXI / ATB`。

一条路由 = 入口端口 + 地址区间 `[addr_lo, addr_hi]` -> 出口端口,
出口地址 = 入口地址 + `addr_offset`;`terminates=1` 表示寄存器空间
(DUT 内部消费,不产生出口事务)。路由表有序,**first-match**。

```systemverilog
// 查询:返回 1 表示命中,填 exit_port/exit_addr/terminates
bit lookup(input  debug_sys_port_e ep,
           input  bit [63:0] addr,
           output debug_sys_port_e exit_port,
           output bit [63:0] exit_addr,
           output bit terminates);
```

`configure_standalone()` 默认配 identity 路由(apb->apb、debug->debug、atb->atb),
所以现有 standalone 测试行为不变(predictor 走 clone,等价于旧的 in==out)。

## predictor

- 订阅所有入口 monitor(`apb_in`/`axi_in`/`atb_in`/`debug_in`)。
- 每笔入口事务:用对应 `get_*_addr()` 取地址 -> `map.lookup()` -> 按出口端口
  调对应 `emit_*_from_*` 产生预期事务 -> 写到对应 `*_exp` 端口。
- **同协议 identity xform 已实现**(clone + 设出口地址)。
- **跨协议 xform 是 stub**(只打 `PRED_TODO` info,不写预期),等 DUT 桥接 spec:
  `emit_axi_from_apb`、`emit_apb_from_axi`、`emit_apb_from_debug`、`emit_axi_from_debug`。
- `get_debug_addr()` / `get_atb_addr()` 默认返回 0(占位),DUT 接入时重写
  以从 JTAG/SWD/ATB 事务解析出真实目标地址。

## scoreboard

- 每个出口一对队列:`*_exp_q`(predictor)与 `*_act_q`(out-monitor)。
- `compare_*`:in-order pop exp vs pop act,`.compare()` 比较,记 match/mismatch。
- `check_phase`:任一出口的 exp 或 act 队列非空 -> 报错(有未匹配)。
- `report_phase`:打印各出口 match/mismatch 计数。

## 接入 DUT 时协作者要做的事(框架已就位)

1. **填地址映射**:在 test 的 `build_phase` 里替换默认 map:
   ```systemverilog
   cfg.addr_map = debug_sys_addr_map::type_id::create("dut_map");
   // 例:SWD/JTAG 0x0000_0000~0x0000_FFFF -> APB 出口
   cfg.addr_map.add(DEBUG_SYS_PORT_DEBUG, 64'h0, 64'h0000_FFFF, DEBUG_SYS_PORT_APB);
   // 例:APB 进 0x0001_0000~0x0001_FFFF -> AXI 出口,地址偏移 +0x1000_0000
   cfg.addr_map.add(DEBUG_SYS_PORT_APB, 64'h0001_0000, 64'h0001_FFFF,
                    DEBUG_SYS_PORT_AXI, 64'h1000_0000);
   // 寄存器空间(DUT 内部消费)
   cfg.addr_map.add(DEBUG_SYS_PORT_APB, 64'h0000_0000, 64'h0000_0FFF,
                    DEBUG_SYS_PORT_NONE, 64'h0, 1'b1);
   ```
   把它设给 env 之前(test 创建 cfg 之后)即可,env build 会取到。
2. **实现跨协议 xform**:填 `debug_sys_predictor` 里 4 个 `emit_*_from_*` stub
   (按 DUT 桥接语义构造出口事务:方向/地址/size/data)。
3. **重写地址解析**:`get_debug_addr()`(从 JTAG/SWD 事务取目标地址,
   依赖 DUT debug link 协议,如 ARM ADIv5 MEM-AP)、必要时 `get_atb_addr()`。
4. **AXI 激活 + 开检查**:按 DUT 位置把 `axi_monitor_env` 的 agent 改 active,
   `cfg.enable_checks = 1`。
5. **移除 loopback**:删 `tb/debug_*_loopback.sv` 接线,改接 DUT 端口。
6. **乱序路径**(可选):AXI ID 重映射时,把 `compare_axi` 从 in-order 改成
   ID-keyed 关联(代码里已标 TODO)。

## 已知限制

- 比较仍用 svt 事务的 `.compare()`,对随机化字段/时序偏严;接入 DUT 后若误报,
  改成自定义关键字段比较。
- 队列无上界;若出口永不响应会无限堆积(后续可加上界 + 超时)。
- 跨协议 xform、`get_debug_addr` 未实现(standalone 用不到,DUT 接入时填)。
