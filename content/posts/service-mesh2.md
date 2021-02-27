---
title: ServiceMesh探究PPT记录
date: 2021-01-03T14:21:26+08:00
lastmod: 2021-01-03T14:21:26+08:00
author: hanamichi
cover: /img/servicemesh.jpg
categories: ['云原生']
tags: ['service mesh','kubernetes']
---

ServiceMesh PPT

<!--more-->

- [云原生](#云原生)
- [service mesh](#service-mesh)
  - [what's service mesh](#whats-service-mesh)
  - [why need Service Mesh](#why-need-service-mesh)
  - [缺点](#缺点)
- [Istio](#istio)
- [参考链接](#参考链接)
- [PPT](#ppt)

## 云原生

关键词: 微服务，高度分布式，不断变化

- 应用系统应该与底层物理基础设施解耦。 应用程序应该与操作系统等基础设施分离，不应该依赖Linux或Windows等底层平台，或依赖某个云平台。也就是说，应用从开始就设计为运行在云中，无论私有云或公有云；
- 应用必须能满足扩展性需求 垂直扩展（向上和向下）或水平扩展（跨节点服务器）。

简单总结:

* 云原生是一种行为方式和设计理念，凡是能够提高云上资源利用率和应用交付效率的行为和方式都是云原生的
* 云原生应用: 将系统资源，底层基础设施和应用编排交给云平台管理，应用只关注业务逻辑

## service mesh

### what's service mesh

**微服务的网络通信基础设施，负责(系统内部的)服务间的通信**

Service Mesh 实际是处于 TCP/IP 之上的抽象层。

* Service Mesh 对服务节点间请求的路由机制进行了抽象 (TCP 对网络端点间传输字节的机制进行了抽象)
  * 不关心消息体，不关心消息编码
  * 将某些东西从A传到B, 并处理传送过程中的出现的故障
* 为应用运行时提供统一的、应用层面的可见性和可控性
  * 将服务间通信从底层基础设施中分离，让其可被监控、托管和控制

feature list:

* 流量控制
  * 服务发现
  * 请求路由
  * 负载均衡
  * 灰度发布(蓝绿部署)
  * A/B Test
  * 错误重试
  * 断路器
  * 故障注入
* 可观察性
  * 遥测数据
  * 调用追踪
  * 服务拓扑
* 通信安全
  * 服务身份认证
  * 访问鉴权
  * 通信加密

### why need Service Mesh

应用架构的发展:

* 单体应用时代， 主要是应用进程内部的调用

* SOA&微服务时代, 应用层被拆分为多个服务，应用层变为了一种拓扑结构，服务间的调用需要一个通信层，比如 Spring Cloud 中常用的 Netflix 开源的 Hystrix, 这部分其实就是微服务的治理能力，由框架接入的能力，侵入了服务内部，且服务的开发语言选择也与框架绑定

  ![](/Users/hanamichi/Downloads/微服务冰山理论.png)

* 云原生模型，容器和编排层(k8s)的兴起，容器提供了资源隔离和依赖管理以及应用发布的能力，k8s提供了对底层硬件的资源池化能力以及应用生命周期的管理能力。随着服务及其实例的增多，服务拓扑间的流量路线变得非常复杂，再加上服务是多语言开发的，网络通信层的抽象就顺理成章的出现了

### 缺点

* sidecar带来的延迟

## Istio

Istio 是 Service Mesh 的标志性产品，有一定可能性成为事实标准

主要功能点:

- 为 HTTP、gRPC、WebSocket 和 TCP 流量自动负载均衡。
- 通过丰富的路由规则、重试、故障转移和故障注入对流量行为进行细粒度控制。
- 可插拔的策略层和配置 API，支持访问控制、速率限制和配额。
- 集群内（包括集群的入口和出口）所有流量的自动化度量、日志记录和追踪。
- 在具有强大的基于身份验证和授权的集群中实现安全的服务间通信。

## 参考链接

* [What’s a service mesh? And why do I need one?](https://buoyant.io/2020/10/12/what-is-a-service-mesh/)



## PPT

![](/img/inpost/ServiceMesh/ServiceMesh.001.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.002.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.003.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.004.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.005.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.006.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.007.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.008.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.009.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.010.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.011.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.012.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.013.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.014.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.015.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.016.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.017.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.018.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.019.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.020.jpeg)

![](/img/inpost/ServiceMesh/ServiceMesh.021.jpeg)