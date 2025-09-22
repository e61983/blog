---
title: "RabbitMQ！鎹鴉傳信的分工法 - 通往地獄的開始？！"
date: 2025-09-22T23:04:47+08:00
draft: false
tags: ["RabbitMQ", "Go", "Docker", "Message Queue"]
---

## 前言

在鬼殺隊的任務分派中，如果沒有調度中心，任務可能會亂七八糟。  
想像一下：如果所有柱同時衝去打同一隻鬼，那些在另一邊肆虐的鬼該怎麼辦？  

這時候，我們需要一個「訊息中介」來幫忙分配工作。  
就像**蟲柱 蝴蝶忍**負責調度藥物與情報，**炎柱 煉獄杏壽郎**帶領隊伍作戰一樣 ——  
這個「中介人」在系統世界裡，就是 **RabbitMQ**。  

<!--more-->

## RabbitMQ 是什麼？

RabbitMQ 是一個 **訊息代理系統 (Message Broker)**。  
它能接收來自一方的訊息（Producer），暫存在 **Queue**，再由另一方（Consumer）處理。  

換句話說，它就像**鬼殺隊的任務分派所**：  
- 產生任務的人 = Producer  
- 任務清單 = Queue  
- 接任務的劍士 = Consumer  
- Exchange 則是「分派邏輯」：決定哪個任務要派給誰。  

## 常見設計模式

{{< mermaid >}}
flowchart LR
    subgraph WorkQueue["工作隊列（任務分工）"]
        P1["Producer（任務所）"] --> Q1["Queue（任務清單）"]
        Q1 --> C1["劍士 1"]
        Q1 --> C2["劍士 2"]
    end

    subgraph PubSub["發佈 / 訂閱（情報共享）"]
        P2["Producer（鎹鴉傳信）"] --> E1["Fanout Exchange（情報放送）"]
        E1 --> Q2["炎柱專用清單"]
        E1 --> Q3["音柱專用清單"]
        Q2 --> C3["炎柱 煉獄"]
        Q3 --> C4["音柱 宇髄"]
    end

    subgraph Routing["路由（分類調度）"]
        P3["Producer（鬼情報）"] --> E2["Topic Exchange（情報分流）"]
        E2 -->|routing_key=上弦| Q4["高危任務清單"]
        E2 -->|routing_key=下弦| Q5["低危任務清單"]
        Q4 --> C5["水柱 富岡"]
        Q5 --> C6["善逸 & 伊之助"]
    end
{{< /mermaid >}}

* **工作隊列**：就像分工出擊，多個劍士平分戰場。
* **發佈/訂閱**：情報同時發送給不同柱。
* **路由模式**：不同強度的鬼交給不同等級的劍士處理。

## 用 Docker Compose 架設 RabbitMQ

在現代開發環境中，我們常透過 Docker Compose 來快速啟動 RabbitMQ。
以下配置同時展示了 **definitions.json**（自動初始化設定），讓 RabbitMQ 啟動就有使用者、vhost、queue 與 exchange。

```yaml
services:
  rabbitmq:
    image: rabbitmq:3.13-management
    container_name: rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
      - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf
      - ./definitions.json:/etc/rabbitmq/definitions.json:ro
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M

volumes:
  rabbitmq_data:
```

### definitions.json

```json
{
  "users": [
    { "name": "appuser", "password_hash": "V6pRsZxUi7UgkFHFdS1MGf3TRmBe8HLSn3speAQZqGAZrkuB", "tags": "management" }
  ],
  "vhosts": [
    { "name": "/app" }
  ],
  "permissions": [
    {
      "user": "appuser",
      "vhost": "/app",
      "configure": ".*",
      "write": ".*",
      "read": ".*"
    }
  ],
  "queues": [
    { "name": "task_queue", "vhost": "/app", "durable": true }
  ],
  "exchanges": [
    { "name": "logs", "vhost": "/app", "type": "fanout", "durable": true }
  ],
  "bindings": [
    { "source": "logs", "vhost": "/app", "destination": "task_queue", "destination_type": "queue" }
  ]
}
```

> **注意**：在 definitions.json 中，密碼必須使用 `password_hash` 而不是 `password`，且值必須是 hash 過的字串。  
> 可以使用 `docker exec rabbitmq rabbitmqctl hash_password 你的密碼` 來產生 hash 值。

### rabbitmq.conf

```
load_definitions = /etc/rabbitmq/definitions.json
```

## 使用 Go 舉個栗子：Producer & Consumer

在隊伍中，**Producer 就像是鎹鴉**，**Consumer 就像是劍士**。

> **重要**：在實際開發中，**務必處理所有錯誤**！使用 `_` 忽略錯誤會導致 `nil pointer dereference` 的 panic。

### Producer (發送訊息)

```go
package main

import (
    "log"

    amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
    // 建立連接，並處理錯誤
    conn, err := amqp.Dial("amqp://appuser:apppass@localhost:5672//app")
    if err != nil {
        log.Fatalf("Failed to connect to RabbitMQ: %v", err)
    }
    defer conn.Close()

    // 建立通道，並處理錯誤
    ch, err := conn.Channel()
    if err != nil {
        log.Fatalf("Failed to open a channel: %v", err)
    }
    defer ch.Close()

    // 宣告 Queue，並處理錯誤
    q, err := ch.QueueDeclare("task_queue", true, false, false, false, nil)
    if err != nil {
        log.Fatalf("Failed to declare a queue: %v", err)
    }

    body := "柱 集結！"
    err = ch.Publish("", q.Name, false, false,
        amqp.Publishing{
            DeliveryMode: amqp.Persistent,
            ContentType:  "text/plain",
            Body:         []byte(body),
        })
    if err != nil {
        log.Fatalf("Failed to publish a message: %v", err)
    }

    log.Println("Sent:", body)
}
```

### Consumer (接收訊息)

```go
package main

import (
    "fmt"
    "log"

    amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
    // 建立連接，並處理錯誤
    conn, err := amqp.Dial("amqp://appuser:apppass@localhost:5672//app")
    if err != nil {
        log.Fatalf("Failed to connect to RabbitMQ: %v", err)
    }
    defer conn.Close()

    // 建立通道，並處理錯誤
    ch, err := conn.Channel()
    if err != nil {
        log.Fatalf("Failed to open a channel: %v", err)
    }
    defer ch.Close()

    // 開始消費訊息，並處理錯誤
    msgs, err := ch.Consume("task_queue", "", false, false, false, false, nil)
    if err != nil {
        log.Fatalf("Failed to register a consumer: %v", err)
    }

    log.Println("Waiting for missions...")
    for d := range msgs {
        fmt.Printf("Received任務: %s\n", d.Body)
        d.Ack(false)
    }
}
```

## 環境配置建議

1. **Cluster + Quorum Queue**

   * 就像多個鬼殺隊據點，確保任務清單不會因單一據點毀滅而消失。
   * 建議至少 3 節點，使用 **Quorum Queue** 代替傳統 Mirrored Queue。

2. **初始化（Definitions 檔案）**

   * 透過 `definitions.json` 自動建立 vhost、使用者、queue 與 exchange。
   * 好處：部署流程標準化，不怕人為失誤。

3. **監控與告警**

   * 使用 **Prometheus + Grafana** 監控 queue 長度、記憶體、磁碟使用量。
   * 若「訊息堆積如山」就要趕快多派幾個 worker。

## 資源限制

RabbitMQ 若不加限制，可能像**無慘的細胞分裂**一樣暴走。
以下方法可控制 RAM、磁碟與 CPU 使用：

### Docker Compose 限制

```yaml
deploy:
  resources:
    limits:
      cpus: "1.0"     # 最多 1 顆 CPU
      memory: 512M    # 最多 512 MB RAM
```

### RabbitMQ 配置

```conf
# 記憶體最多用系統 RAM 的 40%
vm_memory_high_watermark.relative = 0.4

# 磁碟不足 2GB 就暫停寫入
disk_free_limit.absolute = 2GB
```

## 除錯指南：常用 Shell 指令

- 檢查容器是否正在運行：

```bash
docker ps | grep rabbitmq
```

- 列出使用者（確認帳號是否存在、標籤是否正確）：

```bash
docker exec rabbitmq rabbitmqctl list_users
```

- 列出 vhost（確認目標 vhost 是否存在，注意根目錄 vhost 為「/」）：

```bash
docker exec rabbitmq rabbitmqctl list_vhosts
```

- 查看指定 vhost 的權限（確認使用者是否擁有 read/write/configure）：

```bash
docker exec rabbitmq rabbitmqctl list_permissions -p /app
```

- 變更使用者密碼（快速與程式使用的密碼對齊）：

```bash
docker exec rabbitmq rabbitmqctl change_password appuser apppass
```

- 產生密碼雜湊（當使用 definitions.json 初始化需要 password_hash 時）：

```bash
docker exec rabbitmq rabbitmqctl hash_password apppass
```

- 查看最近日誌（快速定位連線被拒原因，例如 vhost not found）：

```bash
docker logs rabbitmq --tail 50
```

- AMQP 連線字串小抄（/app 需使用 URL 編碼或雙斜線）：

```bash
# 兩種等價寫法（指向 vhost "/app"）
amqp://appuser:apppass@localhost:5672//app
amqp://appuser:apppass@localhost:5672/%2Fapp
```

## 參考資料

* [RabbitMQ 官方文件](https://www.rabbitmq.com/documentation.html)
* [RabbitMQ Docker Hub](https://hub.docker.com/_/rabbitmq)
* [Go RabbitMQ client (amqp091-go)](https://pkg.go.dev/github.com/rabbitmq/amqp091-go)

## 結語

RabbitMQ 就像鬼殺隊的「任務分派中心」。
透過 **Docker Compose**，我們能快速建立環境；
透過 **Go 的 Producer / Consumer**，我們能即時傳遞訊息；
透過 **definitions.json**，我們能讓配置自動化，避免人手操作失誤。

在生產環境中，記得啟用 **Cluster + Quorum Queue**，
並設好 **資源限制與監控**，才能確保隊伍不會因系統壓力而崩潰。