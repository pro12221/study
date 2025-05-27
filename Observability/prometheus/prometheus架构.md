# prometheus架构
![[Pasted image 20250525221637.png]]
Retrieval：拉取指标，存到TSDB
HTTP-server：暴露prometheusUI界面，提供promql-API，接受远程写入
TSDB：存储指标
