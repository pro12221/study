| 类型                       | 说明                   | 示例                                 |
| ------------------------ | -------------------- | ---------------------------------- |
| **瞬时向量（Instant Vector）** | 某一时刻多个时序的样本（只取“当前值”） | `up`, `node_cpu_seconds_total`     |
| **区间向量（Range Vector）**   | 一段时间范围内多个时序的样本（时间窗口） | `rate(node_cpu_seconds_total[5m])` |
# 标签选择器（Label Selector）
Prometheus 使用标签（Label）来唯一标识每一个时序。  
我们可以通过标签选择器筛选某些时序。
```
metric_name{label_name="value"}
```
# 区间选择器（Range Vector）
```
metric_name[时间范围]
```
# 聚合函数（Aggregation Operators）
|函数名|作用说明|示例|
|---|---|---|
|`sum()`|求和|`sum(up)`|
|`avg()`|求平均值|`avg(...)`|
|`min()` / `max()`|最小/最大值|`min(...)`|
|`count()`|统计符合条件的时间序列数量|`count(up)`|
用于**按标签分组聚合**：
```
sum(rate(node_cpu_seconds_total[1m])) by (instance)
对每个 instance（主机）分开计算总 CPU 使用率
sum(rate(node_cpu_seconds_total[1m])) without (cpu)
会把除了 `cpu` 标签以外的组合都聚合起来
```
# TopN 查询与排序
| 函数名                | 功能         |
| ------------------ | ---------- |
| `topk(n, expr)`    | 取值最大的前 N 项 |
| `bottomk(n, expr)` | 取值最小的前 N 项 |
| `sort(expr)`       | 升序排序       |
| `sort_desc(expr)`  | 降序排序       |
```
topk(3, sum(rate(node_cpu_seconds_total{mode!="idle"}[1m])) by (instance))
CPU 使用率前 3 的主机
```
