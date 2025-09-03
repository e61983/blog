---
title: "從 glibc 到 musl : 靜態編譯上的新選擇"
date: 2025-09-03T22:48:04+08:00
draft: false
tags: ["go","cgo","gcc","backend","musl"]
keywords: []
categories: ["note"]
---


## 前言

在 Go 世界裡，**可移植性** 一直是它引以為傲的特性。大部分時候，我們只要 `go build` 就能得到一個幾乎純靜態的二進位，拿去其他機器執行也不太會出問題。然而，這種「幾乎」背後，跟 `cgo` 和 `cmd/link` 的運作有很大關係。本文將以 **cgo 為核心**，延伸到 **linkmode** 與 **musl-gcc** 的應用，帶同學們理解 Go 執行檔在靜態與動態鏈結上的差異。

<!--more-->

## 靜態常態與 cgo 的例外

Go 預設的編譯模式會產生接近「全靜態」的執行檔，因為 runtime 和標準函式庫大多都是純 Go 實作，不需要依賴外部 libc。這就是為什麼 Go 程式的部署體驗往往很輕鬆。

但一旦涉及 **cgo**（例如 `net`、`os/user`、`crypto/x509` 這些套件），情況就不同了：  
- Go 會透過 cgo 呼叫系統 C 函式庫  
- 執行檔因此產生外部依賴（glibc、pthread、甚至 macOS 的 CoreFoundation）

也就是說，cgo 會讓原本純靜態的世界，重新回到傳統 C 程式必須考慮的「靜態 vs 動態」命題。

## CGO_ENABLED 的切換

要控制 cgo 的開關十分的簡單：  
```bash
# 禁用 cgo
CGO_ENABLED=0 go build -o app_nocgo main.go
```

這樣 Go 會重新編譯所有套件，產生真正純靜態的執行檔（不依賴 libc）。
但如果保留 `CGO_ENABLED=1`（預設），那麼只要用到需要 cgo 的標準庫，執行檔就可能依賴系統動態函式庫。

## Linker 的 linkmode 模式

Go 的 Linker (`cmd/link`) 支援兩種模式：

* **internal linking**（預設）
  Go 自行把目標檔案與靜態庫打包。這是最常見的模式，速度快，但在有 cgo 的情境下，仍會遺留動態依賴。

* **external linking**
  Go 把產生的 .o 檔交給外部 Linker（例如 gcc、clang）。
  這時可以加上：

  ```bash
  go build -ldflags='-linkmode external -extldflags "-static"'
  ```

  嘗試產生完全靜態的執行檔。
  
  {{<notice info "檢查方式">}}
  ```sh
  ldd a.out
  
  # output:
  #	not a dynamic executable
  
  # If it's dynamically linked, you'll see output like this:
  # linux-vdso.so.1 (0x00007f9f674ef000)
  # libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f9f672ef000)
  # /lib64/ld-linux-x86-64.so.2 (0x00007f9f674f1000)
  ```
  {{</notice>}}

在 Linux，如果系統有提供靜態版本的 libc（例如 `/usr/lib/x86_64-linux-gnu/libc.a`），通常可行。
但在 macOS，因為沒有靜態版的 libc，幾乎無法成功。

## glibc 的困境與 musl-gcc 的解法

Linux 上的 glibc 在靜態鏈結時有一個著名的痛點：

* 部分功能（特別是 `libnss` 名稱服務）依賴動態載入 (`dlopen`)，即使你強制 `-static`，最終執行檔仍可能在查詢 DNS 或讀取 `/etc/passwd` 時出錯。

解法之一就是使用 **musl**。
`musl` 是另一套輕量的 C 標準庫，專為靜態編譯與可攜性設計。
在 Alpine Linux 裡，Go 預設就會用 musl 來取代 glibc，這也是為什麼 Alpine 的容器裡，Go 執行檔能夠「真正純靜態」。

在其他 Linux 發行版，你可以安裝 `musl-tools`，然後這樣編譯：

```bash
CC=musl-gcc CGO_ENABLED=1 go build -ldflags='-linkmode external -extldflags "-static"' -o app_musl main.go
```

這樣產生的執行檔：

* 完全靜態
* 無需依賴 glibc
* 更容易在不同 Linux 發行版間運行

缺點是：

* 部分效能可能與 glibc 略有差異
* 某些 glibc 特定 API 在 musl 下不可用


## 使用 `netgo` 與 `osusergo` Tag 來避免不必要的 cgo 依賴

除了透過 `musl-gcc` 來徹底靜態化之外，Go 其實也提供了 **純 Go 實作** 來取代部分預設的 cgo 套件。這就是 `netgo` 與 `osusergo`。

- **`netgo`**  
  Go 的 `net` 套件在解析 DNS 時，預設會透過 cgo 呼叫系統的 `glibc`。  
  這代表執行檔會動態依賴 libc。  
  如果加上：  

  ```bash
  go build -tags netgo
  ```

就會強制使用 Go 自帶的純 Go DNS 解析器（`net/dnsclient`），避免依賴 libc。
代價是：功能上略有限制（例如 `/etc/nsswitch.conf` 支援度較低）。

* **`osusergo`**
  `os/user` 套件預設會使用 cgo 查詢 `/etc/passwd`、`/etc/group` 等系統資訊。
  這同樣導致 libc 依賴。
  加上：

  ```bash
  go build -tags osusergo
  ```

  就能切換到 Go 自帶的純 Go 實作，避免動態鏈結。

實務上，若想確保二進位完全不依賴 libc，可以同時加上這些標籤：

```bash
CGO_ENABLED=0 go build -tags "netgo osusergo" -o app_static main.go
```

這樣能得到：

* 完全純靜態的執行檔
* 不需要 musl 或 glibc
* 可攜性最佳

但需要注意：

* `netgo` 的 DNS 解析能力較弱，可能不支援某些複雜的名稱解析配置
* `osusergo` 只能查詢環境變數，不會讀取 `/etc/passwd` 或 LDAP

因此是否要使用，取決於應用場景。

## 靜態與動態的權衡

| 情境                       | 編譯方式                                                                                     | 結果                |
| ------------------------ | ---------------------------------------------------------------------------------------- | ----------------- |
| 純 Go 程式                  | `CGO_ENABLED=0 go build`                                                                 | 完全靜態              |
| 使用 net/os.user，但想避開 libc | `CGO_ENABLED=0 go build -tags "netgo osusergo"`                                          | 純 Go 靜態，無 libc 依賴 |
| 使用 cgo，允許動態依賴            | `go build`                                                                               | 預設，依賴 libc        |
| 使用 cgo，想嘗試 glibc 靜態      | `go build -ldflags '-linkmode external -extldflags "-static"'`                           | 不保證成功（glibc 限制）   |
| 使用 cgo，確保靜態              | `CC=musl-gcc CGO_ENABLED=1 go build -ldflags '-linkmode external -extldflags "-static"'` | 靜態，依賴 musl        |
| Docker 最小化映像             | Alpine + musl-gcc，多階段構建                                                                  | 適合跨平台部署           |

## 小結

到這裡，我們看到 Go 的靜態編譯其實有幾種不同層次的策略：

1. **純 Go + `netgo` + `osusergo`** → 最純淨的靜態執行檔，無 libc 依賴
2. **glibc external linking** → 嘗試靜態，但可能因 glibc 的設計限制而失敗
3. **musl-gcc** → 藉由 musl，確保完全靜態且具可攜性
4. **動態模式** → 若不介意依賴系統 libc，則可維持預設編譯

換句話說，Go 在「**完全靜態** → **可攜靜態** → **動態依賴**」之間，提供了多種彈性選擇，同學們可以依照需求決定取捨。