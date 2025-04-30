# 分支冲突
## 切换分支

```
git status --查看当前分支
git branch -a ---查看所有分支
git checkout -b test --创建并进入分支
git checkout  test --切换分支
git branch test2  --创建分支
```

## 合并分支

### 进入master分支中
git checkout master

### 合并分支	
git merge test2

### 合并存在的问题
分支冲突：两个分支修改相同文件后合并

#### 主分支修改test文件后提交
vim test.goi 

git add .

git commit -m "222"

#### test2修改test文件后提交
```
git checkout test2

vim test.goi 

git add .

git commit -m "222"
```

#### 合并
```
git checkout master 

git merge test2

cat test.goi 
sdasda
21312

<<<<<<< HEAD
213131
?=======
1231
>>>>>>> test2

此时需要手动解决冲突
 vim test.goi 

 git add .

 git commit -m "000"

```

# 删除分支
git branch -d test test2


# Git身份设置
(全局)
git config --global user.name "pro"
git config --global user.email "w1914563332@gmail.com"


# 推送到远程仓库
## 1. 关联远程仓库（只需执行一次）
git remote add origin https://gitee.com/wsa191456prpo/pro.git

## 2. 推送代码（首次需加 -u 参数）
git push -u origin 分支名
## 例如推送主分支：
git push -u origin master
-u 参数：将本地分支与远程分支关联，后续推送可直接用 git push
## 常规推送（已关联分支）
git push
## 推送到指定远程分支
git push origin 本地分支名:远程分支名
## 例如：
git push origin feature:feature