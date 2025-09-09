---
date: 2025-09-09T21:27:28+08:00
title: "去找吧！我把所有資料都藏在那了 - 通向 Section 航道的旅程"
description: ""
author: "Yuan"
draft: false
tags: ["go","cgo","elf"]
keywords: []
categories: ["note"]
---

## 前言

「我要成為海賊王！」  
這句話大家應該不陌生吧。寫程式有時候就像在 **偉大航道上尋寶**。  
這次的寶藏不是什麼「One Piece」，而是──**把設定檔藏在 ELF Binary 裡的秘密空間**。  

最近剛好遇到一個需求：想把資料包進程式裡，方便部署，但又不想讓人隨便亂改。  
就像在跟同學們玩「海上捉迷藏」一樣，所以筆者決定把設定藏進一個 **神秘的 section**，然後用小工具去 patch。

於是乎本篇就誕生了。
<!--more-->

## 核心概念

在 ELF（Linux）或 PE（Windows） binary 世界裡，有很多「島嶼」──每個 section 就是一個島。  
我們要找的就是那個能保存寶藏的島，例如 `.rodata` 或自訂的 `.mydata`。  

這些島有兩個特色：  
- 不能執行（safe！不怕炸掉程式）；  
- 但可以讀出內容。  

於是我們的計畫就像「把寶藏藏在島上」一樣：

1. 在編譯時留下一個固定大小的空間（像是預留寶箱的大小）；  
2. 寫一個小 patch 工具，就能在航行途中把新的寶物塞進去（但記住──大小不能超過原本的寶箱）。  

### 建立自訂 Section

首先，我們要在 C 世界裡留一個「寶箱」。  

```go
/*
const char mydata[1024] __attribute__((section(".mydata"), used)) = {0};
*/

import "C"
````

這裡透過 `__attribute__((section(".mydata")))` 指定了寶藏島的座標，大小固定 1024 bytes。
之後 Go 就能透過 CGO 拿到這個位置。

### 在 Go 世界開啟寶藏

我們要有個船員（函式），能幫忙把藏在島上的寶物讀出來：

```go
// ===== app/main.go =====
package main

/*
const char mydata[1024] __attribute__((section(".mydata"), used)) = {0};
*/
import "C"

import (
  "fmt"
  "unsafe"
)

func read() []byte {
  return C.GoBytes(unsafe.Pointer(&C.mydata[0]), 1024)
}

func main() {
  fmt.Println("mydata:", string(read()))
}
```

* `C.mydata` 是陣列，要用 `&C.mydata[0]` 才能拿到指標；
* `unsafe` 需要引入。

### Patch 工具：羅盤與鑰匙

接著我們需要一個「航海士」──工具程式，能找到 `.mydata` 的位置並塞進新的資料。

```go
// ===== tools/patcher.go =====
package main

import (
  "debug/elf"
  "flag"
  "io"
  "os"
)

func main() {
  binPath := flag.String("bin", "", "path to target binary")
  newCfg := flag.String("config", "", "path to new config file")
  flag.Parse()

  // 打開寶藏地圖（binary）
  f, err := os.OpenFile(*binPath, os.O_RDWR, 0)
  if err != nil {
    panic(err)
  }
  defer f.Close()

  ef, err := elf.NewFile(f)
  if err != nil {
    panic(err)
  }

  cfg, err := os.ReadFile(*newCfg)
  if err != nil {
    panic(err)
  }

  for _, sec := range ef.Sections {
    if sec.Name == ".mydata" {
      if uint64(len(cfg)) > sec.Size {
        panic("new config too big for treasure chest")
      }
      // 移動到正確位置
      f.Seek(int64(sec.Offset), io.SeekStart)
      // 蓋掉舊的寶藏
      f.Write(cfg)
      break
    }
  }
}
```

* `sec.Data()` 只是回傳內容，不能直接 patch；
* 必須用 `f.Seek(sec.Offset)` 定位，再 `f.Write()` 蓋掉；
* 記得檢查長度，避免寶藏放不下。

## 執行流程

```bash
go build -o myapp ./app
go build -o patcher ./tools/patcher.go

# 放新寶藏
./patcher -bin=myapp -config=new_config.json

# 驗證
./myapp
```

## 小提醒

* **Segmentation Fault**：如果 build 出來不是 ELF（例如 macOS 預設是 Mach-O），`debug/elf` 就會爆炸。要加上：

  ```bash
  GOOS=linux GOARCH=amd64 go build -o myapp ./app
  ```
* **長度限制**：寶藏箱（section）大小固定，超過就會炸。
* **Alignment**：要對齊，否則可能會在別的島上亂挖洞。
* **Windows**：PE + code signing 可能會失效，要額外注意。

## 小結

這趟航海之旅，我們學到怎麼把設定藏在 Binary 的 section 裡，就像 Roger 在偉大航道終點留下了寶藏一樣。

這種方式讓程式既能單檔部署，又能後續動態調整設定。
但就像航海王世界的規則一樣，出航一定有風險在。
同學們在實作、使用的同時也要小心才不會不小心就踩到「陷阱」。