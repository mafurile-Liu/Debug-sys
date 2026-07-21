# Debug Subsystem Verification Environment
## ARM CoreSight SoC-400 UVM Testbench

---

## 📖 快速导航

| 章节 | 内容 |
|------|------|
| [🏗️ 整体架构图](#-整体架构图) | 一句话搞懂整体结构 |
| [📁 项目文件地图](#-项目文件地图) | 每个文件是做什么的 |
| [🧱 四层序列架构](#-四层序列架构) | Test → Scenario → Feature → Protocol |
| [🎯 核心设计亮点](#-核心设计亮点) | Register Shadow Model, Coverage, etc. |
| [🚀 如何运行测试](#-如何运行测试) | 可用的测试用例列表 |
| [📊 验证指标](#-验证指标) | 我们验证什么 |
| [🔮 未来扩展指南](#-未来扩展指南) | 如何添加新功能 |

---

## 🏗️ 整体架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                            TEST LAYER                                │
│   debug_apb_scenario_test.sv                                         │
│   debug_apb_reg_test.sv                                              │
│   debug_port_base_test.sv (所有测试的基类)                           │
└────────────────────────────────────┬────────────────────────────────┘
                                     │
┌────────────────────────────────────▼────────────────────────────────┐
│                       VIRTUAL SEQUENCER LAYER                       │
│   debug_sys_virtual_sequencer.sv                                    │
│   ├── 持有 regmodel 指针                                            │
│   ├── 持有各协议 sequencer 指针                                      │
│   └── 所有 sequence 在此启动 (跨协议协同)                            │
└────────────────────────────────────┬────────────────────────────────┘
                                     │
    ┌────────────────────────────────┼────────────────────────────────┐
    │                                │                                │
┌───▼───────────┐         ┌──────────▼───────────┐         ┌──────────▼───────────┐
│   APB RAL     │         │    JTAG/SWD Port      │         │    ATB / Trace       │
│  Sequences    │         │     Sequences         │         │     Sequences        │
└───────┬───────┘         └──────────┬───────────┘         └──────────┬───────────┘
        │                             │                               │
┌───────▼─────────────────────────────▼───────────────────────────────▼──────────────┐
│                                        ENV LAYER                                    │
│   debug_sys_env.sv                                                                 │
│                                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ APB Master  │  │ APB Slave   │  │  JTAG/SWD   │  │ Scoreboard w/ Shadow    │ │
│  │ VIP         │  │ VIP         │  │ VIP         │  │ Model                   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                                                                                     │
│  RAL Model: debug_sys_reg_block (4 registers)                                       │
│  Config: debug_sys_cfg (enable switches)                                            │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                     │
                              ┌──────▼──────┐
                              │ Loopback    │
                              │ RTL (TBD)   │
                              └─────────────┘
```

---

## 📁 项目文件地图

### 📂 `tb/tests/` - 测试用例层

| 文件名 | 用途 | 状态 |
|--------|------|------|
| `debug_port_base_test.sv` | **所有测试的基类**，提供 run_* 任务方法 | ✅ |
| `debug_apb_reg_test.sv` | **推荐使用** - RAL 方式访问寄存器，符合架构 | ✅ |
| `debug_apb_scenario_test.sv` | **场景测试** - 完整寄存器 BIST，开覆盖率 | ✅ |
| `debug_apb_xfer_test.sv` | ❌ **DEPRECATED** - 直接构造 APB transaction | ⚠️ |
| `debug_port_smoke_test.sv` | JTAG/SWD 端口冒烟测试 | ✅ |
| `debug_reg_access_test.sv` | 简单 RAL 访问示例 | ✅ |
| `debug_trace_test.sv` | ATB Trace 测试 | ✅ |
| `debug_full_test.sv` | 完整回归测试 | ✅ |

---

### 📂 `tb/env/` - 环境组件层

#### 🔄 序列文件 (`*sequence.sv`)

| 文件名 | 层级 | 功能 |
|--------|------|------|
| `debug_apb_reg_sequence.sv` | **Protocol 层** | 最底层寄存器原语: write_reg(), read_reg(), write_and_verify_reg() |
| `debug_apb_reg_test_sequence.sv` | **Feature 层** | 组合原语，实现完整测试功能: 边界值、随机值 |
| `debug_apb_scenario_sequence.sv` | **Scenario 层** | 场景组合: ResetBIST, FullBIST, TraceEnable |
| `debug_apb_xfer_sequence.sv` | ❌ DEPRECATED | 旧方式，直接构造 transaction |
| `debug_reset_sequence.sv` | - | 复位序列 |
| `debug_entry_sequence.sv` | - | JTAG/SWD entry 序列 |

**架构原则**: 上层序列继承下层序列，复用基础方法

---

#### 🧠 核心组件

| 文件名 | 功能 | 亮点 |
|--------|------|------|
| `debug_sys_scoreboard.sv` | **记分板** | ✅ 内置 **Register Shadow Model**<br>✅ 自动建模 RW/RO 行为<br>✅ RO 寄存器写无效的真实 HW 行为<br>✅ 输入/输出双向比较 |
| `debug_sys_ral.sv` | **寄存器模型** | 4 个寄存器: IDCODE(RO), CONTROL(RW), STATUS(RO), TRACE_CONTROL(RW) |
| `debug_sys_cfg.sv` | **配置对象** | 所有开关集中管理: enable_coverage, enable_apb_ral, enable_checks, enable_atb |
| `debug_sys_env.sv` | **环境顶层** | 实例化所有 VIP 和组件，建立连接<br>可配置化构建组件 |
| `debug_sys_virtual_sequencer.sv` | **虚拟序列器** | 跨协议协同的枢纽，持有 regmodel 和各 sequencer 指针 |

---

### 📂 项目根目录

| 文件名 | 说明 |
|--------|------|
| `AI_DESIGN_GUIDE.md` | **架构设计圣经** - 所有设计决策的依据 |
| `PROJECT_BACKGROUND.md` | 项目背景说明 |
| `Makefile` | 编译运行脚本 |
| `scripts/` | 各种工具脚本 |

---

## 🧱 四层序列架构

这是本项目最重要的设计模式，遵循 `AI_DESIGN_GUIDE.md`

```
第 0 层: Base Test (debug_port_base_test.sv)
    ↓  调用 run_apb_scenario_test()
第 1 层: Scenario Sequence (debug_apb_scenario_sequence.sv)
    ↓  调用 write_and_verify_reg() / verify_idcode()
第 2 层: Feature Sequence (debug_apb_reg_test_sequence.sv)
    ↓  调用 write_reg() / read_reg()
第 3 层: Protocol Sequence (debug_apb_reg_sequence.sv)
    ↓  RAL register.write() / read()
RAL Layer (debug_sys_ral.sv)
    ↓
SVT APB Adapter (VIP 内置)
    ↓
Bus Transaction
```

**为什么要四层？**
1. ✅ **复用性**: Protocol 层的方法可以被所有 Feature 复用
2. ✅ **可读性**: 每层只做一件事，代码短而清晰
3. ✅ **可维护性**: 修改协议不影响业务场景，反之亦然
4. ✅ **可扩展性**: 新增场景只需组合已有的 Feature

---

## 🎯 核心设计亮点

### 1️⃣ Register Shadow Model (寄存器影子模型)

**位置**: `debug_sys_scoreboard.sv`

```systemverilog
typedef struct {
  uvm_reg_data_t value;          // 期望值
  uvm_reg_data_t reset_value;    // 复位值
  string access;                  // "RW" / "RO"
  int write_count;               // 写次数统计
  int read_count;                // 读次数统计
} reg_shadow_t;
```

**工作原理**:
- `apb_in` port: 收到写操作 → 更新 shadow value (RO 寄存器忽略写)
- `apb_out` port: 收到读响应 → 比较 read_data vs shadow.value
- 自动建模真实硬件行为

---

### 2️⃣ 可配置化架构

**位置**: `debug_sys_cfg.sv`

```systemverilog
class debug_sys_cfg extends uvm_object;
  bit enable_checks = 1'b0;      // 协议检查开关
  bit enable_coverage = 1'b1;    // 覆盖率开关
  bit enable_apb_ral = 1'b1;     // APB RAL 开关
  bit enable_axi_monitor = 1'b1; // AXI monitor 开关
  bit enable_atb = 1'b1;         // ATB 开关
  // ...
endclass
```

**设计意图**: 同一个 testbench，可以通过 cfg 配置出 N 种不同环境

---

### 3️⃣ 多协议预留架构

Scoreboard 现在就预留了 6 个 analysis port，未来接入 DUT 不用改结构:

| Port | 用途 | 状态 |
|------|------|------|
| `debug_in` / `debug_out` | JTAG/SWD 调试端口 | ✅ 预留 |
| `apb_in` / `apb_out` | APB 总线 | ✅ 已实现 |
| `axi_in` / `axi_out` | AXI 总线 | ✅ 预留 |
| `atb_in` / `atb_out` | ATB Trace 总线 | ✅ 预留 |

---

## 🚀 如何运行测试

### 快速选择指南

| 你的目的 | 推荐测试 | 原因 |
|---------|---------|------|
| 学习架构 / 开发新功能 | `debug_apb_reg_test` | 最简单的 RAL 测试 |
| 完整功能验证 / 覆盖率收集 | `debug_apb_scenario_test` | 最完整的寄存器 BIST |
| 调试 APB loopback | `debug_apb_xfer_test` | 不推荐，但直观 |
| 全回归 | `debug_full_test` | 运行所有测试 |

### Make 命令

```bash
# 编译
make PORT=apb TEST=debug_apb_scenario_test build

# 运行
make PORT=apb TEST=debug_apb_scenario_test run

# 看波形
make PORT=apb TEST=debug_apb_scenario_test waves
```

---

## 📊 验证指标

| 指标 | 当前状态 | 目标 |
|------|---------|------|
| 寄存器覆盖率 | ✅ 内置访问统计，报告自动打印 | 100% |
| 寄存器读写检查 | ✅ Shadow Model 自动比较 | 100% |
| RO 寄存器行为建模 | ✅ 写操作忽略，保持复位值 | 完成 |
| RW 寄存器行为建模 | ✅ 写后读回正确值 | 完成 |

---

## 🔮 未来扩展指南

### 场景 1: 加一个新寄存器

```
1. tb/env/debug_sys_ral.sv
   - 添加新的 uvm_reg 声明
   - 在 reg_block.build() 中创建并 add 到 map

2. tb/env/debug_sys_scoreboard.sv
   - 在 build_phase() 中 init_reg_shadow(addr, reset, access)
```

### 场景 2: 加一个新的 APB 测试场景

```
1. 在 debug_apb_scenario_sequence.sv 中加新的 task
2. 在 scenario_type_e 枚举中加新类型
3. (可选) 创建新的 test 文件调用它，或者直接在 base_test 加 run_* 方法
```

### 场景 3: 接入真实 DUT RTL

```
1. 替换 tb/debug_apb_loopback.sv 为真实 DUT RTL
2. 确认 DUT 的 register map 和 RAL 模型一致
3. 如果 DUT 有特定行为 (如写后有延迟更新)，更新 Shadow Model
4. 运行 debug_apb_scenario_test 验证集成正确性
```

### 场景 4: 加 JTAG RAL 访问（通过 DP 访问寄存器）

```
这是一个跨协议的典型场景:
- Sequence 启动在 Virtual Sequencer 上
- 先发送 JTAG sequence 配置 DP
- 再通过 DP 间接访问寄存器
- Scoreboard 的 Shadow Model 依然可用 (从哪个 port 来都一样)
```

---

## 💡 常见问题

### Q: 为什么不直接构造 APB transaction？

A: 因为未来我们要通过 **JTAG/SWD → DP → APB** 这种路径访问寄存器，
如果测试用的 sequence 是基于 RAL 的，那换一个 adapter 就可以用了，测试代码一行都不用改。
这就是架构的长期价值。

### Q: Scoreboard 里做 coverage？

A: 是的，现在是简单的访问计数统计。如果需要复杂的 covergroup，可以拆到独立 coverage 组件，
或者等接入 VCS 原生的 RAL 覆盖率功能。

### Q: 为什么每个 sequence 都要 inherit？

A: 因为 `uvm_declare_p_sequencer` 是 class member，继承的话就只需要声明一次，
而且 write_reg() 这种方法可以在所有子 sequence 中直接用。

---

## 📚 参考文档

- `AI_DESIGN_GUIDE.md` - 架构设计原则（必读）
- `PROJECT_BACKGROUND.md` - 项目背景
- ARM CoreSight SoC-400 Technical Reference Manual
- Synopsys SVT VIP User Guide
- UVM 1.2 Class Reference

---

*本文档最后更新: 2024*
