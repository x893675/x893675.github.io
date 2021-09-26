---
title: buildx构建多架构镜像
date: 2021-09-20T14:21:26+08:00
lastmod: 2021-09-20T14:21:26+08:00
author: hanamichi
cover: /img/container.jpg
categories: ['容器']
tags: ['docker']
---

使用 docker buildx 进行多架构镜像构建

<!--more-->

- [buildx安装](#buildx安装)
- [buildx 配置设置使用私有镜像仓库](#buildx-配置设置使用私有镜像仓库)
- [samples](#samples)


## buildx安装

**注意**： 建议系统内核升到 5.4+

参考文档 [install buildx](https://github.com/x893675/note/wiki/CloudNative%3A-buildx)

## buildx 配置设置使用私有镜像仓库

docker buildx 上传镜像到私有镜像仓库，通过改 host 以及加证书没有效果。是因为 docker buildx 使用 dns 来解析。

要使用 docker buildx 上传到私有镜像仓库，需要在宿主机搭建一个本地 dns，更改 `/etc/resolv.conf`

如果开启了私有仓库的 https 认证，需要把证书拷贝进 buildx 实例容器中，且在宿主机上也需要配置

## samples

环境说明:

* 私有 harbor， 域名为 caas.registry.com，使用自签 tls 证书
*  centos内核: 5.4.118-1.el7.elrepo.x86_64, 本机 **ip: 10.0.0.13**
* 已安装 docker buildx
* harbor 证书已放置在 `/etc/docker/certs.d/`目录中

步骤如下:

1. 以 systemd 方式安装 coredns, cordons 配置文件如下:

   ```ini
   .:53 {
     # 绑定interface ip
     bind 10.0.0.13
     # 先走本机的hosts
     # https://coredns.io/plugins/hosts/
     hosts {
       # 自定义sms.service search.service 的解析
       # 因为解析的域名少我们这里直接用hosts插件即可完成需求
       # 如果有大量自定义域名解析那么建议用file插件使用 符合RFC 1035规范的DNS解析配置文件
       172.16.29.140 caas.registry.com
       # ttl
       ttl 60
       # 重载hosts配置
       reload 1m
       # 继续执行
       fallthrough
     }
     # file enables serving zone data from an RFC 1035-style master file.
     # https://coredns.io/plugins/file/
     # file service.signed service
     # 最后所有的都转发到系统配置的上游dns服务器去解析
     forward . /etc/resolv.conf
     # 缓存时间ttl
     cache 120
     # 自动加载配置文件的间隔时间
     reload 6s
     # 输出日志
     log
     # 输出错误
     errors
   }
   ```

2. 将 `nameserver 10.0.0.13` 本机 ip 写入 `/etc/resolv.conf` 的第一行，ping harbor 地址查看是否正常

3. 测试登录harbor，拉取镜像正常

4. 参考 [drone exec runner 安装](https://docs.drone.io/runner/exec/installation/linux/) 部署 drone exec runner

5. 创建 cicd buildx instance

   1. `docker buildx create --driver-opt network=host --use --name cicd`
   2. `docker buildx use --global cicd`
   3. `docker buildx inspect --bootstrap`
   4. 进入 buildx cicd 的实例容器， `docker exec -it buildx_buildkit_cicd0 sh`， 将 harbor 的 ca 证书加入到 /usr/local/share/ca-certificates, 执行 `update-ca-certificates`, 重启容器
   5. 将 harbor ca 证书加入 `/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem` 的末尾
   6. 验证在本机执行 buildx 构建上传到 harbor 仓库