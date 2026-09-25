# Animalese-Unity 到 Godot 4 (GDScript) 移植任务规范

## 1. 任务背景与目标
将原基于 Unity 开发的实时合成“动森语（Animalese）”的 UPM 包 `Animalese-Unity`（已同步最新优化版本 v0.2.0），完整、纯粹地使用 **GDScript** 移植为 Godot 4.x 的标准化插件（Addon）及示例工程。
目标是提供一个轻量、解耦、零外部依赖、富含拟真韵律（声调起伏、标点情绪、长音停顿）、支持防爆音掉帧补偿，并且支持与富文本打字机（`RichTextLabel`）毫秒级音画同步的对话语音合成系统。

---

## 2. 架构设计与映射对照（基于 v0.2.0 优化版）

| 模块类别 | Unity 原始实现 (v0.2.0) | Godot 4.x (GDScript) 移植目标 | 说明与核心职责 |
| :--- | :--- | :--- | :--- |
| **基础配置** | `package.json` | `addons/animalese/plugin.cfg` & `animalese_plugin.gd` | 声明插件元信息，注册编辑器自定义节点 `AnimalesePlayer` |
| **核心数据** | `VoiceToken.cs` (struct) | `addons/animalese/scripts/core/voice_token.gd` (`RefCounted`) | 存储音素 ID、字符索引、相对时长、音量缩放、音高偏移。去除冗余 List 包装类 |
| **韵律解析** | `AnimaleseParser.cs` (static) | `addons/animalese/scripts/core/animalese_parser.gd` (`RefCounted`) | 静态解析文本：双重重载支持缓冲区复用；省略号、问号、感叹号、长音、波浪号；Emoji 静音处理；英文双字母与多语言 Unicode 降级 |
| **音素资源** | `PhonemeMapSO.cs` (ScriptableObject) | `addons/animalese/scripts/resources/phoneme_map.gd` (`Resource`) | 音素名 -> `AudioStream` 映射，支持运行时字典缓存与哈希取模降级 |
| **音色配置** | `VoiceProfileSO.cs` (ScriptableObject) | `addons/animalese/scripts/resources/voice_profile.gd` (`Resource`) | 角色发音参数（基准音调、抖动度、语速、步进、高低通滤波参数） |
| **播放器节点** | `AnimalesePlayer.cs` (MonoBehaviour) | `addons/animalese/scripts/nodes/animalese_player.gd` (`Node`) | 状态机驱动、时间累加器与 `-0.2s` 时间债务钳制、**每帧单次发声限频（防爆音）**，发射 `token_played` 信号 |
| **打字机同步** | `AnimaleseSampleTypewriter.cs` | `examples/example_typewriter.gd` + `example_scene.tscn` | 剥离富文本标签（BBCode）对齐可见字符数，配合 `RichTextLabel.visible_characters` 实现音画绝对同步 |

---

## 3. 插件目录规划

```text
res://
├── addons/
│   └── animalese/
│       ├── plugin.cfg
│       ├── animalese_plugin.gd
│       ├── icon.svg
│       ├── scripts/
│       │   ├── core/
│       │   │   ├── voice_token.gd
│       │   │   └── animalese_parser.gd
│       │   ├── resources/
│       │   │   ├── phoneme_map.gd
│       │   │   └── voice_profile.gd
│       │   └── nodes/
│       │       └── animalese_player.gd
│       └── assets/
│           ├── sounds/                       # 从 Samples 导入的 32 个音素 wav 文件
│           │   ├── a.wav ... z.wav
│           │   ├── ch.wav, sh.wav, th.wav, wh.wav, ph.wav, dot.wav
│           ├── default_phoneme_map.tres      # 默认音素表资源
│           └── default_profile.tres          # 默认发音角色预设
│
└── examples/
    ├── example_typewriter.gd
    └── example_scene.tscn
```

---

## 4. 关键算法与技术要点（吸纳 Unity v0.2.0 重大优化）

### 4.1 标点与韵律解析规则 (`AnimaleseParser`)
1. **连续省略号 (`...` / `……`)**：
   - 回溯修饰前两个音素：末尾音素音量 0.6、音高 -0.1；次末尾音素音量 0.8。
   - 生成 5.0x 相对时长的停顿 Token。
2. **标点情绪识别与升降调**：
   - `?` / `？`：末尾音素升调 +0.35，次末尾 +0.15，停顿 3.0x。
   - `!` / `！`：末尾音素升调 +0.25、音量 1.35；次末尾升调 +0.10、音量 1.15，停顿 4.0x。
   - `?!` / `!?`（震惊）：末尾升调 +0.45、音量 1.40；次末尾升调 +0.25、音量 1.20，停顿 4.0x。
   - `-` / `—` / `ー`（长音）：延长前置音素时长 +1.0x，插入 0.2x 占位停顿。
   - `~` / `～`（尾音/撒娇）：延长前置音素 +0.8x，升调 +0.15，插入 0.2x 占位停顿。
   - 逗号停顿 2.0x，句号/冒号/分号停顿 4.0x，空格 0.5x。
3. **多语言、音素匹配与异常字符兜底**：
   - 英文优先贪心匹配双字母辅音（`ch`, `sh`, `th`, `wh`, `ph`）。
   - 匹配单个 ASCII 字母 `a`~`z`。
   - **Emoji 与生僻代理对处理 (v0.2.0 新增)**：识别扩展 Unicode / Emoji 字符，生成 0.5x 静音停顿 Token，不发音但正确占位并推进打字机。
   - 中文/日文等 Unicode 字符保留原字符，音素 ID 留空，播放阶段利用 `hash(code_point) % total_phonemes` 确定性降级。
4. **缓冲区复用 (v0.2.0 新增)**：
   - 提供 `static func parse(text: String, results: Array[VoiceToken] = []) -> Array[VoiceToken]`，支持传入现有数组重用，避免频繁 `parse` 造成的垃圾分配。

### 4.2 播放器与防爆音掉帧控制 (`AnimalesePlayer`)
- **时间债务钳制（Time Debt Clamping, v0.2.0 新增）**：
  - `_timer = max(_timer, -0.2)`，杜绝严重掉帧或切后台切回时出现极大的负时间，导致 `while` 追帧死循环。
- **单帧单次发声限频（Rate-Limited Playback, v0.2.0 新增）**：
  - 在 `while (_timer <= 0)` 循环处理赶帧时，使用布尔标志 `played_audio_this_frame`，**单帧最多只触发一次音频播放**！后续音素只步进时间并触发打字机事件，彻底杜绝掉帧或 2x 快进时音效多重叠加引发的刺耳爆音。
- **发音计算**：
  - 动态计算并设置 `pitch_scale = clamp(base_pitch * (1.0 + pitch_offset * question_rise) + jitter, 0.1, 3.0)`。
  - 音量通过 `volume_db = linear_to_db(clamp(base_volume * volume_scale, 0.0, 1.0))` 映射。
  - 滤波器支持：预先绑定/初始化高通与低通效果器，避免运行时动态构建。

### 4.3 富文本打字机绝对同步机制 (`Typewriter`)
- **富文本 BBCode 标签过滤 (v0.2.0 新增)**：
  - 若输入包含 `[b]`、`[color]` 等 BBCode 格式，在送入 Parser 解析音素前提取纯文本（或剥离标签），确保 Token 的 `char_index` 与 Godot `RichTextLabel.get_parsed_text()` / `visible_characters` 完全 1:1 吻合。
- **按 Token 边界步进**：
  - 监听 `token_played(token, index)` 信号：
    $$\text{visible\_characters} = \begin{cases} \text{tokens}[index + 1].\text{char\_index} & (index + 1 < \text{count}) \\ \text{text.length()} & (\text{最后一个 token}) \end{cases}$$
  - 先将完整文本赋给 UI 组件，初始 `visible_characters = 0`，避免动态加字引发排版回流抖动（Reflow Jitter）。

---

## 5. 里程碑与执行阶段 (Checklist)

- [x] **Phase 1: 基础插件骨架与资源转移**
  - [x] 创建 `addons/animalese/plugin.cfg` 与 `animalese_plugin.gd`。
  - [x] 将 Unity Samples 中的 32 个音素 `.wav` 音频复制至 `addons/animalese/assets/sounds/`。
- [x] **Phase 2: 数据结构与核心资源类**
  - [x] 实现 `VoiceToken` (`scripts/core/voice_token.gd`)（轻量 RefCounted，无冗余容器包装）。
  - [x] 实现 `PhonemeMap` (`scripts/resources/phoneme_map.gd`)，含字典索引与 Unicode 降级机制。
  - [x] 实现 `VoiceProfile` (`scripts/resources/voice_profile.gd`)，定义各种发音参数。
  - [x] 创建 `default_phoneme_map.tres` 与 `default_profile.tres`。
- [x] **Phase 3: 静态解析器与韵律算法移植 (含 v0.2.0 优化)**
  - [x] 实现 `AnimaleseParser` (`scripts/core/animalese_parser.gd`)：
    - [x] 支持缓冲区重用重载。
    - [x] 连续省略号衰减、问/感叹号情绪升调、长音/波浪号处理。
    - [x] 双字母快速匹配、ASCII 字母查找。
    - [x] Emoji / 代理对静音 Token 处理。
  - [x] 编写测试脚本验证分词与韵律 (`tests/test_parser.gd`，9/9 项测试全部通过)。
- [x] **Phase 4: 播放器节点实现 (含 v0.2.0 优化)**
  - [x] 实现 `AnimalesePlayer` (`scripts/nodes/animalese_player.gd`)：
    - [x] 时间债务钳制（-0.2s clamp）。
    - [x] 掉帧/快进防爆音限频机制（单帧最多播放一次音频）。
    - [x] 动态音调抖动与音量计算。
    - [x] 组合模式（零配置自动兜底创建内部播放器，同时支持外挂 2D/3D 空间音频播放器）。
    - [x] 发射 `token_played` / `play_completed` 信号。
  - [x] 注册自定义节点至 Godot 编辑器 (`animalese_plugin.gd`)。
  - [x] 编写单元测试验证播放状态机与生命周期 (`tests/test_player.gd`，全部通过)。
- [x] **Phase 5: 示例场景与打字机同步验证 (含 BBCode 支持)**
  - [x] 创建 `examples/example_scene.tscn`（包含输入框、播放按钮、富文本打字机展示区域）。
  - [x] 实现 `examples/example_typewriter.gd`：支持 BBCode 标签过滤及无抖动音画同步。
  - [x] 运行测试验证中英文混合、Emoji、标点起伏与音画同步 (`tests/test_typewriter_integration.gd` 全部通过)。

---

## 6. 当前状态
- **Status**: 全部五个阶段（Phase 1 ~ Phase 5）已 100% 圆满完成！
  - 核心插件架构已建立，包含 `VoiceToken`、`PhonemeMap`、`VoiceProfile`、`AnimaleseParser`、`AnimalesePlayer`。
  - 插件已在 `animalese_plugin.gd` 注册，支持在编辑器中搜索添加带有图标的 `AnimalesePlayer` 自定义节点。
  - 32 个音素采样已导入并构建默认预设 `.tres` 资产。
  - 示例场景 `examples/example_scene.tscn` 与控制器已就绪，三大自动化测试套件（Parser/Player/Typewriter）全量绿灯通过。
- **Next Step**: 用户可在 Godot 编辑器中直接按 F6 运行 `examples/example_scene.tscn` 体验动森语发音与打字机交互！
