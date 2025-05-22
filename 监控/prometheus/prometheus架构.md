# prometheus的数据模型
`<指标名称>{<标签键1>=<标签值1>, <标签键2>=<标签值2>, ...} @<时间戳> = <数值>`
```
http_requests_total{method="POST", path="/api/users", status="200"} @1678886400000 = 1500
http_requests_total{method="POST", path="/api/users", status="200"} @1678886415000 = 1512
http_requests_total{method="GET", path="/metrics", status="200"} @1678886400000 = 5000
```
## 指标类型
https://docs.youdianzhishi.com/prometheus/promql/metric-type/
# prometheus配置文件
```yml
global:
  scrape_interval: 5s # 抓取频率

scrape_configs:
  - job_name: 'prometheus'
    static_configs:  #静态配置
      - targets: ['192.168.44.60:9090'] # 这里的单个目标写法是正确的
  - job_name: demo
    scrape_interval: 15s  #覆盖全局的抓取时间
    scrape_timeout: 10s   #抓取请求的超时时间
    static_configs:
      - targets: # 这是一个 targets 组
          - '192.168.44.60:10000' # 直接是字符串
          - '192.168.44.60:10001' # 直接是字符串
          - '192.168.44.60:10002' # 直接是字符串
```
# promQL
## 时间序列
```
http_requests_total{method="POST", path="/api/users", status="200"} @1678886400000 = 1500
时间序列=指标名称+lable
指标名称：http_requests_total
lable：  method="POST"  path="/api/users" status="200"
带有时间戳的样本值： @1678886400000 = 1500
```
## 指标类型 
```
Counter (计数器)：一种累积型的指标，其值只会单调递增或在重置时归零（例如，服务启动时）。例如：HTTP 请求总数 http_requests_total。通常与 rate() 或 increase() 函数一起使用。
Gauge (仪表盘)：一种表示可以任意上下波动的单个数值的指标。例如：当前内存使用量 memory_usage_bytes，队列中的任务数。
Histogram (直方图)：对观察结果（通常是请求持续时间或响应大小）进行采样，并将其计入可配置的存储桶 (bucket) 中。它还提供所有观察值的总和和总数。用于计算分位数（如 95 百分位延迟）。指标名称通常以 _bucket（每个桶的计数）、_sum（所有观察值的总和）、_count（观察事件的总数）为后缀。
Summary (摘要)：与直方图类似，也用于观察事件。它在客户端计算并报告滑动时间窗口内的总数、总和以及配置的分位数。
```
## 标签匹配器
- `=`: 精确匹配标签值。 (例如: `method="GET"`)
- `!=`: 不等于标签值。 (例如: `status!="500"`)
- `=~`: 正则表达式匹配标签值。 (例如: `handler=~"/api/v."`)
- `!~`: 正则表达式不匹配标签值。 (例如: `instance!~"staging-.*"`)
# Relabeling
为了更好的识别监控指标，便于后期调用数据绘图、告警等需求，prometheus支持对发现的目标进行label修改，可以在目标被抓取之前动态重写目标的标签集。每个抓取配置可以配置多个重新标记步骤。它们按照它们在配置文件中出现的顺序应用于每个目标的标签集。
### Prometheus默认标签
```
job标签：设置为job_name相应的抓取配置的值。
instance标签：__address__设置为目标的地址<host>:<port>。重新标记后，如果在重新标记期间未设置标签，则默认将__address__标签值赋值给instance。
__schema__：协议类型
__metrics_path：抓取指标数的url
__scrape_interval__：scrape抓取数据时间间隔（秒）
__scrape_timeout__：scrape超时时间（秒）
```
- **`relabel_configs`**: 作用于**目标 (Target)** 层面，在抓取**前**执行，决定**抓不抓**，以及给抓取到的**所有数据**打上**基础身份标签**。
- **`metric_relabel_configs`**: 作用于**指标 (Metric) 或时间序列**层面，在抓取**后**执行，决定**保留哪些具体数据点**，以及给**每个数据点**打上**更详细的标签**。
##  relabel_configs配置
```
**source_labels：源标签，没有经过relabel处理之前的标签名字**

**target_labels：通过relabel处理之后的标签名字**

**separator：源标签的值的连接分隔符。默认是";"**

**module：取源标签值散列的模数**

**regex：正则表达式，匹配源标签的值。默认是(.*)**

**replacement：通过分组替换后标签（target_label）对应的值。默认是$1**

**action：根据正则表达式匹配执行的动作。默认是replace**

- **replace：替换标签值，根据regex正则匹配到原标签值，使用replacement来引用表达式匹配的分组**
- **keep：满足regex正则条件的实例进行采集，把source_labels中没有匹配到regex正则内容的target实例丢掉，即只采集匹配成功的实例**
- **drop：满足regex正则条件的实例不采集，把source_labels中没有匹配到regex正则内容的target实例丢掉，即只采集没有匹配成功的实例**
- **hashmod： 使用hashmod计算source_labels的hash值并进行对比，基于自定义的模数取模，以实现对目标进行分类、重新赋值等功能**
- **labelmap： 匹配regex所有标签名称，然后复制匹配标签的值进行分组，通过replacement分组引用($1,$2,...)替代**
- **labeldrop： **匹配regex所有标签名称，**对匹配到的实例标签进行删除**
- **labelkeep： 匹配regex所有标签名称，对匹配到的实例标签进行保留**
```
# Exporte
## Node Exporte
使用本机网络
```docker
docker run -d \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter:latest \
  --path.rootfs=/host
```
使用其他端口
```
docker run -d \
  --name node-exporter-8081 \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  -p 0.0.0.0:8081:9100 \
  quay.io/prometheus/node-exporter:latest \
  --path.rootfs=/host
```