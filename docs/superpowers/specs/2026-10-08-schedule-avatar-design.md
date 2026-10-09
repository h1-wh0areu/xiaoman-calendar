# 日程分身（小满）系统设计规格

| 项目 | 内容 |
|---|---|
| 产品 | 日程分身（暂定名：小满） |
| 依据 | `docs/日程分身_PRD_V1.4.md` + `docs/原型图/` 八屏 |
| 规格版本 | 2026-10-08 |
| 状态 | 待用户审阅后进入实现计划 |
| 范围决策 | A（八屏跨端 UI）+ B（共享领域引擎）+ C（端到端薄竖切）一并交付 |

---

## 1. 目标与非目标

### 1.1 目标（本阶段可运行完整闭环）

1. **跨端客户端**：Flutter 编译 iOS / Android / macOS / Windows；同一设计系统按 phone / tablet / desktop 自适应。
2. **微信小程序**：Taro 轻端，覆盖查看日程、提醒、签发、家庭认领。
3. **共享引擎**：`packages/core_dart` 实现冲突 / 提醒 / 密度 / 剪贴板 / 晨间报告 / 合并等纯逻辑，可单测。
4. **后端 API**：NestJS 提供鉴权、日程、冲突、签发、家庭、服药、证件元数据、生日方案、同步 Mock、OpLog 协同。
5. **八屏原型全交互**：晨间报告、时间线、会前小抄、冲突仲裁、服药守护、生日方案、证件预警、剪贴板识别。
6. **产品宪法落地**：建议权在 AI、决定权在人；L2 以下对外内容强制签发；低置信冲突不推送；证件原件 / 剪贴板原文不上云。

### 1.2 非目标（Phase-2 接入点，本阶段仅 Provider 接口 + Mock）

- 钉钉 / Outlook / 飞书 / 企业微信 / Google 真实 OAuth 与生产 Webhook
- 运营商级电话外呼线路与通信管理局资质
- 生产级大模型密钥、算法备案与安全评估流程
- 企业团队版计费、场景电商分佣结算
- App Store / 各应用商店正式上架物料与审核包

---

## 2. 技术选型

**选定：Flutter + NestJS + Taro（与 PRD §2.4 / FR-0.5 一致）**

| 层 | 技术 | 理由 |
|---|---|---|
| 手机 / 平板 / PC | Flutter 3.x + Material 3 定制 Theme | 五端统一编译，PC 宽幅与移动纵向同一代码基座 |
| 微信小程序 | Taro 4 + React + TypeScript | PRD 轻端；审核缓冲与裂变入口 |
| API | NestJS + Prisma + PostgreSQL（开发可 SQLite） | 模块清晰，便于同步 / WS / 任务调度 |
| 实时 | WebSocket（`/ws`） | FR-0.1：跨端 5 秒内可见 |
| 本地 | Flutter：SQLite（drift 或 sqflite）+ 安全存储；敏感 L2 本地加密路径 | 离线队列 + 存储方案 C |
| 契约 | `packages/contracts` OpenAPI 3 → TS 类型；Dart 模型与之对齐 | 五端 DTO 一致 |
| AI / 外呼 / 日历同步 | Provider 接口 + Mock 实现 | 可切换真实实现而不改调用方 |

曾评估但未采用：纯 Flutter 全栈（小程序与外呼弱）、React Native（桌面与 PRD 偏差大）。

---

## 3. 仓库结构

```
apps/
  flutter_app/       # iOS · Android · macOS · Windows
  miniprogram/       # Taro 微信小程序
  api/               # NestJS
packages/
  core_dart/         # 日程引擎、冲突、提醒、密度、剪贴板、合并、晨间报告
  contracts/         # OpenAPI + 生成的 TS 类型
  design_tokens/     # 色板 / 域着色 / 字号（Flutter Theme + 小程序 CSS 变量文档）
docs/
  日程分身_PRD_V1.4.md
  原型图/
  superpowers/specs/ # 本文件
```

共享复用目标：业务规则 ≥ 80% 在 `core_dart` + API 领域服务；UI 按端自适应，不造成功能分叉（平台插件层除外）。

---

## 4. 领域模型

| 实体 | 职责 | 关键字段 |
|---|---|---|
| User | 手机号主账号 | phone, trustLevel (L1–L4), personaSliders, storageMode (A/B/C) |
| Event | 统一日程 | title, start/end, domain, source, importance, prepStatus, privacyLevel (L0–L3), aiEligible |
| Conflict | 跨域冲突 | eventAId, eventBId, confidence, stage (T-14/T-3/T-0), options[] |
| ConflictOption | 双方案执行件 | lean, bullets, scripts, needsSignOff |
| Commitment | 承诺项 | who, what, dueAt, status, linkedEventId |
| PersonCard | 人物卡 | name, traits, lastObjection, relationHint |
| Document | 证件档案 | type, expiryAt, holderId, localImageRef（原件不出云） |
| MedReminder | 服药守护 | elderId, drug, schedule, voiceLocalRef, confirmState |
| BirthdayPlan | 生日方案 | personId, scripts, gifts×3, celebratePlan, memoryBasis |
| FamilyGroup | 家庭组 | members (2–10), shareGranularity, claims[] |
| SignOffTicket | 签发台 | content, toneScore, memoryRefs, handwrittenNote, status |
| ReminderRule | 提醒规则 | eventType × importance → offsets；可自适应 |
| OpLog | 协同操作日志 | actorId, op, payload, vectorClock / lamport |

### 日程域着色（与原型一致）

工作蓝 · 家庭橙 · 证件红 · 生日粉 · 学习绿 · 健康紫

### 隐私分级

- **L0** 公开元数据（时间 / 标题）：可云端索引  
- **L1** 详情 / 纪要：云端加密存储（密钥用户侧派生；本阶段可用服务端字段加密模拟）  
- **L2** 证件原件图像 / 录音：仅本地加密，云端仅到期日元数据  
- **L3** 企业域日历：不进 AI 管道，仅时间占位（`aiEligible=false`）

---

## 5. 核心引擎（`packages/core_dart`）

纯 Dart、无 Flutter/IO 依赖，便于单元测试。

| 引擎 | 行为 |
|---|---|
| ConflictEngine | 时间重叠 + 跨域加权；`confidence` 低于阈值则不产出冲突（宁可漏报） |
| ReminderEngine | PRD §3.17 默认提前量表；记录响应用于 30 天内微调；安全级提醒不合批 |
| DensityEngine | 按周统计 → 热力与「建议移出 N 项」文案 |
| ClipboardParser | 本地解析时间 / 地点 / 人物 / 事项；原文不返回持久化结构 |
| MorningBriefBuilder | 当日事件 + 冲突置顶 + prepStatus + 固定收尾语「其余的，我都备好了。」 |
| PrepStatusResolver | 已备稿 / 待签发 / 决策 / 冲突中 |
| MergeEngine | OpLog + lastWriteWins（可配来源优先级）；保留来源角标所需 source 字段 |

### Provider 接口（实现可替换）

```
AiProvider
  generateCheatSheet / generateConflictOptions / generateBirthdayPlan
CallProvider
  outboundMedConfirm
CalendarSyncProvider
  pull / push / listSources
```

本阶段默认 **MockAiProvider**（模板 + 记忆底座字段，对齐原型文案）、**MockCallProvider**、**MockCalendarSyncProvider**。

---

## 6. 信息架构与路由

### 6.1 五 Tab

| Tab | 路由 | 主内容 |
|---|---|---|
| 日程 | `/home` | 晨间值班报告（proto_01） |
| 时间线 | `/timeline` | 1/3/6/12 月（proto_02） |
| 分身 | `/avatar` | 在场统计、信任等级、人格光谱 |
| 家庭 | `/family` | 组群、认领、服药入口（proto_05） |
| 我的 | `/me` | 账号、同步源、存储方案、导出/销毁 |

### 6.2 八屏原型路由

| 原型 | 路由 |
|---|---|
| 01 晨间值班报告 | `/home` |
| 02 关键日程时间线 | `/timeline` |
| 03 会前小抄 | `/events/:id/cheat-sheet` |
| 04 冲突仲裁 | `/conflicts/:id` |
| 05 服药守护 | `/family/med/:id` |
| 06 生日方案卡 | `/life/birthday/:id` |
| 07 证件预警 | `/docs/:id/alert` |
| 08 剪贴板识别 | Overlay；小程序为 `/clipboard-paste` 手动粘贴页 |

### 6.3 辅路由

`/auth` · `/events/:id` · `/events/new` · `/sign-off/:ticketId` · `/commitments` · `/life` · `/sync`

### 6.4 自适应

- Flutter：`LayoutBuilder` 断点 phone / tablet / desktop；桌面 `NavigationRail`，移动底栏  
- PC：宽幅时间线、会前小抄可桌面浮层  
- 小程序：精简卡；复杂配置深链引导 App  
- 银发模式：放大字号 + 一屏一事，五端可切换  

深度链：`xiaoman://…` 与小程序 path 同名对齐。

---

## 7. API 与同步

Base path：`/v1`。鉴权：JWT + refresh；开发态短信验证码固定 `000000`。

| 模块 | 端点摘要 |
|---|---|
| Auth | `POST /auth/sms/send` · `POST /auth/sms/verify` |
| User | `GET/PATCH /me` |
| Events | CRUD `/events` · `POST /events/from-clipboard` |
| Brief | `GET /brief/morning?date=` |
| Conflicts | `GET /conflicts` · `POST /conflicts/:id/choose` |
| Sign-off | `GET /sign-off/:id` · `POST .../approve|reject` |
| Commitments | CRUD `/commitments` |
| Family | 创建 / 邀请 / 加入 / 认领 |
| Med | CRUD + `POST .../confirm` |
| Documents | CRUD（无原件二进制） |
| Birthday | `GET /birthday-plans/:id` |
| Sync | sources + `POST /sync/run`（Mock） |
| Ops | `POST /ops/push` · `GET /ops/since?cursor=` |
| Export | `POST /me/export` · `POST /me/destroy` |

**WebSocket** `/ws`：事件变更、冲突、家庭认领、服药确认。

### 客户端同步

1. 启动：`ops/since` + 今日 / 未来 90 天热点  
2. 本地写：SQLite + OpLog → `ops/push`；失败重试  
3. 合并：MergeEngine；UI 保留来源角标  
4. 存储模式 A/B/C 切换走迁移向导；B/C 时 AI 降级明示  

---

## 8. 错误处理与降级

| 场景 | 策略 |
|---|---|
| 离线 | 本地只读/写队列 + 黄条提示；本地提醒仍可用 |
| AI 超时 | 预置模板兜底 |
| 同步源失败 | 角标置灰；>7 天引导重连 |
| 签发失败 | 不对外发出；草稿可重试 |
| 服药外呼失败 | 子女红色预警 |
| 低置信冲突 | 不推送 |
| 企业域 | 跳过 AI 生成 |

统一错误体：`{ code, message, details? }`。

---

## 9. 测试策略

- **core_dart**：Conflict / Reminder / Density / Clipboard / Merge / MorningBrief 单元测试  
- **API**：auth、events、conflict→sign-off 集成测试  
- **Flutter**：八屏关键 widget / 导航烟测  
- **小程序**：path 验收清单（日程 / 签发 / 家庭认领 / 粘贴建日程）  

---

## 10. 实现分期（编码顺序）

| 阶段 | 交付 | 对应 |
|---|---|---|
| P0 | monorepo 骨架、design tokens、contracts、core_dart + 单测 | B |
| P1 | API：auth、events、brief、conflicts、sign-off、seed 数据 | C |
| P2 | Flutter：五 Tab + 八屏 + 自适应 + 接 API/本地引擎 | A+C |
| P3 | Taro 小程序核心闭环 | A+C |
| P4 | OpLog 同步、家庭/服药/证件/生日/剪贴板打通、导出销毁 | A+B+C |
| P5 | Provider 文档与 Phase-2 真实接入清单 | 扩展 |

---

## 11. 验收标准（本阶段）

1. Flutter 至少在 macOS 或 iOS Simulator / Android Emulator 之一跑通八屏导航与核心交互。  
2. API 本地启动后，登录（验证码 `000000`）→ 拉晨间报告 → 打开冲突双方案 → 签发，全流程成功。  
3. `core_dart` 单测通过；冲突低置信用例不产出推送项。  
4. 小程序开发者工具可打开：今日日程、签发、家庭认领、粘贴建日程。  
5. 种子数据覆盖原型八屏文案场景（项目评审×家长会、护照/驾驶证、妈生日、服药爸等）。  

---

## 12. 规格自检记录

- 无 TBD/TODO 占位；Phase-2 已单列非目标。  
- 架构与 PRD FR-0.5（Flutter+Taro）、隐私 §2.5、宪法 §5.1 一致。  
- 范围绑定 A+B+C 可运行闭环，不含真实 OAuth/外呼/生产 LLM。  
- 「完整系统」在本文中定义为：可演示的端到端产品骨架 + 真实领域引擎 + Mock 外部依赖，而非上线生产全部合规资质。  

---

*本文档经对话确认第 1–4 节后汇总；审阅通过后进入 `writing-plans` 实现计划。*
