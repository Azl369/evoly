# Evoly 时序图渲染器开发计划：Flutter 自研轻量 WaveDrom 子集

## 1. 版本定位

该功能建议作为独立功能分支开发，完成后再 merge 回主仓库。

建议分支名：

```bash
feature/markdown-timing-diagram
```

功能定位：

```text
在 Evoly 文档库 Markdown 预览中，支持 FPGA / 数字电路工程师常用的轻量时序图预览。
```

核心目标不是把 Evoly 做成 GTKWave / Surfer，而是在项目文档、复盘文档和接口说明中沉淀关键时序。

---

## 2. 推荐方案

采用 **Flutter 自研轻量 WaveDrom 子集渲染器**。

不采用：

- WebView 内嵌 WaveDrom JS。
- Node / CLI 生成 SVG。
- GTKWave / Surfer 级别完整波形查看器。
- VCD / FST / GHW 仿真数据库直接预览。

原因：

- Evoly 是本地优先 Flutter App，移动端性能和稳定性优先。
- Markdown 预览页可能存在多个图块，WebView 多实例容易带来卡顿。
- FPGA 项目复盘通常只需要关键时序片段，不需要完整仿真波形数据库。
- Flutter `CustomPainter` 可控、轻量、离线，也更容易和 Evoly 当前主题统一。

---

## 3. 用户语法

V0.1 子集建议支持以下 fenced code block：

````markdown
```wavedrom
{
  "signal": [
    { "name": "clk", "wave": "p......" },
    { "name": "rst_n", "wave": "0.1...." },
    { "name": "valid", "wave": "0..1.0." },
    { "name": "ready", "wave": "1......" },
    { "name": "data", "wave": "x..=x..", "data": ["D0"] }
  ]
}
```
````

别名：

````markdown
```timing
...
```

```wavejson
...
```
````

---

## 4. WaveDrom 子集范围

### 4.1 第一阶段必须支持

`wave` 字符：

| 字符 | 含义 |
|---|---|
| `0` | 低电平 |
| `1` | 高电平 |
| `.` | 延续上一状态 |
| `x` | unknown / don't care |
| `z` | 高阻 |
| `=` | 数据有效段 |
| `p` | 上升沿时钟 |
| `P` | 强调型上升沿时钟，第一版可等同 `p` |

字段：

| 字段 | 说明 |
|---|---|
| `signal` | 信号数组 |
| `name` | 信号名 |
| `wave` | 波形描述 |
| `data` | `=` 数据段标签 |
| `phase` | 可选，小数相位偏移，第一版可解析但只做简单偏移 |

### 4.2 第一阶段可暂缓

- `node`
- `edge`
- `period`
- `config`
- `head`
- `foot`
- group 嵌套
- skin / theme
- 完整 WaveDrom 兼容性

### 4.3 明确不做

- 仿真文件导入。
- 波形游标测量。
- 信号树。
- 拖拽编辑。
- 音频/播放式时间轴。
- 在线渲染服务。

---

## 5. 代码结构

建议新增：

```text
lib/features/documents/presentation/markdown_timing_support.dart
lib/features/documents/presentation/timing/
  timing_diagram_model.dart
  wavedrom_parser.dart
  timing_diagram_view.dart
  timing_diagram_painter.dart
  timing_templates.dart
```

职责：

```text
MarkdownTimingSupport
  识别 wavedrom / timing / wavejson fenced code block

WaveDromParser
  JSON -> TimingDiagram

TimingDiagramModel
  纯 Dart 数据模型，便于单元测试

TimingDiagramView
  Flutter Widget，负责主题、滚动、错误态

TimingDiagramPainter
  CustomPainter，负责实际绘制波形

TimingTemplates
  给文档编辑器插入常用 FPGA 时序模板
```

---

## 6. 数据模型设计

建议模型：

```dart
class TimingDiagram {
  const TimingDiagram({
    required this.signals,
  });

  final List<TimingSignal> signals;
}

class TimingSignal {
  const TimingSignal({
    required this.name,
    required this.wave,
    this.data = const [],
    this.phase = 0,
  });

  final String name;
  final String wave;
  final List<String> data;
  final double phase;
}
```

内部绘制前可转换为段模型：

```dart
class TimingWaveSegment {
  const TimingWaveSegment({
    required this.start,
    required this.end,
    required this.state,
    this.label,
  });

  final int start;
  final int end;
  final TimingWaveState state;
  final String? label;
}

enum TimingWaveState {
  low,
  high,
  unknown,
  highImpedance,
  data,
  clock,
}
```

---

## 7. Markdown 集成方式

新增 `MarkdownTimingSupport`，保持和现有数学公式、音乐谱块一致。

目标集成代码：

```dart
Markdown(
  data: markdown,
  blockSyntaxes: [
    ...MarkdownMathSupport.blockSyntaxes,
    ...MarkdownMusicSupport.blockSyntaxes(),
    ...MarkdownTimingSupport.blockSyntaxes(),
  ],
  inlineSyntaxes: MarkdownMathSupport.inlineSyntaxes(),
  builders: {
    ...MarkdownMathSupport.builders(),
    ...MarkdownMusicSupport.builders(),
    ...MarkdownTimingSupport.builders(),
  },
)
```

要求：

- 解析失败时不影响整篇 Markdown 预览。
- 错误块显示温和提示。
- 长图支持横向滚动。
- 不引入 WebView。
- 不联网。

---

## 8. 绘制设计

### 8.1 布局

建议尺寸：

| 项 | 默认值 |
|---|---:|
| 左侧信号名宽度 | `96` |
| 单周期宽度 | `38` |
| 行高 | `36` |
| 波形高度 | `22` |
| 图块内边距 | `12` |

移动端：

- 外层 `SingleChildScrollView(scrollDirection: Axis.horizontal)`。
- 宽度按最长 `wave.length` 计算。
- 每个时序图包在 `RepaintBoundary` 中，减少滚动重绘压力。

### 8.2 视觉风格

使用 Evoly 主题色：

- 背景：`colorScheme.surfaceContainerLow`。
- 网格线：`outlineVariant` 低透明度。
- 信号名：`textTheme.labelMedium`。
- 普通波形：`onSurface`。
- 数据段：`primary` 或 `tertiary` 轻量描边。
- unknown / high-z：`onSurfaceVariant` 虚线或浅色填充。

原则：

- 不使用重阴影。
- 不使用复杂渐变。
- 不使用昂贵裁剪。
- 让图块像 Evoly 文档预览的一部分，而不是外部 EDA 插件。

### 8.3 波形绘制规则

初版可简化：

- `0`：画低电平水平线。
- `1`：画高电平水平线。
- `.`：延续上一状态。
- 状态变化：画垂直跳变线。
- `x`：画交叉/斜纹或浅色 unknown 段。
- `z`：画中线虚线。
- `=`：画总线样式六边形数据段，并消费 `data` 标签。
- `p` / `P`：每个周期画上升沿/下降沿组合。

---

## 9. 编辑器模板

文档编辑页新增“插入时序图”入口。

第一批模板：

### 9.1 时钟复位

```wavedrom
{
  "signal": [
    { "name": "clk", "wave": "p......" },
    { "name": "rst_n", "wave": "0.1...." }
  ]
}
```

### 9.2 Valid / Ready 握手

```wavedrom
{
  "signal": [
    { "name": "clk", "wave": "p......" },
    { "name": "valid", "wave": "0..1.0." },
    { "name": "ready", "wave": "1......" },
    { "name": "data", "wave": "x..=x..", "data": ["D0"] }
  ]
}
```

### 9.3 SPI 简化传输

```wavedrom
{
  "signal": [
    { "name": "sclk", "wave": "0.p.p.p." },
    { "name": "cs_n", "wave": "1.0...1." },
    { "name": "mosi", "wave": "x.=.=.x.", "data": ["A7", "B3"] },
    { "name": "miso", "wave": "x.=.=.x.", "data": ["12", "34"] }
  ]
}
```

### 9.4 FIFO 写入

```wavedrom
{
  "signal": [
    { "name": "clk", "wave": "p......" },
    { "name": "wr_en", "wave": "0.1.0.." },
    { "name": "full", "wave": "0......" },
    { "name": "din", "wave": "x.=.x..", "data": ["8'hA5"] }
  ]
}
```

---

## 10. 开发阶段

### Phase 1：纯 Dart 解析层

任务：

- 新增 `TimingDiagram` / `TimingSignal` 模型。
- 新增 `WaveDromParser`。
- 支持 `wavedrom` JSON object。
- 校验 `signal` 数组。
- 校验每个 signal 的 `name` / `wave`。
- 支持 `data` 为字符串数组。
- 返回可展示错误信息。

验收：

- 合法 JSON 能解析为模型。
- 缺少 `signal` 会返回错误。
- `signal` 不是数组会返回错误。
- `wave` 为空会返回错误。
- `data` 数量少于 `=` 时不崩溃。

### Phase 2：CustomPainter 预览

任务：

- 新增 `TimingDiagramView`。
- 新增 `TimingDiagramPainter`。
- 实现基础波形绘制。
- 支持横向滚动。
- 支持亮色/暗色主题。
- 支持错误态卡片。

验收：

- `0/1/.` 基础波形正确。
- `p` 时钟可读。
- `=` 数据段可显示标签。
- 长波形横向滚动不卡顿。
- 错误输入不会导致 Markdown 页面崩溃。

### Phase 3：Markdown 集成

任务：

- 新增 `MarkdownTimingSupport`。
- 支持 `wavedrom` / `timing` / `wavejson`。
- 在文档预览中合并 block syntax 和 builder。
- 新增集成测试。

验收：

- 文档中 `wavedrom` code block 被替换成时序图。
- 普通代码块仍然正常显示。
- 数学公式、音乐谱块、时序图可共存。

### Phase 4：编辑器模板

任务：

- 新增 `TimingTemplates`。
- 文档编辑页新增“插入时序图”菜单。
- 复用当前光标插入逻辑。
- 提供 4 个 FPGA 常用模板。

验收：

- 可在正文光标位置插入模板。
- 插入后切换预览可立即看到时序图。
- 不影响音乐谱块插入菜单。

### Phase 5：文档和演示数据

任务：

- 更新 `README.md`。
- 更新 `V0_3_DEV_PLAN.md`。
- 更新或新增演示数据脚本。
- 注入一篇“FPGA 时序图测试文档”。

验收：

- 本地 Windows demo 可看到时序图文档。
- Android demo 可看到时序图文档。

---

## 11. 测试计划

### 11.1 单元测试

文件建议：

```text
test/documents/timing/wavedrom_parser_test.dart
test/documents/timing/timing_wave_segment_test.dart
```

测试项：

- 解析基础 `clk/rst_n`。
- 解析 valid/ready/data。
- 解析 `data` 标签。
- 解析错误 JSON。
- 解析未知字段时忽略。
- 空 `signal` 报错。
- 空 `wave` 报错。

### 11.2 Widget 测试

文件建议：

```text
test/documents/timing/timing_diagram_view_test.dart
test/documents/markdown_timing_integration_test.dart
```

测试项：

- `TimingDiagramView` 可渲染。
- 错误态可渲染。
- Markdown 可识别 `wavedrom`。
- 数学公式、音乐谱块、时序图可共存。

### 11.3 手动验收

场景：

- 打开文档库。
- 新建文档。
- 插入 valid/ready 时序模板。
- 切换预览。
- 横向滑动长时序图。
- 在 Android 真机上快速滚动包含时序图的长文档。
- 切换暗色模式查看对比度。

---

## 12. 性能要求

初版性能目标：

- 单篇文档包含 3 个时序图时，预览滚动无明显卡顿。
- 单个时序图支持 20 个信号、80 个周期以内。
- 超长图自动横向滚动，不强行压缩到屏幕宽度。
- `CustomPainter.shouldRepaint` 只在模型或主题变化时返回 true。
- 每个时序图外层使用 `RepaintBoundary`。

暂不优化：

- 上百信号。
- 上千周期。
- 实时仿真波形缩放。

---

## 13. 风险和规避

### 风险 1：WaveDrom 兼容性预期过高

规避：

- 明确标注“WaveDrom 子集”。
- 错误态提示“当前暂不支持该语法”。
- 文档中列出已支持字符。

### 风险 2：绘制细节复杂

规避：

- 第一版只做常见数字波形。
- `edge`、`node`、分组后置。
- 用单元测试锁定基础字符行为。

### 风险 3：Android 滚动卡顿

规避：

- 不使用 WebView。
- 不使用复杂阴影和裁剪。
- 图块使用 `RepaintBoundary`。
- 长图横向滚动，纵向列表只布局图块高度。

### 风险 4：功能范围滑向 EDA 工具

规避：

- 不做 VCD 文件查看。
- 不做完整波形数据库管理。
- 只服务文档沉淀场景。

---

## 14. 分支开发建议

### 14.1 创建分支

```bash
git checkout -b feature/markdown-timing-diagram
```

### 14.2 分支内提交建议

建议拆成 5 个提交：

```text
1. add timing diagram domain model and parser
2. add Flutter timing diagram painter and view
3. integrate timing diagrams into Markdown preview
4. add timing diagram editor templates
5. update docs, demo data, and tests
```

### 14.3 Merge 前检查

必须通过：

```bash
flutter analyze
flutter test
flutter build apk --debug
```

建议通过：

```bash
flutter build windows
```

手动验收：

- Windows 文档预览正常。
- Android 真机文档预览正常。
- 长文档滚动无明显掉帧。
- 普通 Markdown、数学公式、音乐谱块没有回归。

### 14.4 Merge Checklist

- [ ] 功能分支已 rebase 或 merge 最新 `main`。
- [ ] 无临时调试输出。
- [ ] 无 WebView / 网络依赖。
- [ ] 无新增大型二进制资源。
- [ ] README 已说明支持的时序图语法。
- [ ] V0.3 计划文档已更新当前状态。
- [ ] 演示数据脚本包含 FPGA 时序图测试文档。
- [ ] Android debug build 通过。

---

## 15. 推荐完成定义

该功能可以认为完成，当满足：

- 用户可以在 Markdown 中写 `wavedrom` fenced block。
- 文档预览可以渲染基础数字时序图。
- 支持 `clk/rst_n/valid/ready/data` 常用场景。
- 编辑器可以一键插入常用 FPGA 时序模板。
- 错误语法不会导致页面崩溃。
- 数学公式、音乐谱块、时序图三者可共存。
- Windows 和 Android 构建通过。

