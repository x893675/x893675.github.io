---
layout:     post
title:      "spice介绍"
subtitle:   " \" spice相关概念的简单说明 \""
date:       2017-04-22 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-universe.jpg"
catalog: true
tags:
    - SPICE
    - 云计算
---

### 1.1 spice基本概念

spice是专门为虚拟化环境构建的一套远程桌面系统。spice指整套系统，而不是单个模块或组件。

### 1.2 spice系统组成

![spice系统结构图](https://github.com/x893675/MarkDownPhotos/raw/master/spice%E7%B3%BB%E7%BB%9F%E7%BB%93%E6%9E%84%E5%9B%BE.png)

* spice协议
* spice server
* spice client

### 1.3 VD-Interface

VD-Interface是一套接口规范，VDI Back-End与VDI Front-End通过VD-Interface进行交互。

### 1.4 VDI Back-End

VDI Back-End其实就是一堆QEMU Virtual Device，但是这些Virtual Device都实现了VD-Interface接口规范。

### 1.5 VDI Front-End

VDI Front-End通过调用VDI Back-End提供的VD-Interface接口来实现与VDI Back-End的交互。

### 1.6 spice server

spice-server 作为VDI的前端，通过spice协议与spice客户端进行通信。spice-server以库的形式提供给后端。


### 2.1 spice server

![spice server结构图](https://github.com/x893675/MarkDownPhotos/raw/master/spice_server.png)

spice server编译成libspice,作为一个动态库给后端（通常是qemu）使用。

### 2.2 公共函数

公共函数为可以给外部文件调用的函数（在这里指由qemu调用）

* spice.h:与SpiceServer结构体相关的函数,是qemu调用spice的主要函数
* red_dispatcher.h:与QXL设备相关的函数

主要公共函数：
*   **spice_server_init** :负责初始化spice_server
*   **spice_server_add_interface** :给server注册VDI接口
*   **spice_server_add_client** :处理qemu接收到的客户端连接消息

### 2.3 主要VDI接口

* SpiceCoreInterface：    Spice与Qemu内部交互用的接口
* QXLInterface：          显示数据交互接口
* SpiceKbdInstance：      键盘输入交互接口
* SpiceMouseInterface：   鼠标输入交互接口
* SpicePlaybackInterface：音频播放交互接口
* SpiceRecordInterface：  音频录制交互接口

### 2.4 Channel

Channel的主要作用是使用对应的TCP连接传输消息给客户端,保证其传输的可靠性,其本质是通道,不同的Channel传输不同的消息.

spice中主要有六种Channel:
*   **MainChannel** :与客户端连接的建立和断开有关
*   **InputsChannel** :跟鼠标,键盘,触摸板的输入有关
*   **DisplayChannel** :跟图像传输有关
*   **CursorChannel** :跟鼠标指针的显示有关
*   **PlaybackChannel** :跟播放宿主机的声音有关
*   **RecordChannel** :跟录制客户端的声音有关

### 3.1 usbredirect

usbredirect是spice对USB重定向的支持

![usb_redirection](https://github.com/x893675/MarkDownPhotos/raw/master/usb_redirection.png)
* usb host端，spice client通过libusb与usb外设交互
* spice client通过spice协议在特定通道与spice server交互
* spice server通过VDI接口与qemu(redirect.c)交互



