---
layout:     post
title:      "Linux 查看系统信息"
subtitle:   " \"Linux 查看主板等信息 \""
date:       2017-05-25 12:00:00
author:     "Hanamichi"
header-img: "img/post-bg-2015.jpg"
catalog: true
tags:
    - Linux
---


### 命令

**sudo dmidecode**

### 特定查看某一项

```
sudo dmidecode -t processor      (CPU核芯)
sudo dmidecode -t memory         (内存)
sudo dmidecode -t cache          (缓存)
sudo dmidecode -t system         (电脑型号、产商)
sudo dmidecode -t slot           (插卡槽)
sudo dmidecode -t baseboard      (主板)
sudo dmidecode -t connector      (连接设备)
sudo dmidecode -t chassis        (机箱)
sudo dmidecode -t bios           (BIOS) 
```

**其他设备编号：**

```
1	System
2	Base Board
3	Chassis
4	Processor
5	Memory Controller
6	Memory Module
7	Cache
8	Port Connector
9	System Slots
10	On Board Devices
11	OEM Strings
12	System Configuration Options
13	BIOS Language
14	Group Associations
15	System Event Log
16	Physical Memory Array
17	Memory Device
18	32-bit Memory Error
19	Memory Array Mapped Address
20	Memory Device Mapped Address
21	Built-in Pointing Device
22	Portable Battery
23	System Reset
24	Hardware Security
25	System Power Controls
26	Voltage Probe
27	Cooling Device
28	Temperature Probe
29	Electrical Current Probe
30	Out-of-band Remote Access
31	Boot Integrity Services
32	System Boot
33	64-bit Memory Error
34	Management Device
35	Management Device Component
36	Management Device Threshold Data
37	Memory Channel
38	IPMI Device
39	Power Supply
40	Additional Information
41	Onboard Device
```
