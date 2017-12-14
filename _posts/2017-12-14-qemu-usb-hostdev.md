---
layout:     post
title:      "QEMU-usb总结"
subtitle:   " \" usb重定向和透传 \""
date:       2017-09-01 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-unix-linux.jpg"
catalog: true
tags:

    - 技术
    - 云计算
    - QEMU
---

## QEMU-USB控制器配置

### usb3.0控制器

```xml
<controller type='usb' index='0' model='nec-xhci'>
</controller>
<!-- index值代表USB控制器在usb总线中的位置，数值从0开始，添加另外的usb控制器，index值自增 -->
```

### usb2.0控制器组

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

### usb1.0控制器

```xml
<controller type='usb' index='0' model='piix3-uhci'>
</controller>
<!-- index值代表USB控制器在usb总线中的位置，数值从0开始，添加另外的usb控制器，index值自增 -->
```

## QEMU-USB透传和重定向配置

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

## 总结

在虚拟机中添加多个usb控制器的时候，最好将tablet设备指定到2.0控制器或1.0控制器上，将重定向通道连接在3.0控制器上，透传的时候可根据需要选择控制器透传。