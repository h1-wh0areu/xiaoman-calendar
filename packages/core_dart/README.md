# core_dart

Dart 镜像包占位：与 `@xiaoman/core`（TypeScript）规则对齐，供 Flutter 端侧离线引擎复用。

当前 Flutter App 通过 HTTP 调用 `apps/api`（API 内已引用 TS 引擎）。待本机 Flutter SDK 可用后，可将冲突检测 / 剪贴板解析等算法迁入此包（`flutter create --template=package`）。

规则源：`packages/core/src/`
