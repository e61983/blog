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

各位同學應該常常聽到一句話：「有了 Docker，環境跑起來就不怕！」  
但真的要寫 Dockerfile 或 compose.yaml 的時候，十之八九還是會卡在格式，或不小心讓主機資源爆掉。  

這篇文章就來整理一下 2025 年的實務寫法：

1. Dockerfile 怎麼寫。
2. Compose（compose.yaml）怎麼寫。
3. 怎麼限制資源，避免主機 GG。

<!--more-->

## Dockerfile：容器的食譜

Dockerfile 的角色就像食譜，逐行告訴 Docker 怎麼建置你的應用環境。常見的幾個指令如下：

* **FROM**：指定基礎映像，例如 `FROM python:3.11-slim`。
* **WORKDIR**：設定容器中的工作路徑。
* **COPY / ADD**：把檔案從宿主機複製到容器。
* **RUN**：建置階段要執行的指令（例如安裝套件）。
* **CMD**：定義容器啟動時要跑的預設指令。
* **ENTRYPOINT**：跟 CMD 類似，但更「強制」，適合固定的啟動行為。
* **ENV**：設定環境變數。
* **EXPOSE**：宣告容器會用到的 Port（僅供文件用途，實際仍要用 `-p` 或 `ports`）。

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

乾乾淨淨的一份食譜，就能讓 Go 專案跑起來。

## Docker Compose：多容器的劇本

有了 Dockerfile 只是建好環境，Compose 則像劇本，能協調多個服務一次跑起來。  

### 基本結構

在 **Compose v2**（2023 之後）開始：
- `version` 欄位 **可以省略**，Compose 會自動偵測 schema。
- `services`：定義多個容器服務。
- `volumes`、`networks`：全域資源。

### 範例：API + Postgres

```yaml
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
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M

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

👉 注意：  
過去常見的 `cpus`、`mem_limit` 屬性，在 v2 中雖然還能用，但已經屬於 **legacy 寫法**，官方建議改成 `deploy.resources`。

## 舊版 vs 新版：資源限制對照表

| 功能 | 舊版寫法 (legacy) | 新版建議寫法 (v2) |
|------|------------------|-------------------|
| 限制 CPU | `cpus: "1.0"` | `deploy.resources.limits.cpus: "1.0"` |
| 限制記憶體 | `mem_limit: "512m"` | `deploy.resources.limits.memory: 512M` |
| 保證資源 | 無 | `deploy.resources.reservations` |
| 多副本 | `scale: 3`（已廢棄） | `deploy.replicas: 3`（Swarm 才生效） |

👉 小結：  
- **單機環境**：只會套用 `limits.memory` 與 `limits.cpus`。  
- **Swarm 環境**：`replicas`、`placement`、`reservations` 才會生效。  

## 限制資源：避免把主機吃爆

如果沒有設限，容器很容易就把主機 CPU、記憶體吃光光。  
在 Compose v2，建議用 `deploy.resources` 來控制。

### 單機 Compose 寫法

```yaml
services:
  api:
    build: .
    deploy:
      resources:
        limits:
          cpus: "0.5"   # 限制 0.5 顆 CPU
          memory: 256M  # 限制 256MB 記憶體
```

雖然 `deploy` 最初是給 Docker Swarm 用的，但在 Compose v2（單機模式）也能套用 **資源限制**。

---

## Swarm：補充說明

`deploy` 區塊完整功能（replicas、placement、update_config...）原本是設計給 **Docker Swarm** 的。  

不過要提醒：  
- **Swarm 在 2023 後已進入維護模式**，官方重心已經移到 Kubernetes。  
- 單機 Compose 雖然能吃到部分 `deploy.resources`，但像 `replicas`、`placement` 在非 Swarm 環境並不會生效。  

👉 如果是新專案，不建議再投資 Swarm，應該直接考慮 Kubernetes 或單機 Compose。

## GPU/TPU 限制

在 AI/ML 場景，常常需要 GPU。  
在 Compose v2.5 之後，可以這樣寫：

```yaml
services:
  trainer:
    image: tensorflow/tensorflow:latest-gpu
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

👉 補充：
- 需要安裝 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/)。  
- 等價於 `docker run --gpus 1`。  
- 舊的 `capabilities: ["nvidia-compute"]` 仍能用，但建議用 `driver: nvidia` + `capabilities: [gpu]`。

## docker run 寫法

不透過 Compose，也能在 `docker run` 限制：

```bash
docker run --cpus="0.5" --memory="256m" myapp:latest
```

- `--cpus` 需要 **cgroup v2** 支援（大部分 Linux 已預設啟用）。  
- 在 macOS/Windows 的 Docker Desktop，限制會作用在 **VM 層級**，不是原生宿主機。

## 小結

到 2025 年為止，幾個要點可以記住：

1. **`version` 可省略** → Compose v2 會自動偵測。  
2. **`cpus`、`mem_limit` 是舊寫法** → 改用 `deploy.resources`。  
3. **Swarm 已進入維護模式** → 新專案不要再用。  
4. **GPU 支援靠 NVIDIA Container Toolkit** → `deploy.resources.devices` 或 `--gpus`。  
5. **Docker Desktop 限制** → 設定套用在 VM，不是宿主機。  

## 參考資料

* [Dockerfile reference | Docker Docs](https://docs.docker.com/reference/dockerfile/)  
* [Compose file reference | Docker Docs](https://docs.docker.com/compose/compose-file/)  
* [Deploy configuration | Docker Docs](https://docs.docker.com/reference/compose-file/deploy/)  
* [Resource constraints for containers | Docker Docs](https://docs.docker.com/config/containers/resource_constraints/)  
* [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/)  