---
title: docker详解
date: 2020-10-08T14:21:26+08:00
lastmod: 2020-10-08T14:21:26+08:00
author: hanamichi
cover: /img/docker.jpg
categories: ['容器']
tags: ['docker']
---

docker相关总结

<!--more-->

- [预备知识](#预备知识)
  - [namespace](#namespace)
  - [CGroups](#cgroups)
  - [chroot](#chroot)
- [docker架构](#docker架构)
- [原理](#原理)

## 预备知识

### namespace

命名空间 (namespaces) 是 Linux 为我们提供的用于分离进程树、网络接口、挂载点以及进程间通信等资源的方法。

Linux 的命名空间机制提供了以下七种不同的命名空间，包括

* `CLONE_NEWCGROUP`
* `CLONE_NEWIPC`
* `CLONE_NEWNET`
* `CLONE_NEWNS`
* `CLONE_NEWPID`
* `CLONE_NEWUSER` 
* `CLONE_NEWUTS`

通过这七个选项我们能在创建新的进程时设置新进程应该在哪些资源上与宿主机器进行隔离。

进程是 Linux 以及现在操作系统中非常重要的概念，它表示一个正在执行的程序，也是在现代分时系统中的一个任务单元。

当前机器上有很多的进程正在执行，在上述进程中有两个非常特殊，一个是 `pid` 为 1 的 `/sbin/init` 进程，另一个是 `pid` 为 2 的 `kthreadd` 进程，这两个进程都是被 Linux 中的上帝进程 `idle` 创建出来的，其中前者负责执行内核的一部分初始化工作和系统配置，也会创建一些类似 `getty` 的注册进程，而后者负责管理和调度其他的内核进程。

### CGroups

Linux 的 CGroup 能够为一组进程分配资源，也就是我们在上面提到的 CPU、内存、网络带宽等资源，通过对资源的分配，CGroup 能够提供以下的几种功能：

* resource limiting
* prioritization
* accounting
* control

在 CGroup 中，所有的任务就是一个系统的一个进程，而 CGroup 就是一组按照某种标准划分的进程，在 CGroup 这种机制中，所有的资源控制都是以 CGroup 作为单位实现的，每一个进程都可以随时加入一个 CGroup 也可以随时退出一个 CGroup。

### chroot

在 Linux 系统中，系统默认的目录就都是以 `/` 也就是根目录开头的，`chroot` 的使用能够改变当前的系统根目录结构，通过改变当前系统的根目录，我们能够限制用户的权利，在新的根目录下并不能够访问旧系统根目录的结构个文件，也就建立了一个与原系统完全隔离的目录结构。

## docker架构

![docker-arch](/img/inpost/docker/docker-1.png)

![docker-ps](/img/inpost/docker/docker-2.png)

1. dockerd 是docker-containerd 的父进程， docker-containerd 是n个docker-containerd-shim 的父进程。
2. Containerd 是一个 gRPC 的服务器。它会在接到 docker daemon 的远程请 求之后，新建一个线程去处理这次请求。依靠 runC 去创建容器进程。而在容器启动之后， runC 进程会退出。
3. runC 命令，是 libcontainer 的一个简单的封装。这个工具可以 用来管理单个容器，比如容器创建，或者容器删除。

##  原理

* linux命名空间实现进程、网络以及文件系统的隔离
* cgroups实现CPU、内存等资源的隔离
* 在容器网络模型中，每一个容器内部都包含一个 Sandbox，其中存储着当前容器的网络栈配置，包括容器的接口、路由表和 DNS 设置，Linux 使用网络命名空间实现这个 Sandbox，每一个 Sandbox 中都可能会有一个或多个 Endpoint，在 Linux 上就是一个虚拟的网卡 veth，Sandbox 通过 Endpoint 加入到对应的网络中，这里的网络可能就是我们在上面提到的 Linux 网桥或者 VLAN。
* 想要正常启动一个容器就需要在 rootfs 中挂载几个特定的目录(/dev/,/proc,/bin,/etc,/lib,/usr,/tmp)
* 镜像的本质是压缩包
* UnionFS 其实是一种为 Linux 操作系统设计的用于把多个文件系统『联合』到同一个挂载点的文件系统服务。而 AUFS 即 Advanced UnionFS 其实就是 UnionFS 的升级版，它能够提供更优秀的性能和效率。
* 多种存储驱动，默认为overlay2