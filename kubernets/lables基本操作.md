## 查看标签
```text
# 查看节点标签
kubectl get nodes --show-labels

# 查看Pod标签
kubectl get pods --show-labels

# 查看特定资源的标签
kubectl get <resource-type> <resource-name> --show-labels
```
## 添加/修改标签
```
# 为节点添加/修改标签
kubectl label nodes <node-name> <label-key>=<label-value>

# 为Pod添加/修改标签
kubectl label pods <pod-name> <label-key>=<label-value>

# 强制覆盖现有标签（添加--overwrite）
kubectl label pods <pod-name> <label-key>=<label-value> --overwrite

# 删除节点标签
kubectl label nodes <node-name> <label-key>-

# 删除Pod标签
kubectl label pods <pod-name> <label-key>-
```
