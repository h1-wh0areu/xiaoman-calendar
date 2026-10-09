# 日程分身 Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox syntax.

**Goal:** 按规格交付可运行的 A+B+C 闭环：Flutter 多端 + NestJS API + Taro 小程序 + 共享引擎。

**Architecture:** Monorepo；领域规则在共享包；API 持有持久化与 Mock Provider；Flutter/Taro 消费同一 OpenAPI 契约与设计 Token。

**Tech Stack:** Flutter 3.x · NestJS · Prisma · Taro 4 · TypeScript · pnpm workspace

## Global Constraints

- 手机号主账号；开发验证码 `000000`
- 建议权在 AI，决定权在人；L2 以下强制签发
- 低置信冲突不推送；L2 原件/剪贴板原文不上云
- AI/外呼/日历同步本阶段 Mock Provider

---

## Task checklist

- [x] Plan written
- [x] P0: workspace + design tokens + contracts + core engines + tests
- [x] P1: NestJS API + seed
- [x] P2: Flutter eight screens (源码就绪；本机 Flutter SDK 安装受网络影响，可用 Web 预览)
- [x] P3: Taro miniprogram 核心页
- [x] P4: wire family/med/docs/birthday/clipboard/sync
- [x] P5: README + API/引擎验证通过；Web dev server 可预览
