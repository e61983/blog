---
date: 2017-10-18T00:25:49+08:00
title: "C11 Generic Selections"
description: ""
author: "Yuan"
draft: false
tags: ["c11"]
keywords: [""]
categories: ["c language"]
---

## 前言

Generic 在C11上出現，我們可以透過實作出物件導向中的多型。要注意的是 Generic 是在編譯時期運作的。

<!--more-->

## 主要內容

```c
#include <stdio.h>
void funci(int x) { printf("func value = %d\n", x); }
void funcc(char c) { printf("func char = %c\n", c); }
void funcdef(double v) { printf("Def func's value = %lf\n", v); }
#define func(X) \
    _Generic((X), \
        int: funci, char: funcc, default: funcdef \
    )(X)
int main() {
        func(1);
        func('a');
        func(1.3);
        return 0;
}
```

在多個參數的使用上比較繁瑣，需要自行作每個參數的組合。

```c
#define format2(x,y) _Generic((x), \
    char: _Generic((y), \
        char:"%c - %c\n", \ char*:"%c - %s\n", \
        int:"%c - %d\n", \
        default:"error\n" \
        ), \
    char*: _Generic((y), \
        char:"%s - %c\n", \
        char*:"%s - %s\n", \
        int:"%s - %d\n", \
        default:"error\n" \
        ), \
    int: _Generic((y), \
        char:"%d - %c\n", \
        char*:"%d - %s\n", \
        int:"%d - %d\n", \
        default:"error\n" \
        ), \
    default:"error\n" \
  )

#define print2(x, y) printf(format2(x,y),x,y)
int main(int argc, char **argv)
{
    printf("test 2 parameters\n");
    print2(3, 'c');
    return 0;
}
```
