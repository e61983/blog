---
date: 2022-08-22T14:43:42+08:00
title: "如何在 Go 中使用 Redis"
description: ""
author: "Yuan"
draft: true
tags: ["go","redis"]
keywords: []
categories: ["note"]
---

## 前言

最近想試著使用 Redis ，於是乎這一篇就誕生了！
<!--more-->
本文會使用 Docker 來建立測試用的 Redis Server，並使用 Go 語言來寫入、讀取資料。

## 主要內容

### Redis Server

我們要使用 Docker 來快速的起一個 redis。雖然參考官方文件輸入 docker 指令就可以了，但筆者還是喜歡用 docker-compose 進行操作。所以下列也提供 docker-compse.yaml 的內容。

#### Docker 黨

```bash
docker run --name my-redis --rm -it -v 6379:6379 redis:7-alpine
```

#### Docker-compose 黨

docker-compose.yaml:

```yaml
version: "3.9"
services:
  redis:
    image: redis:7-alpine
    ports:
      - 6379:6379
    restart: "no"
```

然後

```bash
docker-compose up
```

### Go-Redis

這邊也是照著官方的文件操作就可以了！

```bash
go get github.com/go-redis/redis/v9
```

#### 連線到 redis

```go
rdb := redis.NewClient(&redis.Options{
	Addr:	  "localhost:6379",
	Password: "", // no password set
	DB:		  0,  // use default DB
})

pong, err := rdb.Ping(ctx).Result()
if err != nil {
    panic(err)
}
```

#### 寫入值

```go
if err := rdb.Set(ctx, "key2", "value_2", 0).Err(); err != nil {
	return err
}
```

#### 讀取值

```go
value, err := client.Get(ctx, "key2").Result()
if err == redis.Nil {
    fmt.Println("value does not exist")
} else if err != nil {
    fmt.Println("client.Get failed", err)
} else {
    fmt.Println("key2", value)
}
```

### 完整檔案

main.go

```go
func main() {
	ctx := context.Background()
	rdb := redis.NewClient(&redis.Options{
		Addr: "localhost:6379",
	})

	if pong, err := rdb.Ping(ctx).Result(); err != nil {
		panic(err.Error())
	} else {
		fmt.Println(pong)
	}

	if err := rdb.Set(ctx, "key", 1, 0).Err(); err != nil {
		panic(err.Error())
	}

	value, err := rdb.Get(ctx, "key").Int64()
	if err == redis.Nil {
		fmt.Printf("value - %d\n", 0)
	} else if err != nil {
		fmt.Printf("value - %s\n", err.Error())
	} else {
		fmt.Printf("value - %d\n", value)
	}
}
```

### 結果

```bash
PONG
value - 1
```

## 小結

本篇只是順手將找尋的資料以及測試用的程式記下來。未來如果有新的發現，或許會繼續的更新！

## 參考連結

- [Docker Hub - Redis][1]
- [go-redis][2]
- [Redis還在學系列][3]

[1]:https://hub.docker.com/_/redis
[2]:https://redis.uptrace.dev/guide/go-redis.html
[3]:https://ithelp.ithome.com.tw/users/20111658/ironman/4426?page=1
