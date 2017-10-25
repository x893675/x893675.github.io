---
layout:     post
title:      "centos常用操作"
subtitle:   " \" centos操作合集 \""
date:       2017-08-01 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-unix-linux.jpg"
catalog: true
tags:

    - 技术
    - Linux
    - Centos
---



## yum 相关

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

## 内核相关

1 更新内核模块后执行`dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r)`

2 更改默认启动内核

```bash
$ grep "menuentry " /boot/grub2/grub.cfg | awk -F"'" '{print $2}'
CentOS Linux (3.10.0-514.2.2.el7.x86_64.debug) 7 (Core)
CentOS Linux (3.10.0-514.2.2.el7.x86_64) 7 (Core)
CentOS Linux (3.10.0-327.36.1.el7.x86_64) 7 (Core)
CentOS Linux (3.10.0-327.28.3.el7.x86_64) 7 (Core)
CentOS Linux (3.10.0-327.22.2.el7.x86_64) 7 (Core)
CentOS Linux (3.10.0-327.18.2.el7.x86_64) 7 (Core)
CentOS Linux (3.10.0-327.36.1.el7.x86_64.debug) 7 (Core)
CentOS Linux (3.10.0-327.28.3.el7.x86_64.debug) 7 (Core)
CentOS Linux (3.10.0-327.28.2.el7.x86_64.debug) 7 (Core)
CentOS Linux (0-rescue-6889c400aea74d25b7eb9ce82c4a2f02) 7 (Core)


$ vi /etc/default/grub
GRUB_DEFAULT="CentOS Linux (3.10.0-327.36.1.el7.x86_64) 7 (Core)"

$ grub2-mkconfig -o /boot/grub2/grub.cfg
```

3 未完待续…

## 其他技巧

1 查看网络流量的软件nethogs `yum install nethogs -y`

2 编译新版库和软件，使用PKG_CONFIG_PATH,LD_LIBRARY_PATH环境变量解决库依赖问题和动态库链接问题

**未完待续...**

