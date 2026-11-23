# 天气音效工具与制作流程

核对日期：2026-11-23。以下是制作工具选型，不是已经确定的游戏运行时技术栈。第三方工具未安装到系统，也未将第三方声音打包进本仓库。

## 当前可直接使用

本仓库附带[天气音效工作台](../tools/weather-audio/index.html)，使用浏览器原生音频能力，无需 npm 安装或联网加载第三方库。

- 合成雨声、风声、低缓远雷和水滴细节，提供四组预设。
- 调整各层强度、时长与随机种子，相同种子和参数可复现。
- 导入浏览器可解码的本地音频；在浏览器内裁剪、调节音量、添加淡入淡出。
- 试听并导出立体声 16-bit PCM WAV。
- 当前为程序合成原型；自然度需要试听评估。未加入多轨时间线、均衡器、降噪、无缝循环编辑或 MP3 导出。
- 每次导出烘焙淡入淡出，适合单段试听；需要无缝循环的素材请另行处理。

使用方法：直接用现代桌面浏览器打开 `tools/weather-audio/index.html`。如浏览器限制本地文件能力，在仓库根目录执行：

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

然后访问 `http://127.0.0.1:8765/tools/weather-audio/`。文件留在当前浏览器中处理，不向外部服务上传。

## 编辑与自创工具

| 工具 | 用途与本项目适配 | 使用入口与许可 |
| --- | --- | --- |
| Audacity | 多轨剪辑与录音；用于雨声素材剪裁、混音、均衡、淡入淡出及循环拼接处理。建议作为主要桌面编辑器 | [GitHub](https://github.com/audacity/audacity) · [官网](https://www.audacityteam.org/)；README 标注 GPLv3，部分源码另有条款 |
| jsfxr | 参数化短音效合成，可生成并导出 WAV；适合金币、升级、按钮等反馈音，不优先用来制作自然雨声 | [GitHub](https://github.com/chr15m/jsfxr) · [在线工具](https://sfxr.me)；仓库标注 Unlicense |
| Tone.js | 浏览器音频合成、噪声、滤波、包络、效果和调度；适合网页原型中的程序化天气声音和参数控制 | [GitHub](https://github.com/Tonejs/Tone.js) · [示例](https://tonejs.github.io/examples/)；MIT |
| SuperCollider | 音频合成服务器、编程语言和 IDE；适合深入制作雨、风、雷等连续变化的自创声音，再渲染为素材 | [GitHub](https://github.com/supercollider/supercollider) · [官网](https://supercollider.github.io/)；GPL-3.0，学习成本较高 |
| FFmpeg | 批量转码、裁剪、响度处理、滤波和混音；适合素材管线自动化 | [GitHub](https://github.com/FFmpeg/FFmpeg) · [滤镜文档](https://ffmpeg.org/ffmpeg-filters.html)；许可取决于构建配置，按实际使用版本核对 |

推荐组合：Audacity 负责精修，jsfxr 负责轻量反馈音，天气音效工作台负责快速合成试验。若网页原型需要更复杂的实时声音控制，再评估 Tone.js；SuperCollider 留作深入声音设计选择。

工具代码的许可与输入素材、输出声音的权利分别核对。使用 GPL 编辑器处理音频不会仅因使用编辑器就要求游戏采用 GPL；如果嵌入工具代码或分发其二进制，需要另行遵守相应许可。第三方录音和预设素材不能因工具开源就视为自由素材。

## 已找到的环境音与播放项目

| 项目 | 已核对的可用方向 | 注意事项 |
| --- | --- | --- |
| [Moodist](https://github.com/remvze/moodist) / [在线混音](https://moodist.mvze.net) | 小雨、大雨、雨打树叶、窗户、帐篷、车顶、伞，以及雷、风、水流；支持混音、淡入淡出、睡眠计时器 | 代码 MIT；第三方声音涉及 Pixabay、CC0 等不同许可。已核对 README 和声音文件列表，未逐项确认素材授权来源，也未完成听感评估 |
| [Blanket](https://github.com/rafaelmardojai/blanket) | 雨、风、雷暴、溪流、海浪等；有逐项素材来源 | 代码 GPL-3.0；[声音许可表](https://github.com/rafaelmardojai/blanket/blob/master/SOUNDS_LICENSING.md)列出风、溪流为 CC0，雨、雷暴为 CC BY。使用前回到原素材页核对完整版本与署名信息 |
| [Howler.js](https://github.com/goldfire/howler.js) | 网页音频播放库，供网页游戏原型评估 | MIT；用于播放控制，不是音效编辑器或自然声音生成器 |
| [noise.js](https://github.com/zacharydenton/noise.js) | 白噪声、粉噪声、棕噪声生成思路 | README 使用旧式 Web Audio API，作为算法参考，当前不选作直接依赖 |

## 面向游戏的制作方式

将声音拆为三层：场景环境音、持续天气音、触摸触发的近景细节。画面中每个粒子不必对应一次独立播放，雨量大时可用持续声音表达整体密度。

1. 准备来源与许可明确的雨声、风声、远雷等基础素材，或用合成工具自创。
2. 在工作台试音色与强度；自然度要求更高的素材进入 Audacity 做多轨精修。
3. 按关卡组合：滋养使用叶面雨声，助眠使用窗边雨声，归航使用海风、浪声和船帆轻响。
4. 为触摸细节制作多种轻微变体，避免同一水滴反复播放形成机械节奏。
5. 为循环素材修整接缝并检查连续播放；导出 WAV 母版，运行时格式待引擎确定后选择。
6. 分别试听耳机与扬声器，检查削波、突发响声、长时间重复感和关卡切换。助眠声音层的响度应独立于金币与天气升级数值设计。

入眠人数是游戏关卡指标；音频素材是否真正帮助玩家入眠，仍需体验验证。
