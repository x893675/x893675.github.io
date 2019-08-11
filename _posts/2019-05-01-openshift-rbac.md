---
layout:     post
title:      "openshift权限控制"
subtitle:   " \"openshift-rbac详解\""
date:       2019-05-01 12:00:00
author:     "Hanamichi"
header-img: "img/spacex-1.jpg"
catalog: true
tags:
    - openshift
    - k8s
---

## Openshift RBAC
- Openshift中继续沿用Kubernetes RBAC机制来实现授权模块

	![rbac.png](/img/in-post/post-openshift-rbac/rbac.png)

- RBAC的概念

  - RBAC: 基于角色的权限访问控制（Role-Based Access Control），通过给用户绑定相应的角色，使用户获得对应角色对资源的操作权限
  - openshift中将RBAC分为两种，分别是Cluster RBAC和Local RBAC(Cluster RBAC适用于所有项目的角色和绑定。集群范围内存在的角色被视为clusterrole。clusterrolebinding只能引用clusterrole。Local RBAC适用于project中的role和rolebinding。仅存在于project中的role被看为local role。rolebinding可以引用clusterrole和local role。)

- Cluster role和Local role

  - role的概念

    - role是策略规则的集合（策略规则是允许对一组资源操作的动词集，例如get,list...）

    - cluster role 示例

      ```yaml
      apiVersion: authorization.openshift.io/v1
      	kind: ClusterRole
      	metadata:
      	  name: clusterrole-test
      	rules:
      	- apiGroups:
      	  - ""  # “”表示核心api组
      	  attributeRestrictions: null
      	  resources:
      	  - pods
      	  verbs:
      	  - create
      	  - get
      	  - list
      ```

    - role示例（local role是在某个project下定义的，属于某个project,所以我们要指定namespace的名称

      ```yaml
      apiVersion: authorization.openshift.io/v1
      	kind: Role
      	metadata:
      	  name: localrole-test
      	  namespace: default
      	rules:
      	- apiGroups:
      	  - ""  # “”表示核心api组
      	  attributeRestrictions: null
      	  resources:
      	  - pods
      	  verbs:
      	  - create
      	  - get
      	  - list
      ```

- Openshift有一组默认的clusterrole,可以绑定集群范围内和本地的用户以及用户组

  | Default Cluster Role |                         Description                          |
  | :------------------: | :----------------------------------------------------------: |
  |        admin         | 项目管理。如果在rolebinding中使用，管理员用户将有权查看project中的任何资源并可以修改项目中除配额之外的任何资源。 |
  |      basic-user      |         可以获取相关project和user的基本信息的用户。          |
  |    cluster-admin     | 可以在任何project中执行任何操作的超级用户。使用对应project下的rolebinding绑定一个用户时，他们可以完全控制配额以及project中每个资源的每个操作。 |
  |    cluster-status    |               可以获取集群基本状态信息的用户。               |
  |         edit         | 可以修改project中大多数对象但无权查看或修改roles或bindings的用户 |
  |   self-provisioner   |                可以创建自己的project的用户。                 |
  |         view         | 无法对project进行任何修改但可以查看project中大多数对象的用户。他们无法查看或修改roles或binding |
  |    cluster-reader    |              可以读取但不能查看集群中对象的用户              |

- Local Role Binding和Cluster Role Binding

  - Binding就像是关联用户和role的纽带，绑定了用户和role以后，用户就具有了role中定义的对指定资源的操作规则, 由此可知，在Binding的配置文件中，我们就需要指定用户和用户想要绑定的role，其中RoleBinding是project层面的，所以需要指定对应的namespace，而ClusterRoleBinding是集群层面的，不需要指定。

  - Local Role Binding示例(绑定local role)

    ```yaml
    apiVersion: authorization.openshift.io/v1
    	kind: RoleBinding
    	metadata:
    	  name: test-binding
    	  namespace: default
    	roleRef:
    	  name: localrole-test
    	subjects:
    	- kind: User
    	  name: test
    ```

  - Cluster Role Binding示例(绑定cluster role)

    ```yaml
    apiVersion: authorization.openshift.io/v1
    	kind: ClusterRoleBinding
    	metadata:
    	  name: test-binding
    	roleRef:
    	  name: clusterrole-test
    	subjects:
    	- kind: User
    	  name: test
    ```

- serviceaccount的概念

  - Service account是为了方便Pod里面的进程调用Kubernetes API或其他外部服务而设计的。它与User account不同:

    - User account是为人设计的，而service account则是为Pod中的进程调用Kubernetes API而设计
    - User account是跨namespace的，而service account则是仅局限它所在的namespace
    - Token controller检测service account的创建，并为它们创建secret
    - 开启ServiceAccount Admission Controller后
      - 每个Pod在创建后都会自动设置spec.serviceAccount为default（除非指定了其他ServiceAccout)
      - 验证Pod引用的service account已经存在，否则拒绝创建
      - 如果Pod没有指定ImagePullSecrets，则把service account的ImagePullSecrets加到Pod中
      - 每个container启动后都会挂载该service account的token和ca.crt到/var/run/secrets/kubernetes.io/serviceaccount/

  - 新建一个project的时候，系统会默认创建三个service accounts, 并赋予他们默认的角色

    | Service Account |                            Usage                             |
    | :-------------: | :----------------------------------------------------------: |
    |     builder     | 用于build pod, 使用名为system:image-builder的clusterrole, 允许向project中使用任何内部Docker Registry的Image Stream推送镜像 |
    |    deployer     | 用于部署pod，使用名为system：deployer的clusterrole，允许查看和修改project中的replication controllers和pod。 |
    |     default     |   用于运行没有指定serviceaccount的pod,默认没有绑定任何role   |

    注意: 项目中的所有serviceaccount都将获得名为`system:image-puller`的**clusterrole**，该clusterrole允许使用内部Docker Registry从project中的任何ImageStream中pull image。

- Cluster Role和Local Role的使用场景
	1. 根据Openshift官方的架构图描述，对集群或者是project的中的资源操作都是会将用户通过RoleBinding或者是ClusterRoleBinding的方式去绑定Cluster Role从而获取到对相应project下资源的操作权限
	2. Local Role一般只会用于和serviceaccount用户绑定，管理serviceaccount用户的操作行为规则。

- CLuster Role的使用
	1. 赋予用户对于集群层面资源的操作权限
		- 创建一个用户或者使用已经存在的用户(Nomarl User)
		- 创建ClusterRole或者使用Openshift自身定义的Cluster Role
		- 使用ClusterRoleBinding绑定用户和ClusterRole
		- 这样用户就具备了对集群层面资源的操作权限了
		- 例子：
			1. 假设我们已有一个已验证过的用户test，并将test用户设置为集群超级管理员（使用名为cluster-admin的clusterrole）
			
2. 创建clusterrolebinding，绑定用户和角色
			
					```yaml
				apiVersion: authorization.openshift.io/v1
					kind: ClusterRoleBinding
					metadata:
					  name: cluster-admin-binding
					roleRef:
					  name: cluster-admin
					subjects:
					- kind: User
					  name: test
				```
	2. 赋予用户对于Project层面资源的操作权限
		- 管理员用户新建一个namespace
		- 由管理员创建一个用户或者使用已经存在的用户
		- 定义ClusterRole或者使用Openshift默认创建的ClusterRole
		- 使用Project中的rolebinding去绑定一个ClusterRole
		- 这样用户就具备了对相应project下资源的操作权限了
	- 例子:
			1. 假设我们已经有一个以验证过但是未绑定任何角色的用户test(Normal User)，我们现在想将用户设置project名为clusterrole-test（未创建）的项目管理员（需要使用名为admin的clusterrole）。
			
2. 创建名为test的project
			
					`oc new-project clusterrole-test`
			
			3. 创建RoleBinding, 绑定用户和角色
			
					```yaml
				apiVersion: authorization.openshift.io/v1
					kind: RoleBinding
					metadata:
					  name: admin-role-binding
					  namespace: clusterrole-test
				roleRef:
					  kind: ClusterRole
					  name: admin
					subjects:
				
				kind: User
				name: test
				```
	
- Local Role的使用
	1. 在Openshift中Local role是与serviceaccout进行rolebinding的，为serviceaccount添加对相应的project下资源的操作权限。
	2. 在已有的project下创建serviceaccount账号
	3. 定义local role
	4. 创建rolebinding，绑定serviceaccount账号和local role,这样就赋予了serviceaccount在相应Project的操作权限。
	5. 例子:
		- 假设我们在名为local-role-test的project下创建一个名为test的serviceaccount账号，绑定我们自定义的local role。
		
- 新建project
		
				`oc new-project local-role-test`
		
		- 创建serviceaccount
		
		`oc create sa test`
				
		- 创建local role（具有对pod资源的create，get，list操作的权限）
		
				```yaml
			apiVersion: authorization.openshift.io/v1
				kind: Role
				metadata:
				  name: myrole
				  namespace: local-role-test
				rules:
				- apiGroups:
				  - ""  # “”表示核心api组
				  attributeRestrictions: null
				  resources:
				  - pods
				  verbs:
		  - create
				  - get
				  - list
			```
			
		- 创建local role binding, 绑定serviceaccount和local role
		
				```yaml
			apiVersion: authorization.openshift.io/v1
				kind: RoleBinding
				metadata:
				  name: mybinding
				  namespace: local-role-test
				roleRef:
				  name:  myrole
				subjects:
				- kind: ServiceAccount
				  name: test
			```
	
- 用户组使用Role或ClusterRole
	1. 用户和用户组的概念
		- 用户的用户名由字符串表示。可以是简单的用户名，如“alice”，电子邮件样式的名称，如“bob@example.com”，或者用字符串表示的数字ID。由kubernetes管理员来配置身份验证模块，以生成所需格式的用户名。RBAC授权系统不需要任何特定格式。但是"system:"是为Kubernetes系统使用而保留的，因此管理员应该确保用户名不包含此前缀。
		
		- 用户组信息当前由kubernetes中的authenticator模块提供。与用户一样，用户组也被表示为字符串，并且该字符串除了"system:"是保留的之外，没有任何格式要求。
		
- serviceaccount的组由Openshift自身管理，serviceaccount的用户名默认带有system:serviceaccount:前缀，例如:`system:serviceaccount:<project>:<name>`，属于组`system:serviceaccounts:<project>`。
		
		- Normal User的组由用户使用命令手动分配，例如创建一个名为`admins`的用户组
		
				```bash
			oc adm groups new admins
			# 将用户test添加到admins组内
			oc adm groups add-users admins test
		```
	2. 用户组绑定Role或者ClusterRole与用户相比，只是binding内的subjects不同，其它和用户的绑定方法一致。
	3. 举例
		- 对于用户名为“alice@example.com”的用户:
	
				```yaml
		subjects:
				- kind: User
				  name: "alice@example.com"
				  apiGroup: rbac.authorization.k8s.io
		```
			
	- 对于属于用户组“frontend-admins”的用户:
		
				```yaml
			subjects:
			- kind: Group
				  name: "frontend-admins"
			  apiGroup: rbac.authorization.k8s.io
			```
			
		- 对于namespaces名为kube-system下默认的名为default的serviceaccount：
	
				```yaml
		subjects:
			  - kind: ServiceAccount
			    name: default
			    namespace: kube-system
		```
			
	- 对于在名为qa的namespaces下的所有serviceaccount用户:
		
				```yaml
			subjects:
			- kind: Group
				  name: system:serviceaccounts:qa
			  apiGroup: rbac.authorization.k8s.io
			```
			
		- 对于所有的serviceaccount用户:
	
				```yaml
		subjects:
				- kind: Group
				  name: system:serviceaccounts
				  apiGroup: rbac.authorization.k8s.io
		```
			
		- 对于所有已验证的用户：
		
				```yaml
			subjects:
				- kind: Group
				  name: system:authenticated
				  apiGroup: rbac.authorization.k8s.io
			```
			
		- 对于所有未验证的用户
		
				```yaml
			subjects:
			  - kind: Group
			    name: system:unauthenticated
			    apiGroup: rbac.authorization.k8s.io
			```
			
		- 对于所有用户:
		
				```yaml
			subjects:
				- kind: Group
				  name: system:authenticated
				  apiGroup: rbac.authorization.k8s.io
				- kind: Group
				  name: system:unauthenticated
				  apiGroup: rbac.authorization.k8s.io
			```