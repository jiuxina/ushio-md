# 汐宣传封面

封面沿用浅粉与淡紫的柔和背景、右侧角色插画、左上品牌标识和左侧三行放大标题的构图，不包含软件界面截图。三行依次为“以个性化为 / “卖点”的 / MD编辑器”，完整文案不变。16:9 输出为 1920×1080，4:3 输出为 1600×1200；两种比例都另有 2 倍高清母版和 JPEG 版本。

角色使用 `promo/cover-assets/ushio-portrait.png`，脚本会自动移除插画外围白底，并把人物底部裁切到画面边缘。品牌字样、英文副标题和主标题从仓库内既有封面 `sample/cover.png` 提取为透明字形蒙版，因此生成过程不依赖工作区外的字体。

运行以下命令可重新生成封面、缩略图和版式元数据：

```powershell
python promo/scripts/create-cover.py
```

结果写入 `promo/out/covers/`。脚本使用 Pillow、NumPy 与 OpenCV；输出包括 PNG、JPEG、高清 PNG、320px 缩略图和 `cover-layout.json`。
