---
title: dns查询原理
date: 2023-09-09T12:00:00+08:00
lastmod: 2023-09-09T12:00:00+08:00
author: hanamichi
cover: /img/servicemesh.jpg
categories: ['linux']
tags: ['linux','dns']
---

DNS 查询原理

<!--more-->

- [DNS 服务器类型](#dns-服务器类型)
- [DNS 查询过程](#dns-查询过程)
- [本机测试](#本机测试)
  - [环境说明](#环境说明)
  - [测试过程](#测试过程)


## DNS 服务器类型

* 根域名服务器(root name server): 顶级域名服务器的顶级，管理顶级域名服务器的域名和IP地址。
* 顶级域名服务器(top-level domain server): 管理各自顶级域名服务器的域名和IP地址。
* 权威域名服务器(authoritative name server): 管理各自域名的域名和IP地址。
* 本地域名服务器 / 递归域名服务器 (local name server): 一般由运行商提供，主要作用就是代理用户进行域名解析，用户的所有域名解析请求都会发送到本地域名服务器，本地域名服务器会根据域名的层级关系，从根域名服务器开始递归查询，直到找到对应的IP地址，然后返回给用户。常见的本地域名服务器有：114.114.114.114 / 8.8.8.8 等

![dns服务器类型](/img/inpost/dns/dns-2.png)

域名服务器中的缓存时间由记录的 TTL(Time To Live) 值决定，TTL 值越小，缓存时间越短。通常这个时间由域名的所有者设置.

## DNS 查询过程

查询总的来说分为两类: 递归查询和迭代查询

一般来说，客户端到本地域名服务器的查询是递归查询，本地域名服务器到根域名服务器的查询是迭代查询。

用户向本地域名服务器只发送一条查询请求，本地域名服务器会代替用户向根域名服务器，顶级域名服务器，权威域名服务器等发送多条查询请求，直到找到对应的IP地址，然后返回给用户。

```shell
# 本机ip: 10.0.0.146, 网关ip: 10.0.0.4
# 使用 tcpdump 抓包
tcpdump -i any -nt -s 500 port domain

#另外开一个终端，使用 dig 命令查询域名
dig hanamichi.wiki @10.0.0.4
```

结果如下图所示:

![dig查询结果](/img/inpost/dns/dns-1.png)

可以看到，本机向网关发送了一条 dns 查询请求，网关将 dns 查询转发到了上游的公共递归 dns 服务器，上游 dns 服务器返回了查询结果。


以用浏览器访问 `github.com` 网站为例，访问过程如下：

1. 浏览器缓存: 浏览器会首先检查自己的缓存中是否有该域名对应的解析结果，如果有，则直接返回结果，不再进行后续的 DNS 解析。
2. 操作系统缓存: 浏览器缓存中无域名对应 IP 则会自动检查用户计算机系统 Hosts 文件 DNS 缓存是否有该域名对应 IP。
3. 公共递归 DNS 服务器 / Local DNS Server : 通常是向 ISP 的 DNS 服务器中查询，如果 ISP 的 DNS 中没有缓存，则会向根域名服务器发起请求。
4. 询问根域名服务器: 根域名收到请求后会查看区域文件记录，若无则将其管辖范围内顶级域名（如.com、.cn等）服务器 IP 告诉本地 DNS 服务器。
5. 询问顶级域名服务器: 顶级域名服务器收到请求后查看区域文件记录，若无记录则将其管辖范围内权威域名服务器的 IP 地址告诉本地 DNS 服务器。
6. 询问权威域名服务器: 权威域名服务器接受到请求后查询自己的缓存，如果没有则进入下一级域名服务器进行查找，并重复该步骤直至找到正确记录。
7. 递归 DNS 服务器 / 本地域名服务器 把返回的结果保存到缓存，以备下一次使用，同时将该结果反馈给客户端

上述描述的 1,2 两步在客户端完成，3-7 在本地域名服务器完成。

![递归dns服务器查询过程](/img/inpost/dns/dns-3.png)

上图出自`https://github.com/azl397985856/fe-interview/issues/108`

## 本机测试

### 环境说明

time.hanamichi.wiki 在阿里云上做了解析， cname 到 iovip-as0.qiniuio.com， ttl是600秒

iovip-as0.qiniuio.com 是七牛的一个域名，用于做 cdn 加速

### 测试过程

```shell
dig time.hanamichi.wiki +trace +additional
```

![](/img/inpost/dns/dns-4.png)

* 第一次查询，返回了 13 个跟剧名服务器的地址。
* 第二次查询，向 `h.root-servers.net` 查询，返回了顶级域名 .wiki 记录的地址。
* 第三次查询，向 `b.nic.wiki` 查询，返回了权威域名服务器 hanamichi.wiki 的地址
* 第四次查询，向 `dns16.hichina.com` 查询，返回了 time.hanamcihi.wiki 的解析记录

```shell
dig iovip-as0.qiniuio.com +trace +additional
```

![](/img/inpost/dns/dns-5.png)

* 第一次查询，返回了 13 个跟剧名服务器的地址。
* 第二次查询，向 `m.root-servers.net` 查询，返回了顶级域名 .com 记录的地址。
* 第三次查询，向 `a.gtld-servers.net` 查询，返回了权威域名服务器 qiniuio.com 的地址
* 第四次查询，向 `ns3.dnsv5.com` 查询，返回了 `iovip-as0.qiniuio.com.` 的解析记录

查询域名用到的权威服务器可以使用命令:

```shell
nslookup -type=TXT time.hanamichi.wiki 114.114.114.114
```

![](/img/inpost/dns/dns-6.png)