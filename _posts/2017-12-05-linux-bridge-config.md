---
layout:     post
title:      "网桥配置"
subtitle:   " \"Linux配置网桥由虚拟机使用\""
date:       2017-12-05 10:00:00
author:     "Hanamichi"
header-img: "img/post-bg-unix-linux.jpg"
catalog: true
tags:
    - linux
    - 网络

---

## centos7 网桥配置

假定物理网卡为**eth0**，网桥为**br0**

`vim /etc/sysconfig/network-scripts/ifcfg-eht0`

更改文件中的以下条目：

```bash
# NAME,DEVICE,UUID写成自己环境中的值
TYPE=Ethernet
BOOTPROTO=none
NAME=eth0
UUID=XXXXXXXXXXX
DEVICE=eth0
ONBOOT=yes
BRIDGE=br0
```

`vim /etc/sysconfig/network-scripts/ifcfg-br0 `

文件内容如下：

```bash
# 更改相应ip，也可用dhcp
TYPE=Bridge
DEVICE=br0
BOOTPROTO=static
ONBOOT=yes
IPADDR=172.16.73.201
NETMASK=255.255.0.0
GATEWAY=172.16.0.1
DNS1=202.103.24.68
```

`service network restart`

禁用网络过滤

```bash
#增加以下条目
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
```

`sysctl -p /etc/sysctl.conf`

**注意**：更改网络接口文件前可先备份

## ubuntu 网桥配置

假定物理网卡为**eth0**，网桥为**br0**

`vim /etc/network/interfaces`

加入以下内容：

```bash
auto eno1 br0
iface br0 inet static
address 172.16.73.200
netmask 255.255.0.0
gateway 172.16.0.1
bridge_ports eno1
```

` ifup br0 `or`reboot`