---
date: 2025-08-19T19:00:00+08:00
title: "使用 Gomobile 建立 iOS 函式庫"
description: ""
author: "Yuan"
draft: false
tags: ["go","gomobile","ios","swift","xcframework"]
keywords: []
categories: ["mobile development"]
---

## 前言

心之所至，隨意亂寫。

這篇就是想隨手記下：如果有個簡單的 greeting 功能想拿到 iOS 用，用 Gomobile 該怎麼做。於是乎這篇就誕生啦。

<!--more-->

一直想找個方式，讓 Go 寫的邏輯可以直接在 Swift 裡面用上。最近剛好看到 Gomobile 這個工具，就想試試看。

今天，就以一個非常簡單的 `greeting` 為例，來示範整個流程。

## 主要內容

### 環境需求

以下條件，上你的開發環境該是具備了：

* macOS（畢竟 iOS 編譯得在 mac 上）
* Xcode（一切 iOS 專案與模擬器的主戰工具）
* Go ≥ 1.18
* Git（以防你想版本控制一下）

### 安裝 Gomobile

```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

就是這麼簡單，下一步就可以撰寫 Go 程式碼並 bind 了。

### Go 程式碼：建立一個簡單的 `greeting` package

```go
// greeting/greeting.go
package greeting

import "fmt"

func Hello(name string) string {
    return fmt.Sprintf("Hello, %s!", name)
}

func Welcome(name string) string {
    return fmt.Sprintf("Welcome to Go Mobile, %s!", name)
}
```

這個 package 用的都是 Gomobile 支援的基本型別（string），非常 straightforward。

### 編譯 iOS xcframework

回到 terminal，在專案根目錄執行：

```bash
gomobile bind -target=ios -o ./libs/Greeting.xcframework ./greeting
```

如此一來，你就拿到了 `Greeting.xcframework`，可以往下整合啦。

### Xcode 專案整合流程

1. 用 Xcode 創建一個 Swift 的 iOS app。
2. 在 Xcode project 裡新增一個 `frameworks` group。
3. 把 `Greeting.xcframework` 拖進去，記得選「Copy items if needed」並打勾你的 app target。
4. 確認在 Project 的 `General → Frameworks, Libraries, and Embedded Content` 裡看得到這個 framework。

### 在 Swift 中呼叫 Go 函數

在 `ViewController.swift` 裡這樣寫：

```swift
import UIKit
import Greeting

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let hello = GreetingHello("Alice")
        let welcome = GreetingWelcome("Alice")

        print(hello)   // Hello, Alice!
        print(welcome) // Welcome to Go Mobile, Alice!
    }
}
```

就這樣，用 Swift 呼叫 Go 寫的函數，真的沒什麼難度。

### 測試與小提醒

* 在 Xcode 裡按下 `Cmd+B` 編譯看看，有沒有報錯。
* 執行模擬器，觀察 console 輸出是否符合預期。

常見狀況：

* **No such module**：先確認 `xcframework` 是否確實加入；或試試 Clean Build Folder，再重跑。
* **Runtime 錯誤**：通常是參數型別 mismatch，或傳錯東西給 Go。

### 小結

這樣就完成了一個最基本的流程：用 Gomobile 把 Go 的 greeting 函式帶到 iOS 上。對於想把共用邏輯（像算法、工具函數等）放在 Go，然後在不同平台重用的需求，這流程其實還滿實用的耶。雖然 Gomobile 限制的確存在，但對輕量功能來說，超方便的。