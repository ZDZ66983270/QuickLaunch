# QuickLaunch

QuickLaunch is a macOS app launcher inspired by the native Launchpad experience.  
QuickLaunch 是一个参考 macOS 原生启动台体验的应用启动器。

It supports app search, paging, drag-and-drop sorting, and folder creation.  
它支持应用搜索、分页浏览、拖拽排序，以及文件夹创建与整理。

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

If macOS blocks the app on first launch:

1. Right-click `QuickLaunch.app`
2. Choose `Open`
3. Confirm again in the system dialog

如果 macOS 首次拦截应用：

1. 右键 `QuickLaunch.app`
2. 选择“打开”
3. 在系统弹窗中再次确认“打开”
