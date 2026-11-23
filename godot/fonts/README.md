# Raining Sans UI 字体子集

来源：[Google Fonts Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)，采用随附 `OFL.txt` 中的 SIL Open Font License 1.1。

本字体由官方可变 TTF 固定为 500 字重，再裁剪为 `godot/scripts/*.gd` 中出现的字符及 ASCII 可打印字符；为区分修改版本，字体 family/full/PostScript 名称改为 Raining Sans。未将约 17.8 MB 的上游完整字体提交到仓库。

重建方法：在隔离 Python 环境安装 `fonttools`，下载该目录内的官方 `NotoSansSC[wght].ttf` 后，从仓库根目录运行：

```sh
python3 tools/subset_font.py /path/to/NotoSansSC.ttf
```

新界面加入字符后需重新构建字体；当前字体不覆盖任意玩家输入的中文文本。
