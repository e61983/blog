---
date: 2025-08-26T23:54:11+08:00
title: "OTP — 一次性密碼的原理與實作"
description: "深入了解 OTP（一次性密碼）的運作原理，包含 TOTP 與 HOTP 的差異，以及在 Go 中的實作範例。從序列圖到程式碼，完整解析二階段驗證的核心機制。"
author: "Yuan"
draft: false
tags: ["go", "otp", "totp", "hotp", "security", "authentication", "2fa", "backend"]
keywords: []
categories: ["security", "note"]
---

## 前言

有時候我們登入服務時，螢幕會跳出一句：「你的驗證碼是 123456」。這串數字只能用一次，過了幾十秒就失效了。這種機制叫做 **OTP（One-Time Password，一次性密碼）**。

它看似簡單，卻是今天大多數二階段驗證（2FA）或多因子驗證（MFA）的基石。這篇文章，就來聊聊 OTP 的運作方式，最後會給一個 Go 的範例程式，讓你自己動手試試。

<!--more-->

## OTP 是什麼？

顧名思義，OTP 就是 **只能使用一次的密碼**。

它的目的很單純：防止密碼被竊取後還能重複使用。即便攻擊者截獲了一組 OTP，它在下一次登入時也已經過期，等於沒用了。

這樣的設計，有效降低了「重放攻擊」的風險。

## OTP 的生成方式

常見的 OTP 有兩種：

1. **HOTP (HMAC-based One-Time Password)**

   * 基於計數器，每次請求遞增一次。
   * 適合事件觸發的情境（例如交易次數）。
2. **TOTP (Time-based One-Time Password)**

   * 基於時間，每隔 30 秒或 60 秒換一組。
   * 更適合登入驗證（Google Authenticator、Authy 常用的就是這種）。

OTP 通常會透過幾種方式傳遞給使用者：

* 硬體 Token（小小的驗證器）
* 手機 App（Google Authenticator、Microsoft Authenticator）
* 簡訊 / Email（雖然方便，但安全性相對較弱）

## OTP 在登入流程中的位置

來看一張序列圖，幫助我們理解 OTP 在認證流程中的角色：

{{< mermaid >}}
sequenceDiagram
    participant User as 使用者
    participant Server as 服務端
    participant OTP as OTP 產生器 (App/簡訊/硬體)

    User->>Server: 輸入帳號密碼
    Server-->>User: 驗證密碼成功，要求輸入 OTP
    User->>OTP: 查看 OTP (App/簡訊/硬體 Token)
    OTP-->>User: 顯示 6 位數 OTP
    User->>Server: 輸入 OTP
    Server->>Server: 驗證 OTP 是否正確 (TOTP/HOTP)
    Server-->>User: 登入成功
{{< /mermaid >}}

👉 可以看到 OTP 並不是單獨存在，而是作為 **密碼驗證之後的第二步**。

## OTP 的好處

* **安全性更強**：一次性使用，舊密碼完全無效。
* **降低密碼重用風險**：即使其他服務外洩，也影響不到這裡。
* **很適合搭配 2FA / MFA**：形成額外保護層。

## OTP 的限制

* **仍可能被釣魚**：如果使用者把 OTP 輸入到假的網站，攻擊者還是能即時盜用。
* **簡訊 OTP 風險高**：可能遭遇攔截或 SIM 卡攻擊。
* **設備同步問題**：時間或 counter 不一致時，會出現驗證失敗。

## Go 程式實作

下面給兩個小範例，一個是 **TOTP**，一個是 **HOTP**。

### 範例一：TOTP（時間制 OTP）

```go
package main

import (
	"fmt"
	"log"
	"time"

	"github.com/pquerna/otp"
	"github.com/pquerna/otp/totp"
)

func main() {
	// 建立一組新的 TOTP key
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "ExampleCorp",
		AccountName: "alice@example.com",
		Period:      30,
		Digits:      otp.DigitsSix,
		Algorithm:   otp.AlgorithmSHA1,
	})
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Secret:", key.Secret())
	fmt.Println("Provisioning URI:", key.URL())

	// 產生當下的 OTP
	code, _ := totp.GenerateCode(key.Secret(), time.Now())
	fmt.Println("Current OTP:", code)

	// 驗證使用者輸入
	ok := totp.Validate(code, key.Secret())
	fmt.Println("驗證結果:", ok)
}
```

👉 `key.URL()` 可以直接用來產生 QR code，讓 Google Authenticator 掃描。

### 範例二：HOTP（計數制 OTP）

```go
package main

import (
	"fmt"
	"log"

	"github.com/pquerna/otp/hotp"
)

func main() {
	secret := "JBSWY3DPEHPK3PXP"
	counter := uint64(1)

	// 產生 OTP
	code, err := hotp.GenerateCode(secret, counter)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("HOTP:", code)

	// 驗證
	ok := hotp.Validate(code, secret, counter)
	fmt.Println("驗證結果:", ok)
}
```

👉 實際應用中，伺服器需要保存並更新 `counter`。

## 小結

OTP 的定位很清楚：

* 它不是取代密碼，而是 **強化認證流程** 的一環。
* TOTP 與 HOTP 各有應用場景，但 TOTP 在日常帳號登入上更常見。
* 雖然 OTP 提升了安全性，但仍要注意釣魚與簡訊風險。

對開發者來說，Go 已經有現成套件（`pquerna/otp`），幾行程式就能完成 OTP 的產生與驗證。