---
layout:     post
title:      "spice"
subtitle:   " \"spice视频播放优化方案\""
date:       2017-10-31 15:00:00
author:     "Hanamichi"
header-img: "img/post-bg-universe.jpg"
catalog: true
tags:
    - spice
    - 云计算
---

# Qemu Spice视频编码性能优化方案

1、 rdp+显卡透传

使用k1显卡在win10系统中测试可行。去掉qxl显卡，只保留透传显卡，视频和3d软件都可以使用硬件加速。win7系统有问题(nvidia 显卡透传后安装驱动失败，error code 43)，目前还没有找到解决方法。

但是使用此种方案有一个问题是，更改显卡的时机(在虚拟机配置中去掉qxl，增加透传显卡)，因为vnc和spice配置后会自动添加qxl-vga设备，虚拟机装系统的界面目前只有通过vnc和spice可以看见。

2、目前研究的更改spice服务端编码方案

spice使用gstreamer可以进行视频流的多种编码方案。

gstreamer插件中vaapi适用intel核显，vdpau只有解码器插件，最终选择了nvidia nvenc方案。在环境中配置cuda , video_codec_sdk后gstreamer-bad库才能编译nvenc元素

# Qemu Spice视频编码性能测试报告


## 测试环境

* CPU        ： Intel i3-4150 3.5GHz

* 内存       ： 8G DDR 4

* 显卡       ： Nvidia K1 (Driver 367.57， CUDA 8.0， Video Codec SDK 6.0)

* 系统       ： CentOS 7.2.1511 X64

* 虚拟机     ： Qemu 2.7 (Spice 0.13.3, GStreamer 1.12.2)， 

* 虚拟机参数 ： 4 Cores(2 Cores, 2 Threads), Windowd 7/10 X64

* 测试视频   ： 1080P 三原色； 720P 分歧者

* 测试工具   ： PotPlayer、top、nethogs


## CPU性能测试

```
操作系统       编码器       编码格式   QXL  硬解   宿主机    客户机     客户端
Windows 7     SPICE       MJPEG     是    否    135%      16%       40%
Windows 7     GStreamer   MJPEG     是    否    180%      18%       46%
Windows 7     GStreamer   H.264     是    否    210%      18%       50%
Windows 7     GStreamer   VP8       是    否    184%      22%       36%
Windows 7     GStreamer   H.264     是    是    160%      18%       50%
```


## 网络性能测试

```
操作系统       编码器       编码格式   QXL  硬解   宿主机    客户机     1080P       720P
Windows 7     SPICE       MJPEG     是    否    123%      25%       7MB/s       3MB/s
Windows 7     SPICE       MJPEG     否    否    187%      29%      10MB/s      12MB/s
Windows 10    SPICE       MJPEG     否    否    300%      90%                  14MB/s

Windows 7     GStreamer   MJPEG     是    否                         7MB/s       4MB/s
Windows 7     GStreamer   H.264     是    否                       1.0MB/s     0.8MB/s
Windows 7     GStreamer   H.264     是    是                       1.0MB/s     0.8MB/s

```


## 测试结论

* Windows 10中目前QXL驱动无法正常工作，只能使用VGA模式，CPU占用高，连720P视频都无法正常播放；

* 只有QXL驱动能正确运行时，Spice才能生成视频流，否则只是产生图片，CPU和网络性能都很差，且视频十分卡顿；

* 相比于SPICE编码器，使用GStreamer编码器的CPU消耗稍微偏高，但是网络带宽占用降低明显，视频无卡顿，且效果较好；

* 使用NVENC进行硬件编码加速对性能的提升并不明显，只有25%左右，且对编码格式和参数有要求，存在兼容性问题，还需更多具体测试；

* 使用GStreamer编码器的H.264编码格式的压缩率最高，带宽占用最小，但是CPU消耗较多；

* 使用SPICE或GStreamer编码器的MJPEG编码格式的压缩率最低，带宽占用最高，但是CPU消耗较少。



## 优化建议

* 要想视频流畅播放，必须保证QXL驱动能正常工作（初步分析，QXL驱动会通过IO端口协调Spice创建视频流，VGA模式则无法进行）；

* 想要CPU占用率低，就使用SPICE编码器的MJPEG编码格式；

* 想要网络带宽低，就使用GStreamer编码器的H.264编码格式。
