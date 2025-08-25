---
date: 2021-09-14T17:03:13+08:00
title: "使用 Gin 框架實作登入功能"
description: ""
author: "Yuan"
draft: false
tags: ["go","gin","website","backend","cookie"]
keywords: []
categories: ["website"]
---

## 前言

最近又要開始接觸到網頁的東西了!
久沒有碰要再花一點時間回想。想說就趁著這次順手記錄起來吧。

<!--more-->

## 主要內容

### 寫在前面

本篇我們會透過 gin 框架建立 API 伺服器。一開始會先建立一個測試用的 API，接著在試著提供網頁服務後；我們會開始建立登入功能所需的 API `login` 以及 `auth`。

- login 會檢查登入所使用的帳戶密碼，在驗證正確後會給予 Token 於 Cookie 中。
- auth 會檢查 Cookie 是否有合法的 Token 。

由於本篇主要是專注在網頁後端「如何使用 gin 框架」，所以有關 HTML、 JavaScript 、CSS 並不會著墨太多。

### 建立專案

```bash
go mod init github.com/e61983/test-gin-login
go get -u github.com/gin-gonic/gin
```

### 起手式

#### 建立測試用的 API - ping
```bash
cat << EOF > main.go
package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "pong",
		})
	})
	r.Run()
}
EOF
```

現在讓我們先跑起來看看!

```bash
go run main.go
```

並在另一個終端機上試著存取我們建立的 API `ping`

```bash
curl -X GET http://localhost:8080/ping

# Output:
{"message":"pong"}%
```

#### 提供網頁服務

簡單的建立測試用的頁面。

```bash
mkdir -p webroot
cat << EOF > webroot/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Home Page</title>
</head>
<body>
    <h1>Home Page</h1>
</body>
</html>
EOF
```

接下來透過提供 `LoadHTMLGlob()` 載入文件夾中的靜態頁面。

```go
r.LoadHTMLGlob("webroot/*")
r.GET("/", func(c *gin.Context) {
	c.HTML(http.StatusOK, "index.html", gin.H{})
})
```

重新運行後，使用瀏覽器觀看執行結果

{{< figure src="images/result-first.png" caption="我們的第一個畫面" >}}

### 登入 ( Login ) API

在使用 gin 的綁定 (binding) 功能時，我們要在想要綁定的欄位後面，依照想要綁定的方法加上  **Struct Tags**。
之我們就可以使用 `gin.Bind()` 或是 `gin.ShouldBind()` 來取得網頁前端所傳輸的資料。
本篇是用直接比對帳號密碼的方式實作，同學在實務上不要這樣學喔!
在檢驗完之後，將 Token 記錄於 Cookie 。
不過，目前常見驗證是採 JWT 的驗證方式，所以同學也自己來試著改寫看看。

```go
type User struct {
	Account  string `json:"account" form:"account"`
	Password string `json:"password" form:"password"`
}

r.POST("/login", func(c *gin.Context) {
	/* 綁定資料 */
	u := &User{}
	if c.ShouldBind(&u) != nil {
		c.JSON(http.StatusOK, gin.H{"err": 1})
		return
	}
	/* 檢查帳號密碼 */
	if u.Account != TEST_ACCOUNT || u.Password != TEST_PASSWORD {
		c.JSON(http.StatusOK, gin.H{"err": 2})
		return
	}
	/* 將 Token 記錄於 Cookie 中 */
	c.SetCookie(TOKEN_KEY, TEST_TOKEN, 3600, "/", HOST, false, false)
	c.JSON(http.StatusOK, gin.H{})
})
```

### 驗證 ( Auth ) API

我們可以從瀏覽器發送的請求中取出我們先前記錄於 Cookie 的 Token 。
並且比對它是否合法。

```go
r.POST("/auth", func(c *gin.Context) {
	/* 從 Cookie 取出 Token */
	if token, err := c.Cookie(TOKEN_KEY); err != nil {
		if TEST_TOKEN != token {
			c.JSON(http.StatusOK, gin.H{"err": 2})
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"err": nil})
})
```

### 建立登入表單與登入後顯示畫面

建立登入頁面。

```bash
cat << EOF > webroot/login.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="assets/core.css">
    <title>Login Page</title>
</head>
<body>
    <h1>Login Page</h1>
    <div class="container">
        <form>
            <div class="input-wrapper">
                <div class="title">Login</div>
                <div class="label" for="account">Account:</div>
                <input type="text" id="account" name="account" value="tester" />
                <div class="label" for="password">Password:</div>
                <input type="password" id="password" name="password" value="test123" />
                <button id="btn" type="button"> Submit </button>
            </div>
        </form>
    </div>
    <script type="module" >
        import {getData, postData, getCookie, deleteCookie} from '/javascript/core.js';
        function login() {
            let account = document.getElementById("account").value;
            let password = document.getElementById("password").value;
            postData("http://localhost:8080/login",
                {"account": account, "password": password})
                .then(data=>{
                    console.log(data.err)
                    if (data.err !== null){
                        window.location.replace("/")
                    }else{
                        window.location.replace("/admin/")
                    }
                });
        }
        function check(token) {
            postData("http://localhost:8080/auth", {"token": token})
                .then(data=>{
                    if (data.err === null){
                        window.location.replace("/admin/")
                    }
                });
        }
        check(getCookie("token"))
        window.onload = function(){
            document.getElementById("btn").addEventListener("click", login);
        }
    </script>
</body>
</html>
EOF
```

改寫歡迎畫面

```bash
cat << EOF > webroot/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="/assets/core.css">
    <title>Home Page</title>
</head>
<body>
    <h1>Home Page</h1>
    <div class="container">
        <div class="input-wrapper">
            <div class="title">Hello word</div>
            <button id="btn" type="button"> Logout </button>
        </div>
    </div>
    <script type="module" >
        import {getData, postData, getCookie, deleteCookie} from '/javascript/core.js';

        function logout() {
            deleteCookie("token", "/", "localhost")
            window.location.replace("/")
        }
        window.onload = function(){
            document.getElementById("btn").addEventListener('click', logout);
        }
    </script>
</body>
</html>
EOF
```


### 畫存取清界線

我們前面建立了將要顯示的頁面，現在我們要來設定存取的路徑。

```go
/* 登入頁面 */
r.GET("/", func(c *gin.Context) {
	c.HTML(http.StatusOK, "login.html", nil)
})

/* 需要登入才能存取的頁面 */
admin := r.Group("/admin")
admin.GET("/", func(c *gin.Context) {
	if currentUser, ok := c.Get("User"); ok {
		log.Printf("User [ %s ] Accessed", currentUser)
	}
	c.HTML(http.StatusOK, "index.html", nil)
})
```

#### 建立中間層

雖然我們已經建立了 `/login` 與 `/admin/` 這 2 個路徑，但如果我們直接在劉覽器中輸入 `http://localhost:8080/admin/`。會發現還是可以存取的。
為了避免這樣的事情發生，我們可以建立中間層來檢查是否已登入。
如果發現尚未登入的存取請求，我們就將其轉至登入畫面。

```go
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		cookieToken, err := c.Cookie(TOKEN_KEY)
		if err != nil && cookieToken != TEST_TOKEN {
			c.Redirect(http.StatusTemporaryRedirect, BASEURL)
			c.AbortWithStatus(http.StatusTemporaryRedirect)
			return
		} else {
			c.Set("User", TEST_ACCOUNT)
			c.Next()
		}
	}
}
```
#### 使用中間層

在我們建立好的 `admin` 路由群組中，使用我們建立好的中間層。如此一來，要存取此路由群組的請求就會檢查是否已登入了。

```go
admin.Use(AuthMiddleware())
```

{{< figure src="images/result-login.png" caption="登入表單" >}}
{{< figure src="images/result-greeting.png" caption="登入後歡迎畫面" >}}

## 小結

本篇省略了很多實作上的細節，對被省略的部份有興趣的同學可以參考[這裡](./test-gin-login.tar.bz2)。

## 參考連結

- [gin-gonic/gin][1]

[1]:https://github.com/gin-gonic/gin
