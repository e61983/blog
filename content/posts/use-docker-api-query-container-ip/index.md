---
title: "在 Go 裡直接抓 Docker 容器 IP，連線 PostgreSQL"
date: 2025-08-28T00:47:35+08:00
draft: true
---

## 前言

開發環境裡，我們常用 **Docker Compose** 來啟動資料庫。像是 PostgreSQL 這種服務，我們通常會這樣做：

```yaml
ports:
  - "5432:5432"
```

這樣就能用 `localhost:5432` 直接連資料庫，簡單又方便。

不過有些時候，我們不想把資料庫埠口對外暴露，想完全在 Docker network 裡面連線。  
問題是，容器的 IP 會變啊，每次重啟都不一樣，怎麼辦？

答案是：別手動 `docker inspect`，直接在 Go 裡用 **Docker API** 查 IP 就好。  
查完 IP，再用它去連 PostgreSQL，完全自動化，安全又乾淨。

<!--more-->

## Docker Compose 範例

最小化的 `docker-compose.yaml` 長這樣：

```yaml
version: "3.9"
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

我們會用兩個套件：

* `github.com/docker/docker/client` → 查容器資訊
* `github.com/jackc/pgx/v5` → 連 PostgreSQL

程式流程很簡單：

1. 先用 Docker API `ContainerInspect` 拿容器資訊
2. 從 `NetworkSettings.Networks` 讀 IP
3. 拼成連線字串，丟給 pgx 連資料庫

程式碼如下：

```go
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/docker/docker/client"
	"github.com/jackc/pgx/v5"
)

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

	ip, err := getContainerIP(ctx, "db")
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

	var now string
	err = conn.QueryRow(ctx, "SELECT now()").Scan(&now)
	if err != nil {
		log.Fatalf("查詢失敗: %v", err)
	}

	fmt.Println("成功連上資料庫，現在時間:", now)
}
```

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
找到容器 IP: 172.19.0.2
成功連上資料庫，現在時間: 2025-08-28 01:00:00.123456+00
```

## 注意事項

* 這段程式會呼叫 **Docker Daemon API**，需要存取 `/var/run/docker.sock`。
  如果 Go 程式也跑在容器裡，記得掛進去：

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

* 多個 network 時，程式會拿第一個 network 的 IP。實務上可以指定 network 名稱。

* 容器 IP 只在 Docker network 裡有效，外部機器無法直接用。

## 小結

這樣做比直接開 `ports:` 麻煩一點，但更安全。  
對內網環境或安全要求高的專案，這種方式非常適合。