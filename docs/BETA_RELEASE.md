# ApexPlayer 内测发布说明（E1）

## 1. 发布目标
- 版本类型：内测版（A1）
- 重点：验证稳定性与核心体验，不扩功能

## 2. 交付物
- 应用包：`dist/ApexPlayer.dmg`
- 验收文档：`docs/TEST_MATRIX.md`
- 开发总文档：`docs/DEV_PLAN.md`

## 3. 安装说明
1. 下载并打开 `ApexPlayer.dmg`。
2. 拖拽 `ApexPlayer.app` 到 Applications。
3. 首次打开若系统提示未验证开发者：
- 在“系统设置 -> 隐私与安全性”允许打开。

## 4. 已知问题（当前）
- 仅本地签名（未 notarization），首次安装流程会有系统安全提示。
- 大型无损曲库（数千首）首次导入仍可能耗时较长。
- 播放队列当前支持拖拽/移除/持久化，但未提供独立“保存队列模板”功能。

## 5. 回滚步骤
1. 退出应用。
2. 删除 `/Applications/ApexPlayer.app`。
3. 如需清理数据（可选）：删除 `~/Library/Application Support/ApexPlayer`。
4. 恢复到上一个稳定 DMG 版本并重新安装。

## 6. 内测反馈模板
- 复现场景：
- 期望行为：
- 实际行为：
- 影响程度（高/中/低）：
- 日志或截图：

## 7. 发布检查清单
- `swift test` 全绿
- DMG 可打开并安装
- 200 首曲库 + 30 分钟连续播放通过
- 恢复上次播放功能通过
