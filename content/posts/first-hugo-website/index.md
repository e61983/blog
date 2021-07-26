---
date: 2021-07-26T15:35:30+08:00
title: "打造自己的Blog"
subtitle: "使用Hugo 靜態網站產生器"
description: ""
author: "Yuan"
draft: false
tags: ["go", "web", "markdown"]
keywords: []
categories: ["website"]
---

## 前言

以前有使用過 hexo 建立Blog，但一直沒有好好的經營。最近又有想要開始寫 Blog 的念頭。
希望這一次，可以持續撰寫下去。

<!--more-->

## 主要內容

由於筆者是使用 MacBook 作為日常使用的工具，所以本文將以 Mac 環境進行筆記。

### 安裝 Hugo

```bash
brew install hugo
```

### 建立網站

```bash
hugo new ${SITE_NAME}
```

### 撰寫文章

```bash
cd ${SITE_NAME}
hugo new posts/my-first-post.md
```

### 設定佈景主題

```bash
git submodule add https://github.com/upagge/uBlogger.git themes/uBlogger
echo 'theme = "uBlogger"' >> config.toml
```

### 修改樣式

建立相關資料夾

```bash
mkdir -p assets/css/
```

加入自訂樣式

```css
code[class*="language-"] {
    color: white;
	text-shadow: none;
}
```

## 小結

這次只有進行簡易的設定，還有許多功能還未探索。目前打算先用一陣子，再看看還有什麼有趣的東西。

## 參考連結

- [uBlogger offical website][uBlogger]
- [第 12 屆 iT 邦幫忙鐵人賽 - Hugo 貼身打造個人部落格 系列][ironman-3613]

[uBlogger]:https://ublogger.netlify.app
[ironman-3613]:https://ithelp.ithome.com.tw/users/20106430/ironman/3613
