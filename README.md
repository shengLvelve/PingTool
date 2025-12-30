# PingTool



当前版本号V0.0.2
通过Test-Connection采集各地址的连接情况信息，在控制台输出测试结果，并将测试结果输出至脚本目录下新建的output文件。同时对自然日和每小时数据进行统计，输出结果至Figures文件中。

## PARAMETER



##### \[-domainsInput] <String>



进行测试的地址列表，字符串类型。值可填写IP地址以及域名，使用【,】连接。eg、-domainsInput "192.168.18.1,baidu.com,wechat.com,bilibili.com,google.com"

默认值为"192.168.18.1,192.168.31.1,baidu.com,wechat.com,bilibili.com,google.com"



##### \[-watchTime] <Int32>



监测次数，int类型。eg、-watchTime 65535

默认值为65535



##### \[-sleepTime] <Int32>



每轮测试结束后的休眠时间（单位为秒），int类型。eg、-sleepTime 0

默认值为0



##### \[-delimiter] <String>



控制台输出以及文件输出时的分隔符，字符串类型。eg、-delimiter "|"

默认值为“|”



##### \[-displayMode] <String>



控制台输出模式，可选“log”、“latencyList”，各模式显示效果如下。

默认值为latencyList



###### eg、log模式



date-mm-dd|ti:me:ti.mee|Source|Port|Latency|Connected|Status|Target|TargetAddress
2025-12-14|18:05:10.458|shenglvelve-desktop|80|0|False|ConnectionRefused|127.0.0.1|127.0.0.1



###### eg、latencyList模式



+TIME：2025-12-14|18:05:10.458  TARGET：baidu.com  LAST：12.34ms  Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
+TODAY：Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
+HOUR：Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
+12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
+12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
+12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
+12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
+12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|



## EXAMPLE



`.\\\\PingTool.ps1 -domainsInput "192.168.18.1,baidu.com,wechat.com,bilibili.com,google.com" -watchTime 65535 -sleepTime 0  -delimiter "|" -displayMode "latencyList"`



## History



##### V0.0.2 

&nbsp;2025/12/30

