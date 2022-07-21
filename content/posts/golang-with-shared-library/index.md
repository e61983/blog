---
date: 2022-07-21T13:16:54+08:00
title: "Go語言、動態連結函式庫與它們的產地"
description: ""
author: "Yuan"
draft: false
tags: ["go","c","library"]
keywords: []
categories: ["note"]
---

## 前言

最近寫 Go 時想嘗試使用動態連結函式庫。於是乎這一篇就誔生了。
本文會試著使用 Go 編出一個動態連結函式庫，並使用 C 語言程式以及 Go 語言程式呼叫它。
<!--more-->

## 主要內容

### 動態連結函式庫

官方文件中有提到，可以被呼叫的函式要使用 `export 註解` 來提示 cgo。

> -buildmode=c-shared
	Build the listed main package, plus all packages it imports,
	into a C shared library. The only callable symbols will
	be those functions exported using a cgo //export comment.
	Requires exactly one main package to be listed.

#### 程式碼 (hello.go)

```go
package main

import "C"

//export hello
func hello() {
	println("Hello, world! Library")
}

/* 
   We need the main function to make possible 
   cgo compiler to compile the package as c shared 
   library.
*/
func main() {}
```

#### 編譯

```bash
go build -buildmode=c-shared -o libhello.so hello.go
```

#### 結果

```bash
libhello.h libhello.so
```

### C 語言程式

main.c

```c
#import <stdio.h>
#import "libhello.h"

int main(int argc, char *argv[]) {
	printf("Hello world C !\n");
	hello();
	return 0;
}
```

#### 編譯

```bash
gcc -o main_c.out -L. -I. -lhello main.c
```

#### 結果

```bash
./main_c.out
Hello world C !
Hello, world! Library
```

### Go 語言程式 v1

main.go

```go
package main

// #cgo LDFLAGS: -lhello -L.
// #include <libhello.h>
import "C"
import "fmt"

func main() {
	fmt.Println("Hello world Go!")
	C.hello()
}
```

#### 編譯

```bash
go build -o main_go.out  main.go
```

### Go 語言程式 v2

main_dl.go

```go
package main

// #cgo LDFLAGS: -ldl
// #include <dlfcn.h>
import "C"
import (
	"fmt"
	"unsafe"
)

// load dynamic library
func load(path string) (unsafe.Pointer, error) {
	handle, err := C.dlopen(C.CString(path), C.RTLD_LAZY)
	if err != nil {
		return nil, err
	}
	return handle, nil
}

// get symbol 
func findSym(lib unsafe.Pointer, sym string) (unsafe.Pointer, error) {
	pc := C.dlsym(lib, C.CString(sym))
	if pc == nil {
		return nil, fmt.Errorf("find symbol %s failed", sym)
	}
	return pc, nil
}

// unload dynamic library
func unload(lib unsafe.Pointer) error {
	if C.dlclose(lib) != 0 {
		return fmt.Errorf("unload library failed")
	}
	return nil
}

// entry point function
func main() {
	println("Hello World")

	lib, err := load("./libhello.so")
	if err != nil {
		panic(err)
	}
	defer unload(lib)

	addr, err := findSym(lib, "hello")
	if err != nil {
		panic(err)
	}

	var hello func()

	p := &addr
	hello = *(*func())(unsafe.Pointer(&p))
	
	hello()
}
```

#### 編譯

```bash
go build -o main_go_dl.out  main_dl.go
```

## 小結

原本也想試試 Node.js 的使用動態連結函式庫的部份。但是相關的函式庫 `ffi` 一直無法正常的安裝，最後就沒有往下測了。

## 參考連結

- [go build mode][1]
- [Golang生成共享庫(shared library)以及Golang生成C可調用的動態庫.so和靜態庫.a][2]
- [vladimirvivien/go-cshared-examples][3]

[1]:https://pkg.go.dev/cmd/go#hdr-Build_modes
[2]:https://www.twblogs.net/a/5b7d13442b71770a43ddcac9
[3]:https://github.com/vladimirvivien/go-cshared-examples
