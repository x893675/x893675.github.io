---
title: spice图形显示优化
date: 2017-06-01T14:21:26+08:00
lastmod: 2017-12-01T14:21:26+08:00
author: hanamichi
cover: /img/spice.jpg
categories: ['底层虚拟化技术']
tags: ['spice','云计算']
---

# spice图形显示优化

<!--more-->

- [spice图形显示优化](#spice图形显示优化)
  - [Gstreamer框架介绍](#gstreamer框架介绍)
    - [bin](#bin)
    - [pipeline](#pipeline)
    - [elements](#elements)
    - [数据流](#数据流)
    - [spice中gstreamer的使用](#spice中gstreamer的使用)
    - [gstreamer管道创建样例程序](#gstreamer管道创建样例程序)
  - [gstream硬件编解码](#gstream硬件编解码)
    - [环境搭建](#环境搭建)
    - [安装nvidia驱动](#安装nvidia驱动)
    - [安装cuda 8.0 toolkit](#安装cuda-80-toolkit)
    - [安装video-codec-sdk6.0](#安装video-codec-sdk60)
    - [安装gstreamer-1.12](#安装gstreamer-112)
    - [k1初步测试](#k1初步测试)
  - [spice优化](#spice优化)
    - [spice服务端设置使用h264](#spice服务端设置使用h264)
    - [qemu指定使用视频编码](#qemu指定使用视频编码)
    - [spice客户端使用软解](#spice客户端使用软解)
    - [spice客户端使用硬解](#spice客户端使用硬解)
  - [Qemu Spice视频编码性能优化方案](#qemu-spice视频编码性能优化方案)
    - [rdp+显卡透传](#rdp显卡透传)
    - [更改spice服务端编码方案](#更改spice服务端编码方案)
  - [Qemu Spice视频编码性能测试报告](#qemu-spice视频编码性能测试报告)
    - [测试环境](#测试环境)
    - [CPU性能测试](#cpu性能测试)
    - [网络性能测试](#网络性能测试)
    - [测试结论](#测试结论)
    - [优化建议](#优化建议)

##  Gstreamer框架介绍

GStreamer是基于管道的多媒体框架。

Gstreamer是一个libraries和plugins的集合，用于帮助实现各种类型的多媒体应用程序，比如播放器，转码工具，多媒体服务器等

GStreamer插件可以分为:

* 协议处理
* 来源：音频和视频（涉及协议插件）
* 格式：解析器，格式化器，复用器，分离器，元数据，字幕
* 编解码器：编码器和解码器
* 过滤器：转换器，混音器，效果器，...
* 接收器：用于音频和视频（涉及协议插件）

GStreamer包:
* gstreamer: 核心包，包含一些基础元素和基本的应用程序gst-inspect和gst-launch
* gst-plugins-base: 基本示例性元素集
* gst-plugins-good: 此组插件中的元素具有LGPL认证
* gst-plugins-bad: 此组插件接近高品质，但是缺乏认证
* gst-plugins-ugly: 插件可能品质良好，但是会出现部署上的问题
* gst-libav: 使用libav的编解码库(libav是从ffmpeg分出的实现多种音视频编解码及转换的函数库)
* gst-plugins-vaapi: 包含可以使用vaapi的各元素

### bin

多个element构成的特殊的element

### pipeline

是一个特殊的bin,具有全局的时钟，有四种可能的状态，分别是NULL，READY，PAUSED，PLAYING。NULL和READY状态下，element不对数据做任何处理，PLAYING状态对数据进行处理，PAUSE状态介于两者之间，对数据进行preroll。应用程序通过函数调用控制pipeline在不同状态之间进行转换。，应用程序通过控制管道的状态进行数据流的传输。

![pipeline](/img/inpost/spice/gstreamer.png)

### elements

element是pipeline的最小组成部分。element提供了多个pads，或者为sink，或者为source。elements的输入叫做sink pads，输出叫做source pads。应用程序通过pad把element连接起来构成pipeline，如下图所示，其中顺着流的方向为downstream，相反方向是upstream

```bash
$ gst-inspect-1.0 x264enc
Factory Details:
  Rank                     primary (256)
  Long-name                x264enc
  Klass                    Codec/Encoder/Video
  Description              H264 Encoder
  Author                   Josef Zlomek <josef.zlomek@itonis.tv>, Mark Nauwelaerts <mnauw@users.sf.net>

Plugin Details:
  Name                     x264
  Description              libx264-based H264 plugins
  Filename                 /usr/lib/x86_64-linux-gnu/gstreamer-1.0/libgstx264.so
  Version                  1.8.3
  License                  GPL
  Source module            gst-plugins-ugly
  Source release date      2016-08-19
  Binary package           GStreamer Ugly Plugins (Ubuntu)
  Origin URL               https://launchpad.net/distros/ubuntu/+source/gst-plugins-ugly1.0

GObject
 +----GInitiallyUnowned
       +----GstObject
             +----GstElement
                   +----GstVideoEncoder
                         +----GstX264Enc

Implemented Interfaces:
  GstPreset

Pad Templates:
  SINK template: 'sink'
    Availability: Always
    Capabilities:
      video/x-raw
                 format: { I420, YV12, Y42B, Y444, NV12, I420_10LE, I422_10LE, Y444_10LE }
              framerate: [ 0/1, 2147483647/1 ]
                  width: [ 16, 2147483647 ]
                 height: [ 16, 2147483647 ]

  SRC template: 'src'
    Availability: Always
    Capabilities:
      video/x-h264
              framerate: [ 0/1, 2147483647/1 ]
                  width: [ 1, 2147483647 ]
                 height: [ 1, 2147483647 ]
          stream-format: { avc, byte-stream }
              alignment: au
                profile: { high-4:4:4, high-4:2:2, high-10, high, main, baseline, constrained-baseline, high-4:4:4-intra, high-4:2:2-intra, high-10-intra }


Element Flags:
  no flags set

Element Implementation:
  Has change_state() function: gst_video_encoder_change_state

Element has no clocking capabilities.
Element has no URI handling capabilities.

Pads:
  SINK: 'sink'
    Pad Template: 'sink'
  SRC: 'src'
    Pad Template: 'src'

Element Properties:
  name                : The name of the object
                        flags: readable, writable
                        String. Default: "x264enc0"
  parent              : The parent of the object
                        flags: readable, writable
                        Object of type "GstObject"
  threads             : Number of threads used by the codec (0 for automatic)
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 2147483647 Default: 0 
  sliced-threads      : Low latency but lower efficiency threading
                        flags: readable, writable
                        Boolean. Default: false
  sync-lookahead      : Number of buffer frames for threaded lookahead (-1 for automatic)
                        flags: readable, writable
                        Integer. Range: -1 - 250 Default: -1 
  pass                : Encoding pass/type
                        flags: readable, writable
                        Enum "GstX264EncPass" Default: 0, "cbr"
                           (0): cbr              - Constant Bitrate Encoding
                           (4): quant            - Constant Quantizer
                           (5): qual             - Constant Quality
                           (17): pass1            - VBR Encoding - Pass 1
                           (18): pass2            - VBR Encoding - Pass 2
                           (19): pass3            - VBR Encoding - Pass 3
  quantizer           : Constant quantizer or quality to apply
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 50 Default: 21 
  multipass-cache-file: Filename for multipass cache file
                        flags: readable, writable
                        String. Default: "x264.log"
  byte-stream         : Generate byte stream format of NALU
                        flags: readable, writable
                        Boolean. Default: false
  bitrate             : Bitrate in kbit/sec
                        flags: readable, writable, changeable in NULL, READY, PAUSED or PLAYING state
                        Unsigned Integer. Range: 1 - 2048000 Default: 2048 
  intra-refresh       : Use Periodic Intra Refresh instead of IDR frames
                        flags: readable, writable
                        Boolean. Default: false
  vbv-buf-capacity    : Size of the VBV buffer in milliseconds
                        flags: readable, writable, changeable in NULL, READY, PAUSED or PLAYING state
                        Unsigned Integer. Range: 0 - 10000 Default: 600 
  me                  : Integer pixel motion estimation method
                        flags: readable, writable
                        Enum "GstX264EncMe" Default: 1, "hex"
                           (0): dia              - dia
                           (1): hex              - hex
                           (2): umh              - umh
                           (3): esa              - esa
                           (4): tesa             - tesa
  subme               : Subpixel motion estimation and partition decision quality: 1=fast, 10=best
                        flags: readable, writable
                        Unsigned Integer. Range: 1 - 10 Default: 1 
  analyse             : Partitions to consider
                        flags: readable, writable
                        Flags "GstX264EncAnalyse" Default: 0x00000000, "(none)"
                           (0x00000001): i4x4             - i4x4
                           (0x00000002): i8x8             - i8x8
                           (0x00000010): p8x8             - p8x8
                           (0x00000020): p4x4             - p4x4
                           (0x00000100): b8x8             - b8x8
  dct8x8              : Adaptive spatial transform size
                        flags: readable, writable
                        Boolean. Default: false
  ref                 : Number of reference frames
                        flags: readable, writable
                        Unsigned Integer. Range: 1 - 12 Default: 1 
  bframes             : Number of B-frames between I and P
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 4 Default: 0 
  b-adapt             : Automatically decide how many B-frames to use
                        flags: readable, writable
                        Boolean. Default: true
  b-pyramid           : Keep some B-frames as references
                        flags: readable, writable
                        Boolean. Default: false
  weightb             : Weighted prediction for B-frames
                        flags: readable, writable
                        Boolean. Default: false
  sps-id              : SPS and PPS ID number
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 31 Default: 0 
  aud                 : Use AU (Access Unit) delimiter
                        flags: readable, writable
                        Boolean. Default: true
  trellis             : Enable trellis searched quantization
                        flags: readable, writable
                        Boolean. Default: true
  key-int-max         : Maximal distance between two key-frames (0 for automatic)
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 2147483647 Default: 0 
  cabac               : Enable CABAC entropy coding
                        flags: readable, writable
                        Boolean. Default: true
  qp-min              : Minimum quantizer
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 51 Default: 10 
  qp-max              : Maximum quantizer
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 51 Default: 51 
  qp-step             : Maximum quantizer difference between frames
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 50 Default: 4 
  ip-factor           : Quantizer factor between I- and P-frames
                        flags: readable, writable
                        Float. Range:               0 -               2 Default:             1.4 
  pb-factor           : Quantizer factor between P- and B-frames
                        flags: readable, writable
                        Float. Range:               0 -               2 Default:             1.3 
  mb-tree             : Macroblock-Tree ratecontrol
                        flags: readable, writable
                        Boolean. Default: true
  rc-lookahead        : Number of frames for frametype lookahead
                        flags: readable, writable
                        Integer. Range: 0 - 250 Default: 40 
  noise-reduction     : Noise reduction strength
                        flags: readable, writable
                        Unsigned Integer. Range: 0 - 100000 Default: 0 
  interlaced          : Interlaced material
                        flags: readable, writable
                        Boolean. Default: false
  option-string       : String of x264 options (overridden by element properties)
                        flags: readable, writable
                        String. Default: ""
  speed-preset        : Preset name for speed/quality tradeoff options (can affect decode compatibility - impose restrictions separately for your target decoder)
                        flags: readable, writable
                        Enum "GstX264EncPreset" Default: 6, "medium"
                           (0): None             - No preset
                           (1): ultrafast        - ultrafast
                           (2): superfast        - superfast
                           (3): veryfast         - veryfast
                           (4): faster           - faster
                           (5): fast             - fast
                           (6): medium           - medium
                           (7): slow             - slow
                           (8): slower           - slower
                           (9): veryslow         - veryslow
                           (10): placebo          - placebo
  psy-tune            : Preset name for psychovisual tuning options
                        flags: readable, writable
                        Enum "GstX264EncPsyTune" Default: 0, "none"
                           (0): none             - No tuning
                           (1): film             - Film
                           (2): animation        - Animation
                           (3): grain            - Grain
                           (4): psnr             - PSNR
                           (5): ssim             - SSIM
  tune                : Preset name for non-psychovisual tuning options
                        flags: readable, writable
                        Flags "GstX264EncTune" Default: 0x00000000, "(none)"
                           (0x00000001): stillimage       - Still image
                           (0x00000002): fastdecode       - Fast decode
                           (0x00000004): zerolatency      - Zero latency
  frame-packing       : Set frame packing mode for Stereoscopic content
                        flags: readable, writable
                        Enum "GstX264EncFramePacking" Default: -1, "auto"
                           (-1): auto             - Automatic (use incoming video information)
                           (0): checkerboard     - checkerboard - Left and Right pixels alternate in a checkerboard pattern
                           (1): column-interleaved - column interleaved - Alternating pixel columns represent Left and Right views
                           (2): row-interleaved  - row interleaved - Alternating pixel rows represent Left and Right views
                           (3): side-by-side     - side by side - The left half of the frame contains the Left eye view, the right half the Right eye view
                           (4): top-bottom       - top bottom - L is on top, R on bottom
                           (5): frame-interleaved - frame interleaved - Each frame contains either Left or Right view alternately

Presets:
  "Profile Baseline"
  "Profile High"
  "Profile Main"
  "Quality High"
  "Quality Low"
  "Quality Normal"
```

### 数据流

Gstreamer支持两种类型的数据流，分别是push模式和pull模式。在push模式下，upstream的element通过调用downstream的sink pads的函数实现数据的传送。在pull模式下，downstream的element通过调用upstream的source pads的函数实现对数据的请求。

在pads之间传送的数据封装在Buffer里，Buffer中有一个指向实际数据的指针以及一些metadata。metadata的内容包括：

* 时间戳
* 偏移
* 媒体类型
* 其他

### spice中gstreamer的使用

![spice-gstreamer](/img/inpost/spice/gstreamer2.png)

```c
static int spice_gst_encoder_encode_frame(VideoEncoder *video_encoder,
                                          uint32_t frame_mm_time,
                                          const SpiceBitmap *bitmap,
                                          const SpiceRect *src, int top_down,
                                          gpointer bitmap_opaque,
                                          VideoBuffer **outbuf)
{
	//..........
  
 	if (rate_control_is_active(encoder) &&
        (handle_server_drops(encoder, frame_mm_time) ||
         frame_mm_time < encoder->next_frame_mm_time)) {
        /* Drop the frame to limit the outgoing bit rate. */
        return VIDEO_ENCODER_FRAME_DROP;
    }

    if (!configure_pipeline(encoder)) {
        encoder->errors++;
        return VIDEO_ENCODER_FRAME_UNSUPPORTED;
    }

    uint64_t start = spice_get_monotonic_time_ns();
    int rc = push_raw_frame(encoder, bitmap, src, top_down, bitmap_opaque);
    if (rc == VIDEO_ENCODER_FRAME_ENCODE_DONE) {
        rc = pull_compressed_buffer(encoder, outbuf);
        if (rc != VIDEO_ENCODER_FRAME_ENCODE_DONE) {
            /* The input buffer will be stuck in the pipeline, preventing
             * later ones from being processed. Furthermore something went
             * wrong with this pipeline, so it may be safer to rebuild it
             * from scratch.
             */
            free_pipeline(encoder);
            encoder->errors++;
        }
    }
  
  //...........
}

static int push_raw_frame(SpiceGstEncoder *encoder,
                          const SpiceBitmap *bitmap,
                          const SpiceRect *src, int top_down,
                          gpointer bitmap_opaque)
{
	//........对当前帧进行一些处理

    GstFlowReturn ret = gst_app_src_push_buffer(encoder->appsrc, buffer);
    if (ret != GST_FLOW_OK) {
        spice_warning("GStreamer error: unable to push source buffer (%d)", ret);
        return VIDEO_ENCODER_FRAME_UNSUPPORTED;
    }

    return VIDEO_ENCODER_FRAME_ENCODE_DONE;
}
```



### gstreamer管道创建样例程序

```c

/*
程序运行结果与命令行执行
  gst-launch-1.0 filesrc location=/home/x/work/test.mp4 ! qtdemux ! avdec_h264 ! autovideosink
的结果相同
*/

#include <stdlib.h>
#include <gst/gst.h>


int main(int argc, char* argv[])
{
	GstElement *pipeline;
	GstElement *filesrc;
	GstMessage *msg;
	GstBus *bus;
	GError *error = NULL;

	gst_init(&argc, &argv);

	if(argc != 2)
	{
		g_print("usage: %s <filename>\n", argv[0]);
		return -1;
	}

	pipeline = gst_parse_launch("filesrc name=my_filesrc ! qtdemux ! avdec_h264 ! autovideosink", &error);
	if(!pipeline)
	{
		g_print("Parse error: %s\n", error->message);
		exit(1);
	}

	filesrc = gst_bin_get_by_name(GST_BIN(pipeline), "my_filesrc");
	g_object_set(filesrc, "location", argv[1], NULL);
	g_object_unref(filesrc);

	gst_element_set_state(pipeline, GST_STATE_PLAYING);

	bus = gst_element_get_bus(pipeline);

	msg = gst_bus_poll (bus, GST_MESSAGE_EOS | GST_MESSAGE_ERROR, -1);

  switch (GST_MESSAGE_TYPE (msg)) {
    case GST_MESSAGE_EOS: {
      g_print ("EOS\n");
      break;
    }
    case GST_MESSAGE_ERROR: {
      GError *err = NULL; /* error to show to users                 */
      gchar *dbg = NULL;  /* additional debug string for developers */

      gst_message_parse_error (msg, &err, &dbg);
      if (err) {
        g_printerr ("ERROR: %s\n", err->message);
        g_error_free (err);
      }
      if (dbg) {
        g_printerr ("[Debug details: %s]\n", dbg);
        g_free (dbg);
      }
    }
    default:
      g_printerr ("Unexpected message of type %d", GST_MESSAGE_TYPE (msg));
      break;
  }
  gst_message_unref (msg);

  gst_element_set_state (pipeline, GST_STATE_NULL);
  gst_object_unref (pipeline);
  gst_object_unref (bus);

  return 0;
}
```


## gstream硬件编解码

### 环境搭建

**特别说明**： 以Nvidia K1显卡为例，gstreamer版本选取1.12

需要编译安装以下软件：

Cuda 8.0 toolkit----显卡驱动要求367.xx及以上版本，k1显卡只能安装cuda8.0

Video-codec-sdk6.0----nvenc编码sdk

Gstreamer1.12相应的库-----gstreamer1.12版本中加入了cuda8.0的支持，要在gstreamer中使用Nvenc，需要cuda>6.5,nvenc>5.0

```
Cuda下载地址：https://developer.nvidia.com/cuda-toolkit-archive
Video-codec-sdk下载地址：https://developer.nvidia.com/video-codec-sdk-archive
Gstreamer源码下载地址：https://gstreamer.freedesktop.org/src/
```

### 安装nvidia驱动

1. 从官网下载nvidia驱动，版本要求367.xx。
2. 在内核启动项增加nouveau.modeset=0rd.driver.blacklist=nouveau，然后重启
3. 运行驱动程序的.run文件

### 安装cuda 8.0 toolkit

1. 运行.run文件，除驱动安装选项其余全部选择yes。
2. 执行vim /etc/profile,在文件末尾加上`exportPATH=/usr/local/cuda/bin:$PATH exportLD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH`
3. cd /usr/local/cuda/samples
4. make all
5. cd bin执行deviceQuery程序，有输出则安装成功

### 安装video-codec-sdk6.0

1. 解压nvidia_video_sdk_6.0.1.zip
2. `cp -rf nvidia_video_sdk_6.0.1/Samples/common/inc  /usr/local/include/nvenc`

### 安装gstreamer-1.12

1. 先安装gstreamer-1.12.2和gst-plugins-base-1.12.2,编译参数为`./configure --prefix=/usr --libdir=/lib64`
2. `exportPKG_CONFIG_PATH=/usr/local/cuda/pkgconfig/`
3. 安装gst-plugins-bad-1.12.2,编译参数为`NVENCODE_CFLAGS="-I/usr/local/include/nvenc"./configure--prefix=/usr --libdir=/lib64 --disable-gtk-doc `

安装完成之后执行`gst-inspect-1.0 nvenc`，如果有输出，则安装正常

### k1初步测试

K1是kepler架构，核心是gk107,有4个gpu核心

```bash
#Gstreamer编码命令
gst-launch-1.0 -v filesrc location=/root/work/1080psrc ! videoparse format=i420 width=1920 height=1080 framerate=24/1 ! autovideoconvert ! nvh264enc  ! fakesink
#1080psrc是30s视频源数据
```

nvidia显卡编码能力图如下:

![nvidia显卡编码能力](/img/inpost/spice/k1-nvenc.png)

使用1080p 30秒视频源进行编码测试，七进程同时进行24fps h264编码，且运行在k1的一个gpu芯片上，编码完成时间均为30-31s，每个进程的cpu占用率为23%，基本符合图中结论。

## spice优化

### spice服务端设置使用h264

spice服务端源码最新版中有一个函数`spice_server_set_video_codecs(SpiceServer *s, const char* video_codecs)`,该函数可以由QEMU调用，在spice_server初始化时，若QEMU不指定某个特定编码，spice就传入默认编码。

默认编码是spice:mjpeg,gstreammer:mjpeg,gstreammer:h264,gstreammer:vp8,gstreammer:vp9组成的数组。

在使用时，默认使用spice内置mjpeg编码。

### qemu指定使用视频编码

开发使用的是qemu2.7版本的源码，该版本还不支持在启动时设置视频编码，所以需要自己在代码中加入。

具体补丁如下(qemu-kvm 2.7版本)

```c
diff -Naur qemu-kvm-2.7.0_old/qemu-options.hx qemu-kvm-2.7.0/qemu-options.hx
--- qemu-kvm-2.7.0_old/qemu-options.hx	2017-03-31 11:32:40.831770612 +0800
+++ qemu-kvm-2.7.0/qemu-options.hx	2017-03-20 10:15:10.000000000 +0800
@@ -1062,6 +1062,7 @@
     "       [,jpeg-wan-compression=[auto|never|always]]\n"
     "       [,zlib-glz-wan-compression=[auto|never|always]]\n"
     "       [,streaming-video=[off|all|filter]][,disable-copy-paste]\n"
+    "       [,video-codecs=<encoder1>:<codec1>[;<encoder2>:<codec2>]]\n"
     "       [,disable-agent-file-xfer][,agent-mouse=[on|off]]\n"
     "       [,playback-compression=[on|off]][,seamless-migration=[on|off]]\n"
     "       [,gl=[on|off]]\n"
diff -Naur qemu-kvm-2.7.0_old/ui/spice-core.c qemu-kvm-2.7.0/ui/spice-core.c
--- qemu-kvm-2.7.0_old/ui/spice-core.c	2017-03-31 11:35:48.713154167 +0800
+++ qemu-kvm-2.7.0/ui/spice-core.c	2017-03-21 14:53:48.000000000 +0800
@@ -489,6 +489,9 @@
             .name = "streaming-video",
             .type = QEMU_OPT_STRING,
         },{
+            .name = "video-codecs",
+            .type = QEMU_OPT_STRING, 
+        },{
             .name = "agent-mouse",
             .type = QEMU_OPT_BOOL,
         },{
@@ -787,6 +790,23 @@
     } else {
         spice_server_set_streaming_video(spice_server, SPICE_STREAM_VIDEO_OFF);
     }
+    //qemu patch for add video-codecs begin
+    str = qemu_opt_get(opts, "video-codecs");
+    if (str){
+    #if SPICE_SERVER_VERSION >= 0x000c06
+    //#if 1
+        if(spice_server_set_video_codecs(spice_server, str)){
+            error_report("Invalid video codecs.");
+            exit(1);
+        }
+    #else
+        printf("%x\n",SPICE_SERVER_VERSION);
+        error_report("this qemu build does not support the "
+                     "\"video-codecs\" option");
+        exit(1);
+    #endif
+    }
+    //qemu patch for add video-codecs end
     spice_server_set_agent_mouse
         (spice_server, qemu_opt_get_bool(opts, "agent-mouse", 1));
     spice_server_set_playback_compression

```

使用该补丁后，可以通过命令行在-spice之后使用video-codecs=gstreamer:h264指定spice使用264编码。

通过libvirt定义xml文件生成虚拟机时，无法指定该参数。原因是libvirt的xml域没有定义该选项，所以只能在虚拟机xml文件中用以下形式定义
```xml
<domain type='' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
.......

  <qemu:commandline>
    <qemu:arg value='-spice'/>
    <qemu:arg value=''port=5901,addr=0.0.0.0,agent-mouse=on,disable-ticketing,image-compression=auto_glz,streaming-video=filter,seamless-migration=on,video-codecs=gstreamer:h264''/>
   </qemu:commandline
 </domain>
```

注意：
* 一旦用`qemu:commandline`这个节点来定义qemu的命令行参数，若某个选项需要指定多个参数，则所有的参数都只能通过这种方法指定。例如代码中的`-spice`选项，后面的参数有端口，地址等等，需要将xml中的这些定义删除，和`video-codecs=gstreamer:h264`写在一起
* 运行qemu的服务器上必须要安装gstreamer1.0的相关库，特别是h264需要有`gstreamer1-plugins-ugly`这个库。检测是否支持h264的方法是命令行运行`gst-inspect-1.0 x264enc`，如果命令有输出，则表示当前环境支持264编码

### spice客户端使用软解

spice-gtk源码编译安装后会产生spice-client的相关动态库和spicy二进制程序。盒子使用的就是spicy二进制程序和相关的动态库。而remote-viewer只使用了spice-client相关的动态库文件。所以在与spice server交互的时候两者没有太大差别。

spice客户端要使用软解，则运行环境也必须安装`gstreamer1.0`相关的库。

### spice客户端使用硬解

spice客户端使用硬解主要有以下两种情况
1. spice客户端没有识别出视频流的编码
2. 在运行环境中设置`SPICE_GSTVIDEO_AUTO`的值，无论值是多少，只要该环境变量被设置即可

本机环境下使用硬解打印信息如下：

![硬解打印信息](/img/inpost/spice/vaapi_normol.png)


## Qemu Spice视频编码性能优化方案

### rdp+显卡透传

使用k1显卡在win10系统中测试可行。去掉qxl显卡，只保留透传显卡，视频和3d软件都可以使用硬件加速。win7系统有问题(nvidia 显卡透传后安装驱动失败，error code 43)，目前还没有找到解决方法。

但是使用此种方案有一个问题是，更改显卡的时机(在虚拟机配置中去掉qxl，增加透传显卡)，因为vnc和spice配置后会自动添加qxl-vga设备，虚拟机装系统的界面目前只有通过vnc和spice可以看见。

### 更改spice服务端编码方案

spice使用gstreamer可以进行视频流的多种编码方案。

gstreamer插件中vaapi适用intel核显，vdpau只有解码器插件，最终选择了nvidia nvenc方案。在环境中配置cuda , video_codec_sdk后gstreamer-bad库才能编译nvenc元素

## Qemu Spice视频编码性能测试报告


### 测试环境

* CPU        ： Intel i3-4150 3.5GHz

* 内存       ： 8G DDR 4

* 显卡       ： Nvidia K1 (Driver 367.57， CUDA 8.0， Video Codec SDK 6.0)

* 系统       ： CentOS 7.2.1511 X64

* 虚拟机     ： Qemu 2.7 (Spice 0.13.3, GStreamer 1.12.2)， 

* 虚拟机参数 ： 4 Cores(2 Cores, 2 Threads), Windowd 7/10 X64

* 测试视频   ： 1080P 三原色； 720P 分歧者

* 测试工具   ： PotPlayer、top、nethogs


### CPU性能测试

```
操作系统       编码器       编码格式   QXL  硬解   宿主机    客户机     客户端
Windows 7     SPICE       MJPEG     是    否    135%      16%       40%
Windows 7     GStreamer   MJPEG     是    否    180%      18%       46%
Windows 7     GStreamer   H.264     是    否    210%      18%       50%
Windows 7     GStreamer   VP8       是    否    184%      22%       36%
Windows 7     GStreamer   H.264     是    是    160%      18%       50%
```


### 网络性能测试

```
操作系统       编码器       编码格式   QXL  硬解   宿主机    客户机     1080P       720P
Windows 7     SPICE       MJPEG     是    否    123%      25%       7MB/s       3MB/s
Windows 7     SPICE       MJPEG     否    否    187%      29%      10MB/s      12MB/s
Windows 10    SPICE       MJPEG     否    否    300%      90%                  14MB/s

Windows 7     GStreamer   MJPEG     是    否                         7MB/s       4MB/s
Windows 7     GStreamer   H.264     是    否                       1.0MB/s     0.8MB/s
Windows 7     GStreamer   H.264     是    是                       1.0MB/s     0.8MB/s

```


### 测试结论

* Windows 10中目前QXL驱动无法正常工作，只能使用VGA模式，CPU占用高，连720P视频都无法正常播放；

* 只有QXL驱动能正确运行时，Spice才能生成视频流，否则只是产生图片，CPU和网络性能都很差，且视频十分卡顿；

* 相比于SPICE编码器，使用GStreamer编码器的CPU消耗稍微偏高，但是网络带宽占用降低明显，视频无卡顿，且效果较好；

* 使用NVENC进行硬件编码加速对性能的提升并不明显，只有25%左右，且对编码格式和参数有要求，存在兼容性问题，还需更多具体测试；

* 使用GStreamer编码器的H.264编码格式的压缩率最高，带宽占用最小，但是CPU消耗较多；

* 使用SPICE或GStreamer编码器的MJPEG编码格式的压缩率最低，带宽占用最高，但是CPU消耗较少。



### 优化建议

* 要想视频流畅播放，必须保证QXL驱动能正常工作（初步分析，QXL驱动会通过IO端口协调Spice创建视频流，VGA模式则无法进行）；

* 想要CPU占用率低，就使用SPICE编码器的MJPEG编码格式；

* 想要网络带宽低，就使用GStreamer编码器的H.264编码格式。
