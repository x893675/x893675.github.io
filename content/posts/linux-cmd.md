---
title: linux常用命令记录
date: 2017-09-01T14:21:26+08:00
lastmod: 2017-09-01T14:21:26+08:00
author: hanamichi
cover: /img/linux.jpg
categories: ['linux']
tags: ['linux']
---

记录一些linux的命令及使用

<!--more-->

- [查看硬件信息](#查看硬件信息)
  - [dmidecode命令](#dmidecode命令)
- [centos相关](#centos相关)
  - [yum 相关](#yum-相关)
  - [rpm命令](#rpm命令)
  - [rpmbuild及SPEC文件详解](#rpmbuild及spec文件详解)
  - [升级内核](#升级内核)
  - [静态ip配置文件](#静态ip配置文件)
  - [网桥配置](#网桥配置)
  - [docker配置](#docker配置)
  - [参考链接](#参考链接)

## 查看硬件信息

### dmidecode命令

```
sudo dmidecode -t processor      (CPU核芯)
sudo dmidecode -t memory         (内存)
sudo dmidecode -t cache          (缓存)
sudo dmidecode -t system         (电脑型号、产商)
sudo dmidecode -t slot           (插卡槽)
sudo dmidecode -t baseboard      (主板)
sudo dmidecode -t connector      (连接设备)
sudo dmidecode -t chassis        (机箱)
sudo dmidecode -t bios           (BIOS) 
```

**其他设备编号：**

```
1	System
2	Base Board
3	Chassis
4	Processor
5	Memory Controller
6	Memory Module
7	Cache
8	Port Connector
9	System Slots
10	On Board Devices
11	OEM Strings
12	System Configuration Options
13	BIOS Language
14	Group Associations
15	System Event Log
16	Physical Memory Array
17	Memory Device
18	32-bit Memory Error
19	Memory Array Mapped Address
20	Memory Device Mapped Address
21	Built-in Pointing Device
22	Portable Battery
23	System Reset
24	Hardware Security
25	System Power Controls
26	Voltage Probe
27	Cooling Device
28	Temperature Probe
29	Electrical Current Probe
30	Out-of-band Remote Access
31	Boot Integrity Services
32	System Boot
33	64-bit Memory Error
34	Management Device
35	Management Device Component
36	Management Device Threshold Data
37	Memory Channel
38	IPMI Device
39	Power Supply
40	Additional Information
41	Onboard Device
```

## centos相关

### yum 相关

1 **语法**

```bash
yum (选项)(参数)
```

2 **选项**

```bash
-h：显示帮助信息； 
-y：对所有的提问都回答“yes”；
-c：指定配置文件； 
-q：安静模式； 
-v：详细模式； 
-d：设置调试等级（0-10）； 
-e：设置错误等级（0-10）； 
-R：设置yum处理一个命令的最大等待时间； 
-C：完全从缓存中运行，而不去下载或者更新任何头文件。
```

3 **参数**

```bash
install：安装rpm软件包； 
update：更新rpm软件包； 
check-update：检查是否有可用的更新rpm软件包； 
remove：删除指定的rpm软件包； 
list：显示软件包的信息； 
search：检查软件包的信息； 
info：显示指定的rpm软件包的描述信息和概要信息； 
clean：清理yum过期的缓存； 
shell：进入yum的shell提示符； 
resolvedep：显示rpm软件包的依赖关系； 
localinstall：安装本地的rpm软件包； 
localupdate：显示本地rpm软件包进行更新； 
deplist：显示rpm软件包的所有依赖关系;
whatprovides:查找软件所在的包和仓库
```

4 **实例**

* 自动搜索最快镜像插件`yum install yum-fastestmirror`
* 安装yum图形窗口插件`yum install yumex`
* 查看可能批量安装的列表`yum grouplist`

5 **清除缓存**

```bash
yum clean packages #清除缓存目录下的软件包 
yum clean headers #清除缓存目录下的 headers 
yum clean oldheaders #清除缓存目录下旧的 headers
```

### rpm命令

1 **语法**

```bash
rpm (选项)(参数)
```

2 **选项**

```bash
-a：查询所有套件；
-b<完成阶段><套件档>+或-t <完成阶段><套件档>+：设置包装套件的完成阶段，并指定套件档的文件名称； 
-c：只列出组态配置文件，本参数需配合"-l"参数使用； 
-d：只列出文本文件，本参数需配合"-l"参数使用； 
-e<套件档>或--erase<套件档>：删除指定的套件； 
-f<文件>+：查询拥有指定文件的套件； 
-h或--hash：套件安装时列出标记； 
-i：显示套件的相关信息；
-i<套件档>或--install<套件档>：安装指定的套件档； 
-l：显示套件的文件列表； 
-p<套件档>+：查询指定的RPM套件档； 
-q：使用询问模式，当遇到任何问题时，rpm指令会先询问用户； 
-R：显示套件的关联性信息； 
-s：显示文件状态，本参数需配合"-l"参数使用； 
-U<套件档>或--upgrade<套件档>：升级指定的套件档； 
-v：显示指令执行过程； 
-vv：详细显示指令执行过程，便于排错。
```

3 **参数**

```bash
软件包：指定要操纵的rpm软件包。
```

4 **实例**

* 安装rpm包:`rpm -ivh your-package.rpm`
* 强制安装rpm包:`rpm -ivh --force your-pachage.rpm`
* 忽略所有依赖和文件关系安装:`rpm -ivh --force --nodeps your-pachage.rpm`
* 安装src.rpm包:`rpm -i your-package.src.rpm`,源码在`/usr/src`目录下
* 卸载rpm包:`rpm -e 包名`包名含版本号等信息，不能有rpm后缀，使用`--nodeps`强制卸载

5 **不安装提取rpm包文件**

```bash
rpm2cpio xxx.rpm | cpio -vi 
rpm2cpio xxx.rpm | cpio -idmv 
rpm2cpio xxx.rpm | cpio --extract --make-directories

//参数i和extract相同，表示提取文件。v表示指示执行进程，d和make-directory相同，表示根据包中文件原来的路径建立目录，m表示保持文件的更新时间
```

6 **查看rpm包中有哪些文件**

* 一个没有安装过的软件包，使用`rpm -qlp xxxx.rpm`
* 一个已经安装过的软件包，还可以使用`rpm -ql xxxxx.rpm`

7 **获取软件包的版本描述等信息**

* 一个没有安装过的软件包，使用`rpm -qip xxxxx.rpm`，查看包等Changelog信息`rpm -qip xxx.rpm --changelog`
* 一个已经安装过的软件包，还可以使用`rpm -qi xxxxxx.rpm`

8 **查看某个程序所在的包** 

```
返回软件包的全名: rpm -qf `which 程序名`
返回软件包的有关信息: rpm -qif `which 程序名`
返回软件包的文件列表: rpm -qlf `which 程序名`
```

### rpmbuild及SPEC文件详解

[rpmbuild和spec文件详解](http://hanamichi.wiki/2017/12/02/rpmbuild/)

[centos官方rpm包](http://vault.centos.org/)

[阿里云官方镜像站](http://mirrors.aliyun.com/)

[linux各版本源码快速查询比较](http://elixir.free-electrons.com/linux/latest/source)

<a href="https://github.com/x893675/myApp/raw/master/atiflash-4.26.0.1.tar.gz" download target="_blank">Click here to download</a>

### 升级内核

centos系统可以使用**elrepo**来升级内核

1. 导入key

   ```shell
   rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
   ```

2. 安装repo

   ```shell
   yum install https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
   ```

3. 查看可用的内核包(lt为稳定版，ml为最新版)

   ```shell
   yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
   ```

4. 安装最新版内核

   ```shell
   yum --disablerepo=\* --enablerepo=elrepo-kernel install  kernel-ml.x86_64
   ```

5. 查看系统可用内核

   ```shell
   awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
   #output..
   #0 : CentOS Linux (5.4.3-1.el7.elrepo.x86_64) 7 (Core)
   #1 : CentOS Linux (0-rescue-9871dd427bb842f8ae4396c60d6abed4) 7 (Core)
   ```

6. 设置最新的内核为默认版本

   ```shell
   grub2-set-default 0
   # 0 为上一条命令输出的相应序号
   ```

参考链接

* https://www.cnblogs.com/xzkzzz/p/9627658.html
* http://elrepo.org/tiki/tiki-index.php


### 静态ip配置文件

```shell
[root@localhost docker]# cat /etc/sysconfig/network-scripts/ifcfg-ens33 
TYPE="Ethernet"
PROXY_METHOD="none"
BROWSER_ONLY="no"
BOOTPROTO="static"
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
IPV6_ADDR_GEN_MODE="stable-privacy"
NAME="ens33"
UUID="eab6b1ea-2bc3-4832-8186-c8b8805a2ece"
DEVICE="ens33"
ONBOOT="yes"
IPADDR=192.168.200.100
NETMASK=255.255.255.0
GATEWAY=192.168.200.1
DNS1=8.8.8.8
```

### 网桥配置

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

### docker配置

在较新的docker版本中，有两种方式可以更改dockerd的配置:

* 创建`/etc/docker/daemon.json`，写入配置项
* 使用dockerd的flag(使用`dockerd --help`查看dockerd的flag), 在dockerd的启动文件中加入(dockerd使用systemd托管时，使用systemctl cat docker查看服务文件)

⚠️： 以上两种方式不兼容，同一个配置在两种方式中都有定义，dockerd会启动报错

daemon.json文件的样例:

```json
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": { "max-size": "100m" },
    "storage-driver": "overlay2",
    "storage-opts": [ "overlay2.override_kernel_check=true" ]
}
```

### 参考链接

* [Configure and trOubleshoot the docker daemon](https://docs.docker.com/config/daemon/)