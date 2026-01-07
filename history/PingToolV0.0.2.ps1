<#
.SYNOPSIS
    PingTool，测试网络延迟，并将测试数据保存至文件中。

.DESCRIPTION
    通过Test-Connection采集各地址的连接情况信息，在控制台输出测试结果，并将测试结果输出至脚本目录下新建的output文件。同时对自然日和每小时数据进行统计，输出结果至Figures文件中。

.PARAMETER domainsInput
    进行测试的地址列表，字符串类型。值可填写IP地址以及域名，使用【,】连接。eg、-domainsInput "192.168.18.1,baidu.com,wechat.com,bilibili.com,google.com"
    默认值为"192.168.18.1,192.168.31.1,baidu.com,wechat.com,bilibili.com,google.com"

.PARAMETER watchTime
    监测次数，int类型。eg、-watchTime 65535
    默认值为65535

.PARAMETER sleepTime
    每轮测试结束后的休眠时间（单位为秒），int类型。eg、-sleepTime 0
    默认值为0

.PARAMETER delimiter
    控制台输出以及文件输出时的分隔符，字符串类型。eg、-delimiter "|"
    默认值为“|”

.PARAMETER displayMode
    控制台输出模式，可选“log”、“latencyList”，各模式显示效果如下。
    默认值为latencyList
    eg、log模式
        date-mm-dd|ti:me:ti.mee|Source|Port|Latency|Connected|Status|Target|TargetAddress
        2025-12-14|18:05:10.458|shenglvelve-desktop|80|0|False|ConnectionRefused|127.0.0.1|127.0.0.1
    eg、latencyList模式
        TIME：2025-12-14|18:05:10.458  TARGET：baidu.com  LAST：12.34ms  Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
        TODAY：Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
        HOUR：Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|

.EXAMPLE
    .\PingTool.ps1 -domainsInput "192.168.18.1,baidu.com,wechat.com,bilibili.com,google.com" -watchTime 65535 -sleepTime 0  -delimiter "|" -displayMode "latencyList"
    脚本的使用示例。

.NOTES
    PingTool	当前版本号V0.0.2

#>

#接收传参
param(
    #[Parameter(Aliases='Di')]
    <#
    要监测的地址
    127.0.0.1,
    192.168.18.1,
    192.168.31.1,
    baidu.com,
    google.com
    #>
    [string]$domainsInput = "192.168.18.1,192.168.31.1,baidu.com,wechat.com,bilibili.com,google.com" ,

    #预计监测次数
    #[Parameter(Aliases='w')]
    [int]$watchTime = 65535 ,

    #每轮检测间隔（秒）
    #[Parameter(Aliases='s')]
    [int]$sleepTime = 0 ,

    #输出文件分隔符
    #[Parameter(Aliases='de')]
    [string]$delimiter = "|" ,

    #控制台输出方式（log、latencyList...）
    [string]$displayMode = "latencyList"
)

<#
    变量定义
#>
# 状态（TimeOut）颜色
$StatusTimeOutColor = "Red"
# 状态（Success）颜色
$StatusSuccessColor = "Green"
# 低延迟颜色
$LatencyLowColor = "Green"
# 低延迟临界值
$LatencyLow = 100
# 中延迟颜色
$LatencymediumColor = "Yellow"
# 中延迟临界值
$Latencymedium = 300
# 高延迟颜色
$LatencyHighColor = "Red"
# 连接成功颜色
$ConnectedTrueColor = "DarkGreen"
# 连接失败颜色
$ConnectedFalseColor = "Red"
<#
    变量定义（latencyList模式）
#>
#latencyList要显示的数量
$latencyListNum = 50

#定义Get-LatencyColor函数
function Get-LatencyColor {
    param (
        [int]$Latency = 9999 # 参数定义及默认值
    )
    if ($latency -lt $LatencyLow) {
        $LatencyLowColor 
    }
    elseif ($latency -lt $Latencymedium) {
        $LatencymediumColor 
    }
    else {
        $LatencyHighColor
    }
}

#对domainsInput进行预处理，按照“,”拆分为数组
$domains = $domainsInput.Split(",")

<#
    创建文件
    output文件：文件名为output+日期时间，记录每次测试数据
    figures文件：文件名为figures+日期，记录每小时及每天各域名测试情况
#>
#获取文件生成时间
$filetime = Get-Date -UFormat %Y%m%d%H%M%S
#生成output文件存储路径
$filename = "$($PSScriptRoot)\output$filetime"
#生成figures文件存储路径
$Figuresfilename = "$($PSScriptRoot)\Figures$($filetime.Substring(0,8))"
#创建output文件
New-Item -Path "$filename" -ItemType File
#创建figures文件（若同文件名文件已存在，不重复新建文件）
if (Test-Path -Path $Figuresfilename) {}
else {
    New-Item -Path "$Figuresfilename" -ItemType File
}

<#
    初始化哈希数组
    用于每轮测试结束后将测试数据导入数组
#>
$latencyData = New-Object -TypeName 'System.Object[]' -ArgumentList $domains.Count
for ($i = 0; $i -lt $domains.Count; $i++) {
    $latencyData[$i] = @{
        <#
        记录单一目标地址测试数据
        #>
        #最后一次测试时间
        time                      = $(Get-Date).ToString("yyyy-MM-dd" + $delimiter + "HH:mm:ss.fff")
        #目标地址
        target                    = "$($domains[$i])"
        #last：最后一次连接延迟数值（latency）
        last                      = 0
        #测试全程最大值
        max                       = 0
        #当前整点小时最大值
        hourMax                   = 0
        #当前自然日最大值
        todayMax                  = 0
        #测试全程最小值
        min                       = 9999
        #当前整点小时最小值
        hourMin                   = 9999
        #当前自然日最小值
        todayMin                  = 9999
        #sum：latency（last）之和，用来计算avg
        sum                       = 0
        #当前整点小时latency（last）之和
        hourSum                   = 0
        #当前自然日latency（last）之和
        TodaySum                  = 0
        #测试全程执行次数
        total                     = 0
        #当前整点小时执行次数
        hourTotal                 = 0
        #当前自然日执行次数
        todayTotal                = 0
        #测试全程连接失败计数
        connectionFalseCount      = 0
        #当前整点小时连接失败计数
        hourConnectionFalseCount  = 0
        #当前自然日连接失败计数
        todayConnectionFalseCount = 0
        #latency队列，将每次测试latency数值存入，当超过$latencyListNum时移除最后一个元素
        latencyList               = [System.Collections.Generic.Queue[string]]::new()
        #本机名称（source）
        source                    = ""
        #测试连接的端口号（port）
        port                      = 0
        #连接状态（connected）
        connected                 = ""
        #状态（status）
        status                    = ""
        #目标ip地址（targetAddress）
        targetAddress             = ""
    }
}

<#
    当显示模式为log模式时，输出表头
    date-mm-dd|ti:me:ti.mee|domain|Source|Port|Latency|Connected|Status|Target|TargetAddress
#>
if ($displayMode -eq "log") {
    $title = "date-mm-dd", "ti:me:ti.mee", "domain", "Source", "Port", "Latency", "Connected", "Status", "Target", "TargetAddress" -join $delimiter
    Write-Output "$($title)"
}
        
#次数循环
for ($j = 1; $j -le $watchTime; $j++) {

    <#
        ■■■■■■■■■■■■■■■■■■■■■■■■
        ■■■■■■■■获取数据■■■■■■■■
        ■■■■■■■■■■■■■■■■■■■■■■■■
    #>

    #新的一天，新的开始，新的log
    #当文件生成日期与当前日期不一致时，创建新的output文件
    if ($filetime.Substring(0, 8) -ne $(Get-Date -UFormat %Y%m%d)) {
        $filetime = Get-Date -UFormat %Y%m%d%H%M%S
        $filename = "$($PSScriptRoot)\output$filetime"
        New-Item -Path "$filename" -ItemType File	
    }
    
    <#
        使用多线程
        $results = $sourceData | ForEach-Object -Parallel {}
        多线程调用时使用$using:variableName
    #>
    $tempData = $domains | ForEach-Object -Parallel {
        #临时存储用哈希表数组初始化
        $Data = @{
            #本次连接时间（生成）
            time          = ""
            #本次连接地址（域名）（target）
            target        = ""
            #本次连接延迟（latency）
            last          = 0    

            source        = ""

            port          = 0

            connected     = ""

            status        = ""
            #本次连接地址（IP）（target）
            targetAddress = ""
        }

        #获取当前时间
        $today = $(Get-Date)
        $time = $today.ToString("yyyy-MM-dd" + $using:delimiter + "HH:mm:ss.fff")
        $Data["time"] = $time

        #ping当前域名获取数据
        $testData = Test-Connection $_ -Count 1 -TcpPort 80  -Detailed

        <#
            数据项：$time,$domain,$Source,$Target,$TargetAddress,$Port,$Latency,$Connected,$Status
        #>
        #eg.Source=shenglvelve-desktop
        $Data["source"] = "$($testData.Source)"

        #eg.Port=80; 
        $Data["port"] = "$($testData.Port)"

        #eg.Latency=0; （last）
        $Latency = [Int]"$($testData.Latency)"
        #若连接不成功，将latency赋值9999
        if ("$($testData.Status)" -ne "success") {
            $Latency = 9999
        }
        $Data["last"] = $Latency

        #eg.Connected=False; 
        $Data["connected"] = "$($testData.Connected)"
        
        #eg.Status=TimedOut
        $Data["status"] = "$($testData.Status)"

        #eg.Target=google.com;
        $Data["target"] = "$($testData.Target)"

        #eg.TargetAddress=2404:6800:4012:9::200e; 
        $Data["targetAddress"] = "$($testData.TargetAddress)"

        return $Data
    }-ThrottleLimit $domains.Count
    # ↑ 限制使用线程数为domains数组元素数量

    <#
        ■■■■■■■■■■■■■■■■■■■■■■■■
        ■■■■■■■■预处理部分■■■■■■■
        ■■■■■■■■■■■■■■■■■■■■■■■■
    #>

    #遍历latencyData数组
    for ($preprocessingId = 0; $preprocessingId -lt $latencyData.Count; $preprocessingId++) {
        
        $tempData | ForEach-Object {
            
            #使latencyData数组数据与tempData数组数据相对应
            if ($_["target"] -eq $latencyData[$preprocessingId]["target"]) {
                
                <#
                    输出数据到output文件
                    2025-12-28|00:00:01.160|google.com|shenglvelve-desktop|google.com|142.251.45.142|80|9999|False|TimedOut
                #>
                #组装输出文档每行内容
                $line = $_["time"], $_["target"], $_["Source"], $_["Target"], $_["TargetAddress"], $_["Port"], $_["last"], $_["Connected"], $_["Status"] -join $delimiter
                #输出line到文件末尾
                Out-File -Encoding utf8 -filePath $filename -InputObject $line -append
                
                <#
                    每日导出日统计数据至Figures文件，并重置latencyData中相关数据
                    需要重置的变量：todayMax、todayMin、TodaySum、todayTotal、todayConnectionFalseCount
                    [DATE]|[192.168.18.1]|DATE: 2025-12-28|AVG:1.95ms|MAX:20ms|MIN:1ms|LOSS:0%
                #>
                #tempData中日期与latencyData中日期部分作比较，若不同则输出当前日期数据，并重置相关变量
                if ($_["time"].Substring(0, 10) -ne $latencyData[$preprocessingId]["time"].Substring(0, 10)) {
                    #输出当日数据
                    $line = "[DATE]" + $delimiter + "[" + $_["target"] + "]" + $delimiter + "DATE: " + $_["time"].Substring(0, 10) + $delimiter + "AVG:" + $([Math]::Round($($($latencyData[$preprocessingId]["TodaySum"]) / $($latencyData[$preprocessingId]["todayTotal"])), 2)) + "ms" + $delimiter + "MAX:" + $($latencyData[$preprocessingId]["todayMax"]) + "ms" + $delimiter + "MIN:" + $($latencyData[$preprocessingId]["todayMin"]) + "ms" + $delimiter + "LOSS:" + $([Math]::Round($($($latencyData[$preprocessingId]["todayConnectionFalseCount"]) / $($latencyData[$preprocessingId]["todayTotal"]) * 100), 2)) + "%"
                    Out-File -Encoding utf8 -filePath $Figuresfilename -InputObject $line -append

                    #重置相关变量
                    $latencyData[$preprocessingId]["todayMax"] = 0
                    $latencyData[$preprocessingId]["todayMin"] = 9999
                    $latencyData[$preprocessingId]["TodaySum"] = 0
                    $latencyData[$preprocessingId]["todayTotal"] = 0
                    $latencyData[$preprocessingId]["todayConnectionFalseCount"] = 0
                }
                
                <#
                    每小时导出数据至Figures文件，并重置latencyData中相关数据
                    需要重置的变量：hourMax、hourMin、hourSum、hourTotal、hourConnectionFalseCount
                    [HOUR]|[google.com]|TIME: 00:00 |AVG:9999ms|MAX:9999ms|MIN:9999ms|LOSS:100%
                #>
                #tempData中小时与latencyData中小时部分作比较，若不同则输出当前小时数据，并重置相关变量
                if ($_["time"].Substring(11, 2) -ne $latencyData[$preprocessingId]["time"].Substring(11, 2)) {
                    #输出当前小时数据
                    $line = "[HOUR]" + $delimiter + "[" + $_["target"] + "]" + $delimiter + "TIME: " + $_["time"].Substring(11, 2) + ":00 " + $delimiter + "AVG:" + $([Math]::Round($($($latencyData[$preprocessingId]["hourSum"]) / $($latencyData[$preprocessingId]["hourTotal"])), 2)) + "ms" + $delimiter + "MAX:" + $($latencyData[$preprocessingId]["hourMax"]) + "ms" + $delimiter + "MIN:" + $($latencyData[$preprocessingId]["hourMin"]) + "ms" + $delimiter + "LOSS:" + $([Math]::Round($($($latencyData[$preprocessingId]["hourConnectionFalseCount"]) / $($latencyData[$preprocessingId]["hourTotal"]) * 100), 2)) + "%"
                    Out-File -Encoding utf8 -filePath $Figuresfilename -InputObject $line -append
                    #重置相关变量
                    $latencyData[$preprocessingId]["hourMax"] = 0
                    $latencyData[$preprocessingId]["hourMin"] = 9999
                    $latencyData[$preprocessingId]["hourSum"] = 0
                    $latencyData[$preprocessingId]["hourTotal"] = 0
                    $latencyData[$preprocessingId]["hourConnectionFalseCount"] = 0
                }

                $latencyData[$preprocessingId]["time"] = $_["time"]
                $latencyData[$preprocessingId]["last"] = $_["last"]
                #max处理
                if ($latencyData[$preprocessingId]["todayMax"] -lt $_["last"]) {
                    $latencyData[$preprocessingId]["todayMax"] = $_["last"]
                }
                if ($latencyData[$preprocessingId]["hourMax"] -lt $_["last"]) {
                    $latencyData[$preprocessingId]["hourMax"] = $_["last"]
                }
                if ($latencyData[$preprocessingId]["max"] -lt $_["last"]) {
                    $latencyData[$preprocessingId]["max"] = $_["last"]
                }
                #min处理
                if ($latencyData[$preprocessingId]["min"] -gt $_["last"]) {
                    $latencyData[$preprocessingId]["min"] = $_["last"]
                }
                if ($latencyData[$preprocessingId]["todayMin"] -gt $_["last"]) {
                    $latencyData[$preprocessingId]["todayMin"] = $_["last"]
                }
                if ($latencyData[$preprocessingId]["hourMin"] -gt $_["last"]) {
                    $latencyData[$preprocessingId]["hourMin"] = $_["last"]
                }
                #sum处理
                $latencyData[$preprocessingId]["sum"] += $_["last"]
                $latencyData[$preprocessingId]["hourSum"] += $_["last"]
                $latencyData[$preprocessingId]["TodaySum"] += $_["last"]
                #total处理
                $latencyData[$preprocessingId]["total"]++
                $latencyData[$preprocessingId]["hourTotal"]++
                $latencyData[$preprocessingId]["todayTotal"]++
                #connectionFalseCount处理
                if ($_["connected"] -ne "True") {
                    $latencyData[$preprocessingId]["connectionFalseCount"]++
                    $latencyData[$preprocessingId]["hourConnectionFalseCount"]++
                    $latencyData[$preprocessingId]["todayConnectionFalseCount"]++
                }
                $latencyData[$preprocessingId]["source"] = $_["source"]
                $latencyData[$preprocessingId]["port"] = $_["port"]
                $latencyData[$preprocessingId]["connected"] = $_["connected"]
                $latencyData[$preprocessingId]["status"] = $_["status"]
                $latencyData[$preprocessingId]["targetAddress"] = $_["targetAddress"]
                #latencyList处理
                $latencyData[$preprocessingId]["latencyList"].Enqueue($_["last"])
                #当latencyList中元素数量超过latencyListNum，移除最早的元素
                while ($latencyData[$preprocessingId]["latencyList"].Count -gt $latencyListNum) {
                    $latencyData[$preprocessingId]["latencyList"].Dequeue()
                }
            
            }
        }
    }
    #新的一天，新建新的figures文件(每日24时数据导出后创建新的figures文件)
    if ($Figuresfilename.Substring($Figuresfilename.Length - 8) -ne $(Get-Date -UFormat %Y%m%d)) {
        $Figuresfilename = "$($PSScriptRoot)\Figures$($filetime.Substring(0,8))"
        New-Item -Path "$Figuresfilename" -ItemType File
    }

    <#
        ■■■■■■■■■■■■■■■■■■■■■■■■
        ■■■■■■■■输出部分■■■■■■■■
        ■■■■■■■■■■■■■■■■■■■■■■■■
    #>
    #log模式显示输出
    if ($displayMode -eq "log") {
        <#
            Log方式显示
            date-mm-dd|ti:me:ti.mee|Source|Port|Latency|Connected|Status|Target|TargetAddress
            2025-12-14|18:05:10.458|shenglvelve-desktop|80|0|False|ConnectionRefused|127.0.0.1|127.0.0.1
        #>
        
        for ($index = 0; $index -lt $latencyData.Count; $index++) {
            Write-Host $latencyData[$index]["time"] -NoNewline -Separator $delimiter 
            Write-Host $delimiter -NoNewline
            #eg.Source=shenglvelve-desktop
            Write-Host $latencyData[$index]["source"] -NoNewline -Separator $delimiter 
            Write-Host $delimiter -NoNewline
            #eg.Port=80; 
            Write-Host $latencyData[$index]["port"] -NoNewline -Separator $delimiter 
            Write-Host $delimiter -NoNewline
            #eg.Latency=0; 
            # 根据Latency数值显示颜色
            $LatencyColor = Get-LatencyColor -Latency $([int]$latencyData[$index]["last"])
            Write-Host $latencyData[$index]["last"] -NoNewline  -ForegroundColor  $LatencyColor
            Write-Host $delimiter -NoNewline

            #eg.Connected=False; 
            if ($latencyData[$index]["connected"] -like "True" ) {
                Write-Host $latencyData[$index]["connected"] -NoNewline -Separator $delimiter -ForegroundColor $ConnectedTrueColor
            }
            else {
                Write-Host $latencyData[$index]["connected"] -NoNewline -Separator $delimiter -ForegroundColor $ConnectedFalseColor
            }
            Write-Host $delimiter -NoNewline
            #eg.Status=TimedOut
            # 根据Status状态显示颜色
            if ($latencyData[$index]["status"] -like "TimedOut" ) {
                Write-Host $latencyData[$index]["status"]  -Separator $delimiter -ForegroundColor $StatusTimeOutColor -NoNewline
                Write-Host $delimiter -NoNewline
            }
            elseif ($latencyData[$index]["status"] -like "success") {
                Write-Host $latencyData[$index]["status"]  -Separator $delimiter -ForegroundColor $StatusSuccessColor -NoNewline
                Write-Host $delimiter -NoNewline
            }
            else {
                Write-Host $latencyData[$index]["status"]  -Separator $delimiter -NoNewline
                Write-Host $delimiter -NoNewline
            }
            #eg.Target=google.com;
            Write-Host $latencyData[$index]["target"] -NoNewline -Separator $delimiter 
            Write-Host $delimiter -NoNewline
            #eg.TargetAddress=2404:6800:4012:9::200e; 
            Write-Host $latencyData[$index]["targetAddress"] -Separator $delimiter 
        }
    }

    <#
        latencyList显示
        TIME：2025-12-14|18:05:10.458  TARGET：baidu.com  LAST：12.34ms  Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
        TODAY：Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
        HOUR：Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
        12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|12.34ms|
    #>
    if ($displayMode -eq "latencyList") { 
        Clear-Host
        
        #每个域名循环一次
        for ($i = 0; $i -lt $domains.Count; $i++) {
            #确定last字色
            $LatencyColor = Get-LatencyColor -Latency $([int]$latencyData[$i]["last"])
            <#
                输出合计统计数据
            #>
            Write-Host $($latencyData[$i]["time"]) -NoNewline
            Write-Host " `t" -NoNewline
            Write-Host "TARGET："$($latencyData[$i]["target"]) -NoNewline
            Write-Host " `t" -NoNewline
            Write-Host $("LAST：" + $($latencyData[$i]["last"]) + "ms").PadRight(14) -NoNewline -ForegroundColor $LatencyColor
            Write-Host $("AVG：" + $([Math]::Round($($($latencyData[$i]["sum"]) / $($latencyData[$i]["total"])), 2)) + "ms").PadRight(14) -NoNewline
            Write-Host $("MAX：" + $($latencyData[$i]["max"]) + "ms").PadRight(14) -NoNewline
            Write-Host $("MIN：" + $($latencyData[$i]["min"]) + "ms").PadRight(14) -NoNewline
            Write-Host "LOSS："$([Math]::Round($($($latencyData[$i]["connectionFalseCount"]) / $($latencyData[$i]["total"]) * 100), 2))"%" 
            
            <#
                输出当日统计数据
                TODAY：Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
            #>
            Write-Host "TODAY：".PadRight(8) -NoNewline
            Write-Host $("AVG：" + $([Math]::Round($($($latencyData[$i]["TodaySum"]) / $($latencyData[$i]["todayTotal"])), 2)) + "ms").PadRight(14) -NoNewline
            Write-Host $("MAX：" + $($latencyData[$i]["todayMax"]) + "ms").PadRight(14) -NoNewline
            Write-Host $("MIN：" + $($latencyData[$i]["todayMin"]) + "ms").PadRight(14) -NoNewline
            Write-Host "LOSS："$([Math]::Round($($($latencyData[$i]["todayConnectionFalseCount"]) / $($latencyData[$i]["todayTotal"]) * 100), 2))"%" 

            <#
                输出当前小时统计数据
                HOUR：Avg：12.34ms  MAX：12.34ms  MIN：12.45ms  LOSS：12.34%
            #>
            Write-Host "HOUR：".PadRight(8) -NoNewline
            Write-Host $("AVG：" + $([Math]::Round($($($latencyData[$i]["hourSum"]) / $($latencyData[$i]["hourTotal"])), 2)) + "ms").PadRight(14) -NoNewline
            Write-Host $("MAX：" + $($latencyData[$i]["hourMax"]) + "ms").PadRight(14) -NoNewline
            Write-Host $("MIN：" + $($latencyData[$i]["hourMin"]) + "ms").PadRight(14) -NoNewline
            Write-Host "LOSS："$([Math]::Round($($($latencyData[$i]["hourConnectionFalseCount"]) / $($latencyData[$i]["hourTotal"]) * 100), 2))"%" 
            Write-Host
            
            #循环输出latencyList中数值（queue）
            for ($listIndex = 0; $listIndex -lt $($latencyData[$i]["latencyList"]).Count ; $listIndex++) {
                #出队最早的元素，并重新入队
                $item = $($latencyData[$i]["latencyList"].Dequeue())
                $latencyData[$i]["latencyList"].Enqueue($item)
                $LatencyColor = Get-LatencyColor -Latency $item
                Write-Host $("   " + $item + "ms").PadRight(10) -NoNewline -ForegroundColor $LatencyColor
                Write-Host "|" -NoNewline
                if ($listIndex % 10 -eq 9) {
                    #每行显示10个
                    Write-Host
                }
            }
            Write-Host
            Write-Host
        } 
        
        #输出当前进度
        $time = Get-Date -Format "HH:mm:ss.fff"
        Write-Host "`r时间:" $time"  当前第"$j"轮,共"$watchTime"轮" -NoNewline
        
    }     

    #休眠
    Start-Sleep $sleepTime

}




