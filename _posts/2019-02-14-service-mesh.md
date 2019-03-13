---
layout:     post
title:      "service mesh初了解"
subtitle:   " \"service mesh envoy等概念记录\""
date:       2019-02-14 12:00:00
author:     "Hanamichi"
header-img: "img/spacex-01.jpg"
catalog: true
tags:
    - servicemesh
    - k8s
---


## 前置知识

### 重要观点

- Kubernetes 的本质是应用的生命周期管理，具体说是部署和管理（扩缩容、自动恢复、发布）。
- Kubernetes 为微服务提供了可扩展、高弹性的部署和管理平台。
- Service Mesh 的基础是透明代理，通过 sidecar proxy 拦截到微服务间流量后再通过控制平面配置管理微服务的行为。
- Service Mesh 将流量管理从 Kubernetes 中解耦，Service Mesh 内部的流量无需 `kube-proxy` 组件的支持，通过为更接近微服务应用层的抽象，管理服务间的流量、安全性和可观察性。
- Envoy xDS 定义了 Service Mesh 配置的协议标准。
- Service Mesh 是对 Kubernetes 中的 service 更上层的抽象，它的下一步是 serverless。



Service mesh 有如下几个特点：

- 应用程序间通讯的中间层
- 轻量级网络代理
- 应用程序无感知
- 解耦应用程序的重试/超时、监控、追踪和服务发现

目前两款流行的 service mesh 开源软件 [Istio](https://istio.io/) 和 [Linkerd](https://linkerd.io/) 都可以直接在 kubernetes 中集成，其中 Linkerd 已经成为 CNCF 成员。



参考资料:

* [service mesh架构](https://jimmysong.io/kubernetes-handbook/usecases/service-mesh-fundamental.html)



## Envoy

> ENVOY IS AN OPEN SOURCE EDGE AND SERVICE PROXY, DESIGNED FOR CLOUD-NATIVE APPLICATIONS
>
> Envoy 是开源的边缘和服务代理，用于云原生应用

Envoy 是专为大型现代 SOA（面向服务架构）架构设计的 L7 代理和通信总线。该项目源于以下理念：

> *网络对应用程序来说应该是透明的。当网络和应用程序出现问题时，应该很容易确定问题的根源。*

Envoy 提供了以下高级功能：

* 非侵入的架构：`Envoy` 是和应用服务并行运行的，透明地代理应用服务发出/接收的流量。应用服务只需要和 `Envoy` 通信，无需知道其他微服务应用在哪里。

* 基于 Modern C++11实现，性能优异。

* L3/L4 过滤器架构：`Envoy` 的核心是一个 L3/L4 代理，然后通过插件式的过滤器(`network filters`)链条来执行 TCP/UDP 的相关任务，例如 TCP 转发，TLS 认证等工作。

* HTTP L7 过滤器架构：HTTP在现代应用体系里是地位非常特殊的应用层协议，所以 `Envoy` 内置了一个非常核心的过滤器: `http_connection_manager`。`http_connection_manager` 本身是如此特殊和复杂，支持丰富的配置，以及本身也是过滤器架构，可以通过一系列 http 过滤器(`http filters`)来实现 http协议层面的任务，例如：http路由，重定向，CORS支持等等。

* HTTP/2 作为第一公民：`Envoy` 支持 HTTP/1.1 和 HTTP/2，推荐使用 HTTP/2。

* gRPC 支持：因为对 HTTP/2 的良好支持，`Envoy` 可以方便的支持 gRPC，特别是在负载和代理上。

* 服务发现： 支持包括 DNS, EDS 在内的多种服务发现方案。

* 健康检查：内置健康检查子系统。

* 高级的负载均衡方案：除了一般的负载均衡，Envoy 还支持基于 rate limit 服务的多种高级负载均衡方案，包括： automatic retries, circuit breaking, global rate limiting

* Tracing：方便集成 Open Tracing 系统，追踪请求

* 统计与监控：内置 stats 模块，方便集成诸如 prometheus/statsd 等监控方案

* 动态配置：通过动态配置API实现配置的动态调整，而无需重启 `Envoy` 服务的。



### 核心概念

**Host**

这里的 Host，可以理解为由 IP, Port 唯一确定的服务实例

**Downstream**

发送请求给 Envoy 的 Host 是 Downstream(下游)，例如gRPC的 client

**Upstream**

接收 Enovy 发出的请求的 Host 是Upstream(上游)，例如 gRPC的 server

**Listener**

Envoy 监听的一个地址，envoy既然是proxy，专门做转发，就得监听一个端口，接入请求，然后才能够根据策略转发，这个监听的端口称为listener

**endpoint**

是目标的ip地址和端口，这个是proxy最终将请求转发到的地方。

**Cluster**

一组功能一致的上游 Host，称为一个cluster。类似 `k8s` 的 `Service`, `nginx` 的 `upstream`。一个cluster是具有完全相同行为的多个endpoint，也即如果有三个容器在运行，就会有三个IP和端口，但是部署的是完全相同的三个服务，他们组成一个Cluster，从cluster到endpoint的过程称为负载均衡，可以轮询等。

**Http Route Table**

HTTP 的路由规则，例如请求的域名，Path符合什么规则，转发给哪个 Cluster。

### 与类似软件比较

#### [nginx](https://nginx.org/en/)

nginx是一个经典的现代web服务器。 它支持静态内容展现， HTTP L7反向代理 负载均衡，HTTP/2，以及其他的许多特性。 作为一个边缘反向代理，nginx提供了远远多于 Envoy 的功能特性， 但我们认为大多数的现代面向服务的架构其实不需要用到那么多的特性。 而 Envoy 在下列边缘代理的特性做得比 nginx 更为出色:

- 完备的HTTP/2 透明代理支持。 Envoy支持HTTP/2 包括上游连接以及下游连接在内的双向通信。 而 nginx 仅仅支持HTTP/2 下游连接。
- 免费的高级负载功能。 而在 nginx 的世界，只有付费的 nginx plus 服务器才能提供类同于 Envoy 的高级负载功能。
- 可以在每一个服务节点的边界运行同样一套软件来处理事务。 在许多架构体系中，需要使用 nginx 与 haproxy 的混合部署架构。 相比之下，一个独立的代理解决方案会更有利于后续的运维维护。

#### [haproxy](http://www.haproxy.org/)

haproxy 是一个经典的现代软负载均衡服务器。它提供基本的 HTTP 反向代理功能。 而 Envoy 在下列负载均衡的特性做得比 haproxy 更为出色：

- HTTP/2 支持。
- 可插拔架构。
- 与远程服务发现服务的整合。
- 与远程全局限速服务的整合。
- 提供大量的更为细致的统计分析。

### 简单示例

#### 环境准备

* docker
* docker-compose
* git clone https://github.com/envoyproxy/envoy.git

#### 前端代理功能

使用envoy自带的简单例子来验证envoy的前端代理功能

* `cd envoy/examples/front-proxy`
* `docker-compose up --build -d`

服务的结构图如下:

![envoy](/img/in-post/k8s-istio/envoymesh.png)

front-envoy容器监听本机80端口，根据请求的url分发到后端的service1和service2，service1和service2容器中除service自身进程外，也有一个envoy进程。

测试envoy的路由能力:

```shell
[root@localhost front-proxy]# curl -v 192.168.234.185:8000/service/1
* About to connect() to 192.168.234.185 port 8000 (#0)
*   Trying 192.168.234.185...
* Connected to 192.168.234.185 (192.168.234.185) port 8000 (#0)
> GET /service/1 HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 192.168.234.185:8000
> Accept: */*
> 
< HTTP/1.1 200 OK
< content-type: text/html; charset=utf-8
< content-length: 89
< server: envoy
< date: Fri, 01 Mar 2019 02:57:47 GMT
< x-envoy-upstream-service-time: 6
< 
Hello from behind Envoy (service 1)! hostname: b23dda0a4e84 resolvedhostname: 172.18.0.3
* Connection #0 to host 192.168.234.185 left intact
```

```shell
[root@localhost front-proxy]# curl -v 192.168.234.185:8000/service/2
* About to connect() to 192.168.234.185 port 8000 (#0)
*   Trying 192.168.234.185...
* Connected to 192.168.234.185 (192.168.234.185) port 8000 (#0)
> GET /service/2 HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 192.168.234.185:8000
> Accept: */*
> 
< HTTP/1.1 200 OK
< content-type: text/html; charset=utf-8
< content-length: 89
< server: envoy
< date: Fri, 01 Mar 2019 02:58:27 GMT
< x-envoy-upstream-service-time: 4
< 
Hello from behind Envoy (service 2)! hostname: 4c15ee182dcf resolvedhostname: 172.18.0.4
* Connection #0 to host 192.168.234.185 left intact
```

扩展服务1的个数为3，测试envoy的负载均衡功能:

`docker-compose scale service1=3`

多次向 service1 发送请求，前端 envoy 将通过循环轮询三台 service1 机器来负载均衡请求：

```shell
[root@localhost front-proxy]# curl -v 192.168.234.185:8000/service/1
* About to connect() to 192.168.234.185 port 8000 (#0)
*   Trying 192.168.234.185...
* Connected to 192.168.234.185 (192.168.234.185) port 8000 (#0)
> GET /service/1 HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 192.168.234.185:8000
> Accept: */*
> 
< HTTP/1.1 200 OK
< content-type: text/html; charset=utf-8
< content-length: 89
< server: envoy
< date: Fri, 01 Mar 2019 03:00:58 GMT
< x-envoy-upstream-service-time: 4
< 
Hello from behind Envoy (service 1)! hostname: c1cb6c31f7f4 resolvedhostname: 172.18.0.6
* Connection #0 to host 192.168.234.185 left intact
[root@localhost front-proxy]# curl -v 192.168.234.185:8000/service/1
* About to connect() to 192.168.234.185 port 8000 (#0)
*   Trying 192.168.234.185...
* Connected to 192.168.234.185 (192.168.234.185) port 8000 (#0)
> GET /service/1 HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 192.168.234.185:8000
> Accept: */*
> 
< HTTP/1.1 200 OK
< content-type: text/html; charset=utf-8
< content-length: 89
< server: envoy
< date: Fri, 01 Mar 2019 03:01:00 GMT
< x-envoy-upstream-service-time: 5
< 
Hello from behind Envoy (service 1)! hostname: aac59ca26f25 resolvedhostname: 172.18.0.5
* Connection #0 to host 192.168.234.185 left intact
[root@localhost front-proxy]# curl -v 192.168.234.185:8000/service/1
* About to connect() to 192.168.234.185 port 8000 (#0)
*   Trying 192.168.234.185...
* Connected to 192.168.234.185 (192.168.234.185) port 8000 (#0)
> GET /service/1 HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 192.168.234.185:8000
> Accept: */*
> 
< HTTP/1.1 200 OK
< content-type: text/html; charset=utf-8
< content-length: 89
< server: envoy
< date: Fri, 01 Mar 2019 03:01:01 GMT
< x-envoy-upstream-service-time: 2
< 
Hello from behind Envoy (service 1)! hostname: b23dda0a4e84 resolvedhostname: 172.18.0.3
* Connection #0 to host 192.168.234.185 left intact
[root@localhost front-proxy]# curl -v 192.168.234.185:8000/service/1
* About to connect() to 192.168.234.185 port 8000 (#0)
*   Trying 192.168.234.185...
* Connected to 192.168.234.185 (192.168.234.185) port 8000 (#0)
> GET /service/1 HTTP/1.1
> User-Agent: curl/7.29.0
> Host: 192.168.234.185:8000
> Accept: */*
> 
< HTTP/1.1 200 OK
< content-type: text/html; charset=utf-8
< content-length: 89
< server: envoy
< date: Fri, 01 Mar 2019 03:01:04 GMT
< x-envoy-upstream-service-time: 1
< 
Hello from behind Envoy (service 1)! hostname: c1cb6c31f7f4 resolvedhostname: 172.18.0.6
* Connection #0 to host 192.168.234.185 left intact
```

获取监测信息和服务信息:

`docker-compose exec front-envoy /bin/bash`

```shell
root@c08407f9ebea:/# curl localhost:8001/server_info
{
 "version": "9612555c2e8171901b0c04a51af0030b11178116/1.10.0-dev/Clean/RELEASE/BoringSSL",
 "state": "LIVE",
 "command_line_options": {
  "base_id": "0",
  "concurrency": 4,
  "config_path": "/etc/front-envoy.yaml",
  "config_yaml": "",
  "allow_unknown_fields": false,
  "admin_address_path": "",
  "local_address_ip_version": "v4",
  "log_level": "info",
  "component_log_level": "",
  "log_format": "[%Y-%m-%d %T.%e][%t][%l][%n] %v",
  "log_path": "",
  "hot_restart_version": false,
  "service_cluster": "front-proxy",
  "service_node": "",
  "service_zone": "",
  "mode": "Serve",
  "max_stats": "16384",
  "max_obj_name_len": "60",
  "disable_hot_restart": false,
  "enable_mutex_tracing": false,
  "restart_epoch": 0,
  "file_flush_interval": "10s",
  "drain_time": "600s",
  "parent_shutdown_time": "900s"
 },
 "uptime_current_epoch": "3870s",
 "uptime_all_epochs": "3870s"
}

root@c08407f9ebea:/# curl localhost:8001/stats
access_log_file.flushed_by_timer: 274
access_log_file.reopen_failed: 0
access_log_file.write_buffered: 4
access_log_file.write_completed: 4
access_log_file.write_total_buffered: 0
cluster.service1.bind_errors: 0
cluster.service1.circuit_breakers.default.cx_open: 0
cluster.service1.circuit_breakers.default.rq_open: 0
cluster.service1.circuit_breakers.default.rq_pending_open: 0
cluster.service1.circuit_breakers.default.rq_retry_open: 0
cluster.service1.circuit_breakers.high.cx_open: 0
cluster.service1.circuit_breakers.high.rq_open: 0
cluster.service1.circuit_breakers.high.rq_pending_open: 0
cluster.service1.circuit_breakers.high.rq_retry_open: 0
cluster.service1.external.upstream_rq_200: 15
cluster.service1.external.upstream_rq_2xx: 15
cluster.service1.external.upstream_rq_completed: 15
cluster.service1.http2.header_overflow: 0
cluster.service1.http2.headers_cb_no_stream: 0
cluster.service1.http2.rx_messaging_error: 0
cluster.service1.http2.rx_reset: 0
cluster.service1.http2.too_many_header_frames: 0
cluster.service1.http2.trailers: 0
cluster.service1.http2.tx_reset: 0
cluster.service1.lb_healthy_panic: 0
cluster.service1.lb_local_cluster_not_ok: 0
cluster.service1.lb_recalculate_zone_structures: 0
cluster.service1.lb_subsets_active: 0
cluster.service1.lb_subsets_created: 0
cluster.service1.lb_subsets_fallback: 0
cluster.service1.lb_subsets_removed: 0
cluster.service1.lb_subsets_selected: 0
cluster.service1.lb_zone_cluster_too_small: 0
cluster.service1.lb_zone_no_capacity_left: 0
cluster.service1.lb_zone_number_differs: 0
cluster.service1.lb_zone_routing_all_directly: 0
cluster.service1.lb_zone_routing_cross_zone: 0
cluster.service1.lb_zone_routing_sampled: 0
cluster.service1.max_host_weight: 1
cluster.service1.membership_change: 2
cluster.service1.membership_degraded: 0
cluster.service1.membership_healthy: 3
cluster.service1.membership_total: 3
cluster.service1.original_dst_host_invalid: 0
cluster.service1.retry_or_shadow_abandoned: 0
cluster.service1.update_attempt: 783
cluster.service1.update_empty: 0
cluster.service1.update_failure: 0
cluster.service1.update_no_rebuild: 781
cluster.service1.update_success: 783
cluster.service1.upstream_cx_active: 8
cluster.service1.upstream_cx_close_notify: 0
cluster.service1.upstream_cx_connect_attempts_exceeded: 0
cluster.service1.upstream_cx_connect_fail: 0
cluster.service1.upstream_cx_connect_timeout: 0
cluster.service1.upstream_cx_destroy: 0
cluster.service1.upstream_cx_destroy_local: 0
cluster.service1.upstream_cx_destroy_local_with_active_rq: 0
cluster.service1.upstream_cx_destroy_remote: 0
cluster.service1.upstream_cx_destroy_remote_with_active_rq: 0
cluster.service1.upstream_cx_destroy_with_active_rq: 0
cluster.service1.upstream_cx_http1_total: 0
cluster.service1.upstream_cx_http2_total: 8
cluster.service1.upstream_cx_idle_timeout: 0
cluster.service1.upstream_cx_max_requests: 0
cluster.service1.upstream_cx_none_healthy: 0
cluster.service1.upstream_cx_overflow: 0
cluster.service1.upstream_cx_protocol_error: 0
cluster.service1.upstream_cx_rx_bytes_buffered: 1396
cluster.service1.upstream_cx_rx_bytes_total: 2936
cluster.service1.upstream_cx_total: 8
cluster.service1.upstream_cx_tx_bytes_buffered: 0
cluster.service1.upstream_cx_tx_bytes_total: 2044
cluster.service1.upstream_flow_control_backed_up_total: 0
cluster.service1.upstream_flow_control_drained_total: 0
cluster.service1.upstream_flow_control_paused_reading_total: 0
cluster.service1.upstream_flow_control_resumed_reading_total: 0
cluster.service1.upstream_internal_redirect_failed_total: 0
cluster.service1.upstream_internal_redirect_succeeded_total: 0
cluster.service1.upstream_rq_200: 15
cluster.service1.upstream_rq_2xx: 15
cluster.service1.upstream_rq_active: 0
cluster.service1.upstream_rq_cancelled: 0
cluster.service1.upstream_rq_completed: 15
cluster.service1.upstream_rq_maintenance_mode: 0
cluster.service1.upstream_rq_pending_active: 0
cluster.service1.upstream_rq_pending_failure_eject: 0
cluster.service1.upstream_rq_pending_overflow: 0
cluster.service1.upstream_rq_pending_total: 8
cluster.service1.upstream_rq_per_try_timeout: 0
cluster.service1.upstream_rq_retry: 0
cluster.service1.upstream_rq_retry_overflow: 0
cluster.service1.upstream_rq_retry_success: 0
cluster.service1.upstream_rq_rx_reset: 0
cluster.service1.upstream_rq_timeout: 0
cluster.service1.upstream_rq_total: 15
cluster.service1.upstream_rq_tx_reset: 0
cluster.service1.version: 0
cluster.service2.bind_errors: 0
.....
.....
```

以下是envoy-front服务的envoy配置和service1的服务配置:

```yaml
static_resources:
  listeners:
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 80
    filter_chains:
    - filters:
      - name: envoy.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
          codec_type: auto
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: backend
              domains:
              - "*"
              routes:
              - match:
                  prefix: "/service/1"
                route:
                  cluster: service1
              - match:
                  prefix: "/service/2"
                route:
                  cluster: service2
          http_filters:
          - name: envoy.router
            typed_config: {}
  clusters:
  - name: service1
    connect_timeout: 0.25s
    type: strict_dns
    lb_policy: round_robin
    http2_protocol_options: {}
    load_assignment:
      cluster_name: service1
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: service1
                port_value: 80
  - name: service2
    connect_timeout: 0.25s
    type: strict_dns
    lb_policy: round_robin
    http2_protocol_options: {}
    load_assignment:
      cluster_name: service2
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: service2
                port_value: 80
admin:
  access_log_path: "/dev/null"
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 8001
```

```yaml
static_resources:
  listeners:
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 80
    filter_chains:
    - filters:
      - name: envoy.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
          codec_type: auto
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: service
              domains:
              - "*"
              routes:
              - match:
                  prefix: "/service"
                route:
                  cluster: local_service
          http_filters:
          - name: envoy.router
            typed_config: {}
  clusters:
  - name: local_service
    connect_timeout: 0.25s
    type: strict_dns
    lb_policy: round_robin
    load_assignment:
      cluster_name: local_service
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 8080
admin:
  access_log_path: "/dev/null"
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 8081
```

### 动态配置

以上的简单例子是envoy的静态配置，而envoy更强大的是使用xDS协议进行动态配置

Envoy 提供了如下的 API：

- CDS（Cluster Discovery Service）：集群发现服务
- EDS（Endpoint Discovery Service）：端点发现服务
- HDS（Health Discovery Service）：健康发现服务
- LDS（Listener Discovery Service）：监听器发现服务
- MS（Metric Service）：将 metric 推送到远端服务器
- RLS（Rate Limit Service）：速率限制服务
- RDS（Route Discovery Service）：路由发现服务
- SDS（Secret Discovery Service）：秘钥发现服务

所有名称以 DS 结尾的服务统称为 xDS。

envoy是为云原生应用设计的代理，可以很好的继承在k8s与service mesh中。现在**Istio**的默认sidecar容器就是envoy。

通过istio的[bookinfo示例](https://istio.io/zh/docs/examples/bookinfo/)例子可以很好的体会envoy的动态配置功能



参考资料:

* [xDS协议解析](https://jimmysong.io/istio-handbook/data-plane/envoy-xds-protocol.html)
* [envoy官方文档](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview)

* [istio文档](https://istio.io/zh/docs/concepts/what-is-istio/)
* [深入service mesh背后的细节](https://www.cnblogs.com/163yun/p/8962278.html)