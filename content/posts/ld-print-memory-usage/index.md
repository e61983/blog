---
date: 2018-02-06T23:31:12+08:00
title: "GNU LD print memory usage"
description: ""
author: "Yuan"
draft: false
tags: ["linker"]
keywords: []
categories: ["c language"]

---

## 前言

使 GNU LD 輸出總共使用的記憶體大小與程式大小。

<!--more-->

## 主要內容

Makefile:
```
LDFLAGS += -Wl,--print-memory-usage
```

## 參考連結

- [GNU LD - command options](ftp://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_mono/ld.html#SEC3)
