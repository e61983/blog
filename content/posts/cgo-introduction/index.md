---
title: "認識 Cgo：Go 與 C 語言的橋樑"
date: 2025-09-02T22:22:33+08:00
draft: false
tags: ["gcc", "go", "cgo"]
keywords: []
categories: ["note"]
---

## 前言

在撰寫 Go 程式的過程中，有時候我們會遇到這樣的情境：某些功能已經有穩定的 C 函式庫可以使用，若能直接呼叫這些現有資源，就能避免重複造輪子。  
Go 語言本身提供了 `cgo` 這個工具，讓我們能順利地在 Go 程式中嵌入並呼叫 C 程式碼。

本文會帶你從基礎開始認識 `cgo`，並透過範例說明如何在 Go 專案中使用它。

<!--more-->

## cgo 是什麼？

`cgo` 是 Go 語言官方提供的工具，用來讓 Go 程式可以呼叫 C 語言的程式碼或函式庫。只要在 Go 程式碼中使用特殊的 `import "C"` 語法，就能在 Go 與 C 之間進行互操作。

## 基本使用方式

最基本的 `cgo` 程式碼結構如下：

```go
package main

/*
#include <stdio.h>
#include <stdlib.h>
*/
import "C"
import "fmt"

func main() {
    C.puts(C.CString("Hello from C!"))
    fmt.Println("Hello from Go!")
}
```

在這段程式中：

* `/* ... */` 區塊中的程式碼會被視為 C 語言程式碼。
* `import "C"` 表示我們要使用 `cgo`。
* `C.puts` 即呼叫了 C 標準函式庫的 `puts`。

執行結果會依序輸出：

```
Hello from C!
Hello from Go!
```

## C 型別的取用

在使用 `cgo` 時，Go 與 C 型別必須正確對應。常見的幾個範例如下：

```go
var a C.int = 10      // C 的 int 型別
var b C.char = 'A'    // C 的 char 型別
var c C.size_t = 100  // C 的 size_t 型別
```

### Go 與 C 的字串轉換

C 使用 `char*` 表示字串，而 Go 使用 `string`。兩者需要透過轉換：

```go
cs := C.CString("hello")       // Go string -> C string
C.free(unsafe.Pointer(cs))      // 使用完畢後必須釋放記憶體

goStr := C.GoString(cs)         // C string -> Go string
goStrN := C.GoStringN(cs, 5)    // 指定長度的轉換
```

當 Go 傳 Go pointer 給 C 時：
Go 會自動把該區域的記憶體「pin（釘住）」，直到呼叫結束，避免 GC 將內容搬移。  
如果 C 要留存 Go pointer，必須透過 `runtime.Pinner`，或使用 `runtime/cgo.Handle` 進行安全管理。  
另外也有 `GODEBUG=cgocheck=1`（預設）來做動態檢查，若要關閉可以 `GODEBUG=cgocheck=0`，而更嚴格檢查則可開 `GOEXPERIMENT=cgocheck2`。

## Go 與 C 型別對應表

下表列出常見的 Go 與 C 型別對應：

| C 型別                 | Go 對應型別          | 說明       |
| -------------------- | ---------------- | -------- |
| `char`               | `C.char`         | 單一字元     |
| `signed char`        | `C.schar`        | 有號字元     |
| `unsigned char`      | `C.uchar`        | 無號字元     |
| `short`              | `C.short`        | 短整數      |
| `unsigned short`     | `C.ushort`       | 無號短整數    |
| `int`                | `C.int`          | 整數       |
| `unsigned int`       | `C.uint`         | 無號整數     |
| `long`               | `C.long`         | 長整數      |
| `unsigned long`      | `C.ulong`        | 無號長整數    |
| `long long`          | `C.longlong`     | 更長的整數    |
| `unsigned long long` | `C.ulonglong`    | 無號更長的整數  |
| `float`              | `C.float`        | 單精度浮點    |
| `double`             | `C.double`       | 雙精度浮點    |
| `size_t`             | `C.size_t`       | 記憶體大小或索引 |
| `void*`              | `unsafe.Pointer` | 通用指標     |

這張表對於撰寫 Cgo 程式相當實用，可以幫助你快速找到對應的型別。

## 定義編譯器旗標（CFLAGS、LDFLAGS）

在 preamble 中可以用 #cgo 指令指定額外的編譯或連結參數：

```go
// #cgo CFLAGS: -DPNG_DEBUG=1
// #cgo LDFLAGS: -lpng
// #include <png.h>
import "C"
```

若透過 pkg-config 取得設定，也支援這種寫法：

```go
// #cgo pkg-config: png cairo
```

這些旗標會依系統條件進行串接、合併使用，非常方便


## 境變數與安全限制技巧

建議盡量把特定包的 CFLAGS/LDFLAGS 用 #cgo 指令設定，而不要透過環境變數設定，因為後者不會套受 cgo 的安全機制限制：

cgo 對於允許的旗標有嚴格限制（例如 -D, -I, -l 等）；

若需要放寬限制，可以透過環境變數如 CGO_CFLAGS_ALLOW、CGO_CFLAGS_DISALLOW 設定正則表達式
Go Packages
。

## 常見錯誤與除錯技巧

在使用 `cgo` 的過程中，常見的錯誤包括：

1. **找不到標頭檔**

   ```
   #include <foo.h>
   fatal error: foo.h: No such file or directory
   ```

   請確認系統已安裝相關開發套件，例如在 Debian/Ubuntu 中：

   ```bash
   sudo apt-get install libfoo-dev
   ```

2. **記憶體釋放問題**

   * 使用 `C.CString` 產生的字串必須手動 `C.free`，否則會造成 memory leak。

3. **型別不相容**

   * 若將 `C.int` 直接指定給 Go 的 `int`，有時會出現編譯錯誤，建議使用明確轉型：

     ```go
     var g int = int(C.int(10))
     ```

4. **交叉編譯失敗**

   * 由於 `cgo` 依賴 C 編譯器，若要交叉編譯（例如在 Linux 編譯給 Windows），需要安裝對應平台的 cross-compiler。

建議在開發初期就善用 `go build -x` 或 `CGO_ENABLED=0` 測試，這樣能更容易找到問題所在。

## 小結

透過 `cgo`，我們可以將現有的 C 函式庫整合進 Go 專案，兼顧效能與開發效率。本文介紹了基本語法、C 型別取用方式、Go 與 C 型別對應表，以及常見錯誤的解決方式。未來若需要整合 C 函式庫，不妨動手試試，體驗 Go 與 C 的強大組合。