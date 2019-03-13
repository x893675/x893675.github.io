---
layout:     post
title:      "service mesh初了解"
subtitle:   " \"k8s-istio多节点环境搭建验证实践\""
date:       2019-03-01 12:00:00
author:     "Hanamichi"
header-img: "img/spacex-1.jpg"
catalog: true
tags:
    - servicemesh
    - k8s
---

## 环境说明

* node1: 192.168.206.196, 2核4g， centos7.5-1804，安装系统时安装gnome桌面
* node2: 192.168.206.197,  2核4g， centos7.5-1804
* node3: 192.168.206.198,  2核4g， centos7.5-1804
* docker版本: 18.09.3
* k8s版本: 1.12.6(使用18.09.3版本的docker需要使用初始化参数跳过版本自检)
* istio版本: 1.0.6

⚠️：本人使用vmware创建三台虚拟机，每个虚拟机配置两张网卡，一张nat，另一张是虚拟机的服务ip，3个虚拟机可以互联。

## 环境安装

⚠️：按照以下步骤配置虚拟机后，可以直接克隆，修改ip，避免重复操作

### 更改host

1. `hostnamectl set-hostname node1`

2. `vim /etc/hosts`

   ```wiki
   192.168.206.196 node1
   192.168.206.197 node2
   192.168.206.198 node3
   ```

### 关闭selinux

1. `sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux`

2. 执行`getenforce`，输出为**disable**为正常

### 关闭swap分区

1. `swapoff -a`

2. `vim /etc/fstab`, 注释swap挂载信息

   ```shell
   #
   # /etc/fstab
   # Created by anaconda on Thu Mar  7 09:55:12 2019
   #
   # Accessible filesystems, by reference, are maintained under '/dev/disk'
   # See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
   #
   UUID=cff363e1-a656-4384-ada7-91732ab4a060 /                       xfs     defaults        0 0
   UUID=d7701086-8c11-49da-ad77-1a06d0b512bc /boot                   xfs     defaults        0 0
   #UUID=4549c6c1-d0a5-4a8b-ae25-f03847f2b241 swap                    swap    defaults        0 0
   ```

### 安装docker-ce

1. `yum install -y yum-utils device-mapper-persistent-data lvm2`
2. `yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo`
3. `yum install docker-ce -y`
4. `systemctl enable --now docker`

### 加载内核模块

1. `modprobe br_netfilter`

### 安装k8s-1.12.6版本

⚠️: 通过yum直接安装的为最新版本v1.13.4的k8s,测试时与网络组件和istio存在兼容性问题，导致服务启动失败，所以选择1.12.6版本

1. 制作1.12.6版本的rpm包

   1. `git clone https://github.com/kubernetes/release.git`

   2. `cd release/rpm`

   3. 编辑kubelet.spec文件，修改文件开头的版本控制宏如下所示，`vim kubelet.spec`

      ```spec
      %global KUBE_MAJOR 1
      %global KUBE_MINOR 12
      %global KUBE_PATCH 6
      %global KUBE_VERSION %{KUBE_MAJOR}.%{KUBE_MINOR}.%{KUBE_PATCH}
      %global RPM_RELEASE 0
      %global ARCH amd64
      ```

   4. `./docker-build.sh`

   5. 完成后会将文件输出至当前目录下的output目录

      ```shell
      [root@node1 output]# ls -al x86_64/
      total 47972
      drwxr-xr-x 3 hanamichi root      205 Mar 12 12:15 .
      drwxr-xr-x 3 hanamichi root       20 Mar 12 12:14 ..
      -rw-r--r-- 1 hanamichi root  4409594 Mar 12 12:15 cri-tools-1.12.0-0.x86_64.rpm
      -rw-r--r-- 1 hanamichi root  7547822 Mar 12 12:14 kubeadm-1.12.6-0.x86_64.rpm
      -rw-r--r-- 1 hanamichi root  8025550 Mar 12 12:14 kubectl-1.12.6-0.x86_64.rpm
      -rw-r--r-- 1 hanamichi root 20115914 Mar 12 12:14 kubelet-1.12.6-0.x86_64.rpm
      -rw-r--r-- 1 hanamichi root  9008686 Mar 12 12:14 kubernetes-cni-0.6.0-0.x86_64.rpm
      drwxr-xr-x 2 hanamichi root     4096 Mar 12 12:15 repodata
      ```

2. 安装rpm包，`rpm -ivh *.rpm`，若有依赖问题，可通过yum安装依赖软件包

3. `sed -i 's/cgroup-driver=systemd/cgroup-driver=cgroupfs/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf`

4. `systemctl enable --now kubelet`

5. `poweroff`

### 拷贝虚拟机，完成node2, node3的ip更改

⚠️: 开机后需要执行`iptables -P FORWARD ACCEPT`，docker的默认FORWARD策略为drop，之后可以通过更改docker的启动参数`--icc=true`，暂时未研究。之后更新

## 启动k8s

⚠️： 网络组件选用flannel, kubeadm的启动参数需要添加`--pod-network-cidr=10.244.0.0/16`

1. 在node1执行`kubeadm init --apiserver-advertise-address=192.168.206.196 --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors all`

2. 根据完成后的提示创建`.kube/config`文件和记录kubeadm join命令

3. `kubectl apply -f kube-flannel.yaml`,注意，不执行此步骤，coredns这个pod会是pending状态：

   ```yaml
   ---
   apiVersion: extensions/v1beta1
   kind: PodSecurityPolicy
   metadata:
     name: psp.flannel.unprivileged
     annotations:
       seccomp.security.alpha.kubernetes.io/allowedProfileNames: docker/default
       seccomp.security.alpha.kubernetes.io/defaultProfileName: docker/default
       apparmor.security.beta.kubernetes.io/allowedProfileNames: runtime/default
       apparmor.security.beta.kubernetes.io/defaultProfileName: runtime/default
   spec:
     privileged: false
     volumes:
       - configMap
       - secret
       - emptyDir
       - hostPath
     allowedHostPaths:
       - pathPrefix: "/etc/cni/net.d"
       - pathPrefix: "/etc/kube-flannel"
       - pathPrefix: "/run/flannel"
     readOnlyRootFilesystem: false
     # Users and groups
     runAsUser:
       rule: RunAsAny
     supplementalGroups:
       rule: RunAsAny
     fsGroup:
       rule: RunAsAny
     # Privilege Escalation
     allowPrivilegeEscalation: false
     defaultAllowPrivilegeEscalation: false
     # Capabilities
     allowedCapabilities: ['NET_ADMIN']
     defaultAddCapabilities: []
     requiredDropCapabilities: []
     # Host namespaces
     hostPID: false
     hostIPC: false
     hostNetwork: true
     hostPorts:
     - min: 0
       max: 65535
     # SELinux
     seLinux:
       # SELinux is unsed in CaaSP
       rule: 'RunAsAny'
   ---
   kind: ClusterRole
   apiVersion: rbac.authorization.k8s.io/v1beta1
   metadata:
     name: flannel
   rules:
     - apiGroups: ['extensions']
       resources: ['podsecuritypolicies']
       verbs: ['use']
       resourceNames: ['psp.flannel.unprivileged']
     - apiGroups:
         - ""
       resources:
         - pods
       verbs:
         - get
     - apiGroups:
         - ""
       resources:
         - nodes
       verbs:
         - list
         - watch
     - apiGroups:
         - ""
       resources:
         - nodes/status
       verbs:
         - patch
   ---
   kind: ClusterRoleBinding
   apiVersion: rbac.authorization.k8s.io/v1beta1
   metadata:
     name: flannel
   roleRef:
     apiGroup: rbac.authorization.k8s.io
     kind: ClusterRole
     name: flannel
   subjects:
   - kind: ServiceAccount
     name: flannel
     namespace: kube-system
   ---
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: flannel
     namespace: kube-system
   ---
   kind: ConfigMap
   apiVersion: v1
   metadata:
     name: kube-flannel-cfg
     namespace: kube-system
     labels:
       tier: node
       app: flannel
   data:
     cni-conf.json: |
       {
         "name": "cbr0",
         "plugins": [
           {
             "type": "flannel",
             "delegate": {
               "hairpinMode": true,
               "isDefaultGateway": true
             }
           },
           {
             "type": "portmap",
             "capabilities": {
               "portMappings": true
             }
           }
         ]
       }
     net-conf.json: |
       {
         "Network": "10.244.0.0/16",
         "Backend": {
           "Type": "vxlan"
         }
       }
   ---
   apiVersion: extensions/v1beta1
   kind: DaemonSet
   metadata:
     name: kube-flannel-ds-amd64
     namespace: kube-system
     labels:
       tier: node
       app: flannel
   spec:
     template:
       metadata:
         labels:
           tier: node
           app: flannel
       spec:
         hostNetwork: true
         nodeSelector:
           beta.kubernetes.io/arch: amd64
         tolerations:
         - operator: Exists
           effect: NoSchedule
         serviceAccountName: flannel
         initContainers:
         - name: install-cni
           image: quay.io/coreos/flannel:v0.11.0-amd64
           command:
           - cp
           args:
           - -f
           - /etc/kube-flannel/cni-conf.json
           - /etc/cni/net.d/10-flannel.conflist
           volumeMounts:
           - name: cni
             mountPath: /etc/cni/net.d
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         containers:
         - name: kube-flannel
           image: quay.io/coreos/flannel:v0.11.0-amd64
           command:
           - /opt/bin/flanneld
           args:
           - --ip-masq
           - --kube-subnet-mgr
           resources:
             requests:
               cpu: "100m"
               memory: "50Mi"
             limits:
               cpu: "100m"
               memory: "50Mi"
           securityContext:
             privileged: false
             capabilities:
                add: ["NET_ADMIN"]
           env:
           - name: POD_NAME
             valueFrom:
               fieldRef:
                 fieldPath: metadata.name
           - name: POD_NAMESPACE
             valueFrom:
               fieldRef:
                 fieldPath: metadata.namespace
           volumeMounts:
           - name: run
             mountPath: /run/flannel
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         volumes:
           - name: run
             hostPath:
               path: /run/flannel
           - name: cni
             hostPath:
               path: /etc/cni/net.d
           - name: flannel-cfg
             configMap:
               name: kube-flannel-cfg
   ---
   apiVersion: extensions/v1beta1
   kind: DaemonSet
   metadata:
     name: kube-flannel-ds-arm64
     namespace: kube-system
     labels:
       tier: node
       app: flannel
   spec:
     template:
       metadata:
         labels:
           tier: node
           app: flannel
       spec:
         hostNetwork: true
         nodeSelector:
           beta.kubernetes.io/arch: arm64
         tolerations:
         - operator: Exists
           effect: NoSchedule
         serviceAccountName: flannel
         initContainers:
         - name: install-cni
           image: quay.io/coreos/flannel:v0.11.0-arm64
           command:
           - cp
           args:
           - -f
           - /etc/kube-flannel/cni-conf.json
           - /etc/cni/net.d/10-flannel.conflist
           volumeMounts:
           - name: cni
             mountPath: /etc/cni/net.d
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         containers:
         - name: kube-flannel
           image: quay.io/coreos/flannel:v0.11.0-arm64
           command:
           - /opt/bin/flanneld
           args:
           - --ip-masq
           - --kube-subnet-mgr
           resources:
             requests:
               cpu: "100m"
               memory: "50Mi"
             limits:
               cpu: "100m"
               memory: "50Mi"
           securityContext:
             privileged: false
             capabilities:
                add: ["NET_ADMIN"]
           env:
           - name: POD_NAME
             valueFrom:
               fieldRef:
                 fieldPath: metadata.name
           - name: POD_NAMESPACE
             valueFrom:
               fieldRef:
                 fieldPath: metadata.namespace
           volumeMounts:
           - name: run
             mountPath: /run/flannel
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         volumes:
           - name: run
             hostPath:
               path: /run/flannel
           - name: cni
             hostPath:
               path: /etc/cni/net.d
           - name: flannel-cfg
             configMap:
               name: kube-flannel-cfg
   ---
   apiVersion: extensions/v1beta1
   kind: DaemonSet
   metadata:
     name: kube-flannel-ds-arm
     namespace: kube-system
     labels:
       tier: node
       app: flannel
   spec:
     template:
       metadata:
         labels:
           tier: node
           app: flannel
       spec:
         hostNetwork: true
         nodeSelector:
           beta.kubernetes.io/arch: arm
         tolerations:
         - operator: Exists
           effect: NoSchedule
         serviceAccountName: flannel
         initContainers:
         - name: install-cni
           image: quay.io/coreos/flannel:v0.11.0-arm
           command:
           - cp
           args:
           - -f
           - /etc/kube-flannel/cni-conf.json
           - /etc/cni/net.d/10-flannel.conflist
           volumeMounts:
           - name: cni
             mountPath: /etc/cni/net.d
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         containers:
         - name: kube-flannel
           image: quay.io/coreos/flannel:v0.11.0-arm
           command:
           - /opt/bin/flanneld
           args:
           - --ip-masq
           - --kube-subnet-mgr
           resources:
             requests:
               cpu: "100m"
               memory: "50Mi"
             limits:
               cpu: "100m"
               memory: "50Mi"
           securityContext:
             privileged: false
             capabilities:
                add: ["NET_ADMIN"]
           env:
           - name: POD_NAME
             valueFrom:
               fieldRef:
                 fieldPath: metadata.name
           - name: POD_NAMESPACE
             valueFrom:
               fieldRef:
                 fieldPath: metadata.namespace
           volumeMounts:
           - name: run
             mountPath: /run/flannel
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         volumes:
           - name: run
             hostPath:
               path: /run/flannel
           - name: cni
             hostPath:
               path: /etc/cni/net.d
           - name: flannel-cfg
             configMap:
               name: kube-flannel-cfg
   ---
   apiVersion: extensions/v1beta1
   kind: DaemonSet
   metadata:
     name: kube-flannel-ds-ppc64le
     namespace: kube-system
     labels:
       tier: node
       app: flannel
   spec:
     template:
       metadata:
         labels:
           tier: node
           app: flannel
       spec:
         hostNetwork: true
         nodeSelector:
           beta.kubernetes.io/arch: ppc64le
         tolerations:
         - operator: Exists
           effect: NoSchedule
         serviceAccountName: flannel
         initContainers:
         - name: install-cni
           image: quay.io/coreos/flannel:v0.11.0-ppc64le
           command:
           - cp
           args:
           - -f
           - /etc/kube-flannel/cni-conf.json
           - /etc/cni/net.d/10-flannel.conflist
           volumeMounts:
           - name: cni
             mountPath: /etc/cni/net.d
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         containers:
         - name: kube-flannel
           image: quay.io/coreos/flannel:v0.11.0-ppc64le
           command:
           - /opt/bin/flanneld
           args:
           - --ip-masq
           - --kube-subnet-mgr
           resources:
             requests:
               cpu: "100m"
               memory: "50Mi"
             limits:
               cpu: "100m"
               memory: "50Mi"
           securityContext:
             privileged: false
             capabilities:
                add: ["NET_ADMIN"]
           env:
           - name: POD_NAME
             valueFrom:
               fieldRef:
                 fieldPath: metadata.name
           - name: POD_NAMESPACE
             valueFrom:
               fieldRef:
                 fieldPath: metadata.namespace
           volumeMounts:
           - name: run
             mountPath: /run/flannel
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         volumes:
           - name: run
             hostPath:
               path: /run/flannel
           - name: cni
             hostPath:
               path: /etc/cni/net.d
           - name: flannel-cfg
             configMap:
               name: kube-flannel-cfg
   ---
   apiVersion: extensions/v1beta1
   kind: DaemonSet
   metadata:
     name: kube-flannel-ds-s390x
     namespace: kube-system
     labels:
       tier: node
       app: flannel
   spec:
     template:
       metadata:
         labels:
           tier: node
           app: flannel
       spec:
         hostNetwork: true
         nodeSelector:
           beta.kubernetes.io/arch: s390x
         tolerations:
         - operator: Exists
           effect: NoSchedule
         serviceAccountName: flannel
         initContainers:
         - name: install-cni
           image: quay.io/coreos/flannel:v0.11.0-s390x
           command:
           - cp
           args:
           - -f
           - /etc/kube-flannel/cni-conf.json
           - /etc/cni/net.d/10-flannel.conflist
           volumeMounts:
           - name: cni
             mountPath: /etc/cni/net.d
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         containers:
         - name: kube-flannel
           image: quay.io/coreos/flannel:v0.11.0-s390x
           command:
           - /opt/bin/flanneld
           args:
           - --ip-masq
           - --kube-subnet-mgr
           resources:
             requests:
               cpu: "100m"
               memory: "50Mi"
             limits:
               cpu: "100m"
               memory: "50Mi"
           securityContext:
             privileged: false
             capabilities:
                add: ["NET_ADMIN"]
           env:
           - name: POD_NAME
             valueFrom:
               fieldRef:
                 fieldPath: metadata.name
           - name: POD_NAMESPACE
             valueFrom:
               fieldRef:
                 fieldPath: metadata.namespace
           volumeMounts:
           - name: run
             mountPath: /run/flannel
           - name: flannel-cfg
             mountPath: /etc/kube-flannel/
         volumes:
           - name: run
             hostPath:
               path: /run/flannel
           - name: cni
             hostPath:
               path: /etc/cni/net.d
           - name: flannel-cfg
             configMap:
               name: kube-flannel-cfg
   ```

4. 使用`kubectl get pods --all-namespaces`查看pod状态

5. 等主节点正常后，在node2和node3执行kubeadm join命令(kubeadm join命令直接复制主节点部署后输出的命令即可)，也需要在命令末尾加上`--ignore-preflight-errors all` 

## 安装istio和示例服务

### 安装istio

1. 下载istio-1.0.6，`wget https://github.com/istio/istio/releases/download/1.0.6/istio-1.0.6-linux.tar.gz && tar -xvf istio-1.0.6-linux.tar.gz`

2. `kubectl apply -f istio-1.0.6/install/kubernetes/istio-demo.yaml`

3. 使用`kubectl get pods -n istio-system`查看pod状态

   ```shell
   [root@node1 ~]# kubectl get pods -n istio-system
   NAME                                     READY   STATUS      RESTARTS   AGE
   grafana-7ffdd5fb74-mgdx9                 1/1     Running     1          17h
   istio-citadel-5bbbc98c6d-vs5xv           1/1     Running     1          17h
   istio-cleanup-secrets-stsrp              0/1     Completed   0          17h
   istio-egressgateway-77dfd495df-fzkmd     1/1     Running     1          17h
   istio-galley-744969c89-vrljt             1/1     Running     1          17h
   istio-ingressgateway-6bb7555c76-q5vjc    1/1     Running     1          17h
   istio-pilot-f7f56b94c-zqlnx              2/2     Running     3          17h
   istio-policy-755477988-pc8dz             2/2     Running     2          17h
   istio-sidecar-injector-856b74c95-xwc8b   1/1     Running     1          17h
   istio-telemetry-78f76f9d6-n9v87          2/2     Running     2          17h
   istio-tracing-6445d6dbbf-lqxrk           1/1     Running     1          17h
   prometheus-65d6f6b6c-dclj2               1/1     Running     1          17h
   servicegraph-658fd9f76d-zljmr            1/1     Running     2          17h
   ```

   图中**istio-cleanup-secrets-stsrp**为一个job，执行完成后没有destroy，不影响istio的使用，问题之后会去研究

4. `kubectl get ep -n istio-system`

   ```shell
   [root@node1 ~]# kubectl get ep -n istio-system
   NAME                     ENDPOINTS                                                         AGE
   grafana                  10.244.1.22:3000                                                  17h
   istio-citadel            10.244.1.24:9093,10.244.1.24:8060                                 17h
   istio-egressgateway      10.244.1.26:80,10.244.1.26:443                                    17h
   istio-galley             10.244.2.15:9093,10.244.2.15:443                                  17h
   istio-ingressgateway     10.244.2.14:80,10.244.2.14:15030,10.244.2.14:15011 + 5 more...    17h
   istio-pilot              10.244.2.13:9093,10.244.2.13:15010,10.244.2.13:8080 + 1 more...   17h
   istio-policy             10.244.2.12:9093,10.244.2.12:9091,10.244.2.12:15004               17h
   istio-sidecar-injector   10.244.1.25:443                                                   17h
   istio-telemetry          10.244.1.23:42422,10.244.1.23:9093,10.244.1.23:9091 + 1 more...   17h
   jaeger-agent             10.244.1.28:6831,10.244.1.28:5775,10.244.1.28:6832                17h
   jaeger-collector         10.244.1.28:14267,10.244.1.28:14268                               17h
   jaeger-query             10.244.1.28:16686                                                 17h
   prometheus               10.244.1.27:9090                                                  17h
   servicegraph             10.244.1.29:8088                                                  17h
   tracing                  10.244.1.28:16686                                                 17h
   zipkin                   10.244.1.28:9411                                                  17h
   
   ```

5. 根据上个步骤的输出的端点ip和端口，可以在浏览器中访问这些服务。

6. grafana服务

   ![grafana](/img/in-post/k8s-istio/grafana.png)

7. prometheus服务

   ![prometheus](/img/in-post/k8s-istio/prometheus.png)

8. jager服务

   ![jager](/img/in-post/k8s-istio/jager.png)

9. 使用envoy协议sidecar自动注入

   `kubectl label namespace default istio-injection=enabled`

### 安装bookinfo示例服务

1. `kubectl apply -f istio-1.0.6/samples/bookinfo/platform/kube/bookinfo.yaml`

2. `kubectl apply -f istio-1.0.6/samples/bookinfo/networking/bookinfo-gateway.yaml`

3. `kubectl get pods`

   ```shell
   NAME                            READY   STATUS    RESTARTS   AGE
   details-v1-876bf485f-5ps4f      2/2     Running   0          63m
   productpage-v1-8d69b45c-f9kcn   2/2     Running   0          63m
   ratings-v1-7c9949d479-8q7fn     2/2     Running   0          63m
   reviews-v1-85b7d84c56-xhhvm     2/2     Running   0          63m
   reviews-v2-cbd94c99b-8xfw5      2/2     Running   0          63m
   reviews-v3-748456d47b-7ll8r     2/2     Running   0          63m
   ```

## envoy 测试

