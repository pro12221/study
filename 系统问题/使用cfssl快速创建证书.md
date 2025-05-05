项目地址：https://github.com/cloudflare/cfssl
## 安装
```shell
wget https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssl_1.6.5_linux_amd64
wget https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssl-certinfo_1.6.5_linux_amd64
wget https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssljson_1.6.5_linux_amd64
mv cfssl_1.6.5_linux_amd64 /usr/local/bin/cfssl
mv cfssljson_1.6.5_linux_amd64 /usr/local/bin/cfssljson
mv cfssl-certinfo_1.6.5_linux_amd64 /usr/local/bin/cfssl-certinfo
chmod +x /usr/local/bin/cfssl
chmod +x /usr/local/bin/cfssljson
chmod +x /usr/local/bin/cfssl-certinfo
```
## 创建证书
### **CA配置文件**
```json
vim ca-csr.json
{
    "signing": {
        "default": {
            "expiry": "175200h"
        },
        "profiles": {
            "etcd": {
                "expiry": "175200h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            },
            "nginx": {
                "expiry": "175200h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
```
- ca-config.json：可以定义多个Profiles，分别指定不同的过期时间、使用场景等参数；后续在签名证书的时候使用某个Profile。
- signing：表示该证书可用于签名其他证书；生成的ca.pem证书中CA=TRUE
- server auth：表示client可以使用该ca对server提供的证书进行验证
- client auth：表示server可以用该ca对client提供的证书进行验证
### ​**​CA证书签名请求**
向证书颁发机构（CA）申请证书时提交的请求文件，包含CA的基本信息（如国家、组织、域名等）和公钥
```json
vim ca-config.json
{
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Wuhan",
            "ST": "Hubei",
          "O": "k8s",
          "OU": "System"
        }
    ]
}
```
### 生成ca证书
```shell
cfssl gencert --initca ca-csr.json | cfssljson --bare ca
```
- ca-key.pem : CA的私有key
- ca.pem : CA证书
- ca.csr : CA的证书请求文件
### 生成服务端证书
```json
vim nginx-csr.json
{
  "CN": "nginx",
  "hosts": [
    "localhost",
    "0.0.0.0",
    "127.0.0.1",
  ],
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "C": "CN",
      "L": "Wuhan",
      "O": "sdf",
      "OU": "System",
      "ST": "Hubei"
    }
  ]
}

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=nginx  nginx-csr.json | cfssljson -bare nginx
```
生成三个文件：nginx.pem, nginx-key.pem, nginx.csr

### 生成nginx客户端证书(nginx配置https的话不需要这一步)
```json
vim nginx-client-csr.json
{
  "CN": "nginx-client",
  "hosts": [
    ""
  ],
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "C": "CN",
      "L": "Wuhan",
      "ST": "Hubei",
      "O": "sdfdf",
      "OU": "System"
    }
  ]
}

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=nginx nginx-client-csr.json | cfssljson -bare nginx-client
```