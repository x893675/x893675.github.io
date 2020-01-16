---
title: openwrt软路由搭建
date: 2019-12-01T14:21:26+08:00
lastmod: 2019-12-01T14:21:26+08:00
author: hanamichi
cover: /img/openwrt.jpg
categories: ['瞎折腾']
tags: ['linux']
---

记录openwrt的软路由实践

<!--more-->

- [openwrt/lede软路由搭建](#openwrtlede软路由搭建)
  - [目的](#目的)
  - [环境说明](#环境说明)
  - [搭建步骤](#搭建步骤)

## openwrt/lede软路由搭建

下面以koolshare的openwrt固件为例

因为koolshare不开源，所以还是存在安全性隐患，后续考虑使用[lean大神的开源库自己编译](https://github.com/coolsnowwolf/lede)

### 目的

启动一个openwrt的虚拟机作为软路由，并在其上配置代理，宿主机和其他任何以其地址为网关的机器都能科学上网

### 环境说明

* win10系统

* vmware workstation 15
* [koolshare固件](http://firmware.koolshare.cn/LEDE_X64_fw867/)
* [koolshare科学上网插件](https://github.com/hq450/fancyss/tree/master/fancyss_X64/koolss)

### 搭建步骤

1. 下载好虚拟机镜像文件, [下载地址](http://firmware.koolshare.cn/LEDE_X64_fw867/%E8%99%9A%E6%8B%9F%E6%9C%BA%E8%BD%AC%E7%9B%98%E6%88%96PE%E4%B8%8B%E5%86%99%E7%9B%98%E4%B8%93%E7%94%A8/openwrt-koolshare-mod-v2.31-r10822-50aa0525d1-x86-64-combined-squashfs.vmdk)

   ![](/img/inpost/openwrt/openwrt-0.png)

2. 设置主机上vmware workstation的网卡,**VMnet0设置成桥接模式****,VMnet1设置成NAT模式**,可根据自己的情况设置NAT的地址

   ![](/img/inpost/openwrt/openwrt-1.png)

   ![](/img/inpost/openwrt/openwrt-2.png)

3. 使用虚拟机镜像文件创建虚拟机，且配置两张网卡, 第一张网卡采用NAT模式,第二张网卡使用桥接模式

   ![](/img/inpost/openwrt/openwrt-4.png)

4. 等待虚拟机启动成功,编辑lan口的网络设置

   ![](/img/inpost/openwrt/openwrt-5.png)

   ![](/img/inpost/openwrt/openwrt-6.png)

5. 编辑VMnet8的ipv4属性,使用nat网段的一个地址，网关指向openwrt的lan口地址

   ![](/img/inpost/openwrt/openwrt-7.png)

6. 配置好VMnet8后，就可以从宿主机访问openwrt的控制面板了,默认密码`koolshare`,控制面板地址为lan口地址

   ![](/img/inpost/openwrt/openwrt-8.png)

7. 因为koolshare商店下架了科学上网相关的插件,所以需要手动下载安装,将前面下载的科学上网工具导入安装，并根据提示配置自己的代理

   ![](/img/inpost/openwrt/openwrt-9.png)

   ![](/img/inpost/openwrt/openwrt-10.png)

   ![](/img/inpost/openwrt/openwrt-11.png)

8. 另外的虚拟机想通过软路由访问，虚拟机的网卡配置在VMnet8即可

   ![](/img/inpost/openwrt/openwrt-12.png)

9. win10宿主机想走软路由，将宿主机的网卡ipv4配置,高级选项中的跃点书手动改成一个较高的值即可
