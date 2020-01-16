---
title: k8s crio 测试环境搭建
date: 2019-11-01T14:21:26+08:00
lastmod: 2019-11-01T14:21:26+08:00
author: hanamichi
cover: /img/k8s-crio.jpg
categories: ['云原生','容器']
tags: ['kubernetes']
---

k8s+crio+ipvs测试环境搭建记录

<!--more-->

- [k8s-crio环境搭建](#k8s-crio环境搭建)
  - [环境说明](#环境说明)
  - [系统配置](#系统配置)
  - [安装kubeadm](#安装kubeadm)
  - [安装cri-o](#安装cri-o)
  - [安装k8s](#安装k8s)
  - [测试集群正常](#测试集群正常)
- [istio搭建](#istio搭建)
- [微服务使用istio注意事项](#微服务使用istio注意事项)

## k8s-crio环境搭建

### 环境说明

* kubernetes: v1.16.3
* cri-o: release-v1.16.1
* runc: runc-1.0.0-65.rc8.el7
* calico: v3.8
* kubeadm,kubectl,kubelet: v1.16.3
* cni-plugin: release-0.8.3
* kernel: 5.4.3

### 系统配置

1. centos7系统升级内核为`5.4.3`,可参考[centos7升级内核](https://github.com/x893675/note/wiki/Linux-Opt%3A-Centos)

2. 升级系统软件版本

3. 关闭swap分区

4. 将selinux设置为permissive或permissive

5. 设置时间同步

6. 设置内核参数

   ```shell
   cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
   net.bridge.bridge-nf-call-iptables  = 1
   net.ipv4.ip_forward                 = 1
   net.bridge.bridge-nf-call-ip6tables = 1
   EOF
   
   modprobe overlay
   modprobe br_netfilter
   ```

7. 安装ipvsadm,并设置ipvs模块自启

   ```shell
   yum install ipvsadm
   
   cat > /etc/sysconfig/modules/ipvs.modules << EOF
   /sbin/modinfo -F filename ip_vs > /dev/null 2>&1
   if [ $? -eq 0 ];then
   	/sbin/modprobe ip_vs
   fi
   EOF
   ```

### 安装kubeadm

```shell
cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg

EOF
```

`yum --disableexcludes=kubernetes install kubelet-1.16.3 kubeadm-1.16.3 kubectl-1.16.3`

### 安装cri-o

1. 安装依赖软件包

   ```shell
   yum install -y \
     btrfs-progs-devel \
     containers-common \
     device-mapper-devel \
     git \
     glib2-devel \
     glibc-devel \
     glibc-static \
     go \
     gpgme-devel \
     libassuan-devel \
     libgpg-error-devel \
     libseccomp-devel \
     libselinux-devel \
     pkgconfig \
     runc
   ```

2. 编译安装cri-o

   ```shell
   git clone https://github.com/cri-o/cri-o
   
   cd cri-o
   
   git checkout -b v1.16.1 v1.16.1
   
   make && make install
   
   make install.config
   
   make install.systemd
   ```

3. 编译安装conmon

   ```shell
   git clone https://github.com/containers/conmon
   
   cd conmon
   
   make && make install
   ```

4. 编译安装cni-plugins

   ```shell
   git clone https://github.com/containernetworking/plugins
   
   cd plugins
   
   git checkout -b 0.8.3 v0.8.3
   
   ./build_linux.sh
   
   mkdir -p /opt/cni/bin
   
   cp bin/* /opt/cni/bin/
   ```

5. 修改`/etc/crio/crio.config`

   ```ini
   log_level = "info"
   
   cgroup_manager = "systemd"
   ```

6. 启动crio服务

   ```shell
   systemctl daemon-reload && systemctl enable crio --now
   
   #可以使用crio-status config命令查看crio的配置
   ```

7. 安装crio-ctl

   ```shell
   VERSION="v1.17.0"
   
   curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-${VERSION}-linux-amd64.tar.gz --output crictl-${VERSION}-linux-amd64.tar.gz
   
   tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
   
   rm -f crictl-$VERSION-linux-amd64.tar.gz
   ```

8. 配置kubelet

   ```shell
   cat > /etc/sysconfig/kubelet <<EOF
   KUBELET_EXTRA_ARGS=--container-runtime=remote --cgroup-driver=systemd --container-runtime-endpoint='unix:///var/run/crio/crio.sock' --runtime-request-timeout=5m
   EOF
   ```

9. 启动kubelet

   ```shell
   systemctl daemon-reload && systemctl enable kubelet --now
   ```

### 安装k8s

1. 使用kubeadm初始化集群，因之后使用calico网络插件，所以cidr的值需要填写`192.168.0.0/16`

   ```shell
   kubeadm init  --pod-network-cidr=192.168.0.0/16  --kubernetes-version=1.16.3
   ```

2. 安装网络插件

   ```shell
   kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
   ```

3. 执行`kubectl get po --all-namespaces -w`查看并等待pod运行正常

4. 去掉节点的trant标签`kubectl taint nodes --all node-role.kubernetes.io/master-`

5. 集群启动正常后kube-proxy默认使用iptables，先更改成ipvs(**通过kubeadm配置文件配置之后再研究**)

   ```shell
   kubectl get cm kube-proxy -n kube-system -o yaml | sed 's/mode: ""/mode: "ipvs"/' | kubectl apply -f -
   
   for i in $(kubectl get po -n kube-system | awk '/kube-proxy/ {print $1}'); do
     kubectl delete po $i -n kube-system
   done
   
   #执行ipvsadm -l可看到ipvs规则
   ```

6. 配置自动补全

   ```shell
   yum install -y bash-completion
   
   #重新进入shell
   
   source <(kubectl completion bash)
   ```

### 测试集群正常

测试deployment文件如下，部署后通过curl clusterIP:port访问服务，查看网络是否正常

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 80
```

## istio搭建

使用istio版本为**istio-1.4.2**

1. 下载istio

   ```shell
   curl -L https://istio.io/downloadIstio | sh -
   ```

2. 将istioctl添加值环境变量

   ```shell
   export PATH="$PATH:/root/istio-1.4.2/bin"
   ```

3. 安装前验证

   ```shell
   istioctl verify-install
   ```

4. 安装demo

   ```shell
   istioctl manifest apply --set profile=demo
   ```

5. 对namespace的pod自动注入需要加入label

   ```shell
   kubectl label namespace <namespace> istio-injection=enabled
   ```

6. 手动注入

   ```shell
   istioctl kube-inject -f <your-app-spec>.yaml | kubectl apply -f -
   ```

7. 卸载

   ```shell
   istioctl manifest generate --set profile=demo | kubectl delete -f -
   ```

## 微服务使用istio注意事项

* istio通过对每个pod加入一个envoy的sidecar容器接管服务的进出流量，如果服务不是使用k8s作为注册中心，而是使用consul等注册中心，则istio不能显示服务间的调用关系及流量走向，如下图所示，使用的是consul作为注册中心的一个例子:

  ![](img/micro2.jpg)

  而使用k8s作为注册中心，则可以清晰的的到服务间的调用关系和流量走向

  ![](img/micro1.jpg)

* istio目前能识别的是http1.1,http2.0以及grpc的流量，在定义k8s的service时，需要指明name，istio才能对特定的流量进行区别，例如如下service定义:

  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: api
    labels:
      app: api
  spec:
    ports:
      - port: 8080
        targetPort: 8080
        name: http
    selector:
      app: api
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: auth-srv
    labels:
      app: auth
  spec:
    ports:
      - port: 8080
        targetPort: 8080
        name: grpc
    selector:
      app: auth
  ```