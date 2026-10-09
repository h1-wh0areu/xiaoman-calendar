# 小满 · 日程分身

跨端「个人数字分身」日历应用（PRD V1.4）。

## 架构

| 部分 | 路径 | 说明 |
|---|---|---|
| 共享引擎 | `packages/core` | 冲突 / 提醒 / 密度 / 剪贴板 / 晨间报告 / 合并 |
| 设计 Token | `packages/design-tokens` | 色板与 CSS 变量 |
| API 契约 | `packages/contracts` | OpenAPI |
| 后端 | `apps/api` | NestJS · 开发验证码 `000000` |
| Flutter 五端 | `apps/flutter_app` | iOS / Android / macOS / Windows |
| Web（PC 预览） | `apps/web` | Vite React，对齐八屏原型 |
| 微信小程序 | `apps/miniprogram` | Taro 轻端 |

设计规格：`docs/superpowers/specs/2026-10-08-schedule-avatar-design.md`

## 一键编译打包

```bash
# 全平台（Node 产物 + Flutter App；无 Flutter SDK 时加 --skip-flutter）
./build_all.sh

# 仅 API / Web / 小程序
./build_all.sh --skip-flutter
# 或
pnpm build:all:web

# 指定端
./build_all.sh --only api,web,flutter
./build_all.sh --android-aab --continue-on-error
```

产物目录：`dist/release/<version>-<timestamp>/`（软链 `dist/release/latest`），含可部署 zip、Android APK 等；详见产物内 `INSTALL.md`。

本机缺工具链时脚本会自动补齐到仓库 `.tools/`（首次较慢）：

- **Flutter**：中国镜像 → `.tools/flutter/`（也可用 `FLUTTER_ROOT` / `FLUTTER_BIN`）
- **JDK / Android SDK**：优先探测 Homebrew（`openjdk@21`、`android-commandlinetools`）；否则自动装到 `.tools/`
- **Gradle**：腾讯云镜像预置到 `.tools/gradle/`；Android 工程默认走阿里云 Maven
- **iOS / macOS**：需本机完整 Xcode（可用 `./scripts/bootstrap_apple_toolchain.sh` 引导；或 `XCODES_USERNAME`/`XCODES_PASSWORD` + `--auto` 下载）
- **Windows**：须在 Windows 主机编译（不可在 macOS 交叉编译）
- **CI 安装包**：推送仓库后运行 GitHub Actions `Build native apps`，再 `./scripts/fetch_ci_native_artifacts.sh`（或 `./build_all.sh --fetch-ci`）

```bash
# 仅 Flutter；缺 Xcode 时写出指引，并可选拉取 CI 产物
./build_all.sh --only flutter --bootstrap-xcode
./build_all.sh --only flutter --fetch-ci

# Apple 工具链
./scripts/bootstrap_apple_toolchain.sh
```

禁用 Android 自动安装：`./build_all.sh --no-android-sdk-bootstrap`

## 快速启动

```bash
# 依赖
pnpm install

# 单测（领域引擎）
pnpm test

# API（http://localhost:3000/v1）
pnpm dev:api

# Web PC/手机预览（另开终端，http://localhost:5173）
pnpm dev:web
```


登录：任意手机号 + 验证码 **`000000`**（Web/小程序/Flutter 会自动用演示号登录）。

### Flutter

需本机已安装 Flutter 3.x：

```bash
cd apps/flutter_app
flutter create . --platforms=ios,android,macos,windows
flutter pub get
flutter run -d macos   # 或 chrome / ios / android
```

API 默认 `http://localhost:3000/v1`（模拟器访问本机请改 `lib/api_client.dart`）。

### 微信小程序

```bash
pnpm dev:mp
```

用微信开发者工具打开 `apps/miniprogram`，并确保 API 已启动；开发设置中关闭域名校验。

## 演示路径（对齐原型）

1. 晨间值班报告 → 点「N 个雷」→ 冲突双方案 → 签发台  
2. 点「项目评审」→ 会前小抄  
3. 时间线 → 证件 / 生日方案  
4. 家庭 → 认领 / 服药确认  
5. 分身 → 剪贴板识别建日程  

## 说明

- 日历同步、电话外呼、AI 文案当前为 **Mock Provider**，接口已留好替换点。  
- 证件原件 / 剪贴板原文不上云（API 不落库原文）。  
- App 功能永久免费（PRD V1.4）。
