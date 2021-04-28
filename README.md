 秉持精简思想，直指用户需求本质，让用户在半小时内能获得自己想要的效果

 - 通过1个压缩包搭建数蛙工业物联网Saas平台开发环境
 - 通过1个脚本搭建linux下数蛙物联互联网Saas平台运行环境
 - 通过2个安装包搭建windows下数蛙物联互联网Saas平台运行环境

 
# 开发环境压缩包
   [ 数蛙物联网Saas平台开发套件](http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot/deploy/dgiot_develop_tools.zip)，点击下载，开箱即用，快速代入，商用实战
  - windows下的linux开发调测环境
  - git持续集成环境
  - erlang通道插件开发与调测环境
  - python扩展编程开发与调测环境
  - java扩展编程开发与调测环境
  - nodjs+vue+yarn前端交互开发与调测环境

 **请解压到D盘**  目录结构为D:\msys64
 ## window开发环境
 [dgiot_server.zip](http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/windows/dgiot_server_v4.0.0.tar.gz)
 
 ```
 wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/windows/dgiot_server_v4.0.0.tar.gz
 tar xvf dgiot_server.zip
 cd dgiot_server
 make
 _build/dgiot/rel/emqx/bin/emqx.cmd console
 ```
 ## centos 7.6 开发环境
  [dgiot_server.zip](http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/linux/dgiot_server_v4.0.0.tar.gz)
 
 ```
 wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot4.0/linux/dgiot_server_v4.0.0.tar.gz
 tar xvf dgiot_server.zip
 cd dgiot_server
 make
 _build/dgiot/rel/emqx/bin/emqx.cmd console
 ```
 
 ## github下载工程
 后台开发代码工程：
 
 ```
 git clone https://hub.fastgit.org/dgiot/dgiot_server.git
 cd dgiot_server
 make
 _build/dgiot/rel/emqx/bin/emqx.cmd console
 ```
 
 前端源码：
 ```
 git clone https://hub.fastgit.org/dgiot/dgiot_dashboard.git
 cd dgiot_dashboard
 yarn install
 yarn dev
 yarn build
 ```
  
# linux环境一键式部署脚本
部署在工业物联网解决方案的云服务商公网节点，支持设备租赁、设备托管等物联网需求
| 名称 | 下载地址 | 说明   |
| ------------ | ------------ | ------------ |
|  数蛙云平台单机脚本 |  dgiot_cloud_single.zip |  包含数据、存储、接入与计算套件 |
|  数蛙云平台集群脚本 |  dgiot_cloud_cluster |  包含数据、存储、接入与计算套件|

## centos 7.6 
 数蛙云平台单机脚本部署
 dgiot_cloud_single.sh
 + 替换公网ip(wlanip),如公网ip为123.45.67.89,则替换命令为
 ```
sed -i "s/{{wlanip}}/123.45.67.89/g" ./dgiot_cloud_single.sh
 ```
 + 替换最新版本{{dgiot}},如果最新版本为shuwa_iot，则替换命令为
 
 ```
 sed -i "s/{{dgiot}}/shuwa_iot/g" ./dgiot_cloud_single.sh
  ```

环境下完整的操作命令为：
```shell script
 sudo yum install -y git
 git clone https://hub.fastgit.org/dgiot/dgiot_deploy.git
 cd dgiot_deploy
 sed -i "s/{{wlanip}}/123.45.67.89/g" ./dgiot_cloud_single.sh
 sed -i "s/{{dgiot}}/shuwa_iot/g" ./dgiot_cloud_single.sh
 sudo sh ./dgiot_cloud_single.sh
 ps aux|grep emqx
 ```
安装好之后，可以打开 http://123.45.67.89:5080 用户名:dgiot_admin  密码：dgiot_admin  登陆物联网系统

更新版本
备份 /data/shuwa_iot
下载最新版本压缩包到 /data 下 
命令如下：
``` 
cd /data
wget http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot_release/shuwa_iot_dgiot_20.tar.gz
tar -zxvf shuwa_iot_dgiot_20.tar.gz
systemctl restart dgiot
```

# windows环境安装包
部署工业物联网解决方案的企业内网安全私密的window电脑节点、零投入实现企业内部安全的设备接入与数字化转型需求
 | 名称 | 下载地址 | 说明   |
| ------------ | ------------ | ------------ |
|  数蛙边缘数据安装包 |  [dgiot_data_center.exe](http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot/deploy/dgiot_data_center.exe) |  包含数据和存储套件 |
|  数蛙边缘计算安装包 |  [dgiot_edge_hub.exe](http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/dgiot/deploy/dgiot_edge_hub.exe) |  包含接入和计算套件 |

