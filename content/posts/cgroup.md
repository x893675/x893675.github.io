---
title: CGroup理解
date: 2021-02-01T14:21:26+08:00
lastmod: 2021-02-13T14:21:26+08:00
author: hanamichi
cover: /img/cgroup.jpg
categories: ['底层虚拟化技术']
tags: ['linux','docker']
---

ServiceMesh PPT

<!--more-->

- [CGroup](#cgroup)
- [重点概念](#重点概念)
  - [cpu限制](#cpu限制)
- [Env&Prechecks](#envprechecks)
- [cgroup cpu demo](#cgroup-cpu-demo)
  - [demo script](#demo-script)
  - [create test cgroup](#create-test-cgroup)
  - [test](#test)
- [mem demo](#mem-demo)

## CGroup

cgroups(Control Groups) 是 linux 内核提供的一种机制，**这种机制可以根据需求把一系列系统任务及其子任务整合(或分隔)到按资源划分等级的不同组内，从而为系统资源管理提供一个统一的框架**。

简单说，cgroups 可以限制、记录任务组所使用的物理资源。

本质上来说，cgroups 是内核附加在程序上的一系列钩子(hook)，通过程序运行时对资源的调度触发相应的钩子以达到资源追踪和限制的目的。

## 重点概念

* **Task(任务)**：在 linux 系统中，内核本身的调度和管理并不对进程和线程进行区分，只是根据 clone 时传入的参数的不同来从概念上区分进程和线程。这里使用 task 来表示系统的一个进程或线程。将一个 pid 写入到 tasks 中，只有这个 pid 对应的线程，以及由它产生的其他进程、线程会属于这个控制组

* **cgroups.procs**：pid 写入 cgroups.procs，操作系统则会把找到其所属进程的所有线程，把它们统统加入到当前控制组。

使用 `mount | cgroup` 查看系统挂载的 cgroup 子系统

主要有以下几种:

|   子系统   |                                                              |
| :--------: | :----------------------------------------------------------- |
|   blkio    | 对块设备的 IO 进行限制                                       |
|    cpu     | 限制 CPU 时间片的分配，与 cpuacct 挂载在同一目录             |
|  cpuacct   | 生成 cgroup 中的任务占用 CPU 资源的报告，与 cpu 挂载在同一目录 |
|   cpuset   | 给 cgroup 中的任务分配独立的 CPU(多处理器系统) 和内存节点    |
|  devices   | 允许或禁止 cgroup 中的任务访问设备                           |
|  freezer   | 暂停/恢复 cgroup 中的任务                                    |
|  hugetlb   | 限制使用的内存页数量                                         |
|   memory   | 对 cgroup 中的任务的可用内存进行限制，并自动生成资源占用报告 |
|  net_cls   | 使用等级识别符（classid）标记网络数据包，这让 Linux 流量控制器（tc 指令）可以识别来自特定 cgroup 任务的数据包，并进行网络限制 |
|  net_prio  | 允许基于 cgroup 设置网络流量(netowork traffic)的优先级       |
| perf_event | 允许使用 perf 工具来监控 cgroup                              |
|    pids    | 限制任务的数量                                               |

### cpu限制

cpu子系统根据进程设置的调度属性，选择对应的CPU资源调度方法

1. [完全公平调度 Completely Fair Scheduler (CFS)](https://www.kernel.org/doc/Documentation/scheduler/sched-design-CFS.txt?spm=a2c6h.12873639.0.0.5faf1b924vDOWa&file=sched-design-CFS.txt)

   CFS调度针对属性为 **SCHED_OTHER, SCHED_BATCH, SCHED_IDLE** 的进程

   限制手段分为两方面，

   1. 限制资源组的CPU使用硬上限，

   2. 以及资源组的CPU使用权重。

   CFS调度资源组内的任务在CPU空闲时超权重使用CPU资源，但是不能超过硬上限。主要配置是

   * cpu.shares: 相对权重
   * cpu.cfs_period_us: 统计CPU使用时间的周期，需要与 cpu.cfs_quota_us 一起使用
   * cpu.cfs_quota_us = 周期内允许占用的CPU时间(指单核的时间, 多核则需要在设置时累加)

   例如 **groupA cpu.shares=250**, **groupB cpu.shares=750**，则 CFS 保证了groupA的进程能使用25%的CPU资源，groupB的进程能使用75%的CPU资源。如果CPU较空闲，groupA的进程能使用超过25%的CPU资源。如果又加了个groupC进来，并且配置了cpu.shares = 250，那么CPU资源将在三个GROUP之间重分配。

   配置 **cpu.cfs_period_us = 1000000, cpu.cfs_quota_us = 4000000** , 表示 周期为1秒，允许使用4秒CPU时间。（假设CPU>=4核心，表示这个组在一个使用周期(1s)内可以跑满4核资源）

2. [实时调度 Real-Time scheduler (RT)](https://www.kernel.org/doc/Documentation/scheduler/sched-rt-group.txt?spm=a2c6h.12873639.0.0.5faf1b924vDOWa&file=sched-rt-group.txt)

   1. SCHED_FIFO
   2. SCHED_RR

## Env&Prechecks

```bash
[root@worker ~]# cat /etc/*elease*
CentOS Linux release 7.9.2009 (Core)
Derived from Red Hat Enterprise Linux 7.8 (Source)
NAME="CentOS Linux"
VERSION="7 (Core)"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="7"
PRETTY_NAME="CentOS Linux 7 (Core)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:centos:centos:7"
HOME_URL="https://www.centos.org/"
BUG_REPORT_URL="https://bugs.centos.org/"

CENTOS_MANTISBT_PROJECT="CentOS-7"
CENTOS_MANTISBT_PROJECT_VERSION="7"
REDHAT_SUPPORT_PRODUCT="centos"
REDHAT_SUPPORT_PRODUCT_VERSION="7"

CentOS Linux release 7.9.2009 (Core)
CentOS Linux release 7.9.2009 (Core)
cpe:/o:centos:centos:7


[root@worker ~]# uname -a
Linux worker 4.4.246-1.el7.elrepo.x86_64 #1 SMP Tue Nov 24 09:26:59 EST 2020 x86_64 x86_64 x86_64 GNU/Linux

[root@worker cgroup-test]# mount | grep cgroup
tmpfs on /sys/fs/cgroup type tmpfs (ro,nosuid,nodev,noexec,mode=755)
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/usr/lib/systemd/systemd-cgroups-agent,name=systemd)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls,net_prio)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)

[root@worker ~]# lssubsys
cpuset
cpu,cpuacct
blkio
memory
devices
freezer
net_cls,net_prio
perf_event
hugetlb
pids

# 查看物理 CPU 数量
[root@worker cgroup-test]# cat /proc/cpuinfo | grep "physical id" | sort | uniq
physical id	: 0
physical id	: 2
physical id	: 4
physical id	: 6

# 查看每块 CPU 的核心数
[root@worker cgroup-test]# cat /proc/cpuinfo | grep "cores" | uniq
cpu cores	: 1

# 查看主机总的逻辑线程数
[root@worker cgroup-test]# cat /proc/cpuinfo | grep "processor" | wc -l
4

[root@worker ~]#  yum install libcgroup-tools -y
```

## cgroup cpu demo

### demo script

```shell
#!/bin/env bash
# filename is tash.sh
x=0
while [ True ];do
    x=$x+1
done;
```

### create test cgroup

1. `cgcreate -g cpu:/test`
   1. `echo 100000 > /sys/fs/cgroup/cpu/test/cpu.cfs_period_us`
   2. `echo 50000 > /sys/fs/cgroup/cpu/test/cpu.cfs_quota_us`
   3. test 组下的任务最多只能占用 50% 的 cpu 时间
2. `cgcreate -g cpuacct:/test`
3. `cgcreate -g cpuset:/test`
   1. `echo "0-1" > /sys/fs/cgroup/cpuset/test/cpuset.cpus`
   2. `echo 0 > /sys/fs/cgroup/cpuset/test/cpuset.mems`

### test

1. 直接运行 task.sh，查看 cpu 占用，图上所示，脚本使用 **cpu3**，并且占用了 **100%** 的 cpu 时间

   ![使用系统默认cgroup，直接运行脚本](/img/inpost/cgroup/task0.png)

2. 使用 cpu 限制，执行 `cgexec -g cpu:/test ./task.sh &`

   ![使用 50% cpu limit cgroup](/img/inpost/cgroup/task1.png)

3. 使用 cpu 限制和绑定 cpu 运行，执行 `cgexec -g cpu:/test -g cpuset:/test ./task.sh &`

   ![](/img/inpost/cgroup/task2.png)

## mem demo

TODO...