---
date: 2025-08-25T23:45:30+08:00
title: "用 Go 打造 Passkey（WebAuthn）最小可行產品：從原理到 MVP 實作"
description: "從零開始用 Go 實作 Passkey/WebAuthn 認證系統，包含完整的註冊與登入流程，讓你快速理解無密碼登入的核心原理與實作細節。"
author: "Yuan"
draft: false
tags: ["go", "webauthn", "passkey", "security", "authentication", "mvp", "website", "backend"]
keywords: []
categories: ["website", "security"]
---

## 前言

「把密碼換成裝置裡的私鑰」——這就是 Passkey 的核心概念。
我們用最小可行的方式，寫一個可以真的註冊與登入的 WebAuthn 小服務。

<!--more-->

## 目標

* 用 **公私鑰**（FIDO2/WebAuthn）取代傳統密碼。
* 實作 **註冊**（建立金鑰對）與 **登入**（challenge 簽章驗證）。
* 後端：**Go**；前端：**HTML + CSS + JavaScript**，純瀏覽器原生 API（`navigator.credentials.create/get`）。
* 用最小依賴打造能跑的 MVP，幫助你理解並能快速 PoC。

---

## Passkey 是什麼？

* **不再記密碼**：使用者只需要用裝置上的生物辨識/PIN 解鎖「私鑰」。
* **伺服器只存公鑰**：挑戰（challenge）由伺服器發出，裝置用私鑰簽章回傳，伺服器用公鑰驗證。
* **抗釣魚**：RP（網站）綁定 + 起源（origin）驗證，降低釣魚風險。

---

## Passkey 工作流程

### 註冊流程（Registration）

用戶首次建立 Passkey 時的流程：

{{< mermaid >}}
sequenceDiagram
    participant User as 使用者
    participant Browser as 瀏覽器
    participant Server as 後端伺服器
    participant Auth as 裝置認證器<br/>(TouchID/FaceID/Windows Hello)

    User->>Browser: 點擊「註冊 Passkey」
    Browser->>Server: POST /api/register/start<br/>{ username }
    Server->>Browser: 回傳 CreationOptions<br/>{ challenge, user, rp }
    Browser->>Auth: navigator.credentials.create()
    Auth->>User: 請求生物辨識驗證
    User->>Auth: 指紋/臉部/PIN 驗證
    Auth->>Auth: 產生公私鑰對
    Auth->>Browser: 回傳 AttestationResponse<br/>{ publicKey, signature }
    Browser->>Server: POST /api/register/finish<br/>{ attestationObject }
    Server->>Server: 驗證 & 儲存公鑰
    Server->>Browser: 註冊成功
{{< /mermaid >}}

### 登入流程（Authentication）

用戶使用已註冊的 Passkey 進行登入：

{{< mermaid >}}
sequenceDiagram
    participant User as 使用者
    participant Browser as 瀏覽器
    participant Server as 後端伺服器
    participant Auth as 裝置認證器

    User->>Browser: 點擊「使用 Passkey 登入」
    Browser->>Server: POST /api/login/start<br/>{ username }
    Server->>Server: 產生隨機 challenge
    Server->>Browser: 回傳 RequestOptions<br/>{ challenge, allowCredentials }
    Browser->>Auth: navigator.credentials.get()
    Auth->>User: 請求生物辨識驗證
    User->>Auth: 指紋/臉部/PIN 驗證
    Auth->>Auth: 用私鑰簽署 challenge
    Auth->>Browser: 回傳 AssertionResponse<br/>{ signature, authenticatorData }
    Browser->>Server: POST /api/login/finish<br/>{ signature, clientData }
    Server->>Server: 用公鑰驗證簽章
    Server->>Browser: 登入成功
{{< /mermaid >}}

---

## 我們要做的 MVP

### 架構與流程

* `/`：靜態頁（含兩個按鈕：註冊、登入）。
* `/api/register/start` → 前端拿到 **PublicKeyCredentialCreationOptions** → 呼叫 `navigator.credentials.create()` →
  把結果送到 `/api/register/finish` 完成註冊。
* `/api/login/start` → 前端拿到 **PublicKeyCredentialRequestOptions** → 呼叫 `navigator.credentials.get()` →
  把結果送到 `/api/login/finish` 完成登入。

**狀態**

* 使用簡單的 in-memory 儲存（使用者與憑證），並用 cookie `sid` 對應一次性的 WebAuthn SessionData。
* Demo 夠用，正式環境請改用資料庫與安全的 session store。

---

## 後端（Go）

> 使用社群穩定的 WebAuthn 套件，快速把 ceremony 跑起來。
> 以下程式以 **`github.com/go-webauthn/webauthn/webauthn`** 為例。

> 需要 Go 1.20+（建議 1.21/1.22）。
> 執行前先：`go mod init passkey-mvp && go get github.com/go-webauthn/webauthn/webauthn github.com/go-webauthn/webauthn/protocol`

**檔案：`main.go`**

```go
package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/go-webauthn/webauthn/protocol"
	"github.com/go-webauthn/webauthn/webauthn"
)

// ===== In-memory 模擬儲存 =====

type User struct {
	ID          uint64
	Name        string
	DisplayName string
	Credentials []webauthn.Credential
}

func (u *User) WebAuthnID() []byte {
	b := make([]byte, 8)
	for i := 0; i < 8; i++ {
		b[i] = byte((u.ID >> (8 * i)) & 0xff)
	}
	return b
}
func (u *User) WebAuthnName() string        { return u.Name }
func (u *User) WebAuthnDisplayName() string { return u.DisplayName }
func (u *User) WebAuthnIcon() string        { return "" }
func (u *User) WebAuthnCredentials() []webauthn.Credential {
	return u.Credentials
}

var (
	usersMu sync.Mutex
	users   = map[string]*User{} // key = username
	nextID  uint64 = 1

	// 每個 session id 對應 WebAuthn 的暫存資料
	sessionMu sync.Mutex
	regSess   = map[string]*webauthn.SessionData{} // registration session
	authSess  = map[string]*webauthn.SessionData{} // authentication session
)

func getOrCreateUser(username string) *User {
	usersMu.Lock()
	defer usersMu.Unlock()
	if u, ok := users[username]; ok {
		return u
	}
	u := &User{
		ID:          nextID,
		Name:        username,
		DisplayName: username,
	}
	nextID++
	users[username] = u
	return u
}

func setCookie(w http.ResponseWriter, name, val string) {
	http.SetCookie(w, &http.Cookie{
		Name:     name,
		Value:    val,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Expires:  time.Now().Add(15 * time.Minute),
	})
}

func getCookie(r *http.Request, name string) string {
	c, err := r.Cookie(name)
	if err != nil {
		return ""
	}
	return c.Value
}

// ===== WebAuthn 物件 =====

var webAuthn *webauthn.WebAuthn

func mustInitWebAuthn() {
	var err error
	webAuthn, err = webauthn.New(&webauthn.Config{
		RPDisplayName: "Passkey MVP",       // RP 顯示名稱
		RPID:          "localhost",         // RP ID（要和網域相符）
		RPOrigins:     []string{"http://localhost:8080"},
	})
	if err != nil {
		log.Fatalf("webauthn init error: %v", err)
	}
}

// ===== Util =====

func randomB64(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

// ===== Handlers =====

type startRegisterReq struct {
	Username string `json:"username"`
}

func handleRegisterStart(w http.ResponseWriter, r *http.Request) {
	// 1) 前端傳 username；在真實系統會有登入或帳號建立流程
	var req startRegisterReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	user := getOrCreateUser(req.Username)

	// 2) BeginRegistration：產生 PublicKeyCredentialCreationOptions + SessionData
	opts, sessionData, err := webAuthn.BeginRegistration(
		user,
		webauthn.WithAuthenticatorSelection(protocol.AuthenticatorSelection{
			RequireResidentKey: protocol.ResidentKeyRequired(),
			UserVerification:   protocol.VerificationPreferred, // UV 建議 Preferred / Required 視需求
		}),
	)
	if err != nil {
		http.Error(w, "begin registration error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 3) 建一個 sid 對應 SessionData，寫入 cookie
	sid := randomB64(16)
	sessionMu.Lock()
	regSess[sid] = sessionData
	sessionMu.Unlock()
	setCookie(w, "sid", sid)

	// 4) 回傳 options 給前端做 navigator.credentials.create()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(opts)
}

func handleRegisterFinish(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")
	if username == "" {
		http.Error(w, "username required", http.StatusBadRequest)
		return
	}
	user := getOrCreateUser(username)

	sid := getCookie(r, "sid")
	if sid == "" {
		http.Error(w, "missing sid", http.StatusUnauthorized)
		return
	}
	sessionMu.Lock()
	sessionData, ok := regSess[sid]
	delete(regSess, sid) // 一次性
	sessionMu.Unlock()
	if !ok {
		http.Error(w, "session not found", http.StatusUnauthorized)
		return
	}

	// 讓套件從 request 解析前端傳來的 attestation response，完成註冊
	credential, err := webAuthn.FinishRegistration(user, *sessionData, r)
	if err != nil {
		http.Error(w, "finish registration error: "+err.Error(), http.StatusBadRequest)
		return
	}

	// 把 Credential 存到使用者
	usersMu.Lock()
	user.Credentials = append(user.Credentials, *credential)
	usersMu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"ok":true}`))
}

type startLoginReq struct {
	Username string `json:"username"`
}

func handleLoginStart(w http.ResponseWriter, r *http.Request) {
	var req startLoginReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	user, ok := users[req.Username]
	if !ok || len(user.Credentials) == 0 {
		http.Error(w, "user not found or no credentials", http.StatusNotFound)
		return
	}

	// 產生 PublicKeyCredentialRequestOptions + SessionData
	opts, sessionData, err := webAuthn.BeginLogin(user)
	if err != nil {
		http.Error(w, "begin login error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 存 session
	sid := randomB64(16)
	sessionMu.Lock()
	authSess[sid] = sessionData
	sessionMu.Unlock()
	setCookie(w, "sid", sid)

	// 傳給前端做 navigator.credentials.get()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(opts)
}

func handleLoginFinish(w http.ResponseWriter, r *http.Request) {
	username := r.URL.Query().Get("username")
	if username == "" {
		http.Error(w, "username required", http.StatusBadRequest)
		return
	}
	user, ok := users[username]
	if !ok {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}

	sid := getCookie(r, "sid")
	if sid == "" {
		http.Error(w, "missing sid", http.StatusUnauthorized)
		return
	}
	sessionMu.Lock()
	sessionData, ok := authSess[sid]
	delete(authSess, sid)
	sessionMu.Unlock()
	if !ok {
		http.Error(w, "session not found", http.StatusUnauthorized)
		return
	}

	// 解析 assertion response，驗證簽章 + 更新 sign counter
	_, err := webAuthn.FinishLogin(user, *sessionData, r)
	if err != nil {
		http.Error(w, "finish login error: "+err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"ok":true,"message":"login success"}`))
}

func main() {
	mustInitWebAuthn()

	// 靜態頁面
	fs := http.FileServer(http.Dir("./public"))
	http.Handle("/", fs)

	// API
	http.HandleFunc("/api/register/start", handleRegisterStart)
	http.HandleFunc("/api/register/finish", handleRegisterFinish)
	http.HandleFunc("/api/login/start", handleLoginStart)
	http.HandleFunc("/api/login/finish", handleLoginFinish)

	log.Println("listening on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
```

---

## 前端（HTML + CSS + JS）

> 純原生 API；負責把後端提供的 options 轉成 `ArrayBuffer` / `Base64URL` 所需型別，並把 browser 產生的憑證送回 server。

**檔案：`public/index.html`**

```html
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Passkey MVP</title>
  <link rel="stylesheet" href="/style.css" />
</head>
<body>
  <div class="container">
    <h1>Passkey MVP</h1>
    <p class="hint">請在支援 WebAuthn 的瀏覽器上測試（Chrome、Edge、Safari 近版）。</p>

    <label>
      <span>使用者名稱</span>
      <input id="username" placeholder="alice" value="alice" />
    </label>

    <div class="actions">
      <button id="btnReg">註冊 Passkey</button>
      <button id="btnLogin">使用 Passkey 登入</button>
    </div>

    <pre id="log"></pre>
  </div>

  <script src="/utils.js"></script>
  <script src="/web.js"></script>
</body>
</html>
```

**檔案：`public/style.css`**

```css
* { box-sizing: border-box; }
body { margin: 0; font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", "PingFang TC", "Microsoft JhengHei", sans-serif; background: #0b1020; color: #e6eefc; }
.container { max-width: 760px; margin: 40px auto; padding: 24px; background: #0f1530; border: 1px solid #1f2750; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,.35); }
h1 { margin: 0 0 8px; font-size: 28px; }
.hint { opacity: .8; margin: 0 0 16px; }
label { display: block; margin: 12px 0 20px; }
label span { display: block; margin-bottom: 6px; opacity: .9; }
input { width: 100%; padding: 10px 12px; border-radius: 10px; border: 1px solid #2b3366; background: #0b122a; color: #e6eefc; }
.actions { display: flex; gap: 12px; }
button { padding: 10px 14px; border-radius: 999px; border: 1px solid #2b3366; background: #1a2350; color: #e6eefc; cursor: pointer; }
button:hover { background: #223070; }
pre { margin-top: 16px; padding: 12px; background: #0b122a; border: 1px solid #2b3366; border-radius: 8px; overflow: auto; min-height: 120px; }
```

**檔案：`public/utils.js`**

```javascript
// Base64URL <-> ArrayBuffer helpers
const b64urlToArrayBuffer = (b64url) => {
  const pad = "=".repeat((4 - (b64url.length % 4)) % 4);
  const b64 = (b64url + pad).replace(/-/g, "+").replace(/_/g, "/");
  const str = atob(b64);
  const buf = new ArrayBuffer(str.length);
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < str.length; i++) bytes[i] = str.charCodeAt(i);
  return buf;
};

const arrayBufferToB64url = (buf) => {
  const bytes = new Uint8Array(buf);
  let str = "";
  for (let i = 0; i < bytes.byteLength; i++) str += String.fromCharCode(bytes[i]);
  const b64 = btoa(str);
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
};

const log = (...args) => {
  const el = document.querySelector("#log");
  el.textContent += args.map(a => (typeof a === "string" ? a : JSON.stringify(a, null, 2))).join(" ") + "\n";
};
const getUsername = () => document.querySelector("#username").value.trim();
```

**檔案：`public/web.js`**

```javascript
async function postJSON(url, data) {
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type":"application/json"},
    body: JSON.stringify(data || {})
  });
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
  return res.json();
}

function decodeCreationOptions(opts) {
  // 伺服器傳來的是 JSON（base64url 字串），需轉回 ArrayBuffer
  opts.publicKey.challenge = b64urlToArrayBuffer(opts.publicKey.challenge);
  opts.publicKey.user.id = b64urlToArrayBuffer(opts.publicKey.user.id);
  if (opts.publicKey.excludeCredentials) {
    for (const cred of opts.publicKey.excludeCredentials) {
      cred.id = b64urlToArrayBuffer(cred.id);
    }
  }
  return opts;
}

function decodeRequestOptions(opts) {
  opts.publicKey.challenge = b64urlToArrayBuffer(opts.publicKey.challenge);
  if (opts.publicKey.allowCredentials) {
    for (const cred of opts.publicKey.allowCredentials) {
      cred.id = b64urlToArrayBuffer(cred.id);
    }
  }
  return opts;
}

function encodeAttestationResponse(cred) {
  return {
    id: cred.id,
    rawId: arrayBufferToB64url(cred.rawId),
    type: cred.type,
    response: {
      clientDataJSON: arrayBufferToB64url(cred.response.clientDataJSON),
      attestationObject: arrayBufferToB64url(cred.response.attestationObject),
    }
  };
}

function encodeAssertionResponse(cred) {
  return {
    id: cred.id,
    rawId: arrayBufferToB64url(cred.rawId),
    type: cred.type,
    response: {
      clientDataJSON: arrayBufferToB64url(cred.response.clientDataJSON),
      authenticatorData: arrayBufferToB64url(cred.response.authenticatorData),
      signature: arrayBufferToB64url(cred.response.signature),
      userHandle: cred.response.userHandle ? arrayBufferToB64url(cred.response.userHandle) : null,
    }
  };
}

document.querySelector("#btnReg").addEventListener("click", async () => {
  try {
    const username = getUsername();
    if (!username) return log("請輸入使用者名稱");

    log("開始註冊：", username);
    const creationOptions = await postJSON("/api/register/start", { username });
    decodeCreationOptions(creationOptions);

    const credential = await navigator.credentials.create(creationOptions);
    log("credential created");

    const payload = encodeAttestationResponse(credential);
    const res = await fetch(`/api/register/finish?username=${encodeURIComponent(username)}`, {
      method: "POST",
      headers: {"Content-Type":"application/json"},
      body: JSON.stringify(payload),
    });
    if (!res.ok) throw new Error(await res.text());

    log("註冊完成 ✅");
  } catch (err) {
    log("註冊失敗：", String(err));
  }
});

document.querySelector("#btnLogin").addEventListener("click", async () => {
  try {
    const username = getUsername();
    if (!username) return log("請輸入使用者名稱");

    log("開始登入：", username);
    const requestOptions = await postJSON("/api/login/start", { username });
    decodeRequestOptions(requestOptions);

    const assertion = await navigator.credentials.get(requestOptions);
    log("assertion received");

    const payload = encodeAssertionResponse(assertion);
    const res = await fetch(`/api/login/finish?username=${encodeURIComponent(username)}`, {
      method: "POST",
      headers: {"Content-Type":"application/json"},
      body: JSON.stringify(payload),
    });
    if (!res.ok) throw new Error(await res.text());

    log("登入成功 🎉");
  } catch (err) {
    log("登入失敗：", String(err));
  }
});
```

---

## 跑起來

```bash
# 建立專案
mkdir passkey-mvp && cd passkey-mvp
go mod init passkey-mvp
go get github.com/go-webauthn/webauthn/webauthn github.com/go-webauthn/webauthn/protocol

# 建立目錄與檔案
mkdir public
# 將上面的 main.go 放在專案根目錄
# 將 index.html / style.css / utils.js / web.js 放在 ./public
# ├── go.mod
# ├── go.sum
# ├── main.go
# └── public
#     ├── index.html
#     ├── style.css
#     ├── utils.js
#     └── web.js

# 啟動
go run .
# 打開瀏覽器
# http://localhost:8080
```

> 測試流程：輸入 `alice` → 點「註冊 Passkey」→ 瀏覽器彈出系統 UI（指紋/臉）→ 成功後再點「使用 Passkey 登入」。

**注意**：

* RP ID 設為 `localhost`，Origin 是 `http://localhost:8080`。如果改成 HTTPS 或自訂網域，請同步調整 `webauthn.Config` 與前端網址。
* Safari 通常需要 HTTPS；在本機開發可先用 Chrome/Edge 測試。

---

## 常見問題（MVP 版本）

1. **為什麼我看不到系統生物辨識 UI？**
   檢查：

   * 瀏覽器版本是否新；
   * 網域/Origin 是否與後端設定一致；
   * 作業系統是否已設定 PIN/指紋/臉部辨識。

2. **多裝置同步（iCloud/Google Password Manager）怎麼處理？**
   這屬於使用者端的 Passkey 管理，MVP 無需特別處理。正式環境請設計「Authenticator 生命週期管理」（新增、移除、Device Bound vs Synced）。

3. **資料該存哪？**
   本文用 in-memory 存放。實際上要把 `user.Credentials` 存到資料庫（例如 `credential_id`, `public_key`, `sign_count` 等欄位），`FinishLogin` 後要更新 sign counter。

4. **釣魚防護靠什麼？**
   WebAuthn 憑證會綁定 RP ID / Origin，偽造站點無法通過驗證。仍需搭配 HTTPS、正確的 Content Security Policy 與嚴格的 cookie 設定。

---

## 延伸與強化

* **註冊時的策略**：Resident Key、User Verification（Required/Preferred）、Authenticator Attachment（platform/cross-platform）。
* **後端框架化**：把帳號、憑證存取抽象成 repository，改以 Postgres/SQLite。
* **Session 安全**：改為加密的 Server/DB-backed session 或使用框架（例如 gorilla/sessions）。
* **混合登入**：傳統密碼 + TOTP → 導入 Passkey，提供漸進式升級。
* **企業整合**：可延伸至 Web + 桌面/行動端（如使用 WebView/ASWebAuthenticationSession）的一致登入體驗。

---

## 總結

本文以最小可行的方式，把 **Passkey/WebAuthn** 從原理整到可跑的 **Go + Browser** MVP。
你現在不只理解 **challenge 簽章** 與 **公私鑰** 的核心，更擁有一個能把「無密碼登入」跑起來的基本骨架。接下來，把 in-memory 換成 DB、把 session 換成安全實作、把註冊/登入流程整合到你現有的系統，就能一步步上線。