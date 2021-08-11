---
date: 2021-08-04T14:43:00+08:00
title: "使用 Leaflet 地圖"
description: ""
author: "Yuan"
draft: false
tags: ["map","leaflet","geojson"]
keywords: []
categories: ["website", "gis"]
resources:
- src: "images/first-map.png"
- src: "images/leaflet-mapbox.png"
- src: "images/add-marker.png"
- src: "images/add-custom-marker.png"
- src: "images/add-line.png"
- src: "images/add-controller.png"
- src: "images/add-geolayer.png"
---

## 前言

最近剛好要更新地圖應用。先前是直接使用 Mapbox ，但覺得它的 Marker 操作起來不是很彈性。因緣際會下聽說了 Leaflet ，就來試看看吧。

維基百科是這樣說的。

> Leaflet是一個開源的JavaScript庫，用於構建Web地圖應用。首次發布於2011年，[2]它支持大多數移動和桌面平台，支持HTML5和CSS3。

<!--more-->

## 主要內容


### 安裝方式

本文撰寫時會以 CDN 的方式引入 Leaflet.js，實際使用時筆者是會使用套件管理工具進行安裝。
安裝方式:

```bash
yarn add leaflet
```

使用 CDN 的方式:

```javascript
 <link rel="stylesheet" href="https://unpkg.com/leaflet@1.7.1/dist/leaflet.css"
   integrity="sha512-xodZBNTC5n17Xt2atTPuE1HxjVMSvLVW9ocqUKLsCC5CXdbqCmblAshOMAS6/keqq/sMZMZ19scR4PsZChSR7A=="
   crossorigin=""/>
   
<!-- Make sure you put this AFTER Leaflet's CSS -->
 <script src="https://unpkg.com/leaflet@1.7.1/dist/leaflet.js"
   integrity="sha512-XQoYMqMTK8LvdxXYG3nZ448hOEQiglfqkJs1NOQV44cWnUrBc8PkAOcXy20w0vlaXaVUearIOBhiXZ5V3ynxwA=="
   crossorigin=""></script>
```

### 起手式

在網頁中加入

```html
<div id="map" style="width:95vw;height:95vh" />
```

初始化地圖

```javascript
var map = L.map('map').setView([34.985851028839406, 135.75788488621308], 10);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png?{foo}',
  {
    foo: 'bar', 
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map);
```

{{< figure src="images/first-map.png" caption="我們的第一張地圖" >}}

如果我們想要使用 Mapbox 的圖資，在已取得存取金鑰之後(Access Toekn)，可在建立 titleLayer 時改用下列方式初始化。

```javascript
var map = L.map('map').setView([34.985851028839406, 135.75788488621308], 10);
L.tileLayer(''https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
  {
    attribution: '&copy; <a href="https://www.mapbox.com/about/maps/">Mapbox</a> contributors'
    maxZoom: 18,
    zoomOffset: -1,
    tileSize: 512,
    id: 'mapbox/streets-v11',
    accessToken: token
  }).addTo(map);
```
{{< figure src="images/leaflet-mapbox.png" caption="使用 Mapbox 圖資" >}}

如果想要移除預設的 zoom controller 可以在初始化的時候加上 `zoomControl: false`

```javascript
var map = L.map('map', {zoomControl: false}).setView([34.985851028839406, 135.75788488621308], 10);
```

### 加上 Marker 

在 Leaflet 中加上 marker 就跟呼吸一樣自然。

```javascript
L.marker([35.04074994371372, 135.72932367775914]).addTo(map);
L.marker([34.97374817523019, 135.77195253085293]).addTo(map);
L.marker([34.99936852552379, 135.7854861479551]).addTo(map);
```

{{< figure src="images/add-marker.png" caption="加上 marker" >}}

如果想要改變樣式，可以透過 `icon` 或是 `iconDiv` 來更改。

```javascript
var myIcon = L.icon({
    iconUrl: 'marker.png',
    iconSize: [100, 95],
    iconAnchor: [22, 94],
    popupAnchor: [-3, -76],
    shadowUrl: 'my-icon-shadow.png',
    shadowSize: [68, 95],
    shadowAnchor: [22, 94]
});
L.marker([34.70432671595862, 135.50096236284378], {
	icon: myIcon
}).addTo(map);
```

```javascript
var myDivIcon = L.divIcon({
    className:'my-div-icon-wrapper',
    html:`<div>這是 Div Icon </div>`
});
L.marker([34.68985107822455, 135.5253549268327], {
	icon: myDivIcon
}).addTo(map);
```

```css
.my-div-icon-wrapper div{
    width: 100px;
    background-color: #060390;
    color: #eee;
    text-align: center;
}
```

{{< figure src="images/add-custom-marker.png" caption="加上 marker" >}}

### 來畫線吧

```javascript
var latlngs = [
    [35.02537491062854, 135.7438607946139],
    [34.88948810597932, 135.8076289149232],
    [34.961035819215525, 135.65613226663768],
    [34.976863645786004, 135.82695459531024],
    [34.88036360232042, 135.7002729085305],
    [35.02537491062854, 135.7438607946139],
];
L.polyline(latlngs, {color: 'red'}).addTo(map);
```

{{< figure src="images/add-line.png" caption="來個封印陣吧!" >}}

### 群組化並加上控制項

我們可以把想要歸在一起的東西放到同一個群組，這樣在接下來要分層顯示的時候，會更簡便一些。

讓我們稍微調整一下程式碼。

```javascript
...

let layer1 = L.layerGroup([
    L.marker([35.04074994371372, 135.72932367775914]),
    L.marker([34.97374817523019, 135.77195253085293]),
    L.marker([34.99936852552379, 135.7854861479551])
]).addTo(map);

...

let layer2 = L.layerGroup([
    L.marker([34.70432671595862, 135.50096236284378], { icon: myIcon }),
    L.marker([34.68985107822455, 135.5253549268327], { icon: myDivIcon })
]).addTo(map);

...

let layer3= L.layerGroup([
    L.polyline(latlngs, {color: 'red'})
]).addTo(map);

```

將我們群組化後的 Layer 加入控制項中。

```javascript
let controller = L.control.layers().addTo(map);
controller.addOverlay(layer1,"Marker");
controller.addOverlay(layer2,"自定的Marker");
controller.addOverlay(layer3,"封印陣");
controller.expand();
```

{{< figure src="images/add-controller.png" caption="加入控制項" >}}

補充一下，如果想移除各個 Layer 的話可以透過下列方式，移除

```javascript
map.value.eachLayer((layer) => {
    if (layer instanceof L.Marker) {
        map.value.removeLayer(layer);
    }
});


// or 

layer1.remove();
```

### 20210808 新增 - geoJSON Layer

測試資料可以到[政府開放資料平台][4]取得。

```javascript

let data = {"type":"FeatureCollection", "features": [
"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[121.543841724,25.0449066970000,...................... ]]]
]}

function onEachFeature(feature, layer) {
  if (feature.properties && feature.properties.TOWNNAME) {
    layer.bindPopup(feature.properties.TOWNNAME);
  }
}

L.geoJSON(data, {
    onEachFeature: onEachFeature,
    filter: function(feature, layer) {
        return feature.properties.TOWNNAME == '大安區';
    },
    style: function(feature) {
        switch (feature.properties.TOWNNAME) {
            case '大安區': return {color: "#00ff00",weight:1};
            default: return {color: "#333333",weight:1,opacity:0.5 };
        }
    }
}).addTo(map);
```

{{< figure src="images/add-geolayer.png" caption="使用 geolayer" >}}

### 成果

<iframe width="100%" height="500" src="//jsfiddle.net/e61983/m96ncL4z/14/embedded/" allowfullscreen="allowfullscreen" allowpaymentrequest frameborder="0"></iframe>

## 小結

使用 Leaflet 之後，不管是在操作 Marker 還是要建立 Path 都變得更加容易了。只能說是相見恨晚!

## 參考連結

- [Leafletjs][1]
- [Migrate Mapbox Static Title API][2]
- [Leaflet-providers preview][3]

[1]:https://leafletjs.com/
[2]:https://docs.mapbox.com/help/troubleshooting/migrate-legacy-static-tiles-api/
[3]:http://leaflet-extras.github.io/leaflet-providers/preview/index.html
[4]:https://data.gov.tw/dataset/7438
