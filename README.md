# ClockFlow

参考 [Humans since 1982 · ClockClock 24](https://www.humanssince1982.com/collections/collectibles) 的指针组合与动态变化效果，自行实现的 iOS 时钟：24 个钟面、48 根指针，在每分钟切换时旋转并组成当前时间。

因为觉得这个效果很好玩，想自己做出来在 iPhone 上体验，所以有了这个个人研究与学习项目。

![ClockFlow 沉浸横屏预览](Previews/immersive-landscape.png)

## 功能

- 黑底简约配色，支持横屏、竖屏和沉浸显示。
- 八种指针编舞，可自动轮换、随机或固定选择；整点与十分钟有图案彩蛋。
- 保持屏幕开启、调节亮度，以及日期、12/24 小时制等设置。

这是应用内的前台显示，不是 iOS 系统常显；手动锁屏后不会继续显示动画。

## 运行

需要 Xcode 16+、iOS / iPadOS 17+。

1. 打开 `Handscape.xcodeproj`，选择 `Handscape` scheme。
2. 选择模拟器，按 ⌘R 运行。
3. 真机运行时，将 `Configuration/Signing.local.xcconfig.example` 复制为 `Signing.local.xcconfig`（同一目录），填写自己的 Team ID 和 Bundle Identifier，再选择 iPhone 运行。本地签名文件不会上传。

核心检查：`bash scripts/check-core.sh`。

## 参考与说明

本项目用于个人研究和非商业体验，不是官方应用，与原作者及工作室无关联。参考效果不代表使用原作源码，也不声称完整复现官方动画；绘制、编舞与界面代码由本项目自行实现。

数字构形也参考了 [Manuel Wieser 的公开示例](https://codepen.io/Lorti/pen/XpQewQ)。相关第三方作品与品牌权利归各自权利人所有，个人研究用途不代表已取得授权。
