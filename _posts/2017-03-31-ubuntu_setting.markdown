---
layout:     post
title:      "ubuntu常用操作"
subtitle:   " \" ubuntu操作合集 \""
date:       2017-03-31 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-unix-linux.jpg"
catalog: true
tags:
    - 技术
    - Linux
    - Ubuntu
---


## 运行环境
1. ubuntu 16.04 64bit
2. 下载源设置为阿里云服务器

## apt相关命令

```
apt-cache search package #搜索包  
apt-cache show package #获取包的相关信息，如说明、大小、版本等  
apt-cache depends package #了解使用依赖  
apt-cache rdepends package #查看该包被哪些包依赖  
apt-get source package #下载该包的源代码  
sudo apt-get install package #安装包  
sudo apt-get install package=version #安装指定版本的包  
sudo apt-get install package --reinstall #重新安装包  
sudo apt-get -f install #修复安装, "-f = --fix-missing"  
sudo apt-get remove package #删除包  
sudo apt-get remove package --purge #删除包，包括删除配置文件等  
sudo apt-get update #更新apt软件源信息  
sudo apt-get upgrade #更新已安装的包  
sudo apt-get dist-upgrade #升级系统  
sudo apt-get dselect-upgrade #使用dselect升级  
sudo apt-get build-dep package #安装相关的编译环境  
sudo apt-get clean && sudo apt-get autoclean #清理无用的包  
sudo apt-get check #检查是否有损坏的依赖 
```

## Gnome桌面环境搭建

成品图如下：

![ubuntu_gnome_desktop](/img/in-post/ubuntu_gnome_desktop.png)

1.**安装Gnome Flashback**

`sudo apt-get install gnome-session-flashback`

注销返回到登录界面，单击密码输入框右上角的徽标型按钮，即可选择桌面环境。可供选择的有Gnome Flashback (Metacity) 会话模式和Gnome Flashback (Compiz)会话模式。

Metacity更轻更快，而Compiz则能带给你更棒的桌面效果。

2.**安装Gnome Tweak Tool**

Gnome Tweak Tool能够帮助你定制比如字体、主题等

`sudo apt-get install gnome-tweak-tool`

启动按步骤： 应用程序 > 系统工具 > 首选项 > Tweak Tool

3.**安装Numix主题和图标**

1. `sudo add-apt-repository ppa:numix/ppa`
2. `sudo apt-get update`
3. `sudo apt-get install numix-gtk-theme numix-icon-theme-circle`

如果想安装Numix桌面壁纸,使用如下命令:

`sudo apt-get install numix-wallpaper-*`

## 编译内核

1. linux内核源码位于`/usr/src`目录下，在linux官网下载内核源码(sudo apt-get source linux-xxx)，放在该目录下
2. 复制系统中现有源码目录下的`.config`文件到新下载的源码目录下
3. `make menuconfig`
4. 选择load→OK→Save→OK→EXIT→EXIT
5. `make bzImage -jN` N为系统CPU核心数量\*2
6. 如果出现`fatal error: openssl/opensslv.h: No such file or directory`错误，则执行` apt-get install libssl-dev`
7. `make modules -jN` N的意思同上
8. `make modules_install`
9. `make install`
10. 之后只需要更改grub启动项即可。`mkinitramfs 4.9.2 -o /boot/initrd.img-4.9.2` 其中的4.9.2视自己编译的源码
11. `update-grub2`



## 清理不需要的内核

Linux 内核镜像包含以下包：
* linux-image- : 内核镜像
* linux-image-extra ： 额外的内核模块
* linux-headers ： 内核头文件

查看系统中的内核镜像命令：

`dpkg --list | grep linux-image`
`dpkg --list | grep linux-headers`

在列出的内核镜像中，你可以移除特定版本（以3.19.0-15为例）

`sudo apt-get purge linux-image-3.19.0-15`
`sudo apt-get purge linux-headers-3.19.0-15`

## 编译内核deb包

1. apt-get update
2. apt-get upgrade
3. apt-get dist-upgrade
4. apt-get source linux-image-$(uname -r)
5. apt-get build-dep linux-image-$(uname -r)
6. cd the download kernel source dir
7. cp /boot/config-$(uname -r) ./.config
8. apt-get install libncurses5 libncurses5-dev
9. apt-get install qt3-dev-tools libqt3-mt-dev(可能需要，可能找不到包，与源有关)
10. make menuconfig(default)
11. make-kpkg -j N --initrd --append-to-version=my-very-own-kernel kernel-image kernel-headers(N为cpu核心数，my-very-own-kernel为自己给内核的版本号)
12. dpkg -i *.deb
13. update-grub

## 编译安装单个内核模块



**未完待续...**