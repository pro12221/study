# prometheus的数据模型
`<指标名称>{<标签键1>=<标签值1>, <标签键2>=<标签值2>, ...} @<时间戳> = <数值>`
```
http_requests_total{method="POST", path="/api/users", status="200"} @1678886400000 = 1500
http_requests_total{method="POST", path="/api/users", status="200"} @1678886415000 = 1512
http_requests_total{method="GET", path="/metrics", status="200"} @1678886400000 = 5000
```
