<div align="center">
  <img src="assets/icon/app_icon.png" alt="HanMusic 图标" width="120"/>
</div>

# HanMusic

> 曲藏本地，声达六端。

**HanMusic** 是一款基于 **Flutter + GetX（MVVM）** 的跨平台音乐播放器：本地曲库管理、自定义网络源串流播放、AI 歌词、睡眠定时。一次编写，覆盖 Android / iOS / Windows / macOS / Linux / Web 六端。

> ⚠️ **使用须知**：本项目不内置任何版权音源，网络音乐源需自行配置（自建 API）；AI 歌词需自备阶跃星辰 / 智谱 / DeepSeek 的 API Key；B站缓存导入仅读取本机已有的离线缓存。所有数据仅存本地，不上传任何用户数据。

## 功能特性

- **本地音乐库（F1）**：文件/文件夹导入，读取标签与内嵌封面（文件名兜底），搜索、排序、多选管理
- **网络音乐源（F2）**：配置自己的音乐 API（接口路径 + 字段映射），在线搜索与串流播放
- **播放器核心（F3）**：四种播放模式、队列管理、后台播放与通知栏/锁屏控制、上次播放恢复
- **睡眠定时（F4）**：预设/自定义倒计时、"播完当前歌曲后停止"、顺延；入口覆盖播放页、设置页与迷你播放条
- **歌单与收藏（F5）**：自建歌单增删改查、拖拽排序、整单/随机播放；内置 10 张渐变封面 + 自定义图片封面；「我喜欢的音乐」收藏歌单，播放页心形收藏、一键加入
- **播放历史（F6）**：实际播放 ≥10s 记录、同曲去重合并、时间倒序，点击回放
- **应用设置（F7）**：主题切换、播放失败自动跳过、数据管理（占用展示与逐项确认清空）、版本与开源许可
- **多端适配（F8）**：桌面端 media_kit 播放后端，移动端后台音频，平台差异收敛在适配层
- **B站缓存导入（F9）**：目录授权扫描本机 B站离线缓存，解析元数据，零转换提取最优音轨入库；缓存被清理后条目灰显不参与播放
- **AI 歌词服务（F10）**：阶跃星辰 / 智谱 / DeepSeek 三家 OpenAI 兼容接口，输入 Key + 选模型即用；歌词获取链路（缓存 → 内嵌 → 网络源 → AI）+ 本地缓存；API Key 仅存系统安全区（Keystore/Keychain/DPAPI），禁止明文落盘
- **歌词与播放动画（F11）**：「专辑旋转动画 / 歌词滚动」一键切换；LRC 自动跟随当前行、点击跳转进度；极光流彩背景、唱片呼吸辉光、渐变进度条

## 支持平台

| 平台 | 状态 | 说明 |
|---|---|---|
| Android | ✅ 已验证 | 后台播放与通知栏/锁屏控制；release 签名构建通过 |
| Windows | ✅ 可构建 | 桌面主要场景，需系统开启开发者模式（插件 symlink 依赖） |
| Web | ✅ 已验证 | 受浏览器限制（自动播放策略、文件访问），允许功能降级 |
| iOS / macOS | 🚧 待验证 | 架构已兼容，需对应系统环境验证 |
| Linux | 🚧 待验证 | 架构已兼容（media_kit 后端） |

## 技术栈

| 类别 | 选型 |
|---|---|
| 框架 | Flutter (stable, Dart ≥ 3.11) |
| 状态 / 路由 / 依赖注入 | GetX |
| 音频播放 | just_audio + just_audio_background |
| 桌面播放后端 | just_audio_media_kit（libmpv） |
| 音频焦点 / 中断处理 | audio_session |
| 文件 / 目录选择 | file_picker |
| 持久化 | get_storage |
| 安全存储（API Key） | flutter_secure_storage |
| 网络请求 | http |
| 元数据解析 | audio_metadata_reader |

依赖引入遵循极简与准入规则，见[架构文档选型表](doc/01-技术架构要求.md)。

## 快速开始

```bash
git clone https://github.com/lcjwy/HanMusic.git
cd HanMusic
flutter pub get
flutter analyze   # 零警告
flutter test      # 单元测试
flutter run       # 按所选设备运行
```

## 发布构建（Android）

复制 `android/key.properties.example` 为 `android/key.properties`，填写本地密钥库路径、别名和口令。这些文件已被 Git 忽略；密钥库应存放在受控位置。CI 可通过 `HAN_MUSIC_STORE_FILE`、`HAN_MUSIC_STORE_PASSWORD`、`HAN_MUSIC_KEY_ALIAS`、`HAN_MUSIC_KEY_PASSWORD` 注入，环境变量优先于本地配置。缺少完整签名配置时，release 构建明确失败，不回退到 debug 签名：

```bash
flutter build apk --release   # 产物：build/app/outputs/flutter-apk/app-release.apk
```

> 旧签名密钥与口令曾随仓库提交，历史记录中的材料仍视为已暴露。维护者应评估签名轮换/应用商店密钥升级流程；本次移出版本管理不撤销历史泄露，也不会自动更换已安装应用的签名身份。原有本地签名文件可继续用于兼容验证，勿再次上传。

## 目录结构

```
lib/
├── main.dart          # 入口：初始化服务、注册路由、运行 App
└── app/
    ├── core/          # 通用基础层：常量、主题、工具、异常、平台适配
    ├── data/          # 数据层：模型、仓库、数据源（含 AI 供应商适配）
    ├── services/      # 全局服务：播放器、定时、歌词、B站导入、安全存储…
    ├── modules/       # 页面模块（一个模块 = 一个 MVVM 单元：view/controller/bindings）
    └── routes/        # GetX 路由表
```

## 文档

| 文档 | 内容 |
|---|---|
| [doc/01-技术架构要求.md](doc/01-技术架构要求.md) | MVVM 分层、依赖选型与准入规则、目录结构约定、关键技术方案 |
| [doc/02-需求文档.md](doc/02-需求文档.md) | 项目背景、平台范围、功能需求总览（F1–F11）、版本规划与风险 |
| [doc/03-功能说明文档.md](doc/03-功能说明文档.md) | 各功能模块的交互流程、边界规则、异常处理与验收清单 |
| [doc/04-需求进度.md](doc/04-需求进度.md) | 功能进度总览、各版本交付明细、构建验证状态与待办 |

## 分支

- `main`：文档与基线
- `dev`：日常开发主线（MVP 实现）
- `dev_mx` / `dev_cj`：并行开发分支（dev_cj 含 Android release 签名配置）
