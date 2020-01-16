---
title: 关于Qemu的记录
date: 2017-12-07T14:21:26+08:00
lastmod: 2017-12-07T14:21:26+08:00
author: hanamichi
cover: /img/qemu.jpg
categories: ['底层虚拟化技术']
tags: ['云计算','qemu']
---

qemu-kvm的一些记录

<!--more-->

- [虚拟机xml文件中使用qemu命令行参数](#虚拟机xml文件中使用qemu命令行参数)
- [虚拟机xml文件中配置网卡](#虚拟机xml文件中配置网卡)
  - [NAT模式](#nat模式)
  - [桥接模式](#桥接模式)
- [qemu中usb控制器](#qemu中usb控制器)
  - [qemu中usb控制器定义及重定向通道](#qemu中usb控制器定义及重定向通道)
    - [USB2.0控制器](#usb20控制器)
    - [USB3.0控制器](#usb30控制器)
  - [QEMU-USB控制器配置](#qemu-usb控制器配置)
    - [usb3.0控制器](#usb30控制器-1)
    - [usb2.0控制器组](#usb20控制器组)
    - [usb1.0控制器](#usb10控制器)
  - [QEMU-USB透传和重定向配置](#qemu-usb透传和重定向配置)
  - [总结](#总结)

## 虚拟机xml文件中使用qemu命令行参数

qemu中有些命令行的参数可以使用xml直接定义，另外一些不能直接定义的需要使用libvrit提供的`qemu:commandline`标签来配置。

````xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <!--- 虚拟机定义（os,cpu,mem等） -->
  <device>
  <!--- 虚拟机设备定义 -->
  </device>
  <qemu:commandline>
    <qemu:arg value=''/>
    <qemu:env name='' value=''/>
  </qemu:commandline>
</domain>
````

实例：

```xml
<qemu:commandline>
   <qemu:arg value='-option-rom'/>
   <qemu:arg value='path/to/my.rom'/>
</qemu:commandline>
```

```xml
<qemu:commandline>
   <qemu:env name='my_env' value='my_value'/>
</qemu:commandline>
```

## 虚拟机xml文件中配置网卡

### NAT模式

查看libvirt当前默认虚拟网络是否开启

`virsh net-list --all`

```bash
# virsh net-define /usr/share/libvirt/networks/default.xml
# virsh net-autostart default
# virsh net-start default
```

`brctl show`,如果**virbr0**正常，则设置正常

更改系统配置，开启IP转发。

`# vim /etc/sysctl.conf`

```bash
 net.ipv4.ip_forward = 1
```

虚拟机xml文件网络配置如下：

```xml
<interface type='network'>
   <source network='default'/>
   <mac address='00:16:3e:1a:b3:4a'/>
</interface>
```

### 桥接模式

linux网桥配置参考文章：[Linux下网桥配置](http://hanamichi.wiki/posts/linux-cmd/)

```xml
<interface type='bridge'>
  <source bridge='br0'/>
  <mac address='00:16:3e:1a:b3:4a'/>
  <model type='virtio'/>
</interface>
```

## qemu中usb控制器

qemu中模拟了usb1,usb2,usb3的相应控制器，但是对于hub设备，qemu只完成了对低速设备（usb1.x设备）的支持。其中usb1控制器有两个端口，usb2控制器有6个端口，usb3控制器有16个端口。


### qemu中usb控制器定义及重定向通道

#### USB2.0控制器

2.0 控制器在 qemu 中定义是以一个 ehci 控制器加上 3 个 uhci 控制器来定义，这是因为 qemu 中的 ehci 控制器只支持 2.0 设备，不向下兼容 1.x 设备，所以加上了 3 个 uhci 控制器(ehci 控制器有 6 个端口，uhci 控制器有 2 个端口)。具体定义如图 1-1 所示

![图1-1](/img/inpost/qemu/1-1.png)

当虚拟机usb重定向通道数大于 4 个，且没有指定重定向通道的具体地址(即连接在哪个控制器的端口)，qemu 会在系统中添加一个 1.1 的 Hub 设备，该 Hub 设备连接在 uchi 控制器的某一个端口上。系统中总线图如图 1-2 所示。图中 nec usb hub就是 qemu 创建的 1.1hub 设备

![图1-2](/img/inpost/qemu/1-2.png)

重定向通道个数改为 6 个，并创建一个 uhci 控制器给 tablet 设备使用，将ehci 的 6 个端口全部空出供重定向通道使用，将重定向通道与 ehci 的 6 个端口一一对应，这样设置，qemu 就不会创建 hub 设备，系统中总线图如图 1-3 所示。在 libvirt 中具体的设置方法如图 1-4 所示，图中创建了一组 2.0 控制器，一个 1.0 控制器，将 tablet 设备连接在 1.0 控制器上，将 6 个重定向通道分别连接在 2.0 控制器的 6 个端口上。

**注意**:tablet 和重定向通道地址的 bus 值是对应控制器的索引值，且控制器的端口号都是从 1 开始。

![图1-3](/img/inpost/qemu/1-3.png)

![图1-4](/img/inpost/qemu/1-4.png)

#### USB3.0控制器

Qemu 中的 3.0 控制器最多支持 15 个端口，目前 vdi 环境 xhci 控制器有 6 个端口。

与 2.0 环境一样，当重定向通道数大于 4 个，qemu 会自动添加一个 1.1 的hub，但是与 2.0 环境不同的是这个时候重定向设备可以成功，设备可以正常使用，只是运行在 1.0 协议下(用 u 盘测试读写速度为 1.0 下的速度，不超过 10MB/S)。此时系统中的总线如图 2-1 所示。现在猜测有这样的不同，可能跟 hub 所连接的端口有关(2.0 环境下 hub 连接在 uhci 控制器下)。

![图2-1](/img/inpost/qemu/2-1.png)

重定向通道个数改为 6 个，设置方法与 2.0 环境相同，只是将 2.0 控制器更改为 3.0 控制器，其他不变。具体定义如图 2-2 所示，系统中总线如图 2-3 所示。

![图2-2](/img/inpost/qemu/2-2.png)

![图2-3](/img/inpost/qemu/2-3.png)

在查看 libvirt 的更新日志后，发现 libvirt 增加了在 xml 中直接配置 xhci3.0 控制器的端口个数的功能。更改日志如图 2-4 所示。已经用 qemu 命令行验证可行。

![图2-4](/img/inpost/qemu/2-4.png)

### QEMU-USB控制器配置

#### usb3.0控制器

```xml
<controller type='usb' index='0' model='nec-xhci'>
</controller>
<!-- index值代表USB控制器在usb总线中的位置，数值从0开始，添加另外的usb控制器，index值自增 -->
```

#### usb2.0控制器组

```xml
<controller type='usb' index='0' model='ich9-ehci1'>
</controller>
<controller type='usb' index='0' model='ich9-uhci1'>
      <master startport='0'/>
</controller>
<controller type='usb' index='0' model='ich9-uhci2'>
      <master startport='2'/>
</controller>
<controller type='usb' index='0' model='ich9-uhci3'>
      <master startport='4'/>
</controller>
<!-- 在虚拟机中添加一个2.0控制器，必须以一个2.0控制器和3个1.0控制器组的形式添加，且3个1.0控制器的index值必须跟2.0控制器的index值相同 -->
<!-- index值代表USB控制器在usb总线中的位置，数值从0开始，添加另外的usb控制器，index值自增 -->
```

#### usb1.0控制器

```xml
<controller type='usb' index='0' model='piix3-uhci'>
</controller>
<!-- index值代表USB控制器在usb总线中的位置，数值从0开始，添加另外的usb控制器，index值自增 -->
```

### QEMU-USB透传和重定向配置

以3.0控制器加2.0控制器组为例讲解

**虚拟机usb控制器配置如下：**

```xml
<controller type='usb' index='0' model='nec-xhci'>
</controller>
<controller type='usb' index='1' model='ich9-ehci1'>
</controller>
<controller type='usb' index='1' model='ich9-uhci1'>
      <master startport='0'/>
</controller>
<controller type='usb' index='1' model='ich9-uhci2'>
      <master startport='2'/>
</controller>
<controller type='usb' index='1' model='ich9-uhci3'>
      <master startport='4'/>
</controller>
```

**虚拟机usb输入设备和重定向通道配置如下：**

```xml
<input type='tablet' bus='usb'>
      <address type='usb' bus='1' port='1'/>
</input>
<redirdev bus='usb' type='spicevmc'>
      <address type='usb' bus='0' port='1'/>
</redirdev>
<redirdev bus='usb' type='spicevmc'>
      <address type='usb' bus='0' port='2'/>
</redirdev>
    <redirdev bus='usb' type='spicevmc'>
<address type='usb' bus='0' port='3'/>
</redirdev>
<redirdev bus='usb' type='spicevmc'>
      <address type='usb' bus='0' port='4'/>
</redirdev>
<!-- 将tablet输入设备连接在2.0控制器的端口上，address标签中bus值为控制器的索引值，port值为连接在控制器的哪个端口，2.0控制器有6个端口，port值默认从1开始 -->
<!-- 将4个重定向通道连接到3.0控制器上，address标签的值同2.0控制器，port值为1-15 -->
<!-- 可根据自己的需要改变连接情况 -->
```

**USB设备透传设置如下:**

```bash
virsh qemu-monitor-command domain-name --hmp 'device_add usb-redir,chardev=chardev1235,id=device1236,bus=usb.0,port=4'
#domain-name,chardev,id根据自己的情况修改
#bus=usb.0,port=4表示将设备连接到索引值为0的usb控制器的4号端口上,port项为可选

virsh qemu-monitor-command domain-name --hmp 'device_add usb-redir,chardev=chardev1235,id=device1236,bus=usb1.0'
#表示将设备连接到索引值为1的usb控制器上
```

### 总结

在虚拟机中添加多个usb控制器的时候，最好将tablet设备指定到2.0控制器或1.0控制器上，将重定向通道连接在3.0控制器上，透传的时候可根据需要选择控制器透传。