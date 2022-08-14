---
date: 2022-08-14T15:41:25+08:00
title: "在 Go 語言中使用 Websocket"
description: ""
author: "Yuan"
draft: false
tags: ["go","websocket"]
keywords: []
categories: ["website"]
---

## 前言

先前在網頁中想取得即時資料。在那個時候有聽到 websocket 這個東西，但一直沒有時間試試。最近剛好又想起了這件事，於是乎這一篇就誕生啦。
<!--more--> 本篇會透過一個簡單的範例 `echo` 來練習使用 WebSocket。

## 主要內容

Websocket 是基於 HTTP/HTTPS 協定，後續再使用 Upgrade Header 改為 WebSocket 協定。

### 來個簡單的範例吧

這個範例會實做 2 個部份，一個是使用 Go 語言實作的網頁後端服務，它會提供 WebSocket 伺服端；另一個部份是使用 HTML + Javascript 實作客戶端的部份。

#### 網頁後端

這個範例我們使用的是 [gorilla/websocket][1]  實作的版本，我們可以透過下例的指令來使用它。

```bash
go get github.com/gorilla/websocket
```

`echo` 函式中會使用 Upgrader 將目前使用的協定從 http 協定改為 WebSocket ，並開始接收來自客戶端的訊息。當收到訊息後，會直接把收到的訊息直接回傳給客戶端。 

main.go

```go
package main

import (
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
    CheckOrigin: func(r *http.Request) bool {return true},
}

// 提供 echo 服務
func echo(w http.ResponseWriter, r *http.Request){
        c, err := upgrader.Upgrade(w, r, nil)
        if err != nil {
            log.Print("upgrade:", err)
            return
        }
        defer c.Close()
        for {
        	// 接收到的訊息
            messageType, message, err := c.ReadMessage()
            if err != nil {
                log.Println("read:", err)
                break
            }
            log.Println("read", string(message))
            	// 送出原本收到的訊息
            err = c.WriteMessage(messageType, message)
            if err != nil {
                log.Println("write:", err)
                break
            }
            log.Println("send", string(message))
        }
}

func main(){
    http.HandleFunc("/ws", echo)
    http.ListenAndServe(":8080", nil)
}
```

#### 網頁前端

index.html

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script>
        // 載入完成
        window.addEventListener("load", function (event) {
            msg = document.getElementById("msg");
            btn = document.getElementById("btn");
            input = document.getElementById("input");
            
            // 加上按鈕按下時的處理函式
            btn.addEventListener("click", event => {
                console.log("fire~", input.value)
                ws.send(input.value)
            })
            
            // 建立 websocket 連線
            let ws = new WebSocket("ws://localhost:8080/ws");
            ws.onopen = () => {
                console.log("ws is open");
            }
            
            ws.onclose = () => {
                console.log("ws is close");
            }
            
            // 加上收到訊息時的處理函式 - 將收到的訊息顯示在 msg 中。
            ws.onmessage = event => {
                msg.innerHTML = event.data
                console.log("roger~~", event.data)
            }
            
            window.addEventListener("beforeunload", function (event) {
                ws.close()
            })
            
        });
	</script>
    <title>WebSocket 測試 - ECHO</title>
</head>
<body>
    <div>
        <div>收到的訊息</div>
        <div id="msg"></div>
    </div>
    <input type="text" id="input" /><button id="btn">send</button>
    </body>
</html>
```

### 結果

當我們輸入 `hi` 並按下 send 時後端會收到我們所傳送的訊息，並立即回傳給前端。

{{< figure src="images/demo.png" caption="範例執行結果" >}}

## 小結

本文撰寫了一個非常簡單的範例，主要的目的在於瞭解 WebSocket 的使用方式。實際在使用時，還會有其他的業務邏輯與異常處理的部份。有興趣的同學就再自行玩玩囉~

## 參考連結

- [gorilla/websocket][1]
- [WebSocket][2]

[1]:https://github.com/gorilla/websocket
[2]:https://developer.mozilla.org/ja/docs/Web/API/WebSocket
