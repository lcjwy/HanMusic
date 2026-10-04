# HanMusic

基于 **Flutter + GetX（MVVM）** 的跨平台音乐播放器：本地曲库管理、自定义网络源串流播放、睡眠定时。一次编写，覆盖 Android / iOS / Windows / macOS / Linux / Web 六端。

## 文档

| 文档 | 内容 |
|---|---|
| [doc/01-技术架构要求.md](doc/01-技术架构要求.md) | MVVM 分层、依赖选型与准入规则、目录结构约定、关键技术方案 |
| [doc/02-需求文档.md](doc/02-需求文档.md) | 项目背景、平台范围、功能需求总览（F1–F10）、版本规划与风险 |
| [doc/03-功能说明文档.md](doc/03-功能说明文档.md) | 各功能模块的交互流程、边界规则、异常处理与验收清单 |

## 功能（MVP v0.1）

- **F1 本地音乐库**：文件/文件夹导入，读取标签与内嵌封面（文件名兜底），搜索、排序、多选管理
- **F2 网络音乐源**：配置自己的音乐 API（接口路径 + 字段映射），在线搜索与串流播放
- **F3 播放器核心**：四种播放模式、队列管理、后台播放与通知栏/锁屏控制、上次播放恢复
- **F4 睡眠定时**：预设/自定义倒计时、"播完当前歌曲后停止"、顺延
- **F8 多端适配**：桌面端 media_kit 播放后端，移动端后台音频，平台差异收敛在适配层

## 技术栈

Flutter (stable) · GetX（状态/路由/依赖注入）· just_audio + just_audio_background · audio_session · file_picker · get_storage · http · audio_metadata_reader · just_audio_media_kit

依赖引入遵循极简与准入规则，见[架构文档选型表](doc/01-技术架构要求.md)。

## 开发

```bash
flutter pub get
flutter analyze   # 零警告
flutter test      # 单元测试
flutter run       # 按所选设备运行
```

Windows 桌面端构建需系统开启开发者模式（插件 symlink 依赖）：`设置 → 系统 → 开发者选项`。

## 发布构建（Android）

签名信息在 `android/key.properties`，密钥库为 `android/app/han_music.jks`（别名 `music110`），`release` 构建自动使用：

```bash
flutter build apk --release   # 产物：build/app/outputs/flutter-apk/app-release.apk
```

> 密钥库与口令按项目约定随仓库提交；若仓库转为公开或多人协作，应将两者移出版本管理并妥善保管（丢失无法再发布同签名更新）。

## 分支

- `main`：文档与基线
- `dev`：日常开发主线（MVP 实现）
- `dev_mx` / `dev_cj`：并行开发分支（dev_cj 含 Android release 签名配置）
