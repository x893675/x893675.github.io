---
title: 云桌面spice初探
date: 2017-05-01T14:21:26+08:00
lastmod: 2017-05-01T14:21:26+08:00
author: hanamichi
cover: /img/spice.jpg
categories: ['底层虚拟化技术']
tags: ['spice','云计算']
---

# spice初探

<!--more-->

- [spice初探](#spice初探)
  - [概念&结构](#概念结构)
    - [spice基本概念](#spice基本概念)
    - [spice系统组成](#spice系统组成)
    - [VD-Interface](#vd-interface)
    - [VDI Back-End](#vdi-back-end)
    - [VDI Front-End](#vdi-front-end)
    - [spice server](#spice-server)
    - [spice server](#spice-server-1)
    - [公共函数](#公共函数)
    - [主要VDI接口](#主要vdi接口)
    - [Channel](#channel)
    - [usbredirect](#usbredirect)
  - [spice协议](#spice协议)
    - [Spice基本结构](#spice基本结构)
    - [Spice图形命令流](#spice图形命令流)
    - [Spice代理命令流](#spice代理命令流)
    - [Spice  Client](#spice-client)
      - [*Spice Client基本结构*](#spice-client基本结构)
      - [*Client 类结构*](#client-类结构)
      - [*Channels*](#channels)
      - [*Screens and Windows*](#screens-and-windows)
    - [Spice Server](#spice-server-2)
      - [*spice server 结构*](#spice-server-结构)
      - [*red server (reds.c)*](#red-server-redsc)
      - [*server 图形子系统*](#server-图形子系统)
      - [*Red Worker( red_worker.c)*](#red-worker-red_workerc)
      - [*Red Dispatcher(red_dispatcher.c)*](#red-dispatcherred_dispatcherc)
    - [Spice Protocol](#spice-protocol)
    - [SPICE视频流压缩](#spice视频流压缩)

## 概念&结构

### spice基本概念

spice是专门为虚拟化环境构建的一套远程桌面系统。spice指整套系统，而不是单个模块或组件。

### spice系统组成

![spice系统结构图](/img/inpost/spice/spice-arch.png)

* spice协议
* spice server
* spice client

### VD-Interface

VD-Interface是一套接口规范，VDI Back-End与VDI Front-End通过VD-Interface进行交互。

### VDI Back-End

VDI Back-End其实就是一堆QEMU Virtual Device，但是这些Virtual Device都实现了VD-Interface接口规范。

###  VDI Front-End

VDI Front-End通过调用VDI Back-End提供的VD-Interface接口来实现与VDI Back-End的交互。

### spice server

spice-server 作为VDI的前端，通过spice协议与spice客户端进行通信。spice-server以库的形式提供给后端。


### spice server

![spice server结构图](/img/inpost/spice/spice-server.png)

spice server编译成libspice,作为一个动态库给后端（通常是qemu）使用。

### 公共函数

公共函数为可以给外部文件调用的函数（在这里指由qemu调用）

* spice.h:与SpiceServer结构体相关的函数,是qemu调用spice的主要函数
* red_dispatcher.h:与QXL设备相关的函数

主要公共函数：
*   **spice_server_init** :负责初始化spice_server
*   **spice_server_add_interface** :给server注册VDI接口
*   **spice_server_add_client** :处理qemu接收到的客户端连接消息

### 主要VDI接口

* SpiceCoreInterface：    Spice与Qemu内部交互用的接口
* QXLInterface：          显示数据交互接口
* SpiceKbdInstance：      键盘输入交互接口
* SpiceMouseInterface：   鼠标输入交互接口
* SpicePlaybackInterface：音频播放交互接口
* SpiceRecordInterface：  音频录制交互接口

### Channel

Channel的主要作用是使用对应的TCP连接传输消息给客户端,保证其传输的可靠性,其本质是通道,不同的Channel传输不同的消息.

spice中主要有六种Channel:
*   **MainChannel** :与客户端连接的建立和断开有关
*   **InputsChannel** :跟鼠标,键盘,触摸板的输入有关
*   **DisplayChannel** :跟图像传输有关
*   **CursorChannel** :跟鼠标指针的显示有关
*   **PlaybackChannel** :跟播放宿主机的声音有关
*   **RecordChannel** :跟录制客户端的声音有关

### usbredirect

usbredirect是spice对USB重定向的支持

![usb_redirection](/img/inpost/spice/usb-redirection.png)
* usb host端，spice client通过libusb与usb外设交互
* spice client通过spice协议在特定通道与spice server交互
* spice server通过VDI接口与qemu(redirect.c)交互

## spice协议

SPICE(Simple Protocol for Independent Computing Environment)全称独立计算环境简单协议。

Spice 是一个开放的远程计算解决方案，使得客户端可以访问远程机器桌面和设备(比如键盘，鼠标，audio 和 USB)。通过 Spice 我们可以像使用本地计算机一样访问远程机器，这样可以把 CPU GPU 密集工作从客户端移交给远程高性能机器。Spice 适用于 LAN 和 WAN。

### Spice基本结构

![spice整体结构图](/img/inpost/spice/spice_schem.png)

spice server和qemu之间实现了vdi的一系列接口，vdi后端就是qemu模拟的各种设备，spice server作为vdi前端。

Spice可以细分为4部分:

* guest端，qxl driver和SPICE VDAgent
* host端，spice server 以libspice动态库形式供虚拟机监控管理程序(qemu)分享虚拟机
* spice protocol，spice server 与 spice client 交互遵循的协议规范
* client端，终端用户直接交互操作虚拟机(remote-viewer或者spice-gtk)

### Spice图形命令流

![spice图形命令流](/img/inpost/spice/spice-graphic-flow.png)

上图显示了 Spice 的基本架构，以及 guest 到 client 之间传送的 graphic 命令数据流

当 Guest OS 上一个用户应用请求 OS 图形引擎执行一个渲染操作。图形引擎传送命令给QXL驱动，QXL驱动会把OS命令转换为QXL命令然后推送到QXL设备的commands RIng缓冲中。commands Ring 是 QXL Device 中的一个队列。Libspice 会从这个 commands Ring取得命令数据，然后加到 graphics 命令树上。显示树上包含一组操作命令，这些命令的执行会产生显示内容。这棵树可以优化掉那些会被覆盖掉的命令，命令树还用来检测 video 数据流。当命令从 libspice 的发送队列发送给客户端时，发送命令被转换为 Spice 协议消息，同时这个命令从发送队列和树上移除。

当 libspice 不再需要一个命令时，它被推送到 release ring。驱动使用这个队列来释放相应的命令资源

当客户端从 libspice 接收到一个命令时，客户端使用这个命令来更新显示。

###  Spice代理命令流

![spice代理命令流](/img/inpost/spice/spice-agent-flow.png)

Spice 代理是 guest 中的一个软件模块。Spice server 和 Spice client 使用代理来执行在guest 上下文中的工作，比如配置 guest display 设置。上图显示了 spice client 和 server 通过 VDI Port驱动和VDI Port设备进行通信的过程。Message 包括 client 生成的 guest 显示配置信息，server生成的鼠标移动信息以及代理生成的配置应答信息。驱动使用 Input/Output Rings 和 VDI Port Device 通信。client 和 server 生成的信息都写入到同一个写队列中，然后再写入 VDI Port Device 的 output buffer ring。Message port 决定 message 被 server 处理还是推送给 client 处理。

### Spice  Client

spice 跨平台(Linux & Windows)客户端是终端用户的接口

#### *Spice Client基本结构*

![spice client基本结构](/img/inpost/spice/spice-client.png)

#### *Client 类结构*

为了有一个清晰的跨平台结构，Spice 定义了一个通用的接口，而把平台相关的实现放在了一个并行的目录中。这个通用的接口就是 Platform class，定义了许多低级服务，比如 timer 和 cursor 操作。

**Application**是一个主要的类，包含 Clients， monitos 和 screens，这个类实现了通用的应用功能:命令行解析，主循环，时间处理，鼠标事件重定向，全屏切换等等。

#### *Channels*

client 和 server 通过 channels 进行通信，每一个 channel 类型对应着特定的数据类型。每个 channel 使用专门的 TCP socket，这个socket可以是安全的(使用SSL)或者不安全的。在客户端，每一个 channel 会有一个专门的线程来处理，所以我们可以为每一个 channel 设置单独的优先级来达到不同的 QoS。

**RedClient**是主 channel。它拥有所有其他的实例化通道，并且可以控制他们(创建，连接，断开等)，并且处理控制，配置和迁徙。

主要的通道有:

* Main : 由RedClient实现
* DisplayChannel : 处理图形化命令，图像和数据流
* InputsChannel : 鼠标和键盘输入
* CursorChannel : 指针设备位置，显示和光标形状
* PlaybackChannel : 从服务器接收音频数据，在client播放
* RecordChannel : 在client端进行录音

#### *Screens and Windows*

* Screen layer : 绑定到特定的screen,用来提供矩形区域的操作(设置，清除，更新等)，layer 是z-ordered
* RedScreen : 实现screen的逻辑，控制window，使用screen layer显示其内容
* RedDrawable : 基本 pixmap 的平台特定实现。它支持基本的渲染操作
* RedWindow_p : 平台相关的window数据和方法
	 RedWindow : 继承自RedDrawable和RedWindow_p，基本窗口状态和功能(显示，隐藏，设置标题，设置指针设备等)的跨平台的实现	

### Spice Server

spice server 是通过 libspice 和 VDI library 实现的。VDI 提供了一个标准的方法来发布虚拟设备的接口。这使得其他的软件部件可以和这些 virtual device 交互。

一方面，server 使用 Spice 协议和远程 client 通信，另一方面，它和 VDI host 应用(QEMU)进行交互。

server 为了远程显示的目的，server 维护了一个命令序列和一棵树来管理当前对象的依赖关系和覆盖关系。QXL 命令被处理转换为 Spice 协议，然后发送给客户端。

#### *spice server 结构*

![spice client基本结构](/img/inpost/spice/spice-server.png)

Server 通过 channels 和 client 通信。每一个 channel 类型对应一种特定类型的数据。每一个 channel 使用专用的 TCP socket。服务端的 channel 和 client 的 channel 是对应的，也有Main、 Inputs、Display、Cursor、Playback 和 Record这些管道。

Main和Input Channel被处理函数控制(实现位于reds.c) ，display和cursor channel被每个display的redwork线程控制，libspice和VDI Host应用程序(QEMU)通过每个功能结构交互(qxl,agent 等)。

#### *red server (reds.c)*

Server自身，用来监听客户端连接请求，接受连接并与客户端通信，主要负责如下工作:

* 通道
  * 管理通道(注册，注销，停止)
  * 通知client活动的通道，便于client 创建它们
  * main和input通道的管理
  * 连接的建立(main 和其他通道)
  * socket操作以及链接管理
  * 处理SSL和ticketing
* VDI接口处理(增加，移除)
* 迁移进程协作
* 处理用户命令(来自QEMU monitor)
* 和guest agent通信
* Statistics 统计？

#### *server 图形子系统*

![spice client基本结构](/img/inpost/spice/spice-server-graphic.png)

不像 Spice 中的其他子系统，graphics 子系统在 server 中通过专有的线程并行运行。这种结构使得图形命令的处理和渲染保持独立，因此消耗很多的 CPU资源。

上图显示了 Spice server 图形子系统的结构。Red server 实例化一个 dispatcher，并带有 QXL interface。dispatcher 为这个 QXL interface 创建 red worker。worker 处理的命令有三个来源:

1. 同步的 QXL 设备命令
2. red server commands
3. 异步的 QXL 设备命令

其中1和2由dispatcher通过socket分发，3由worker从QXL device rings pull  

#### *Red Worker( red_worker.c)*

red worker负责:

* 处理QXL设备命令(draw, update, cursor等)
* 处理接受自dispatcher的消息
* display 和 cursor 通道管理
* 图片压缩(使用quic, lz, glz 编码)
* 视频流处理(鉴别视频流，编码和创建流)
* Ring操作

#### *Red Dispatcher(red_dispatcher.c)*

* 为每个QXL设备状态调度到具体的处理函数
* 创建red worker线程
* ...还未看

### Spice Protocol

spice protocol 用于 client 和 server 间的通信. 比如传输图形对象, 键盘和鼠标事件, 光标
信息, audio playback 和录音，以及控制命令。

### SPICE视频流压缩

spice 处理视频流有两套方案:

* Spice 集成的mjpeg编码
* 使用gstreamer框架编码

其中使用gstreamer框架可以使用的编码格式(spice 目前支持的)有mjpeg, h264, vp8, 均采用CPU编码。

spice 抽象了一个`VideoEncoder`结构体，调用统一的接口进行编码的一系列操作，编码方案和编码操作没有耦合在一起，相互透明。

```c
typedef struct VideoEncoder VideoEncoder;
struct VideoEncoder {
    /* Releases the video encoder's resources */
    void (*destroy)(VideoEncoder *encoder);

    int (*encode_frame)(VideoEncoder *encoder, uint32_t frame_mm_time,
                        const SpiceBitmap *bitmap,
                        const SpiceRect *src, int top_down,
                        gpointer bitmap_opaque, VideoBuffer** outbuf);

    void (*client_stream_report)(VideoEncoder *encoder,
                                 uint32_t num_frames, uint32_t num_drops,
                                 uint32_t start_frame_mm_time,
                                 uint32_t end_frame_mm_time,
                                 int32_t end_frame_delay, uint32_t audio_delay);

    void (*notify_server_frame_drop)(VideoEncoder *encoder);

    uint64_t (*get_bit_rate)(VideoEncoder *encoder);

    void (*get_stats)(VideoEncoder *encoder, VideoEncoderStats *stats);

    SpiceVideoCodecType codec_type;
};

typedef VideoEncoder* (*new_video_encoder_t)(SpiceVideoCodecType codec_type,
                                             uint64_t starting_bit_rate,
                                             VideoEncoderRateControlCbs *cbs,
                                             bitmap_ref_t bitmap_ref,
                                             bitmap_unref_t bitmap_unref);

VideoEncoder* mjpeg_encoder_new(SpiceVideoCodecType codec_type,
                                uint64_t starting_bit_rate,
                                VideoEncoderRateControlCbs *cbs,
                                bitmap_ref_t bitmap_ref,
                                bitmap_unref_t bitmap_unref);

#if defined(HAVE_GSTREAMER_1_0) || defined(HAVE_GSTREAMER_0_10)

VideoEncoder* gstreamer_encoder_new(SpiceVideoCodecType codec_type,
                                    uint64_t starting_bit_rate,
                                    VideoEncoderRateControlCbs *cbs,
                                    bitmap_ref_t bitmap_ref,
                                    bitmap_unref_t bitmap_unref);
#endif

typedef struct RedVideoCodec {
    new_video_encoder_t create;
    SpiceVideoCodecType type;
    uint32_t cap;
} RedVideoCodec;
```

上面的代码段是编码器` VideoEncoder`的结构体定义和两种编码方案的编码器创建函数声明。在创建编码器函数的实现中会创建相应的编码器实例，填充`VideoEncoder`结构体，并将编码器实例返回。**编码器只会在满足创建流的条件后被调用创建**。

![spice video encoder](/img/inpost/spice/spice1.png)

启动虚拟机，即QEMU进程启动时，会分析命令行参数，如果指定了使用spice，则会调用spice的初始化函数进行初始化。此时会将spice server 端支持的视频编码格式加入一个数组中，以便在之后创建编码器的时候使用。

```c
static VideoEncoder* dcc_create_video_encoder(DisplayChannelClient *dcc,
                                              uint64_t starting_bit_rate,
                                              VideoEncoderRateControlCbs *cbs)
{
    DisplayChannel *display = DCC_TO_DC(dcc);
    RedChannelClient *rcc = RED_CHANNEL_CLIENT(dcc);
    int client_has_multi_codec = red_channel_client_test_remote_cap(rcc, SPICE_DISPLAY_CAP_MULTI_CODEC);
    int i;

    for (i = 0; i < display->priv->video_codecs->len; i++) {
        RedVideoCodec* video_codec = &g_array_index (display->priv->video_codecs, RedVideoCodec, i);

        if (!client_has_multi_codec &&
            video_codec->type != SPICE_VIDEO_CODEC_TYPE_MJPEG) {
            /* Old clients only support MJPEG */
            continue;
        }
        if (client_has_multi_codec &&
            !red_channel_client_test_remote_cap(rcc, video_codec->cap)) {
            /* The client is recent but does not support this codec */
            continue;
        }

        VideoEncoder* video_encoder = video_codec->create(video_codec->type, starting_bit_rate, cbs, bitmap_ref, bitmap_unref);
        if (video_encoder) {
            return video_encoder;
        }
    }

    /* Try to use the builtin MJPEG video encoder as a fallback */
    if (!client_has_multi_codec || red_channel_client_test_remote_cap(rcc, SPICE_DISPLAY_CAP_CODEC_MJPEG)) {
        return mjpeg_encoder_new(SPICE_VIDEO_CODEC_TYPE_MJPEG, starting_bit_rate, cbs, bitmap_ref, bitmap_unref);
    }

    return NULL;
}
```

在创建编码器之前会对询问客户端是否支持多个编码，之后对之前初始化的编码格式数组按顺序进行测试，如果客户端支持，则创建编码器返回。如果数组中的所有格式都不支持，则选用默认的mjpeg格式编码。

![spice video stream](/img/inpost/spice/spice2.png)

上图是spice中视频命令流的主要函数流程图。其中左图是得到qxl绘图指令后执行各种操作后把视频流发送给客户端。

中图是处理display命令的具体执行函数，只有**qxl的命令是绘图指令**才会进行之后的绘图区域创建和维护渲染树创建流等操作。

右图是`current_add`函数中的具体流程，维护树的同时，将进行是否创建流的判断，条件是**帧率大于20fps，且有4个渐进帧**

spice中关于gstreamer的使用放在gstreamer介绍中作为样例讲解。
