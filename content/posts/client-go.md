---
title: client-go详解
date: 2020-10-07T14:21:26+08:00
lastmod: 2020-10-07T14:21:26+08:00
author: hanamichi
cover: /img/client-go.jpg
categories: ['云原生']
tags: ['kubernetes']
---

client-go中informer list&watch机制

<!--more-->

- [clien-go结构原理图示](#clien-go结构原理图示)
- [informer](#informer)
  - [informer组件](#informer组件)
  - [流程实例](#流程实例)

## clien-go结构原理图示

![](/img/inpost/client-go/client-go-1.png)

![](/img/inpost/client-go/client-go-2.jepg)

kubernetes里面的apiserver的只负责数据的CRUD接口实现，并不负责业务逻辑的处理，所以k8s中就通过外挂controller通过对应资源的控制器来负责事件的处理。而controller和apiserver之前的桥梁就是 informer

apiserver本质上就是一个http的rest接口实现，watch机制则也是基于http协议，不过不同于一般的get其通过chunk机制，来实现消息的通知。

![](/img/inpost/client-go/client-go-3.png)

![](/img/inpost/client-go/client-go-4.png)

## informer

Informer模块是Kubernetes中的基础组件，负责各组件与Apiserver的资源与事件同步。

List/Watch机制是Kubernetes中实现集群控制模块最核心的设计之一，它采用统一的异步消息处理机制，保证了消息的实时性、可靠性、顺序性和性能等，为声明式风格的API奠定了良好的基础。

Informer依赖Kubernetes的List/Watch API。 通过Lister()对象来List/Get对象时，Informer不会去请求Kubernetes API，而是直接查询本地缓存，减少对Kubernetes API的直接调用。

Informer 只会调用 Kubernetes List 和 Watch 两种类型的 API。Informer 在初始化的时，先调用 Kubernetes List API 获得某种 resource 的全部 Object，缓存在内存中; 然后，调用 Watch API 去 watch 这种 resource，去维护这份缓存; 最后，Informer 就不再调用 Kubernetes 的任何 API。

### informer组件

- Controller:  并不是 Kubernetes Controller，这两个 Controller 并没有任何联系
- Reflector：通过Kubernetes Watch API监听resource下的所有事件
- Lister：用来被调用List/Get方法
- Processor：记录并触发回调函数, Processor 中记录了所有的回调函数实例(即 ResourceEventHandler 实例)
- DeltaFIFO: DeltaFIFO 和 LocalStore 是 Informer 的两级缓存, 用来存储Watch API返回的各种事件
- LocalStore: DeltaFIFO 和 LocalStore 是 Informer 的两级缓存, Lister的List/Get方法访问

在k8s中一些控制器可能会关注多种资源，比如Deployment可能会关注Pod和replicaset，replicaSet可能还会关注Pod，为了避免每个控制器都独立的去与apiserver建立链接，k8s中抽象了sharedInformer的概念，即共享的informer, 针对同一资源只建立一个链接

因为彼此共用informer,但是每个组件的处理逻辑可能各不相同，在informer中通过观察者模式，各个组件可以注册一个EventHandler来实现业务逻辑的注入

![](/img/inpost/client-go/client-go-5.png)

### 流程实例

以 Pod 为例，详细说明一下 Informer 的关键逻辑：

1. Informer 在初始化时，Reflector 会先 List API 获得所有的 Pod
2. Reflect 拿到全部 Pod 后，会将全部 Pod 放到 Store 中
3. 如果有人调用 Lister 的 List/Get 方法获取 Pod， 那么 Lister 会直接从 Store 中拿数据
4. Informer 初始化完成之后，Reflector 开始 Watch Pod，监听 Pod 相关 的所有事件;如果此时 pod_1 被删除，那么 Reflector 会监听到这个事件
5. Reflector 将 pod_1 被删除 的这个事件发送到 DeltaFIFO
6. DeltaFIFO 首先会将这个事件存储在自己的数据结构中(实际上是一个 queue)，然后会直接操作 Store 中的数据，删除 Store 中的 pod_1
7. DeltaFIFO 再 Pop 这个事件到 Controller 中
8. Controller 收到这个事件，会触发 Processor 的回调函数

![](/img/inpost/client-go/client-go-6.png)