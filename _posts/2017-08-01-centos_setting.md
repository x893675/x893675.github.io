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

## rpm命令

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

## rpmbuild及SPEC文件详解

[rpmbuild和spec文件详解](http://hanamichi.wiki/2017/12/02/rpmbuild/)

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

