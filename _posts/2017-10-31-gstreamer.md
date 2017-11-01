---
layout:     post
title:      "Gstreamer"
subtitle:   " \"多媒体框架Gstreamer介绍\""
date:       2017-10-31 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-universe.jpg"
catalog: true
tags:
    - gstreamer
    - 多媒体

---

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

### *bin*

多个element构成的特殊的element

### *pipeline*

是一个特殊的bin,具有全局的时钟，有四种可能的状态，分别是NULL，READY，PAUSED，PLAYING。NULL和READY状态下，element不对数据做任何处理，PLAYING状态对数据进行处理，PAUSE状态介于两者之间，对数据进行preroll。应用程序通过函数调用控制pipeline在不同状态之间进行转换。，应用程序通过控制管道的状态进行数据流的传输。

![pipeline](/img/in-post/post-gstreamer/gstreamer.png)

### *elements*

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

### *数据流*

Gstreamer支持两种类型的数据流，分别是push模式和pull模式。在push模式下，upstream的element通过调用downstream的sink pads的函数实现数据的传送。在pull模式下，downstream的element通过调用upstream的source pads的函数实现对数据的请求。

在pads之间传送的数据封装在Buffer里，Buffer中有一个指向实际数据的指针以及一些metadata。metadata的内容包括：

* 时间戳
* 偏移
* 媒体类型
* 其他

![spice-gstreamer](/img/in-post/post-gstreamer/gstreamer2.png)

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

