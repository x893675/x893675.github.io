---
layout:     post
title:      "libvirt-qemu常用配置"
subtitle:   " \"虚拟机各设备配置\""
date:       2017-12-05 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-unix-linux.jpg"
catalog: true
tags:
    - QEMU
    - spice
    - 云计算
    - libvirt

---

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

```Xml
<qemu:commandline>
   <qemu:env name='my_env' value='my_value'/>
</qemu:commandline>
```

## 虚拟机xml文件中配置网卡

#### NAT模式

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

```Xml
  <interface type='network'>
     <source network='default'/>
     <mac address='00:16:3e:1a:b3:4a'/>
  </interface>
```

#### 桥接模式

linux网桥配置参考文章：[Linux下网桥配置](http://hanamichi.wiki/2017/12/05/linux-bridge-config/)

```Xml
 <interface type='bridge'>
    <source bridge='br0'/>
    <mac address='00:16:3e:1a:b3:4a'/>
    <model type='virtio'/>
 </interface>
```

## pci设备透传

**TODO**:设备透传配置