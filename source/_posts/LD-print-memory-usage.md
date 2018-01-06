---
title: GNU LD print memory usage
categories:
- ノート
tags:
- linker
---

使 GNU LD 輸出總共使用的記憶體大小與程式大小。

Makefile:
```
LDFLAGS += -Wl,--print-memory-usage
```

##  Reference:
- [GNU LD - command options](ftp://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_mono/ld.html#SEC3)

