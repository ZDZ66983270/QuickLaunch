### Launchpad Icon Target Size Table | Launchpad 图标目标显示尺寸表

| Scale factor  | 基准资源                   | 渲染目标大小 (px)                              | 计算公式 (≈0.8125×资源大小) |
| ------------- | ---------------------- | ---------------------------------------- | ------------------- |
| 1× (非 Retina) | 128×128                | **104 px**                               | 128 × 0.8125 = 104  |
| 2× (Retina)   | 256×256                | **208 px**（实测你看到 206，系统可能有 1–2px 四舍五入差异） | 256 × 0.8125 = 208  |
| 3× (高分屏)      | 384×384（系统会从 512 资源缩小） | **312 px**                               | 384 × 0.8125 = 312  |
| 4× (超高分屏)     | 512×512                | **416 px**                               | 512 × 0.8125 = 416  |


Usage notes | 使用建议

- Choose the source icon size based on the current scale factor
- 根据当前 Scale factor 选择合适的原始图标资源
- Multiply the icon size by `0.8125` for the final rendered size
- 实际渲染时，建议将图标尺寸乘以 `0.8125`
- Compute the displayed size dynamically instead of hard-coding a fixed value
- 不要写死固定值，最好动态计算实际显示尺寸
- Keep other surrounding layout metrics unchanged
- 其他界面相关元素的尺寸建议保持不变
