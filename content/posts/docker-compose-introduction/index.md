---
date: 2025-08-27T23:24:29+08:00
title: "Dockerfile 與 Docker Compose 寫法全攻略"
description: ""
author: "Yuan"
draft: false
tags: ["docker", "docker-compose", "dockerfile", "containerization", "devops"]
keywords: []
categories: ["backend"]
---

## 前言

各位同學們應該常常聽到一句話：「有了 Docker，環境跑起來就不怕！」
不過當真的要寫 Dockerfile 或是 compose.yaml 的時候，十之八九就會卡在格式，或是跑一跑把主機資源吃爆。

這篇文章就來隨性聊聊：

1. Dockerfile 怎麼寫。
2. Compose（compose.yaml）怎麼寫。
3. 怎麼限制資源，避免主機 GG。

<!--more-->

## Dockerfile：容器的食譜

Dockerfile 的角色就像是食譜，逐行告訴 Docker 怎麼建置你的應用環境。常見的幾個指令如下：

* **FROM**：指定基礎映像，例如 `FROM python:3.11-slim`。
* **WORKDIR**：設定容器中的工作路徑。
* **COPY / ADD**：把檔案從宿主機複製到容器。
* **RUN**：建置階段要執行的指令（例如安裝套件）。
* **CMD**：定義容器啟動時要跑的預設指令。
* **ENTRYPOINT**：跟 CMD 類似，但更「強制」，適合固定的啟動行為。
* **ENV**：設定環境變數。
* **EXPOSE**：宣告容器會用到的 Port。

### 範例：Go 應用的 Dockerfile

```dockerfile
FROM golang:1.22-alpine
WORKDIR /app

# 安裝依賴
COPY go.mod .
COPY go.sum .
RUN go mod download

# 複製程式碼並建置
COPY . .
RUN go build -o server .

# 開放服務 Port
EXPOSE 8080

# 啟動指令
CMD ["./server"]
```

這樣一份食譜，乾乾淨淨就能讓 Go 專案跑起來。

## Docker Compose：多容器的劇本

有了 Dockerfile 只是把環境建好，Compose 則是能讓多個服務一次跑起來，像是一份劇本協調大家該怎麼登場。

Compose 檔案基本結構：

* **version**：Compose 檔案版本（v2 可以省略）。
* **services**：定義多個容器服務。

  * **image** 或 **build**：映像檔來源或建置方式。
  * **ports**：Port 映射。
  * **volumes**：資料卷掛載。
  * **environment**：環境變數設定。
  * **depends\_on**：依賴的其他服務。
* **volumes**：全域可重複使用的 Volume。
* **networks**：網路設定（選用）。

### 範例：API + Postgres

```yaml
version: "3.9"

services:
  api:
    build: .
    ports:
      - "8080:8080"
    volumes:
      - ./data:/app/data
    environment:
      - ENV=production
    depends_on:
      - db
    cpus: "1.0"       # 限制最多 1 顆 CPU
    mem_limit: "512m" # 限制最多 512MB 記憶體

  db:
    image: postgres:16
    restart: always
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: demo
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

這樣一份設定檔，直接就能 `docker compose up`，兩個服務就乖乖跑起來。

## 限制資源：避免把主機吃爆

Docker 容器如果不加限制，很容易就把主機 CPU、記憶體用到掛。各位同學們要學會「設限」，才能避免悲劇。

### 方法一：Compose v2 寫法

```yaml
services:
  api:
    build: .
    cpus: "0.5"       # 限制 0.5 顆 CPU
    mem_limit: "256m" # 限制 256MB 記憶體
```

這種寫法在 `docker compose up` 就會生效。

### 方法二：Swarm 模式（deploy 區塊）

```yaml
services:
  api:
    image: myapp:latest
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 256M
        reservations:
          cpus: "0.25"
          memory: 128M
```

這種寫法只有在 Docker Swarm 或 Enterprise 環境才會真的限制。

### 方法三：docker run 參數

不透過 Compose，直接下參數：

```bash
docker run --cpus="0.5" --memory="256m" myapp:latest
```

## 小節

各位同學們，Dockerfile 就像食譜，負責建置應用的料理過程；Compose 則像劇本，協調多個容器怎麼同台演出。加上資源限制，才不會變成「吃爆 RAM、把 CPU 跑滿」的慘案。

只要掌握了這些基本格式，接下來不管是學校專題還是 Side Project，都能很放心地用 Docker 把環境跑起來。

## 參考資料

* [Dockerfile reference | Docker Docs](https://docs.docker.com/reference/dockerfile/)
* [Compose file reference | Docker Docs](https://docs.docker.com/compose/compose-file/)
* [Resource constraints for containers | Docker Docs](https://docs.docker.com/config/containers/resource_constraints/)
