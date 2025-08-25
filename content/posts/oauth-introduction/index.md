---
date: 2025-08-22T20:30:22+08:00
title: "OAuth 與授權流程詳解"
description: ""
author: "Yuan"
draft: false
tags: ["oauth", "authentication", "authorization", "security", "website", "api"]
keywords: []
categories: ["security"]
---

## 前言

在現代應用程式開發中，**使用者身份驗證**與**資源授權**已成為必備功能。
傳統帳號密碼模式存在風險，也不利於跨平台整合，因此 OAuth（Open Authorization）被提出，成為最常見的 **授權框架（authorization framework）**。

它的設計目標是：

* 使用者不需交出帳號密碼
* 第三方應用能安全存取有限的資源
* 支援 Web、Mobile、Server、IoT 等不同場景

<!--more-->

---

## OAuth 是什麼？

OAuth 並不是「驗證（Authentication）」協議，而是 **授權（Authorization）協議**。

它允許使用者：

* 在不直接暴露帳號密碼的情況下
* 授權第三方應用程式
* 存取自己在某個服務（Resource Server）上的資料

👉 簡單說：

> 使用者告訴某平台：「我允許這個應用程式幫我拿資料，但我不會把密碼交給它。」

---

## 核心角色

OAuth 中有四個角色：

1. **Resource Owner** — 使用者本人，擁有資源。
2. **Client** — 想要存取資源的應用程式。
3. **Authorization Server** — 負責驗證身份、頒發 Access Token。
4. **Resource Server** — 保存資料，驗證 Token 後回應請求。

---

## 常見流程：Authorization Code Flow

最典型的 OAuth 流程是 **Authorization Code Flow**：

1. Client 導引用戶至 Authorization Server 登入並授權
2. 驗證成功後回傳 **Authorization Code**
3. Client 以 Code 換取 **Access Token**
4. Client 使用 Token 存取 Resource Server

{{< mermaid >}}
sequenceDiagram
    participant User
    participant Browser
    participant Server as Client (Backend)
    participant Auth as Authorization Server
    participant API as Resource Server

    User->>Browser: 使用 Web App
    Browser->>Auth: 導向登入/授權頁
    Auth->>User: 請求登入
    User->>Auth: 登入並授權
    Auth->>Browser: 回傳 Authorization Code
    Browser->>Server: 傳 Code 給後端
    Server->>Auth: 用 Code 換取 Access Token
    Auth->>Server: 回傳 Access Token
    Server->>API: 存取資源
    API->>Server: 回傳資料
{{< /mermaid >}}

---

## 主要內容

### OAuth Flow 詳解

OAuth 提供多種授權流程（Flow），用於不同情境。

#### Authorization Code Flow

* **適用情境**：Web 應用（有安全後端）。
* **特點**：使用 Authorization Code 換 Token，避免 Token 暴露在瀏覽器中。
* **安全性**：高。

#### Authorization Code Flow with PKCE

* **適用情境**：行動裝置、SPA（無法安全儲存 Client Secret）。
* **特點**：使用 PKCE（Proof Key for Code Exchange）避免 Code 攔截攻擊。
* **安全性**：高，現今最常用。

#### Implicit Flow

* **適用情境**：早期純前端應用（無後端）。
* **特點**：直接回傳 Access Token。
* **安全性**：低，容易洩漏 Token，已不建議使用。

#### Client Credentials Flow

* **適用情境**：Server to Server 通訊（背景任務、API-to-API）。
* **特點**：使用 Client ID + Secret 換 Token，無使用者身份。
* **安全性**：高。

#### Resource Owner Password Credentials (ROPC)

* **適用情境**：老系統整合。
* **特點**：使用者直接把帳號密碼交給 Client。
* **安全性**：低，風險高，不建議使用。

#### Device Authorization Flow

* **適用情境**：IoT、智慧電視、無瀏覽器的裝置。
* **特點**：顯示代碼，使用者用手機/電腦登入完成授權。
* **安全性**：中等，需輪詢授權伺服器。

### Flow 選擇建議

| Flow                      | 適用情境             | 安全性    |
| ------------------------- | ---------------- | ------ |
| Authorization Code        | Web + 後端         | 高      |
| Authorization Code + PKCE | SPA / Mobile     | 高      |
| Implicit                  | 純前端（舊）           | 低（不建議） |
| Client Credentials        | Server to Server | 高      |
| ROPC                      | 老系統整合            | 低（不建議） |
| Device Code               | IoT / TV         | 中等     |

### Access Token 與 Refresh Token

* **Access Token**：短期有效，用於 API 請求。
* **Refresh Token**：長期有效，可換新 Token，避免使用者頻繁登入。

### OAuth 與 OpenID Connect

* **OAuth**：授權，處理「能不能存取資源」。
* **OpenID Connect (OIDC)**：基於 OAuth，解決「使用者是誰」。

👉 如果你需要同時「登入驗證 + 授權存取」，就會採用 **OIDC + OAuth**。

## 小結

OAuth 是現代應用程式中最重要的授權框架，
它的價值在於：

* 使用者不用直接交出帳號密碼
* 第三方應用能安全存取限定資源
* 支援多種場景：Web、Mobile、Server、IoT

在實務中：

* **Web / Mobile → Authorization Code Flow（+PKCE）**
* **Server to Server → Client Credentials Flow**
* **IoT / TV → Device Flow**
* **避免使用 Implicit / ROPC**

這些設計讓 OAuth 成為現代系統安全的核心。

## 參考連結

- [RFC 6749 - The OAuth 2.0 Authorization Framework][1]
- [OAuth 2.0 Security Best Current Practice][2]
- [OpenID Connect Core 1.0][3]
- [PKCE by OAuth Public Clients][4]

[1]: https://tools.ietf.org/html/rfc6749
[2]: https://tools.ietf.org/html/draft-ietf-oauth-security-topics
[3]: https://openid.net/specs/openid-connect-core-1_0.html
[4]: https://tools.ietf.org/html/rfc7636
