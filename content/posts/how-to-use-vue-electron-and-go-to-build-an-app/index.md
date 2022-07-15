---
date: 2022-07-15T16:01:27+08:00
title: "使用 Vue、Electron 以及 Go 建立一個小工具"
description: ""
author: "Yuan"
draft: false
tags: ['go','vue','electron']
keywords: []
categories: ["note"]
---

## 前言

最近剛好有機會要寫有圖形化介面的程式。想來想去感覺可以寫寫看 Electron！於是乎本篇就這樣誕生了。
<!--more-->

## 主要內容

### 建立 Vue 專案

```bash
yarn create vite test-001 --template vue
cd test-001
yarn
yarn dev
```

### 加入路徑別名

把專案中的 `src` 加上別名 `@`。

```bash
mv vite.config.js vite.config.cjs.bk

cat << EOF > vite.config.cjs
import { defineConfig } from 'vite'
import Vue from '@vitejs/plugin-vue'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
	plugins: [
		Vue(),
	],
	resolve: {
		alias: {
			'@': path.resolve(__dirname, './src'),
		},
	},
})
EOF
```

### 安裝及設定 Tailwindcss

```bash
yarn add -D tailwindcss postcss autoprefixer
cat << EOF > postcss.config.cjs
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  }
}
EOF

cat << EOF > tailwind.config.cjs
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

mkdir -p src/styles

cat << EOF > src/styles/base.css
@layer base {
    html, body, #app {
        @apply h-full w-full;
    }
    body, #app {
        @apply bg-[#333333];
        @apply font-light;
    }
}
EOF

cat << EOF > src/styles/components.css
@layer components {
    * {
        @apply outline outline-1 outline-red-500;
    }
}
EOF

cat <<EOF > src/styles/index.css
@import "tailwindcss/base";
@import "base.css";

@import "tailwindcss/components";
@import "components.css";

@import "tailwindcss/utilities";
EOF

sed -i "3iimport '@/styles/index.css'" src/main.js

sed -i '/<\/template>/i \ \ \<h1\ class=\"text-red-200\"\>Hello\ world\<\/h1\>' src/App.vue
```

### 加入 Unplugin Icons

```bash

yarn add --dev  unplugin-vue-components unplugin-icons @iconify/json

mkdir -p src/components
sed -i "4iimport Components from 'unplugin-vue-components/vite'" vite.config.cjs
sed -i "4iimport IconsResolver from 'unplugin-icons/resolver'" vite.config.cjs
sed -i "4iimport Icons from 'unplugin-icons/vite'" vite.config.cjs

sed -i '/plugins:/a \ \ \ \ \ Components({\
     dirs: ["src/components"],\
     resolvers: [\
	  IconsResolver({\
	      prefix: false,\
	      enabledCollections: ["mdi"],\
	  })\
      ],\
    }),\
    Icons(),' vite.config.cjs
    
sed -i '/<\/template>/i \ \ \<mdi-account-heart\ \/\>' src/App.vue
```

### 加入 Vue Router 和 vite-plugin-pages

```bash
yarn add vue-router@4
yarn add --dev vite-plugin-pages

mkdir -p src/router

cat << EOF > src/router/index.js
import { createRouter, createWebHistory, createWebHashHistory } from "vue-router";
import routes from "~pages";

const router = createRouter({
  // refer to: https://nklayman.github.io/vue-cli-plugin-electron-builder/guide/commonIssues.html
  history: import.meta.env.PROD ? createWebHashHistory() : createWebHistory(import.meta.env.BASE_URL),
  routes,
});

export default router;
EOF

mkdir -p src/pages
sed -i "4iimport Pages from 'vite-plugin-pages'" vite.config.cjs
sed -i '/plugins:/a \ \ \ \ \ Pages({\
		dirs: [\
			{ dir: "src/pages", baseRoute: "" },\
		],\
	}),' vite.config.cjs

sed -i "3iimport Router from './router'" src/main.js
sed -i 's/createApp(App)/createApp(App).use(Router)/' src/main.js

cat << EOF > src/App.vue
<template>
  <div class="w-full h-full p-1">
    <RouterView></RouterView>
  </div>
</template>
EOF

cat << EOF > src/pages/index.vue
<template>
    <div class="flex w-full h-full rounded overflow-hidden">
        <div :class="[
            'transition-all duration-500 ease-out',
            'h-full w-0 lg:block lg:w-2/12 flex-shrink-0',
            'max-w-xs'
        ]"></div>
        <div class="flex h-full w-full">
          <img src="@/assets/vue.svg" class="w-1/4" alt="Vue logo" />
          <div class="flex flex-col">
              <HelloWorld />
          </div>
        </div>
    </div>
</template>
EOF

```

### 安裝及配置 Electron

```bash
yarn add --dev electron concurrently wait-on cross-env electron-builder

mkdir -p electron

cat << EOF > electron/main.cjs
const { app, BrowserWindow } = require('electron')
const path = require('path')

const NODE_ENV = process.env.NODE_ENV

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    show: false,
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs')
    }
  })

  mainWindow.once('ready-to-show', () => {
    mainWindow.show()
  })

  mainWindow.loadURL(
      NODE_ENV === 'development'
      ? 'http://localhost:5173'
      : \`file://\${path.join(__dirname, '../dist/index.html')}\`
  );

  if (NODE_ENV === "development") {
    mainWindow.webContents.openDevTools()
  }
}

app.whenReady().then(() => {
  createWindow()

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit()
})
EOF

cat << EOF > electron/preload.cjs
window.addEventListener('DOMContentLoaded', () => {
  const replaceText = (selector, text) => {
    const element = document.getElementById(selector)
    if (element) element.innerText = text
  }

  for (const dependency of ['chrome', 'node', 'electron']) {
    replaceText(\`\${dependency}-version\`, process.versions[dependency])
  }
})
EOF

sed -i '/export default/a \ \ \ \ base: "./",' vite.config.cjs

sed -i '/version/a "main": "electron/main.cjs",' package.json

sed -i '/"build/a "electron": "wait-on tcp:5173 && cross-env NODE_ENV=development electron .",' package.json
sed -i '/"build":/a "electron:serve": "concurrently -k \\\"yarn dev\\\" \\\"yarn electron\\\"\",' package.json
sed -i '/"build":/a "electron:build": "vite build && electron-builder",' package.json

sed -i '$d' package.json && sed -i '$d' package.json && cat << EOF >> package.json
  },
  "build": {
    "appId": "com.my-website.my-app",
    "productName": "MyApp",
    "copyright": "Copyright © 2022 Yuan",
    "mac": {
      "category": "public.app-category.utilities"
    },
    "nsis": {
      "oneClick": false,
      "allowToChangeInstallationDirectory": true
    },
    "files": [
      "dist/**/*",
      "electron/**/*"
    ],
    "directories": {
      "buildResources": "assets",
      "output": "dist_electron"
    }
  }
}  
EOF

yarn electron:serve
```

#### 修正安全提示中的

```bash
sed -i '/<meta name/a \ \ \ \ \<meta http-equiv="Content-Security-Policy" content="script-src '\''self'\''" /\>' index.html

```

### Add Makefile

為了不用每次編譯時要下什麼指令，所以寫個 Makefile 省心 ~

```bash
TAB="$(printf '\t')"

cat << EOF > Makefile
all: run

build:
${TAB}yarn electron:build

.PHONY: web
web:
${TAB}yarn dev

.PHONY: run
run:
${TAB}yarn electron:serve

.PHONY: clean
clean:
${TAB}\$(RM) -r dist dist_electron
EOF
```

### 額外記下來的

順手記下這次有用到的一些東西。

#### 使用 Axios

```bash
yarn add axios

mkdir -p src/composables

echo << EOF > src/composables/useApi.js
import axios from 'axios';

const instance = axios.create({
  baseURL: 'http://localhost:8088/',
  timeout: 1000,
  headers: {
    "Content-Type": "application/json",
  }
});

const useAxios = ({url, method, arg}) => { 
    return instance[method](url, arg)
}

export default useAxios;
EOF
```


#### Electron 建立視窗後在背景做點事

```javascript
app.on('ready', async () => {
  const { execFile } = require('child_process')
  
  execFile('./resources/server/CCSNoteServer.exe')
  
  createWindow()
})
```

```
const { ipcRenderer } = require('electron')
```

## 小結

筆都在這一篇快要完成的時候更新了 vite 的版本，從 vite 2.99 更新到 3.0.0。
接下來世界就變了 🤣

{{< figure src="images/vite-cjs.png" caption="migrate to ESM" >}}

vite 預設使用的 Port 從 3000 改到了 5173。

{{< figure src="images/vite-default-port.png" caption="dev port" >}}

修正後基本上只要把上面的指令直接貼在終端機中就可以了。

最後附上執行結果！

```bash
make
```

{{< figure src="images/vue-electron.png" caption="screenshot" >}}

## 參考連結

- [Vite+Electron快速构建一个VUE3桌面应用(一)][1]
- [[个人项目] 用 Electron + Vue3 + Golang 做个一个桌面 Markdown 笔记软件][2]
- [electron12起，如何解决require is not defined的问题？][3]
- [cawa-93/vite-electron-builder][4]

[1]:https://github.com/Kuari/Blog/issues/52
[2]:https://juejin.cn/post/7056686048058802212
[3]:https://newsn.net/say/electron-require-is-not-defined-2.html
[4]:https://github.com/cawa-93/vite-electron-builder