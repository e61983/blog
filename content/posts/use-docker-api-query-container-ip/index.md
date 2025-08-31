---
date: 2025-08-31T23:03:35+08:00
title: "在 Go 裡直接抓 Docker 容器 IP，連線 PostgreSQL"
description: "透過 Docker API 自動查詢容器 IP 地址，無需暴露 port 即可從 Go 應用連接 PostgreSQL 資料庫，實現更安全的開發環境配置"
author: "Yuan"
draft: false
tags: ["go", "docker", "postgresql", "api", "compose", "backend"]
keywords: []
categories: ["backend"]
---

## 前言

開發環境裡，我們常用 **Docker Compose** 來啟動資料庫。像是 PostgreSQL 這種服務，我們通常會這樣做：

```yaml
ports:
  - "5432:5432"
```

這樣就能用 `localhost:5432` 直接連資料庫，簡單又方便。

最近在思考，如果我們不想把資料庫連接埠對外暴露，想完全在 Docker network 裡面連線。  
但容器的 IP 每次重啟都不一樣，我們該怎麼辦？

答案是：別手動 `docker inspect`，直接在 Go 裡用 **Docker API** 查 IP 就好。  
查完 IP，再用它去連 PostgreSQL，完全自動化，安全又乾淨。

<!--more-->

## Docker Compose 範例

最小化的 `docker-compose.yaml` 長這樣：

```yaml
services:
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

注意：這裡沒有 `ports:`，資料庫只在 Docker network 裡對外提供服務。

## Go 程式實作

我們會用三個套件：

* `github.com/docker/docker/client` → 查容器資訊
* `github.com/jackc/pgx/v5` → 連 PostgreSQL
* `github.com/compose-spec/compose-go/v2/cli` → 解析 docker-compose.yml

程式流程：

1. 用 compose-go 解析 `docker-compose.yml`，自動獲取專案名稱
2. 根據專案名稱和服務名稱，組合出容器名稱
3. 用 Docker API `ContainerInspect` 拿容器資訊
4. 從 `NetworkSettings.Networks` 讀 IP
5. 拼成連線字串，丟給 pgx 連資料庫

程式碼如下：

```go
package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/compose-spec/compose-go/v2/cli"
	"github.com/docker/docker/client"
	"github.com/jackc/pgx/v5"
)

// 從 docker-compose.yml 獲取專案資訊
func getProjectInfo(composePath string) (projectName string, serviceName string, err error) {
	// 使用 compose-go 載入專案設定
	options, err := cli.NewProjectOptions(
		[]string{composePath},
		cli.WithOsEnv,
		cli.WithDotEnv,
	)
	if err != nil {
		return "", "", fmt.Errorf("無法建立專案選項: %w", err)
	}

	project, err := options.LoadProject(context.Background())
	if err != nil {
		return "", "", fmt.Errorf("無法載入專案: %w", err)
	}

	// 取得專案名稱
	projectName = project.Name
	
	// 尋找資料庫服務（這裡假設名稱是 "db"）
	for name := range project.Services {
		if name == "db" {
			serviceName = name
			break
		}
	}

	if serviceName == "" {
		return "", "", fmt.Errorf("找不到名為 'db' 的服務")
	}

	return projectName, serviceName, nil
}

// 拿容器 IP
func getContainerIP(ctx context.Context, containerName string) (string, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		return "", fmt.Errorf("無法建立 Docker client: %w", err)
	}
	defer cli.Close()

	containerJSON, err := cli.ContainerInspect(ctx, containerName)
	if err != nil {
		return "", fmt.Errorf("無法 inspect 容器: %w", err)
	}

	for _, network := range containerJSON.NetworkSettings.Networks {
		return network.IPAddress, nil
	}

	return "", fmt.Errorf("找不到容器的 IP")
}

func main() {
	ctx := context.Background()

	// 自動從 compose.yml 獲取專案資訊
	composePath := "compose.yml"
	projectName, serviceName, err := getProjectInfo(composePath)
	if err != nil {
		log.Fatalf("無法獲取專案資訊: %v", err)
	}

	// Docker Compose 的容器命名規則: projectName-serviceName-1
	containerName := fmt.Sprintf("%s-%s-1", projectName, serviceName)
	fmt.Printf("專案名稱: %s, 服務名稱: %s, 容器名稱: %s\n", 
		projectName, serviceName, containerName)

	ip, err := getContainerIP(ctx, containerName)
	if err != nil {
		log.Fatalf("查 IP 失敗: %v", err)
	}

	fmt.Println("找到容器 IP:", ip)

	connStr := fmt.Sprintf("postgres://user:password@%s:5432/demo", ip)

	conn, err := pgx.Connect(ctx, connStr)
	if err != nil {
		log.Fatalf("無法連線資料庫: %v", err)
	}
	defer conn.Close(ctx)

	var now time.Time
	err = conn.QueryRow(ctx, "SELECT now()").Scan(&now)
	if err != nil {
		log.Fatalf("查詢失敗: %v", err)
	}

	fmt.Println("成功連上資料庫，現在時間:", now)
}
```

{{<notice "warning" "常見問題與解決方案">}}
如果你遇到類似以下的錯誤：

```
github.com/docker/docker/client: github.com/docker/docker/client@v0.1.0-alpha.0: parsing go.mod:
module declares its path as: github.com/moby/moby/client
        but was required as: github.com/docker/docker/client
```
1. 初始化 go.mod（如果還沒有的話）：

```bash
go mod init your-project-name
```

2. 在 `go.mod` 修改依賴：

```go
replace github.com/docker/docker => github.com/moby/moby latest
```

3. 下載依賴套件：

```bash
go mod tidy
```
{{</notice>}}

## 執行測試

1. 先啟動 PostgreSQL 容器：

```bash
docker compose up -d db
```

2. 執行 Go 程式：

```bash
go run main.go
```

3. 會看到類似輸出：

```
專案名稱: blog, 服務名稱: db, 容器名稱: blog-db-1
找到容器 IP: 172.19.0.2
成功連上資料庫，現在時間: 2025-08-31 23:05:00.389548 +0800 CST
```

**說明：**
- `blog` 是自動從目錄名稱推導出的專案名稱
- `blog-db-1` 是 Docker Compose 的標準容器命名格式
- 程式會自動解析 `docker-compose.yml` 來取得這些資訊

## 調整使用的 Docker Socket 路徑

### 環境變數
```go
import "os"

func main() {
    // 設定自定義 Docker socket 路徑
    os.Setenv("DOCKER_HOST", "unix:///tmp/docker.sock")
    
    // 其他程式碼保持不變
    cli, err := client.NewClientWithOpts(client.FromEnv)
    // ...
}
```

### 在程式中指定
```go
cli, err := client.NewClientWithOpts(
    client.WithHost("unix:///tmp/docker.sock"),
)
```

### 遠端 Docker Daemon
```go
// TCP 連接
cli, err := client.NewClientWithOpts(
    client.WithHost("tcp://remote-docker-host:2376"),
    client.WithTLSClientConfig("/path/to/ca.pem", "/path/to/cert.pem", "/path/to/key.pem"),
)

// 或使用環境變數
os.Setenv("DOCKER_HOST", "tcp://remote-docker-host:2376")
os.Setenv("DOCKER_TLS_VERIFY", "1")
os.Setenv("DOCKER_CERT_PATH", "/path/to/certs")
```

### 安全考量
```yaml
# 只給 read-only 權限（如果支援）
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
  
# 或使用 Docker-in-Docker (DinD)
services:
  app:
    image: your-app
    depends_on:
      - docker
  docker:
    image: docker:dind
    privileged: true
    environment:
      DOCKER_TLS_CERTDIR: ""
```

* **專案名稱推導規則**：
  - 如果沒有在 `docker-compose.yml` 中指定 `name:`，compose-spec/compose-go 會使用目錄名稱當專案名稱
  - 也可以在 compose 檔案中明確指定：
  ```yaml
  name: my-custom-project-name
  services:
    db:
      # ...
  ```

* **容器命名格式**：Docker Compose 使用 `{projectName}-{serviceName}-{instance}` 格式
  - 舊版本使用底線：`{projectName}_{serviceName}_{instance}`
  - 新版本使用破折號：`{projectName}-{serviceName}-{instance}`

* **指定不同的 compose 檔案**：
  ```go
  composePath := "path/to/your/docker-compose.yml"
  projectName, serviceName, err := getProjectInfo(composePath)
  ```

* 多個 network 時，程式會拿第一個 network 的 IP。實務上可以指定 network 名稱。

* 容器 IP 只在 Docker network 裡有效，外部機器無法直接用。

## 小結

透過結合 [compose-spec/compose-go](https://github.com/compose-spec/compose-go) 套件，我們實現了完全自動化的容器 IP 查詢：

1. **自動解析** docker-compose.yml 檔案
2. **智能推導** 專案名稱和容器名稱
3. **動態查詢** 容器 IP 地址
4. **無需 hardcode** 任何容器相關資訊

這樣做比直接開 `ports` 麻煩一點，但更安全更靈活。
對內網環境或安全要求高的專案，這種方式非常適合。當你的專案有多個環境或經常變更容器配置時，這種自動化方法能大幅減少維護成本。