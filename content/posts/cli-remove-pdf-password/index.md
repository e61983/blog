---
date: 2021-09-02T10:13:38+08:00
title: "使用 qpdf 來合併 PDF 與移除密碼保護"
description: ""
author: "Yuan"
draft: false
tags: ["cli","pdf"]
keywords: []
categories: ["note"]
---

## 前言

突然有了移除 PDF 密碼保護的需求。在查找相關的資料時，順手記錄下來。

<!--more-->

## 主要內容

### 安裝

筆者是使用 MacBook ，所以本文在測試時會是在 MacOS 下進行。
在 MacOS 中，可以輸入下列指令來安裝 `qpdf`。

```bash
brew install qpdf
```

如果是使用 Ubuntu / Debian 系統，可以使用下列指令進行安裝

```bash
sudo apt install -y qpdf
```

### 合併檔案

在點併檔案的時候，如果沒有輸入頁碼(範圍)的話，會將整份文件進行合併。

```bash
qpdf --empty --pages 1.pdf 2.pdf 3.pdf -- out.pdf
```

我們可以在檔名後面加上指定的頁碼或是範圍

```bash
qpdf --empty --pages doc1.pdf 1-2 doc2.pdf 1 doc1.pdf 3 -- out.pdf
```

### 移除密碼

使用下列指令來移除密碼保護。

```bash
qpdf --decrypt crypt.pdf --password=${PASSWORD} decrypt.pdf
```

#### 組合技

我們可以使用下列的指令以 `doc1.pdf` 第1頁、crypt.pdf、`doc1.pdf` 第2-3頁輸出為 `out.pdf`。

```bash
qpdf --empty --pages  doc1.pdf 1 crypt.pdf --password=${PASSWORD} doc2.pdf  -- out.pdf
```

## 參考連結

- [qpdf/qpdf][offical]
- [Syntax for merging entire PDF files][1]

[1]:https://github.com/qpdf/qpdf/issues/11
[offical]:https://github.com/qpdf/qpdf
