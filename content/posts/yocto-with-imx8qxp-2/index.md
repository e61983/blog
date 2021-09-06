---
date: 2021-09-02T13:36:25+08:00
title: "在 i.MX 8QuadXPlus 上使用 Yocto 建置 Linux 系統 2"
subtitle: "修改預設的除錯埠至 UART2"
description: ""
author: "Yuan"
draft: false
tags: ["i.mx8qxp","device tree","yocto","linux"]
keywords: []
categories: ["embedded system"]
---

## 前言

繼上一篇我們建立了可開機的映像檔後，接下來我們要來修改修改預設的除錯埠。從 UART0 改至 UART2。
<!--more-->

## 主要內容

### 寫在開始之前

在 Yocto 專案中，有關硬體的配置都會記錄在 Machine Layer。所以我們要先從  Machine 配置檔找到相關的資訊，再開始修改。
在找到 u-boot 相關的資訊後，我們可能要修改:
1. 裝置樹 ( Devicetree )
2. GPIO初始化 (時序、iomux)
3. 除錯埠相關設定
4. Kernel 開機參數

### UART2 在哪裡

從主板上我們可以看到有一組 DB9 的連接埠，上面寫著 RS232。但我們要如何知道它是哪一個 UART 埠呢?

{{< figure src="images/uart2-photo.png" caption="主板上的 UART2" >}}

我們可以從官方提供的電路圖來看，先找到 J37 (主板上有寫) 的元件。再從此開始一路的往源頭找。

{{< figure src="images/uart2-db9.png" caption="UART2 DB9" >}}
{{< figure src="images/bb_uart2.png" caption="電路圖" >}}

最後我們可以看到它是接在 i.mx8qxp 的 `AD34` 與 `AD35` 上。

{{< figure src="images/cpu_uart2.png" caption="電路圖" >}}

我們可以看到 `AD34` 與 `AD35` 即是 `UART2_RX` 與 `UART2_TX` 。

{{< figure src="images/ad34_ad45.png" caption="i.MX 8QuadXPlus and 8DualXPlus Automotive and Infotainment Applications Processors, P128" >}}

也可以在參考手冊找到 UART2 的暫存器位置。

{{< figure src="images/uart2_address.png" caption="i.MX 8DualX/8DualXPlus/8QuadXPlus Applications Processor Reference Manual, P31" >}}

### 測試 UART2 是否正常

在這裡我們可以先將 **boot** 切換至 eMMC 並從新開機。
連接好 i.mx8qxp 後，我們可以在 Host 端使用習慣的 RS232 工具軟體開啟 RS232 串列埠。
接著在 i.mx8qxp 上配置好 UART2 的鮑率後，就可以進行測試了。

> 如果主板的 eMMC 中並沒有可用的系統，關於這一點，以後我們會專門製作一篇為大家講解.。
 
在 Host 端:

```bash
screen /dev/tty.XXXXX 115200
```

在 i.mx8qxp 端:

```bash
# 修改 ttyLP2 所使用的鮑率
stty -F /dev/ttyLP2 115200

echo "Hello Word!" > /dev//dev/ttyLP2
```

### 修改 U-Boot

#### 來自 Machine Layer 的訊息

我們在[上一篇]({{< ref "yocto-with-imx8qxp/#建立-yocto-環境" >}})是指定 `imx8qxpc0mek` 為目標機器，所以我們可以先找到此配置檔。

```bash
cd imx-yocto-bsp/sources
find . -iname "*imx8qxpc0mek*"

# Output:
# ./meta-imx/meta-bsp/conf/machine/imx8qxpc0mek.conf
```

#### U-Boot 相關配置

在找到目標機器的配置檔後，我們可以找詢有關 `VIRTUAL/BOOTLOADER` 或是 `VIRTUAL/UBOOT` 相關的設定。
如果沒有看到相關設定的話，我們可以再往它的 `require` 或是 `include` 檔查找。

在 **imx8qxp-mek.conf** 我們知道了 U-Boot 的 defconfig 檔, 檔名為 **imx8qxp_mek**

{{< figure src="images/imx8qxp-mek.conf.png" caption="imx8qxp-mek.conf" >}}

{{< notice info "imx8qxpc0mek.conf 引用路徑(非完整)" >}}
- imx-yocto-bsp/sources/meta-imx/meta-bsp/conf/machine/imx8qxpc0mek.conf
	- require imx-yocto-bsp/sources/meta-freescale/conf/machine/imx8qxp-mek.conf
		- require imx-yocto-bsp/sources/meta-freescale/conf/machine/include/imx8x-mek.inc 
			- require imx-yocto-bsp/sources/meta-freescale/conf/machine/include/imx-base.inc 
{{< /notice >}}

#### 確認 U-Boot 套件資訊

我們可以透過找尋下列變數，來找到使用的 U-Boot Package 名稱。

- PREFERRED_PROVIDER_u-boot
- PREFERRED_PROVIDER_virtual/bootloader

在編譯過後，原始碼可以在 ${WORK_DIR} 資料夾中找到。

```bash
ls imx-yocto-bsp/first-build/tmp/work/imx8qxpc0mek-poky-linux/u-boot-imx/1_2021.04-r0/git

# Output:
# api     config.mk  dts                    include   MAINTAINERS  scripts
# arch    configs    env                    Kbuild    Makefile     test
# board   disk       examples               Kconfig   net          tools
# cmd     doc        fs                     lib       post
# common  drivers    imx8qxp_mek_defconfig  Licenses  README
```

不過我們其實也可以直接使用 `devshell` ，在 devshell 環境進行修改就可以了。

#### 確認 U-Boot 開機時使用的裝置樹(Devicetree)

開機所使用的裝置樹資訊，會記錄在 `defconfig` 中，我們可以在 `configs` 中找詢 **imx8qxp_mek_defconfig** 配置檔。從配置檔中，我們可以看到它是使用 **fsl-imx8qxp-mek**。

這個檔案我們可以在 `/arch/arm/dts/` 中看到。

{{< figure src="images/imx8qxp_mek_defconfig.png"  caption="imx8qxp_mek_defconfig" >}}


#### 修改 U-Boot 裝置樹(Devicetree)

在找尋的過程中發現 **fsl-imx8qxp-ai_ml.dts** 是使用 UART2 作為預設的輸出，所以我們可以參考它來進行修改。

下列是我們會修改到的檔案:
- arch/arm/dts/fsl-imx8dx.dtsi
- arch/arm/dts/fsl-imx8qxp-mek-u-boot.dtsi
- arch/arm/dts/fsl-imx8qxp-mek.dts

```bash
bitbake -c devshell virtual/bootloader
```

```diff
diff --git a/arch/arm/dts/fsl-imx8dx.dtsi b/arch/arm/dts/fsl-imx8dx.dtsi
index a36bf388c7..4d2606defe 100644
--- a/arch/arm/dts/fsl-imx8dx.dtsi
+++ b/arch/arm/dts/fsl-imx8dx.dtsi
@@ -975,25 +975,7 @@
                reg = <SC_R_UART_2>;
                #power-domain-cells = <0>;
                power-domains = <&pd_dma>;
-               #address-cells = <1>;
-               #size-cells = <0>;
                wakeup-irq = <347>;
-
-               pd_dma2_chan12: PD_UART2_RX {
-                   reg = <SC_R_DMA_2_CH12>;
-                   power-domains =<&pd_dma_lpuart2>;
-                   #power-domain-cells = <0>;
-                   #address-cells = <1>;
-                   #size-cells = <0>;
-
-                   pd_dma2_chan13: PD_UART2_TX {
-                       reg = <SC_R_DMA_2_CH13>;
-                       power-domains =<&pd_dma2_chan12>;
-                       #power-domain-cells = <0>;
-                       #address-cells = <1>;
-                       #size-cells = <0>;
-                   };
-               };
            };
            pd_dma_lpuart3: PD_DMA_UART3 {
                reg = <SC_R_UART_3>;
@@ -2839,10 +2821,7 @@
        clock-names = "per", "ipg";
        assigned-clocks = <&clk IMX8QXP_UART2_CLK>;
        assigned-clock-rates = <80000000>;
-       power-domains = <&pd_dma2_chan13>;
-       dma-names = "tx","rx";
-       dmas = <&edma2 13 0 0>,
-           <&edma2 12 0 1>;
+       power-domains = <&pd_dma_lpuart2>;
        status = "disabled";
    };
diff --git a/arch/arm/dts/fsl-imx8qxp-mek-u-boot.dtsi b/arch/arm/dts/fsl-imx8qxp-mek-u-boot.dtsi
index 5327485bfa..7df4d1bb5e 100644
--- a/arch/arm/dts/fsl-imx8qxp-mek-u-boot.dtsi
+++ b/arch/arm/dts/fsl-imx8qxp-mek-u-boot.dtsi
@@ -68,6 +68,10 @@
 	u-boot,dm-spl;
 };

+&pinctrl_lpuart2 {
+	u-boot,dm-spl;
+};
+
 &pinctrl_usdhc1 {
 	u-boot,dm-spl;
 };
@@ -136,6 +140,10 @@
 	u-boot,dm-spl;
 };

+&pd_dma_lpuart2 {
+	u-boot,dm-spl;
+};
+
 &pd_conn_usbotg0 {
 	u-boot,dm-spl;
 };
@@ -208,6 +216,10 @@
 	u-boot,dm-spl;
 };

+&lpuart2 {
+	u-boot,dm-spl;
+};
+
 &usbmisc1 {
 	u-boot,dm-spl;
 };
diff --git a/arch/arm/dts/fsl-imx8qxp-mek.dts b/arch/arm/dts/fsl-imx8qxp-mek.dts
index 86aa868479..a5a5c5e49d 100644
--- a/arch/arm/dts/fsl-imx8qxp-mek.dts
+++ b/arch/arm/dts/fsl-imx8qxp-mek.dts
@@ -21,8 +21,8 @@
 	};

 	chosen {
-		bootargs = "console=ttyLP0,115200 earlycon";
-		stdout-path = &lpuart0;
+		bootargs = "console=ttyLP2,115200 earlycon";
+		stdout-path = &lpuart2;
 	};

 	regulators {
@@ -126,6 +126,13 @@
 			>;
 		};

+		pinctrl_lpuart2: lpuart2grp {
+			fsl,pins = <
+				SC_P_UART2_RX_ADMA_UART2_R	0x06000020
+				SC_P_UART2_TX_ADMA_UART2_T	0x06000020
+			>;
+		};
+
 		pinctrl_usdhc1: usdhc1grp {
 			fsl,pins = <
 				SC_P_EMMC0_CLK_CONN_EMMC0_CLK		0x06000041
@@ -217,6 +224,12 @@
 	status = "okay";
 };

+&lpuart2 {
+	pinctrl-names = "default";
+	pinctrl-0 = <&pinctrl_lpuart2>;
+	status = "okay";
+};
+
 &gpio0 {
 	status = "okay";
 };
```

{{< notice info "fsl-imx8qxp-mek.dts 引用路徑(非完整)" >}}
- fsl-imx8qxp-mek.dts
	- include fsl-imx8qxp.dtsi
		- include fsl-imx8dxp.dtsi
			- include fsl-imx8dx.dtsi
				- include fsl-imx8-ca35.dtsi
{{< /notice >}}


{{< notice info "doc/README.SPL" >}}
**Device tree**
The U-Boot device tree is filtered by the fdtgrep tools during the build
process to generate a much smaller device tree used in SPL (spl/u-boot-spl.dtb)
with:
- the mandatory nodes (/alias, /chosen, /config)
- the nodes with one pre-relocation property:
  'u-boot,dm-pre-reloc' or 'u-boot,dm-spl'

fdtgrep is also used to remove:
- the properties defined in CONFIG_OF_SPL_REMOVE_PROPS
- all the pre-relocation properties
  ('u-boot,dm-pre-reloc', 'u-boot,dm-spl' and 'u-boot,dm-tpl')

All the nodes remaining in the SPL devicetree are bound
(see doc/driver-model/design.rst).

{{< /notice >}}


#### 修改 U-Boot 開機配置

下列是我們會修改到的檔案:
- arch/arm/mach-imx/imx8/clock.c
- board/freescale/imx8qxp_mek/imx8qxp_mek.c
- include/configs/imx8qxp_mek.h

```diff
diff --git a/arch/arm/mach-imx/imx8/clock.c b/arch/arm/mach-imx/imx8/clock.c
index 4eb22ce129..05343d901d 100644
--- a/arch/arm/mach-imx/imx8/clock.c
+++ b/arch/arm/mach-imx/imx8/clock.c
@@ -27,7 +27,7 @@ u32 mxc_get_clock(enum mxc_clock clk)
 	switch (clk) {
 	case MXC_UART_CLK:
 		err = sc_pm_get_clock_rate(-1,
-				SC_R_UART_0, 2, &clkrate);
+				SC_R_UART_2, 2, &clkrate);
 		if (err != SC_ERR_NONE) {
 			printf("sc get UART clk failed! err=%d\n", err);
 			return 0;
diff --git a/board/freescale/imx8qxp_mek/imx8qxp_mek.c b/board/freescale/imx8qxp_mek/imx8qxp_mek.c
index a4f9fab986..71068b090d 100644
--- a/board/freescale/imx8qxp_mek/imx8qxp_mek.c
+++ b/board/freescale/imx8qxp_mek/imx8qxp_mek.c
@@ -42,14 +42,14 @@ DECLARE_GLOBAL_DATA_PTR;
 			 (SC_PAD_28FDSOI_DSE_DV_HIGH << PADRING_DSE_SHIFT) | \
 			 (SC_PAD_28FDSOI_PS_PU << PADRING_PULL_SHIFT))

-static iomux_cfg_t uart0_pads[] = {
-	SC_P_UART0_RX | MUX_PAD_CTRL(UART_PAD_CTRL),
-	SC_P_UART0_TX | MUX_PAD_CTRL(UART_PAD_CTRL),
+static iomux_cfg_t uart2_pads[] = {
+	SC_P_UART2_RX | MUX_PAD_CTRL(UART_PAD_CTRL),
+	SC_P_UART2_TX | MUX_PAD_CTRL(UART_PAD_CTRL),
 };

 static void setup_iomux_uart(void)
 {
-	imx8_iomux_setup_multiple_pads(uart0_pads, ARRAY_SIZE(uart0_pads));
+	imx8_iomux_setup_multiple_pads(uart2_pads, ARRAY_SIZE(uart2_pads));
 }

 int board_early_init_f(void)
@@ -57,8 +57,8 @@ int board_early_init_f(void)
 	sc_pm_clock_rate_t rate = SC_80MHZ;
 	int ret;

-	/* Set UART0 clock root to 80 MHz */
-	ret = sc_pm_setup_uart(SC_R_UART_0, rate);
+	/* Set uart2 clock root to 80 MHz */
+	ret = sc_pm_setup_uart(SC_R_UART_2, rate);
 	if (ret)
 		return ret;

@@ -348,7 +348,7 @@ int board_init(void)
 void board_quiesce_devices(void)
 {
    const char *power_on_devices[] = {
-       "dma_lpuart0",
+       "dma_lpuart2",

        /* HIFI DSP boot */
        "audio_sai0",
        
diff --git a/include/configs/imx8qxp_mek.h b/include/configs/imx8qxp_mek.h
index 8e5e48026e..124cbc715c 100644
--- a/include/configs/imx8qxp_mek.h
+++ b/include/configs/imx8qxp_mek.h
@@ -30,7 +30,7 @@
 #define CONFIG_SPL_BSS_MAX_SIZE		0x1000	/* 4 KB */
 #define CONFIG_SYS_SPL_MALLOC_START	0x82200000
 #define CONFIG_SYS_SPL_MALLOC_SIZE     0x80000	/* 512 KB */
-#define CONFIG_SERIAL_LPUART_BASE	0x5a060000
+#define CONFIG_SERIAL_LPUART_BASE	0x5a080000 /* use UART2 */
 #define CONFIG_MALLOC_F_ADDR		0x00138000

 #define CONFIG_SPL_RAW_IMAGE_ARM_TRUSTED_FIRMWARE
@@ -125,7 +125,7 @@
 	"script=boot.scr\0" \
 	"image=Image\0" \
 	"splashimage=0x9e000000\0" \
-	"console=ttyLP0\0" \
+	"console=ttyLP2\0" \
 	"fdt_addr=0x83000000\0"			\
 	"fdt_high=0xffffffffffffffff\0"		\
 	"cntr_addr=0x98000000\0"			\
```

#### 建立 U-Boot  的 Patch

```bash
git diff > ${BUILD_DIR}/0001-UART0-to-UART2-modification.patch
bitbake -c clean virtual/bootloader
```
### 修改 Kernel

修改完 Bootloader 的配置之後，接下來我們要修改 Kernel 的配置。

我們可以透過找尋 `PREFERRED_PROVIDER_virtual/kernel` 變數，來找到使用的 Kernel Package 名稱 **linux-fslc-imx**。

#### 確認 Kernel 用的裝置樹(Devicetree)

我們可以看到 **machine/imx8qxpc0mek.conf** 中， `KERNEL_DEVICETREE` 變數記錄了許多裝置樹。
但實際會使用哪一個來開機，會是在 u-boot 決定的。所以我們可以觀察 u-bbot 中的程式碼，最後會發它是使用 **imx8qxp-mek.dtb** 來開機的。

{{< figure src="images/linux-fdt.png" caption="imx8qxp_mek.c:412" >}}


#### 修改 Kernel 用的裝置樹(Devicetree)

```bash
bitbake -c devshell virtual/kernel
```

下列是我們會修改到的檔案:

- arch/arm64/boot/dts/freescale/imx8x-mek.dtsi

```diff
---
diff --git a/arch/arm64/boot/dts/freescale/imx8x-mek.dtsi b/arch/arm64/boot/dts/freescale/imx8x-mek.dtsi
index e7f348c2ad14..b08160c5832e 100644
--- a/arch/arm64/boot/dts/freescale/imx8x-mek.dtsi
+++ b/arch/arm64/boot/dts/freescale/imx8x-mek.dtsi
@@ -6,7 +6,7 @@
 #include <dt-bindings/usb/pd.h>
 / {
 	chosen {
-		stdout-path = &lpuart0;
+		stdout-path = &lpuart2;
 	};

 	brcmfmac: brcmfmac {
```


{{< notice info "imx8x-mek.dts 引用路徑(非完整)" >}}
- imx8x-mek.dts
	- imx8x-mek.dtsi
{{< /notice >}}

{{< notice info "Documentation/devicetree/bindings/chosen.txt (節錄)" >}}
**The chosen node**

The chosen node does not represent a real device, but serves as a place
for passing data between firmware and the operating system, like boot
arguments. Data in the chosen node does not represent the hardware.

(略)

**stdout-path**

Device trees may specify the device to be used for boot console output
with a stdout-path property under /chosen, as described in the Devicetree
Specification，e.g.

(略)

{{< /notice >}}

#### 建立 Kernel 的 Patch

```bash
git diff > ${BUILD_DIR}/0001-Kernel-UART0-to-UART2-modification.patch
bitbake -c clean virtual/kernel
```

### 建立新的 Layer 並加入 Patch

```bash
# 建立新的 Layer - meta-first
bitbake-layers create-layer meta-first

# 使用 meta-first Layer
bitbake-layers add-layer meta-first

# 建立新的 recipe 用來加上我們前面的修改
recipetool appendsrcfile ../meta-first virtual/bootloader ../0001-UART0-to-UART2-modification.patch
recipetool appendsrcfile ../meta-rtc virtual/kernel  ../0001-Kernel-UART0-to-UART2-modification.patch
```

{{< notice info >}}
我們可以使用 `bitbake-layers` 來查看 bbappend 是否有發生作用。
```bash
bitbake-layers show-appends
bitbake -e virtual/bootloader
```
{{< /notice >}}

### 重新編譯映像檔並燒寫至 SD 卡

```bash
# 開始編譯
bitbake imx-image-core

# 將映像檔寫入 SD 卡中
bzcat <image_name>.wic.bz2 | sudo dd of=/dev/sd<partition> bs=1M conv=fsync
```

### 結果

在接上 Host 與 主板上的 UART2 之後，我們重新啟動電源。

{{< figure src="images/uart2_connection.png" caption="從 UART2 看到 U-Boot 的輸出訊息" >}}

可以看到開機的相關資訊已改從 UART2 輸出了。

{{< figure src="images/result-uboot.png" caption="從 UART2 看到 U-Boot 的輸出訊息" >}}
{{< figure src="images/result-kernel.png" caption="從 UART2 看到 Kernel 的輸出訊息" >}}

## 小結

這一篇需要了解的東西比較多。除了 Yocto 本身之外，還要了解 U-Boot 的配置、Kernel  的配置、裝置樹以及 Kernel 的開機流程。

- Yocto 可以參考 [Yocto 基礎介紹]({{< ref "yocto-introduction">}})

其他的部份，以後我們會再為大家進行說明。

本篇所使用的 patch 就放在[這](0001-UART0-to-UART2-modification.patch)提供給同學參考了。

## 參考連結

- [var-MACHINEOVERRIDES][var-MACHINEOVERRIDES]
- [[NXP i.MX 應用處理器教室] 在i.MX8QXP 平台更換偵錯的 UART接口][1]

[var-MACHINEOVERRIDES]:https://www.yoctoproject.org/docs/1.7/ref-manual/ref-manual.html#var-MACHINEOVERRIDES
[1]:https://www.wpgdadatong.com/tw/blog/detail?BID=B3695