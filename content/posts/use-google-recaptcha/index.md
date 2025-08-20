---
date: 2025-08-20T23:22:42+08:00
title: "使用 Go 串接 Google reCAPTCHA Enterprise"
description: ""
author: "Yuan"
draft: false
tags: ["go","google","recaptcha","security","web backend"]
keywords: []
categories: ["website"]
---

## 前言

在網站應用中，表單或登入功能常常成為機器人攻擊的目標。
Google reCAPTCHA Enterprise 提供了更安全且彈性的防護方式，能透過 **風險評分 (Score)** 來判斷使用者行為是否可信。

<!--more-->

本篇會示範如何從零開始設定並串接 reCAPTCHA Enterprise，包含 **GCP 設定、前端整合、後端驗證**。

## 主要內容

### 前置準備

#### 建立 reCAPTCHA Key

1. 進入 [Google Cloud Console](https://console.cloud.google.com/)
2. 啟用 **reCAPTCHA Enterprise API**
3. 建立 **Site Key**，需要設定：

   * 網域（允許的前端來源）
   * 驗證模式（建議使用 **Score-based**）
4. 記下以下資訊：

   * **Site Key**（前端需要）
   * **Project ID**（後端呼叫 API 使用）
5. 建立 Service Account

   * 前往 IAM & Admin → Service Accounts
   * 建立新帳號，角色選擇 reCAPTCHA Enterprise Admin 或 Editor
   * 建立完成後，下載 JSON 憑證檔，命名為 service-account.json

### 前端：取得 Token

在網頁上載入 `enterprise.js`，呼叫 `execute()` 取得 token。

```html
<script src="https://www.google.com/recaptcha/enterprise.js?render=your_site_key"></script>
<script>
  function onSubmit(e) {
    e.preventDefault();

    grecaptcha.enterprise.ready(async () => {
      const token = await grecaptcha.enterprise.execute('your_site_key', { action: 'login' });

      // 傳送 token 到後端
      const resp = await fetch('/verify-recaptcha', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token })
      });

      const result = await resp.json();
      if (result.success && result.score >= 0.5) {
        alert("驗證通過，可以登入");
      } else {
        alert("驗證失敗，請再試一次");
      }
    });
  }
</script>

<form onsubmit="onSubmit(event)">
  <input type="text" name="username" placeholder="帳號">
  <input type="password" name="password" placeholder="密碼">
  <button type="submit">登入</button>
</form>
```

這裡 `action: 'login'` 是自訂的標籤，方便後端追蹤不同的驗證情境。

### 後端：驗證 Token (Go 範例)

使用官方 Go SDK `cloud.google.com/go/recaptchaenterprise/v2`，建立 **Assessment** 驗證 token。

```go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"

    recaptcha "cloud.google.com/go/recaptchaenterprise/v2/apiv1"
    recaptchapb "cloud.google.com/go/recaptchaenterprise/v2/apiv1/recaptchaenterprisepb"
    "google.golang.org/api/option"
)

type VerifyRequest struct {
    Token string `json:"token"`
}
type VerifyResponse struct {
    Success bool    `json:"success"`
    Score   float32 `json:"score"`
}

func verifyRecaptchaHandler(w http.ResponseWriter, r *http.Request) {
    var req VerifyRequest
    _ = json.NewDecoder(r.Body).Decode(&req)

    ctx := context.Background()
    client, _ := recaptcha.NewClient(ctx, option.WithCredentialsFile("service-account.json"))
    defer client.Close()

    projectID := os.Getenv("GOOGLE_CLOUD_PROJECT")

    assessment, err := client.CreateAssessment(ctx, &recaptchapb.CreateAssessmentRequest{
        Parent: fmt.Sprintf("projects/%s", projectID),
        Assessment: &recaptchapb.Assessment{
            Event: &recaptchapb.Event{
                Token:   req.Token,
                SiteKey: "your_site_key",
            },
        },
    })
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    resp := VerifyResponse{
        Success: assessment.TokenProperties.Valid,
        Score:   assessment.RiskAnalysis.Score,
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(resp)
}

func main() {
    http.HandleFunc("/verify-recaptcha", verifyRecaptchaHandler)
    log.Println("Server started on :8080")
    http.ListenAndServe(":8080", nil)
}
```

需要準備：

* **Service Account JSON** 憑證 (`service-account.json`)
* 環境變數 `GOOGLE_CLOUD_PROJECT` 設定為 GCP 專案 ID

### 驗證邏輯

* `Success = true` → token 有效
* `Score` 越高越可能是真人
* 建議策略：

  * 登入、金流相關操作：`score >= 0.5`
  * 一般留言或表單：可適度放寬
  * `score < 0.3` 時可要求額外驗證（例如簡訊或 Email 驗證）

## 小結

完整流程如下：

1. 建立 reCAPTCHA Key
2. 前端呼叫 `grecaptcha.enterprise.execute()` 拿到 token
3. 後端透過 `CreateAssessment` 驗證 token
4. 根據 `Valid` 與 `Score` 判斷是否放行

這樣就完成了 reCAPTCHA Enterprise 的基本串接，可以有效防護網站免受機器人攻擊。

## 參考連結

- [Google reCAPTCHA Enterprise][1]
- [Go Client Library for reCAPTCHA Enterprise][2]

[1]:https://cloud.google.com/recaptcha-enterprise
[2]:https://pkg.go.dev/cloud.google.com/go/recaptchaenterprise