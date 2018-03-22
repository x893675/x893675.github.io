---
layout:     post
title:      "Git"
subtitle:   " \"Git操作整理\""
date:       2018-03-07 12:00:00
author:     "Hanamichi"
header-img: "img/spacex-3.jpg"
catalog: true
tags:
    - Linux
    - Centos
---

## 搭建yum本地仓库

使用国内的源作为本地源的上游，可以使用以下国内源:

* [阿里云](http://mirrors.aliyun.com/ )
* [中国科技大学](http://centos.ustc.edu.cn/[centos/)，[中科大centos源使用帮助](https://lug.ustc.edu.cn/wiki/mirrors/help/centos)

本地源搭建完毕后，通过docker启动一个nginx服务，使建立的本地仓库可以通过url访问

### 打开端口或者关闭防火墙

todo...

### 安装软件包

`yum install createrepo`

### 制作本地yum仓库

**1.修改本地源(以中科大源和centos7为例)**

`cd /etc/yum.repos.d/`

`mv CentOS-Base.repo CentOS-Base.repo.bak`

`wget -O CentOS-Base.repo https://lug.ustc.edu.cn/wiki/_export/code/mirrors/help/centos?codeblock=3`

**2.与上游镜像仓库进行同步**

`mkdir /root/html/Centos-yum`

`reposync -p /root/html/Centos-yum`

第二条命令会将`/etc/yum.repos.d`目录下的所有仓库全部下载，也可通过`--repoid=name`参数指定需要下载哪个repo文件的包

**3.建仓**

通过前两步yum源的server端就建立好了。然后进行建仓，即yum源仓库，供client端检索使用

`createrepo -p /root/html/Centos-yum/base`

该命令会在base目录下建立repodata目录

以上3个步骤完成后，客户端就可以通过配置repo文件下载这些rpm包了

### 使用docker的nginx服务挂在yum仓库

`docker pull nginx`

`docker run --name=yum-src -d -p 10022:80 -v /root/work/html:/usr/share/html nginx`

配置docker参考文章http://blog.csdn.net/wangfei0904306/article/details/77623400

### 客户端配置

```bash
[ustc_base]
name=src_from_ustc - base
baseurl=http://172.29.101.81:10022/CentOS-YUM/base
gpgcheck=0

[ustc_updates]
name=src_from_ustc - update
baseurl=http://172.29.101.81:10022/CentOS-YUM/updates
gpgcheck=0

[ustc_extras]
name=src_from_ustc - extras
baseurl=http://172.29.101.81:10022/CentOS-YUM/extras
gpgcheck=0
```

