# Animalese-Unity 到 Godot 4 (GDScript) 移植任务规范

## 1. 任务背景与目标
将原基于 Unity 开发的实时合成“动森语（Animalese）”的 UPM 包 `Animalese-Unity`，完整、纯粹地使用 **GDScript** 移植为 Godot 4.x 的标准化插件（Addon）及示例工程。
目标是提供一个轻量、解耦、零外部依赖、富含拟真韵律（声调起伏、标点情绪、长音停顿）并且支持与富文本打字机（`RichTextLabel`）毫秒级音画同步的对话语音合成系统。

---

## 2. 架构设计与映射对照

| 模块类别 | Unity 原始实现 | Godot 4.x (GDScript) 移植目标 | 说明与核心职责 |
| :--- | :--- | :--- | :--- |
| **基础配置** | `package.json` | `addons/animalese/plugin.cfg` & `animalese_plugin.gd` | 声明插件元信息，注册编辑器自定义节点 `AnimalesePlayer` |
| **核心数据** | `VoiceToken.cs` (struct) | `addons/animalese/scripts/core/voice_token.gd` (`RefCounted`) | 存储音素 ID、字符索引、相对时长、音量缩放、音高偏移 |
| **韵律解析** | `AnimaleseParser.cs` (static) | `addons/animalese/scripts/core/animalese_parser.gd` (`RefCounted`) | 静态解析文本：处理省略号、问号、感叹号、长音、波浪号，贪心双字母与多语言 Unicode 降级 |
| **音素资源** | `PhonemeMapSO.cs` (ScriptableObject) | `addons/animalese/scripts/resources/phoneme_map.gd` (`Resource`) | 音素名 -> `AudioStream` 映射，支持运行时字典缓存与哈希取模降级 |
| **音色配置** | `VoiceProfileSO.cs` (ScriptableObject) | `addons/animalese/scripts/resources/voice_profile.gd` (`Resource`) | 角色发音参数（基准音调、抖动度、语速、步进、高低通滤波参数） |
| **播放器节点** | `AnimalesePlayer.cs` (MonoBehaviour) | `addons/animalese/scripts/nodes/animalese_player.gd` (`Node`) | 状态机驱动、时间累加器、音调/音量随机化计算，发射 `token_played` 信号 |
| **打字机同步** | `AnimaleseSampleTypewriter.cs` | `examples/example_typewriter.gd` + `example_scene.tscn` | 配合 `RichTextLabel.visible_characters` 实现无抖动音画绝对同步 |

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
│           ├── sounds/                       # 从 Samples 导入的 31 个音素 wav 文件
│           │   ├── a.wav ... z.wav
│           │   ├── ch.wav, sh.wav, th.wav, wh.wav, ph.wav
│           ├── default_phoneme_map.tres      # 默认音素表资源
│           └── default_profile.tres          # 默认发音角色预设
│
└── examples/
    ├── example_typewriter.gd
    └── example_scene.tscn
```

---

## 4. 关键算法与技术要点

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
3. **多语言与音素匹配**：
   - 英文优先贪心匹配双字母辅音（`ch`, `sh`, `th`, `wh`, `ph`）。
   - 匹配单个 ASCII 字母 `a`~`z`。
   - 中文/日文等 Unicode 字符保留原字符，音素 ID 留空，播放阶段利用 `hash(code_point) % total_phonemes` 确定性降级。

### 4.2 播放器与并发音频方案 (`AnimalesePlayer`)
- 时间驱动：在 `_process(delta)` 中累加/递减时间，支持变速倍率 `speed_multiplier`。
- 音频并发与切音控制：
  - 音素之间时间约为 `0.06s`，使用内部单 `AudioStreamPlayer` 或双缓冲交叉播放，确保短促干净的拟真音效。
  - 动态计算并设置 `pitch_scale = clamp(base_pitch * (1.0 + pitch_offset * question_rise) + jitter, 0.1, 3.0)`。
  - 音量通过 `volume_db = linear_to_db(clamp(base_volume * volume_scale, 0.0, 1.0))` 映射。
  - 支持可选的高通/低通滤波（通过动态附加 AudioEffect 或独立 Bus 实现）。

### 4.3 打字机绝对同步机制 (`Typewriter`)
- 初始时将完整富文本或字符串一次性赋予 UI 组件（如 `RichTextLabel.text`），并设置 `visible_characters = 0`。
- 监听 `token_played(token, index)` 信号：
  $$\text{visible\_characters} = \begin{cases} \text{tokens}[index + 1].\text{char\_index} & (index + 1 < \text{count}) \\ \text{text.length()} & (\text{最后一个 token}) \end{cases}$$
- 避免动态字符拼接造成的 UI 文本折行跳动与回流（Reflow Jitter）。

---

## 5. 里程碑与执行阶段 (Checklist)

- [x] **Phase 1: 基础插件骨架与资源转移**
  - [x] 创建 `addons/animalese/plugin.cfg` 与 `animalese_plugin.gd`。
  - [x] 将 Unity Samples 中的 32 个音素 `.wav` 音频复制至 `addons/animalese/assets/sounds/`。
- [ ] **Phase 2: 数据结构与核心资源类**
  - [ ] 实现 `VoiceToken` (`scripts/core/voice_token.gd`)。
  - [ ] 实现 `PhonemeMap` (`scripts/resources/phoneme_map.gd`)，含字典索引与 Unicode 降级机制。
  - [ ] 实现 `VoiceProfile` (`scripts/resources/voice_profile.gd`)，定义各种发音参数。
  - [ ] 创建 `default_phoneme_map.tres` 与 `default_profile.tres`。
- [ ] **Phase 3: 静态解析器与韵律算法移植**
  - [ ] 实现 `AnimaleseParser` (`scripts/core/animalese_parser.gd`)。
  - [ ] 编写测试脚本验证分词、省略号修饰、问感叹号修饰、长音延伸及非英文字符降级。
- [ ] **Phase 4: 播放器节点实现**
  - [ ] 实现 `AnimalesePlayer` (`scripts/nodes/animalese_player.gd`)。
  - [ ] 完成定时驱动循环、音调随机化、音量计算及 `token_played` / `play_completed` 信号发射。
  - [ ] 注册自定义节点至 Godot 编辑器。
- [ ] **Phase 5: 示例场景与打字机同步验证**
  - [ ] 创建 `examples/example_scene.tscn`（包含输入框、播放按钮、富文本打字机展示区域）。
  - [ ] 实现 `examples/example_typewriter.gd` 同步逻辑。
  - [ ] 运行测试验证中英文混合输入、标点符号韵律起伏与音画同步效果。

---

## 6. 当前状态
- **Status**: Phase 1 已完成（插件骨架、配置入口及 32 个音素采样已就绪）。
- **Next Step**: 开始 Phase 2，实现 `VoiceToken`、`PhonemeMap` 与 `VoiceProfile` 核心数据类及资源。

