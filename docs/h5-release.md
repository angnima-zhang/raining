# TapTap H5 发布路线

确认日期：2026-11-23。目标改为 TapTap **H5 游戏**，继续使用 Godot 作为开发工具，以单线程 Web 导出作为交付物。当前不再把 Godot Web 转普通 Tap 小游戏的适配器作为必经路线。

## 当前产物

- 横屏设计尺寸：1280×720。
- 本地试玩：启动本地服务器后访问 `http://127.0.0.1:8766/`。
- 网页目录：`godot/build/web/`。
- 上传候选 ZIP：`godot/build/raining-h5.zip`，根目录包含 `index.html`。
- 构建报告：`godot/build/h5-build-report.json`，记录文件尺寸和包体 SHA-256。
- 本次 ZIP：10,209,124 字节，约 10.2 MB（9.74 MiB），包含 Web 引擎；未压缩总量约 39.9 MB。
- PCK：60,116 字节；自带中文字体子集 48,196 字节，避免依赖设备上安装的中文字体。

构建产物放在 Git 忽略的目录中，不将 WASM 或整个发布包提交到源码仓库。字体许可证随 ZIP 以 `OFL.txt` 提供；字体来源及重建方式见 `godot/fonts/README.md`。

## 本机构建

在仓库根目录执行：

```sh
python3 tools/build_h5.py --godot /path/to/Godot
```

需要对应 Godot 版本的 `web_nothreads_release.zip` 导出模板。本轮已为本机 Godot 4.7.2 安装官方 Web 发布模板，未下载其它平台模板。

脚本导出 Web、检查必需文件、生成 ZIP 并检查 ZIP 完整性，最后写入构建报告。发布 ZIP 的入口位于根目录，不额外套文件夹。测试目录、参考 MP3、网页声音工作台、文档和完整原始字体不进入游戏包。

本地运行时通过 HTTP 服务网页目录，不能双击 `index.html` 以 `file://` 方式运行：

```sh
python3 -m http.server 8766 --bind 127.0.0.1 --directory godot/build/web
```

## 已验证

- Godot 4.7.2 Web 发布导出成功，关闭线程和 GDExtension。
- 浏览器启动成功，中文显示正常；检查了窄窗口等比显示及 1280×720 横屏布局。
- 浏览器鼠标长按五批雨完成首关，10 金币升级速度。
- 刷新网页后保留首关完成状态及速度升级。
- 第二关三棵树全部灭火，30 金币升级范围。
- 第三关十棵树可由扩大后的雨云多目标覆盖并完成结算。
- 检查时浏览器控制台没有错误或警告。
- 原有 15 项进度检查与 9 项场景、输入、音频缓冲检查继续通过。

雨声音频生成及播放代码保留；本次未进行主观音质评审，也未在真实手机或 TapTap H5 容器验证触摸、声音中断和性能。

## 平台接入边界

官方支持 H5 上传和广告变现，已经核对 CLI 存在 `upload-h5-package`。本次只生成本地上传候选包，未创建平台游戏、上传、绑定包体、申请广告或提交审核。

下一步先确认平台目标游戏，上传后取得自测入口，在 TapTap 容器中检查 WebGL/WASM、长按、音频启动/中断、存档和加载体验。普通 Tap 小游戏的整包限制不能自动当作 H5 的限制；具体 H5 限额以该入口的当前规则和上传校验为准。

激励广告在开发者认证、财务主体信息和游戏广告功能开通后接入。Godot Web 通过 JavaScript 桥接平台广告回调；完整观看才给奖励，取消或加载失败不影响基本通关。当前未添加真实广告或模拟广告按钮。

## 官方依据

- [小游戏介绍：普通小游戏与 H5 两类包体](https://developer.taptap.cn/minigameapidoc/quick-start/guide/minigames-intro/)
- [CLI 安装与命令入口](https://developer.taptap.cn/v3/cli/)
- [H5 广告支持与开通流程](https://developer.taptap.cn/minigameapidoc/quick-start/mcp-guide/ad-integration-guide/)
- [激励视频广告及完整观看回调](https://developer.taptap.cn/minigameapidoc/dev/tutorial/open-capabilities/ad/rewarded-video-ad/)
