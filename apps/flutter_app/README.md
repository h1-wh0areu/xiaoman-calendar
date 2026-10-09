# Flutter 客户端（小满）

覆盖 iOS / Android / macOS / Windows（同一代码基座）。

## 首次生成平台工程

本仓库只提交 `lib/` 与 `pubspec.yaml`。安装 Flutter SDK 后在本目录执行：

```bash
flutter create . --project-name xiaoman --platforms=ios,android,macos,windows
flutter pub get
# 先启动仓库根目录 API：pnpm dev:api
flutter run -d macos
```

模拟器访问本机 API 时，按平台修改 `lib/api_client.dart` 的 `baseUrl`（Android 模拟器常用 `http://10.0.2.2:3000/v1`）。
