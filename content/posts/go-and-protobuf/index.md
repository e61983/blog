---
date: 2022-08-09T23:20:07+08:00
title: "在 Go 中與 Protobuf 共舞 ？！"
description: ""
author: "Yuan"
draft: false
tags: ["go","protobuf"]
keywords: []
categories: ["note"]
---

## 前言

會有這一篇的誕生是因為原本在寫 gRPC 的筆記時發現篇幅太長，想說還是拆開寫好了。於是乎這一篇就出現了。

<!--more-->

## 主要內容

本篇我們會先對 Protocol Buffer 的語法進行瞭解，接著撰寫、並轉譯一個範例，最後實際的跑一個範程式。

> Protocol Buffers（簡稱：ProtoBuf）是一種開源跨平台的序列化資料結構的協定。其對於儲存資料或在網路上進行通訊的程式是很有用的。這個方法包含一個介面描述語言，描述一些資料結構，並提供程式工具根據這些描述產生程式碼，這些代碼將用來生成或解析代表這些資料結構的位元組流。
資料來源: https://zh.wikipedia.org/zh-tw/Protocol_Buffers

### 資料型態

- int / int32 / int64
- uint / uint32 / uint64
- bool
- float
- double
- bytes
- string
- enum ( Enumeration )

	 first defined enum value, which must be 0.
- map
- any
- timestamp / duration

可以參考[這裡][3]

### 資料欄修飾字
- oneof
- required
	表示該資料欄是必要的。
- optional
	指該資料欄是可選的 (0筆或1筆)。
- repeated
	指該資料欄是可以有多筆的。
- reserved 


### 範例

```proto
syntax = "proto3";

option go_package = "foo.example.idv/protobuf/example";

import "google/protobuf/timestamp.proto";

message Employee {
	string name = 1;
	google.protobuf.Timestamp Birthday = 2;
};

message Company {
	string name = 1;
	repeated Employee employees = 2;
};
```

### 安裝 Protocol Buffer 編譯器

```bash
brew install protobuf
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
```

### 產生相應的 Go 程式碼

```bash
protoc --go_out=. \
    --go_opt=paths=source_relative \
    protobuf/example/foo.proto
```

{{< notice info >}}
如果出現 
```protoc-gen-go: program not found or is not executable``` 

這個錯誤，請同學先確認一下 `~/go/bin` 是否有在你的 $PATH 中。
如果沒有就把它加進去吧！
你可以

```export PATH=$HOME/go/bin:$PATH```
{{< /notice>}}


#### 結果

```bash
ls
foo.pb.go foo.proto
```

### 實際用看看

我們來撰寫一支程式，實際的使用剛剛產生的程式碼。它會建立一個使用 protobuf 結構的序列化檔案 foo。並且再將它讀回並顯示出來。 

```go

 com := &example.Company{
        Name: "FooBarBar",
        Employees: []*example.Employee{
            {Name:"Alice"},
            {Name:"Bonny"},
            {Name:"Candy"},
        },
    }
    
    out, err := proto.Marshal(com)
    if err != nil {
        log.Fatalln("Failed to encode address book:", err)
    }
    if err := ioutil.WriteFile("foo", out, 0644); err != nil {
        log.Fatalln("Failed to write company:", err)
    }

    in, err := ioutil.ReadFile("foo")
    if err != nil {
        log.Fatalln("Error reading file:", err)
    }
    
    com2 := &example.Company {}
    if err := proto.Unmarshal(in, com2); err != nil {
        log.Fatalln("Failed to parse company:", err)
    }


```

### 實際來一遍

```bash
mkdir -p test/protobuf/example
cd test
cat << EOF > protobuf/example/foo.proto
syntax = "proto3";
option go_package = "foo.example.idv/protobuf/example";

import "google/protobuf/timestamp.proto";

message Employee {
	string name = 1;
	google.protobuf.Timestamp Birthday = 2;
};

message Company {
	string name = 1;
	repeated Employee employees = 2;
};
EOF

cat << EOF > main.go
package main

import (
	"fmt"
	"io/ioutil"
	"log"

	"foo.example.idv/protobuf/example"
	"google.golang.org/protobuf/proto"
)

func main(){
    com := &example.Company{
        Name: "FooBarBar",
        Employees: []*example.Employee{
            {Name:"Alice"},
            {Name:"Bonny"},
            {Name:"Candy"},
        },
    }
    fmt.Println("original")
    fmt.Println(com)
    fmt.Println("==============================")
    out, err := proto.Marshal(com)
    if err != nil {
        log.Fatalln("Failed to encode address book:", err)
    }
    if err := ioutil.WriteFile("foo", out, 0644); err != nil {
        log.Fatalln("Failed to write company:", err)
    }

    in, err := ioutil.ReadFile("foo")
    if err != nil {
        log.Fatalln("Error reading file:", err)
    }
    com2 := &example.Company {}
    if err := proto.Unmarshal(in, com2); err != nil {
        log.Fatalln("Failed to parse company:", err)
    }
    fmt.Println("read from file")
    fmt.Println(com2)
}
EOF
go mod init foo.example.idv
go get google.golang.org/protobuf/proto
protoc --go_out=. --go_opt=paths=source_relative protobuf/example/foo.proto
go mod tidy
clear
go run main.go
```

#### 結果

```bash
original
name:"FooBarBar" employees:{name:"Alice"} employees:{name:"Bonny"} employees:{name:"Candy"}
==============================
read from file
name:"FooBarBar" employees:{name:"Alice"} employees:{name:"Bonny"} employees:{name:"Candy"}
```

## 小結

本文的介紹十分的簡約，如果想要瞭解更多可以參考官方網站的說明。
如果對 `protobuf` 實際的資料結構有興趣不仿可以對著官方文件研究一下 `實際來一遍` 所產生的 `foo` 檔案。

## 參考連結

- [Protocol Buffer Basics: Go][1]
- [Protocol Buffer - Scalar Value Types][2]
- [Go Generated Code][3]

[1]:https://developers.google.com/protocol-buffers/docs/gotutorial
[2]:https://developers.google.com/protocol-buffers/docs/proto3#scalar
[3]:https://developers.google.com/protocol-buffers/docs/reference/go-generated