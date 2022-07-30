---
date: 2022-06-22T11:26:48+08:00
title: "如何解決在 MacOS VS Code 按鍵無法連續輸入的問題"
description: ""
author: "Yuan"
draft: false
tags: ["VSCode","MacOS"]
keywords: []
categories: ["note"]
---

## 前言

筆者已經習慣 vim 的輸入模式。所以在使用 VS Code 時，會安裝 vim 輸入模式的外掛。在鍵盤按鍵接住時，VS Code 卻不會連續輸入。本文主要就是要來解決這個問題。

<!--more-->

## 主要內容

### 解決方式

```bash
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
```
{{<notice info>}}
如果要復原的話，則只要改成 `true` 就可以了。
`
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool true
`
{{</notice>}}

## 參考連結

- [macOS 长按连续输入的简单设置方法][1]

[1]:https://zihengcat.github.io/2018/08/02/simple-ways-to-set-macos-consecutive-input/