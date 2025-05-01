# pod资源类型
```
静态pod:kubelet加载配置信息/etc/kubernetes/manifests后自动创建，无调度过程，在本节点创建
自主式pod：又用户自己定义并提交给API-server，server调度后创建。
```
 ## pod重启策略
```
Always:无论何种exit code都重启
OnFailure：错误退出就重启
Never：不重启
```
## 镜像下载策略
```
Always:不管存在不存在都拉
IfNotPresent：存在就不拉去
Nerver：不拉取
```

## `command` 和 `args`
```
docker:
当 ENTRYPOINT 和 CMD 同时存在时，CMD 的内容会作为 ENTRYPOINT 的默认参数。 • 如果 docker run 提供了参数，则会覆盖 CMD 的内容。
k8s:
在k8s里面如果你指定了command，这个命令可以覆盖镜像的entrypoint。
1.如果没有提供command和args参数，则默认使用镜像定义的值。 
2.如果单独提供command，没有args参数，则仅使用k8s中定义的command，原有的镜像里面的cmd和entrypoint将被忽略。 
3.如果单独提供args，没有command参数，则原有镜像里面的cmd被覆盖，而entrypoint将和args同时生效。 
4.如果同时提供command和args，则忽略镜像中默认的cmd和entrypoint，只有command和args生效。
```
# 命名空间

```
apiVersion: v1
kind: Namespace
metadata:
  name: test
spec: {}
status: {}
```
