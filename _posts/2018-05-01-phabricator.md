## 使用docker搭建phabracator服务

#### 启动mysql服务

```bash
docker run -d -p 3306:3306 \
           --name mysql \ 
           -e MYSQL_ROOT_PASSWORD=mysql \
           -e MYSQL_DATABASE=db \
           -e MYSQL_USER=user \
           -e MYSQL_PASSWORD=passwd \
           mysql:latest
```

#### 启动phabracator

```bash
docker run --name phabricator \
           -p 80:80 -p 443:443 -p 2222:22 \
           --env MYSQL_PORT=3306 \
           --env PHABRICATOR_HOST=172.29.101.81 \
           --env MYSQL_USER=root \
           --env MYSQL_PASS=mysql \
           --env MYSQL_HOST=172.29.101.81 \
           --env PHABRICATOR_REPOSITORY_PATH=/repos \
           -v /opt/phabricator/repo:/repos \
           --env PHABRICATOR_HOST_KEYS_PATH=/hostkeys/persisted \
           -v ~/.ssh/:/hostkeys/ \
           --link mysql \
           -d 172.16.59.153/xwzhu4/phabricator:latest
```

**注意**：

1. `/opt/phabricator/repo`目录要有写权限
2. 首次登陆需要创建管理员账号
3. 第一次登陆后首先要设置账号的授权方式。`Auth->Add Provider->Username/Password`

## 仓库配置

#### 新建仓库

1. Diffusion -> Create Repository -> Create Git Repository -> 填写仓库信息
2. 此时仓库未激活，如果作为独立仓库使用，可以点击Activite Repository激活仓库。

#### 迁移仓库

1. 上一步建立仓库成功后，在仓库管理界面选择 URIs -> Add New URI添加uri
2. 输入源仓库克隆地址，选择`Observe: Copy from a remote`
3. 激活仓库，开始导入

#### 镜像仓库

1. 仓库导入成功后，进入仓库管理界面(Manage Repository -> URIs)，更改上一步添加的uri为`Mirror: Push a copy to a remote`
2. 设置mirror uri远端认证，点击Set Credential，创建远端git仓库的账号密码。 
3. 设置成功后，改仓库的更新会自动同步到远端git仓库

#### 设置规则

phabracator用Herald应用设置各种规则。

下图为在菜单栏添加Herald应用

![菜单栏添加Herald](/img/post-phabricator/phabricator2.png)

**设置规则强制使用code review**：

Heralb   ->   Create   Herald   Rule ->   Commit   Hook:   Commit Content   ->   Global

![](/img/post-phabricator/phabricator3.png)

设置这个全局规则后，没有经过代码审查的代码进行push操作都会被服务器拒绝。

#### 添加ssh keys

![](/img/post-phabricator/phabricator4.png)

可以上传已有的public key。也可以重新生成。

若选择生成密钥，phabricator会自动保存公钥，点击下载私钥，保存到`~/.ssh目录`

```bash
$ chmod 400 ~/.ssh/id_rsa_phabricator.key

$ vim ~/.ssh/config

host 172.29.101.81
  port 2222
  IdentityFile ~/.ssh/id_rsa_phabricator.key
```

## arcanist

Arcanist是Pharicator code review的命令行工具

#### 安装

`git clone git://github.com/facebook/libphutil.git`

`git clone git://github.com/facebook/arcanist.git`

将arc的路径加入系统路径中:

`export PATH=$PATH:/somewhere/arcanist/bin/`

或在系统的profile或是bash(如果用bash)的配置文件的末尾加上这一句。

执行`arc --help`看是否安装成功

#### arc配置

* 设置默认编辑器

  `arc set-config editor "vim"`

* 在项目下配置`.arcconfig`

  ```json
  {
      "phabricator.uri":"http://172.29.101.81/"
  }
  ```

* 在项目下配置静态检查`.arclint`

  ```json
  //以python代码为例，对项目中所有.py结尾的文件用pep8检查
  {
    "linters": {
      "sample": {
        "type": "pep8",
        "include": "(\\.py$)"
      }
    }
  }
  ```

* 为项目安装证书，用于phabricator的认证

  `arc install-certificate`

  根据提示访问指定页面，复制api token

#### arc命令

```bash
arc diff：发送变更详情和审查请求
arc land：推送变更（Git and Mercurial），当通过审查后使用这个命令
arc list：显示变更处理的情况
arc cover：查找最有可能审查变更的人
arc patch：给版本打补丁
arc export：从Differential下载补丁
arc amend：更新Git commit
arc commit：提交变更（SVN）
arc branch：查看Git branches更加详细的信息
```

参考文章：https://www.jianshu.com/p/b1a75a14638c
