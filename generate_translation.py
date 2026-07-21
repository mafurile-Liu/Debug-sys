import os
import sys
from pathlib import Path

# 工作目录
work_dir = Path(r"C:\Users\t16-21\Documents\Debug SYS验证")

# 创建输出目录
output_dir = work_dir / "GIC翻译文档"
output_dir.mkdir(exist_ok=True)

# ==================== 翻译内容数据库 ====================

overview_translations = {
    1: {
        "title": "ARM通用中断控制器架构学习 - v3和v4版本概述",
        "subtitle": "版本 3.2",
        "content": "",
        "note": "📌 **文档说明**\n\n这是ARM官方的GIC架构学习文档，介绍了Generic Interrupt Controller（通用中断控制器）v3和v4版本的核心概念。GIC是ARM架构中管理中断的关键组件，负责中断的优先级、路由和分发。"
    },
    2: {
        "title": "发布信息",
        "content": """
**文档历史记录**

| 版本 | 日期 | 保密性 | 变更内容 |
|------|------|--------|----------|
| 3.2-03 | 2025年4月22日 | 非保密 | 图片更新 |
| 3.2-02 | 2025年1月10日 | 非保密 | 图片更新 |
| 3.2-01 | 2021年12月6日 | 非保密 | 替换 DAIO492B |

---

**专有声明**

本文档受版权和其他相关权利保护，文档中信息的使用或实现可能受一项或多项专利或待批专利申请的保护。未经Arm Limited（"Arm"）明确的事先书面许可，不得以任何形式复制本文档的任何部分。除非另有明确说明，否则本文档不通过禁止反言或其他方式授予任何知识产权的许可（明示或暗示）。

您对本文档信息的访问是有条件的，即您同意不会将本文档中的信息用于或允许他人用于确定本文档的主题是否侵犯任何第三方专利。
        """,
        "note": "💡 **理解注解**\n\n- 这是ARM官方文档的法律声明部分，保护ARM的知识产权\n- 文档为「非保密」级别，可公开学习使用\n- 最新版本3.2-03更新于2025年4月，内容较新"
    },
    3: {
        "title": "法律声明与保密状态",
        "content": """
**关于适销性、质量满意、非侵权或特定用途适用性的默示保证**：在法律允许的最大范围内，Arm不对因使用本文档而导致的任何直接、间接、特殊、附带、惩罚性或后果性损害承担责任，即使已被告知此类损害的可能性。

本文档中提及的任何第三方产品或服务并不构成Arm对其使用的明示或暗示认可。

**出口合规**：您有责任确保对本文档的任何使用、复制或披露完全符合相关出口法律法规。

本文档可能会为方便起见被翻译成其他语言。如果英文原文与翻译版本存在冲突，以英文原文为准。

---

**保密状态**

本文档为**非保密**文档。使用、复制和披露本文档的权利可能受到Arm与文档接收方之间协议条款的许可限制约束。

"无限制访问"是Arm的内部分类。
        """,
        "note": "💡 **理解注解**\n\n- 这是标准的法律免责声明，所有ARM官方文档都包含类似内容\n- 重点：英文版本优先于任何翻译版本\n- 虽然是"非保密"，但商业使用仍需遵守ARM的许可协议"
    },
    4: {
        "title": "产品状态与反馈",
        "content": """
**产品状态**

本文档中的信息为**最终版**，即针对已开发产品的最终文档。

---

**反馈**

Arm欢迎对本产品及其文档提供反馈：
- 产品反馈：在 https://support.developer.arm.com 创建工单
- 文档反馈：填写 https://developer.arm.com/documentation-feedback-survey 调查问卷

---

**包容性语言承诺**

Arm重视包容性社区。Arm认识到，我们和我们的行业使用过可能具有冒犯性的语言。Arm致力于引领行业并创造变革。

我们认为本文档不包含任何冒犯性语言。如要报告本文档中的冒犯性语言，请发送电子邮件至 terms@arm.com。
        """,
        "note": "💡 **理解注解**\n\n- Final状态表示文档内容已经过审核，是可靠的参考资料\n- ARM非常重视社区反馈，提供了明确的反馈渠道\n- 包容性语言承诺是现代科技公司的普遍做法，旨在消除技术文档中的歧视性语言"
    },
    5: {
        "title": "目录",
        "content": """
| 章节 | 标题 | 页码 |
|------|------|------|
| 1 | 概述 | 6 |
| 2 | 开始之前 | 7 |
| 3 | 什么是通用中断控制器？ | 8 |
| 4 | Arm GIC 基础原理 | 10 |
| 5 | 配置 Arm GIC | 20 |
| 6 | 中断处理 | 26 |
| 7 | 发送和接收软件生成中断 | 37 |
| 8 | 示例 | 41 |
| 9 | 知识检查 | 42 |
| 10 | 相关信息 | 43 |
| 11 | 后续步骤 | 44 |
| 12 | 附录：传统操作 | 45 |
        """,
        "note": "📌 **学习路径建议**\n\n1. **基础概念**：第3-4章 - 理解GIC是什么和核心原理\n2. **配置实践**：第5章 - 如何配置GIC寄存器\n3. **中断处理**：第6章 - 中断生命周期管理\n4. **高级主题**：第7章 - SGI软件中断（多核间通信）\n\n建议按顺序学习，每章后可做「知识检查」巩固理解。"
    },
    6: {
        "title": "第1章 - 概述",
        "content": """
本指南概述了Arm通用中断控制器（GIC）v3和v4的特性。本指南描述了符合GICv3规范的中断控制器的操作。还介绍了如何在裸机环境中配置GICv3中断控制器。

本指南是Arm通用中断控制器相关指南系列中的第一篇：
- Arm CoreLink 通用中断控制器 v3 和 v4：概述（本指南）
- Arm CoreLink 通用中断控制器 v3 和 v4：本地特定外设中断（LPIs）
- Arm CoreLink 通用中断控制器 v3 和 v4：虚拟化

---

**背景**

中断是向处理器发出的信号，表示发生了需要处理的事件。中断通常由外设生成。

例如，系统可能使用通用异步收发器（UART）接口与外部通信。当UART接收到数据时，需要一种机制来告知处理器新数据已到达并准备好处理。UART可以使用的一种机制是生成中断来通知处理器。

小型系统可能只有几个中断源和单个处理器。然而，大型系统可能有更多的潜在中断源和处理器。GIC执行中断管理、优先级排序和路由的关键任务。GIC汇集来自整个系统的所有中断，对它们进行优先级排序，并将它们发送到某个核心进行处理。GIC主要用于提高处理器效率和实现中断虚拟化。

GIC是基于Arm GIC架构实现的。该架构已从GICv1发展到最新版本GICv3和GICv4。Arm提供了多种通用中断控制器，为所有类型的Arm Cortex多处理器系统提供一系列中断管理解决方案。这些控制器从适用于小型CPU核心系统的最简单的GIC-400，到适用于高性能和多芯片系统的GIC-600。GIC-600AE增加了额外的安全功能，针对高性能ASIL B至ASIL D系统。
        """,
        "note": "💡 **深入理解**\n\n**为什么需要GIC？**\n\n在多核系统中，如果没有GIC：\n1. ❌ 每个外设都要直接连线到每个CPU - 硬件复杂度爆炸\n2. ❌ CPU需要轮询所有外设 - 效率极低\n3. ❌ 无法实现中断优先级 - 紧急事件可能被延误\n\n**GIC的核心价值**：\n```\n外设中断 → GIC（仲裁+优先级+路由）→ 目标CPU核心\n```\n\n**GIC产品系列对比**：\n- **GIC-400**：入门级，适用于小核心数（如手机、嵌入式）\n- **GIC-500/600**：高性能，适用于服务器、数据中心\n- **GIC-600AE**：汽车级，支持功能安全（ASIL B-D）"
    }
}

lpis_translations = {
    1: {
        "title": "ARM通用中断控制器架构学习 - 本地特定外设中断 (LPIs)",
        "subtitle": "版本 1.0",
        "content": "",
        "note": "📌 **文档说明**\n\n这是GIC系列的第二篇文档，专门介绍**Locality-specific Peripheral Interrupts (LPIs)** - 本地特定外设中断。\n\n**LPIs是什么？**\n- 这是GICv3/v4引入的一种新型中断\n- 专门用于**消息信号中断 (MSI)**\n- 支持**极大量**的中断源（理论上可达百万级）\n- 主要用于PCIe等现代高速外设\n\n这是GIC高级主题，建议先掌握Overview文档的基础概念。"
    }
}

# 补充更多翻译内容
def get_translation(doc_type, page_num):
    """获取指定页面的翻译"""
    if doc_type == "overview":
        return overview_translations.get(page_num, {
            "title": f"第{page_num}页 - 待翻译",
            "content": "此页面翻译正在补充中...",
            "note": "📝 翻译进行中"
        })
    else:
        return lpis_translations.get(page_num, {
            "title": f"LPIs 第{page_num}页 - 待翻译",
            "content": "此页面翻译正在补充中...",
            "note": "📝 翻译进行中"
        })

# ==================== 生成Markdown文档 ====================

def generate_markdown():
    md_content = """# ARM GIC v3/v4 官方文档中文翻译

> 📚 **包含两篇文档**：
> 1. **Overview** - GIC架构概述 (45页)
> 2. **LPIs** - 本地特定外设中断 (24页)

---

## 📖 翻译说明

✅ **翻译原则**：
- 忠实原文，专业术语保持统一
- 技术术语首次出现保留英文
- 增加「💡 理解注解」帮助入门
- 保留所有原文图表

🔍 **GIC核心概念速查表**：

| 缩写 | 全称 | 中文 | 说明 |
|------|------|------|------|
| GIC | Generic Interrupt Controller | 通用中断控制器 | ARM架构中断管理核心 |
| SPI | Shared Peripheral Interrupt | 共享外设中断 | 可路由到任意CPU的中断 |
| PPI | Private Peripheral Interrupt | 私有外设中断 | 特定CPU私有，如定时器 |
| SGI | Software Generated Interrupt | 软件生成中断 | 核间通信用，软件触发 |
| LPI | Locality-specific Peripheral Interrupt | 本地特定外设中断 | GICv3新增，MSI用 |
| ITS | Interrupt Translation Service | 中断翻译服务 | LPI的消息翻译单元 |

---

# 📄 第一篇：GIC v3/v4 概述 (Overview)

---

"""

    # 生成Overview的1-6页
    for page in range(1, 7):
        trans = get_translation("overview", page)
        img_path = work_dir / f"gic_overview_page-{page:02d}.png"
        
        md_content += f"""
## 📑 第 {page} 页：{trans['title']}

"""
        if img_path.exists():
            md_content += f"""
![第{page}页原文]({img_path.absolute()})

"""
        
        if trans["content"]:
            md_content += f"""
### 🀄 中文翻译

{trans['content']}

"""
        
        if trans["note"]:
            md_content += f"""
### 💡 理解注解

{trans['note']}

"""
        
        md_content += "\n---\n"

    # 添加剩余页面说明
    md_content += """
## 📌 剩余页面翻译说明

> ⚠️ **工作进行中**：由于文档共69页，完整翻译需要更多时间。
>
> 目前已完成：
> - ✅ Overview 第1-6页（封面、目录、第1章）
> - 🚧 剩余页面正在持续翻译中...

---

# 📄 第二篇：本地特定外设中断 (LPIs)

---

## 📑 LPI 第 1 页：封面

"""

    lpi_img = work_dir / "gic_lpis_page-01.png"
    if lpi_img.exists():
        md_content += f"![LPI第1页]({lpi_img.absolute()})\n"

    md_content += """
### 💡 理解注解

**📌 LPIs 是什么？**

**LPI = Locality-specific Peripheral Interrupt**

这是GICv3引入的重大革新：

| 特性 | 传统中断 (SPI/PPI) | LPI 中断 |
|------|-------------------|----------|
| **触发方式** | 引脚电平/边沿 | 消息写入 (MSI) |
| **数量上限** | ~1000个 | 百万级 |
| **内存需求** | 寄存器配置 | 内存中表结构 |
| **典型应用** | UART, GPIO, 定时器 | PCIe设备, 高速网卡 |

**为什么需要LPI？**
1. 现代服务器有上百个PCIe设备，每个设备可能需要数十个中断
2. 传统寄存器方式无法支持这么多中断源
3. MSI消息方式比引脚方式更可靠（无抖动问题）

---

## 📊 本次翻译完成情况总结

| 项目 | 状态 |
|------|------|
| 📄 Overview 第1-6页 | ✅ 已翻译 + 注解 |
| 📄 Overview 第7-45页 | 🚧 待翻译 |
| 📄 LPIs 第1页 | ✅ 封面 + 说明 |
| 📄 LPIs 第2-24页 | 🚧 待翻译 |
| 🖼️  原文图片提取 | ✅ 69张全部提取 |
| 💡 理解注解 | ✅ 每页都有针对性注解 |

---

## 🎯 学习建议

**初学者路径**：
1. 先读Overview第1-6章，理解GIC基础
2. 动手在QEMU或开发板上尝试配置GIC
3. 理解中断处理流程后再学习LPIs
4. 最后研究虚拟化相关内容

**进阶路径**：
- 研究GIC-600/TRM（技术参考手册）
- 分析Linux Kernel的GIC驱动代码
- 学习KVM中的中断虚拟化
"""

    # 保存Markdown
    md_file = output_dir / "GIC_v3_v4_官方文档中文翻译.md"
    md_file.write_text(md_content, encoding="utf-8")
    print(f"✅ Markdown文档已生成: {md_file}")
    
    return md_file

if __name__ == "__main__":
    generate_markdown()
