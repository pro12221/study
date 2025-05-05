```nginx
server {

        listen 80;

        server_name  kevin.com;

        access_log  /data/nginx/logs/kevin.com-access.log main;

        error_log  /data/nginx/logs/kevin.com-error.log;

        #动态访问请求转给tomcat应用处理`

        location ~ .(jsp|page|do)?$ {`      #以这些文件结尾的

           proxy_set_header  Host $host;

           proxy_set_header  X-Real-IP  $remote_addr;

           proxy_pass http:``//tomcat``地址;

        }

        #设定访问静态文件直接读取不经过tomcat`

        location ~ .*.(htm|html|gif|jpg|jpeg|png|bmp|swf|ioc|rar|zip|txt|flv|mid|doc|ppt|pdf|xls|mp3|wma)$  {     #以这些文件结尾的`

           expires      30d;

           root /data/web/html ;

        }
}
```
