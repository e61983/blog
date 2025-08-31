---
title: "在 Go Binary 裡，與可寫 section 共舞？！"
date: 2025-08-31T23:27:28+08:00
draft: true
---

## 前言

最近有同學在問：能不能把設定 embed 進 Go binary 裡，然後「不中斷運行」就能改？  
Go 經典做法是 `//go:embed`，但 embed 起來的配置只能讀不能改。 那…如果我們真的想直接 patch binary 裡的 section，可以怎麼做呢？  
於是乎這篇就出現了。

<!--more-->

## 核心概念

我們這裡講的是 ELF（Linux）或 PE（Windows） binary 裡的 `.rodata` 或自訂 section，屬於不可執行但可以讀出的區段。如果我們把預設設定寫進去，編譯完成後本來是讀不寫的；但只要：

* 在編譯時 **保留固定長度的空間**；
* 準備一個小工具，在 binary 上下 patch 那段 byte（只能覆寫、不能增減長度）；

就能實現「binary global file」的功能──在 deploy 後仍能動態改設定，還不用重 build。

## 實作步驟

### 1. 建立自訂 section 放入設定

在 Go 程式裡，透過 `//go:embed` 或 `ldflags`，把設定放進一個自訂 section（例如 `.configdata`），並且靜默留下一些 padding 確保後續 patch 有空間。

```go
//go:embed default_config.json
var defaultConfig []byte

var configData [1024]byte

func init() {
    copy(configData[:], defaultConfig)
}
```

在 linker 語法裡，也可以指定 section name（例如使用 `-ldflags "-X main.configSection=..."`）。

### 2. Patch 工具讀寫 section

實作一個小工具（用 Go 寫），流程如下：

1. 用 `debug/elf` 或 `debug/pe` 開啟目標 binary。
2. 掃描找出 `.configdata` section 的 offset 與 size。
3. Seek 到該區段裡你要替換的位元組位置。
4. 覆寫新的設定內容（長度不可超過原本空間）。
5. 重新寫回 binary。

這樣一來，你就能在 binary 裡 embed 預設值 + patchable 區塊，即便 binary 不重新 build，deploy 後也能動態改設定。

## 完整範例程式碼

（這邊只擺核心片段示意，完整可再實作調整）

```go
// ===== app/main.go =====
package main

import (
  _ "embed"
  "fmt"
)

//go:embed default_config.json
var defaultConfig []byte

var configData [1024]byte

func init() {
  copy(configData[:], defaultConfig)
}

func main() {
  fmt.Println("config:", string(configData[:]))
}
```

```go
// ===== tools/patcher.go =====
package main

import (
  "bytes"
  "debug/elf"
  "flag"
  "os"
)

func main() {
  binPath := flag.String("bin", "", "path to target binary")
  newCfg := flag.String("config", "", "path to new config file")
  flag.Parse()

  f, _ := os.OpenFile(*binPath, os.O_RDWR, 0)
  defer f.Close()

  ef, _ := elf.NewFile(f)
  for _, sec := range ef.Sections {
    if sec.Name == ".configdata" {
      data, _ := sec.Data()
      offset := bytes.Index(data, []byte("{"))
      if offset >= 0 {
        f.Seek(int64(sec.Offset)+int64(offset), 0)
        newData, _ := os.ReadFile(*newCfg)
        if len(newData) > len(data)-offset {
          panic("new config too large")
        }
        f.Write(newData)
      }
    }
  }
}
```

執行：

```bash
go build -o myapp ./app
go build -o patcher ./tools/patcher.go
./patcher -bin=myapp -config=new_config.json
```

這樣 `myapp` 裡的 `.configdata` 就被 patch 成你提供的新 JSON 了！

{{<notice "warning" "執行 patcher 出現 nil 錯誤">}}
當出現下列錯誤訊息時
```bash
panic: runtime error: invalid memory address or nil pointer dereference 
[signal SIGSEGV: segmentation violation code=0x2 addr=0x28 pc=0x1024cc6b4]
```
可能是編譯出來的執行檔並不是 ELD 格式的。

同學們可以使用 `file` 去確認它。
```
file ./myapp
./myapp: Mach-O 64-bit executable arm64

GOOS=linux GOARCH=amd64 go build -o myapp ./app

file ./myapp
./myapp: ./app/app: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, BuildID[sha1]=1ffa1b26eaac55e65c340df723c0d4178f2cedae, with debug_info, not stripped
```

{{</notice>}}
## 小結

將設定 embed 進 binary，在 runtime 可讀但不可寫，是 Go 預設模樣。
但如果同學們希望 deploy 後還能動態 patch，那可以：

* 在 compile 時 **embed + padding** 放入固定長度空間。
* 用專屬工具 **解析 binary 格式**、找到 section、覆寫內容。

這種方式兼具「部署單檔」與「運行後配置可調」的彈性，但要注意：**不可改長度**、**alignment 要對**，還有 Windows 的 code signing 可能被破壞（Linux 通常沒這問題）。