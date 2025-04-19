```bash
CA服务器：192.168.44.31
WEB服务器：192.168.44.32
```

# CA配置文件

```bash
vim /etc/pki/tls/openssl.cnf
[ ca ]
56 default_ca      = CA_default            # The default ca section
57 
58 ####################################################################
59 [ CA_default ]
60 
61 dir             = /etc/pki/CA           # Where everything is kept
62 certs           = $dir/certs            # 公钥存放位置
63 crl_dir         = $dir/crl              # 证书吊销列表
64 database        = $dir/index.txt        # 存放信息的数据库
65 #unique_subject = no                    # Set to 'no' to allow creation of
66                                         # several certs with same subject.
67 new_certs_dir   = $dir/newcerts         # default place for new certs.
68 
69 certificate     = $dir/myca.crt         # 公钥的名字
70 serial          = $dir/serial           # 每颁发一次证书，序列号加一
71 crlnumber       = $dir/crlnumber        # 吊销一次，序列号加一
72                                         # must be commented out to leave a V1 CRL
73 crl             = $dir/crl.pem          # The current CRL
74 private_key     = $dir/private/myca.key# 私钥
75 
76 x509_extensions = usr_cert              # The extensions to add to the cert
77 
78 # Comment out the following two lines for the "traditional"
79 # (and highly broken) format.
80 name_opt        = ca_default            # Subject Name options
81 cert_opt        = ca_default            # Certificate field options
82 
83 # Extension copying option: use with caution.
84 # copy_extensions = copy
85 
86 # Extensions to add to a CRL. Note: Netscape communicator chokes on V2 CRLs
87 # so this is commented out by default to leave a V1 CRL.
88 # crlnumber must also be commented out to leave a V1 CRL.
89 # crl_extensions        = crl_ext
90 
91 default_days    = 365                   # 证书有效期
92 default_crl_days= 30                    # how long before next CRL
93 default_md      = sha256                # use SHA-256 by default
94 preserve        = no                    # keep passed DN ordering
95 
96 # A few difference way of specifying how similar the request should look
97 # For type CA, the listed attributes must be the same, and the optional
98 # and supplied fields are just that :-)
99 policy          = policy_match        
146 [ req_distinguished_name ]
147 countryName                     = Country Name (2 letter code)  #国家名字
148 countryName_default             = CN
149 countryName_min                 = 2
150 countryName_max                 = 2
151 
152 stateOrProvinceName             = State or Province Name (full name)
153 stateOrProvinceName_default    = Hubei  #省名字
154 
155 localityName                    = Locality Name (eg, city)
156 localityName_default            = Wuhan   #市名字
157 
158 0.organizationName              = Organization Name (eg, company)
159 0.organizationName_default      = Default Company Ltd       
```

## 创建目录

```bash
[root@ca ~]# mkdir 
[root@ca ~]# cd /etc/pki/CA;mkdir {certs,private,newcerts,crl}
[root@ca CA]# touch index.txt
[root@ca CA]# echo 01 > serial
```

# 创建私钥

```bash
cd /etc/pki/CA
(umask 077;openssl genrsa -out private/myca.key -des3 2048)
输入密码
```

# 生成公钥拷贝到web服务器

```bash
openssl  req -new -x509 -key private/myca.key -days 365 -out myca.crt
scp myca.crt root@web.wsa.com:/root/
```

# web服务器生成私钥和请求文件

```bash
#生成私钥
(umask 077;openssl genrsa -out web.key -des3 2048)
#生成请求文件
openssl req -new -key web.key -out web.csr
#将请求文件拷给ca
scp web.csr root@ca.wsa.com:/root/
```

# CA给web签名

```bash
[root@ca ~]# openssl ca -in /root/web.csr -out /root/web.crt
Using configuration from /etc/pki/tls/openssl.cnf
Enter pass phrase for /etc/pki/CA/private/myca.key:
Check that the request matches the signature
Signature ok
Certificate Details:
        Serial Number: 1 (0x1)
        Validity
            Not Before: Apr 19 10:44:17 2025 GMT
            Not After : Apr 19 10:44:17 2026 GMT
        Subject:
            countryName               = CN
            stateOrProvinceName       = Hubei
            organizationName          = Default Company Ltd
            commonName                = web.wsa.com
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            Netscape Comment: 
                OpenSSL Generated Certificate
            X509v3 Subject Key Identifier: 
                5C:CC:B6:76:26:E4:AF:F9:87:44:A1:E9:5A:8C:38:2E:AA:16:93:0C
            X509v3 Authority Key Identifier: 
                keyid:8A:F0:40:76:DF:80:A3:5A:70:3C:B4:FB:4B:24:86:3E:E0:61:A7:3A

Certificate is to be certified until Apr 19 10:44:17 2026 GMT (365 days)
Sign the certificate? [y/n]:y

1 out of 1 certificate requests certified, commit? [y/n]y
Write out database with 1 new entries
Data Base Updated

#将文件拷贝给web
scp web.crt root@web.wsa.com:/root
```

# web服务器配置ssl加密

```bash
安装软件包
yum install httpd mod_ssl openssl

配置
[root@mysql02 conf.d]# grep -Ev "^#|^$" /etc/httpd/conf.d/ssl.conf 
Listen 443 https
SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog
SSLSessionCache         shmcb:/run/httpd/sslcache(512000)
SSLSessionCacheTimeout  300
SSLCryptoDevice builtin
<VirtualHost _default_:443>             #虚拟主机
DocumentRoot "/var/www/html"            # 网站目录
ServerName web.wsa.com:443              #域名
ErrorLog logs/ssl_error_log            #日志
TransferLog logs/ssl_access_log
LogLevel warn
SSLEngine on                            #开启ssl
SSLHonorCipherOrder on
SSLCipherSuite PROFILE=SYSTEM
SSLProxyCipherSuite PROFILE=SYSTEM
SSLCertificateFile /root/web.crt             #web公钥
SSLCertificateKeyFile /root/web.key          #web私钥
SSLCACertificateFile /root/myca.crt          #ca公钥
<FilesMatch "\.(cgi|shtml|phtml|php)$">
    SSLOptions +StdEnvVars
</FilesMatch>
<Directory "/var/www/cgi-bin">
    SSLOptions +StdEnvVars
</Directory>
BrowserMatch "MSIE [2-5]" \
         nokeepalive ssl-unclean-shutdown \
         downgrade-1.0 force-response-1.0
CustomLog logs/ssl_request_log \
          "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"
</VirtualHost>
```