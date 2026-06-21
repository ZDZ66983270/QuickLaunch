<img width="1511" height="886" alt="image" src="https://github.com/user-attachments/assets/828991e3-b1b2-4feb-89c5-039883cbf18f" /># QuickLaunch

Miss the classic Launchpad on newer Macs? QuickLaunch brings that familiar fullscreen app launcher back, with drag-and-drop folders, fast search, and a desktop-native feel.  
如果你在新版 Mac 上怀念以前那个一键铺满全屏的启动台，QuickLaunch 就是把这种熟悉体验带回来的替代方案，还补上了拖拽分组、快速搜索和更贴近桌面的使用感。

Built for users who want the old Launchpad workflow instead of hunting apps through Finder, Spotlight, or the Dock.  
它特别适合那些不想只靠 Finder、Spotlight 或 Dock 找应用，而是更习惯旧版启动台工作流的用户。

It supports app search, paging, drag-and-drop sorting, and folder creation.  
它支持应用搜索、分页浏览、拖拽排序，以及文件夹创建与整理。

## Why QuickLaunch | 为什么是 QuickLaunch

- Bring back the old-school Launchpad feeling on modern macOS  
  在现代 macOS 上找回旧版启动台的感觉
- Open all your apps in one clean fullscreen-style launcher  
  用一个整洁的大屏启动器查看和打开所有应用
- Organize icons the way long-time Mac users expect  
  按老 Mac 用户熟悉的方式整理图标与文件夹
- Great for users migrating to newer Macs and missing the old workflow  
  很适合升级到新版 Mac 后，仍怀念旧工作流的用户

## Highlights | 功能特点

- Fast app discovery and launch  
  快速扫描并启动本机应用
- Search and filter in real time  
  实时搜索和筛选应用
- Launchpad-style paged grid  
  启动台风格的分页网格布局
- Drag to reorder and group apps into folders  
  支持拖拽排序并拖入生成文件夹
- Wallpaper-synced background experience  
  背景支持与系统壁纸同步

## Project Contents | 仓库内容
<img width="1511" height="886" alt="image" src="https://github.com/user-attachments/assets/f64f97b9-f41f-4643-80a0-4e74827256df" />

This repository is prepared for source-code sharing and DMG distribution.  
这个仓库已经整理为“源码 + DMG 安装包”同时可上传的形式。

Included files:

- Source code | 源码
- `dist/QuickLaunch-portable.dmg`
- Packaging scripts | 打包脚本

## Build | 构建

```bash
make build
make app
make dist
make dmg
```

Generated output:

```text
dist/
├── QuickLaunch-portable.dmg
├── QuickLaunch-portable.zip
└── README_Distribution_Guide.txt
```

## Run | 运行

```bash
make run
```

or open the packaged app:

```bash
open build/QuickLaunch.app
```

## Repository Structure | 目录结构

```text
QuickLaunch/
├── QuickLaunchApp.swift
├── Models/
├── Services/
├── ViewModels/
├── Views/
├── Resources/
├── dist/
├── docs/
├── AppStore/
├── CodeSigning/
└── Legal/
```

## Attribution | 署名说明

This codebase is based on work by David Jia and has been optimized by Codex.  
本代码基于 David Jia 的作品，并由 Codex 进行优化整理。

## Usage Terms | 使用条款

Free for personal use only. Commercial use is not allowed.  
仅限个人免费使用，不可用于商业用途。

## Distribution Notes | 分发说明

Download the latest DMG from the Releases page when available.  
如果已发布 Release，建议优先从 Releases 页面下载最新 DMG。

If macOS blocks the app on first launch:

1. Right-click `QuickLaunch.app`
2. Choose `Open`
3. Confirm again in the system dialog

如果 macOS 首次拦截应用：

1. 右键 `QuickLaunch.app`
2. 选择“打开”
3. 在系统弹窗中再次确认“打开”
