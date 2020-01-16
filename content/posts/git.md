---
title: git常用命令记录
date: 2018-03-07T14:21:26+08:00
lastmod: 2018-03-07T14:21:26+08:00
author: hanamichi
cover: /img/code.jpg
categories: ['linux']
tags: ['linux']
---

记录一些git的命令及使用

<!--more-->

- [Git设置](#git设置)
  - [Git使用socks5代理](#git使用socks5代理)
  - [设置存储http密码](#设置存储http密码)
- [Git常用命令](#git常用命令)
  - [分支操作](#分支操作)
  - [Tag操作](#tag操作)
  - [撤销本地修改](#撤销本地修改)
  - [查看分支的合并情况](#查看分支的合并情况)
  - [git rebase](#git-rebase)
  - [git revert](#git-revert)
  - [暂存](#暂存)
- [代码提交规范](#代码提交规范)
  - [Git commit日志基本规范](#git-commit日志基本规范)


## Git设置

### Git使用socks5代理

`git config --global http.proxy 'socks5://127.0.0.1:1080' `

`git config --global https.proxy 'socks5://127.0.0.1:1080' `

### 设置存储http密码

1. 使用文件存储，密码为明文`git config credential.helper store`
2. 使用内存存储`git config credential.helper cache`
3. 对于mac os，默认开启osxkeychain存储密码

## Git常用命令

### 分支操作

1. 创建分支: `git checkout -b branch_name`
2. 查看全部分支: `git branch -av`
3. 合并分支: `git merge --no-ff branch_name`
4. 删除本地分支:`git branch -d branch_name`
5. 删除远程分支:`git branch -r -d branch_name`，`git push origin :branch_name`
6. 查看代码库上流:`git remote -v`
7. 根据commit id获取分支名:`git branch --contains commit-id`
8. 为当前分支设置跟踪分支:`git branch -u branch_name`

### Tag操作

1. 列出所有tag: `git tag`

2. 创建标签

   1. 创建轻量标签: `git tag tag_name`
   2. 创建附注标签: `git tag -a tag_name`

   git标签分为两种类型：轻量标签和附注标签。轻量标签是指向提交对象的引用，附注标签则是仓库中的一个独立对象。建议使用附注标签。

3. 切换到标签: `git checkout tag_name`

4. 查看标签版本信息: `git show tag_name`

5. 删除标签: `git tag -d tag_name`

6. 删除远程标签: `git push origin :refs/tags/tag_name`

7. 发布标签

   1. 发布指定标签: `git push origin tag_name`
   2. 发布所有标签: `git push origin --tag`

### 撤销本地修改

`git reset --hard HEAD`

`git checkout .`

### 查看分支的合并情况

 `git log --graph --pretty=oneline --abbrev-commit`

### git rebase

`git rebase -i branch/commit_id`

### git revert

该命令可以撤销某一次的提交并生成一次新的提交

`git revert commit-id`

### 暂存

使用`git stash`可以使当前修改暂存

`git stash list` 查看仓库所有暂存的提交

`git stash pop xx` 应用某个暂存的提交

## 代码提交规范

### *Git commit日志基本规范*

```bash
<type>(<scope>): <subject>
<BLANK LINE>
<body>
<BLANK LINE>
<footer>
```
