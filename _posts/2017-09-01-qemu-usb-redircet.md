---
layout:     post
title:      "QEMU"
subtitle:   " \" usb及usb重定向 \""
date:       2017-09-01 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-unix-linux.jpg"
catalog: true
tags:

    - 技术
    - 云计算
    - QEMU
---



## qemu中usb控制器简介

qemu中模拟了usb1,usb2,usb3的相应控制器，但是对于hub设备，qemu只完成了对低速设备（usb1.x设备）的支持。其中usb1控制器有两个端口，usb2控制器有6个端口，usb3控制器有16个端口。



## qemu中usb控制器定义及重定向通道

### USB2.0控制器

2.0 控制器在 qemu 中定义是以一个 ehci 控制器加上 3 个 uhci 控制器来定义，这是因为 qemu 中的 ehci 控制器只支持 2.0 设备，不向下兼容 1.x 设备，所以加上了 3 个 uhci 控制器(ehci 控制器有 6 个端口，uhci 控制器有 2 个端口)。具体定义如图 1-1 所示

![图1-1](/img/in-post/post-centos_setting/1-1.png)

当虚拟机usb重定向通道数大于 4 个，且没有指定重定向通道的具体地址(即连接在哪个控制器的端口)，qemu 会在系统中添加一个 1.1 的 Hub 设备，该 Hub 设备连接在 uchi 控制器的某一个端口上。系统中总线图如图 1-2 所示。图中 nec usb hub就是 qemu 创建的 1.1hub 设备

![图1-2](/img/in-post/post-centos_setting/1-2.png)

重定向通道个数改为 6 个，并创建一个 uhci 控制器给 tablet 设备使用，将ehci 的 6 个端口全部空出供重定向通道使用，将重定向通道与 ehci 的 6 个端口一一对应，这样设置，qemu 就不会创建 hub 设备，系统中总线图如图 1-3 所示。在 libvirt 中具体的设置方法如图 1-4 所示，图中创建了一组 2.0 控制器，一个 1.0 控制器，将 tablet 设备连接在 1.0 控制器上，将 6 个重定向通道分别连接在 2.0 控制器的 6 个端口上。

**注意**:tablet 和重定向通道地址的 bus 值是对应控制器的索引值，且控制器的端口号都是从 1 开始。

![图1-3](/img/in-post/post-centos_setting/1-3.png)

![图1-4](/img/in-post/post-centos_setting/1-4.png)

### USB3.0控制器

Qemu 中的 3.0 控制器最多支持 15 个端口，目前 vdi 环境 xhci 控制器有 6 个端口。

与 2.0 环境一样，当重定向通道数大于 4 个，qemu 会自动添加一个 1.1 的hub，但是与 2.0 环境不同的是这个时候重定向设备可以成功，设备可以正常使用，只是运行在 1.0 协议下(用 u 盘测试读写速度为 1.0 下的速度，不超过 10MB/S)。此时系统中的总线如图 2-1 所示。现在猜测有这样的不同，可能跟 hub 所连接的端口有关(2.0 环境下 hub 连接在 uhci 控制器下)。

![图2-1](/img/in-post/post-centos_setting/2-1.png)

重定向通道个数改为 6 个，设置方法与 2.0 环境相同，只是将 2.0 控制器更改为 3.0 控制器，其他不变。具体定义如图 2-2 所示，系统中总线如图 2-3 所示。

![图2-2](/img/in-post/post-centos_setting/2-2.png)

![图2-3](/img/in-post/post-centos_setting/2-3.png)

在查看 libvirt 的更新日志后，发现 libvirt 增加了在 xml 中直接配置 xhci3.0 控制器的端口个数的功能。更改日志如图 2-4 所示。已经用 qemu 命令行验证可行。

![图2-4](/img/in-post/post-centos_setting/2-4.png)