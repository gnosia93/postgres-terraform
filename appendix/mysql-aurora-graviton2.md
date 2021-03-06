## Performance of Amazon Aurora MySQL ##

### 데이터베이스 생성 ###

이번 챕터에서는 graviton2(r6g.) 와 x64(r5.) 를 대상으로 그 사이즈가 2x ~ 16x 사이에 있는 인스턴스를 대상으로 성능테스트를 수행합니다. 
성능 테스트시 적용되는 Aurora MySQL 데이터베이스의 파리미터 값은 다음과 같습니다. 쓰레드 구조로 동작하는 MySQL 의 경우 운영환경에서 통상 physical memory 의 최대 75% 까지 innodb_buffer_pool 을 설정하나, 이번 테스트에서는 40GB 만 설정합니다. 
```
[mysql.conf]
  innodb_buffer_pool_size = 42949672960      -- byte 단위로 설정 (40GB)
  query_cache_type = 0                       -- query cache disable
  max_connections = 2000
```
* https://aws.amazon.com/ko/premiumsupport/knowledge-center/low-freeable-memory-rds-mysql-mariadb/
* https://aws.amazon.com/ko/blogs/database/best-practices-for-amazon-aurora-mysql-database-configuration/
* https://www.chriscalender.com/temporary-files-binlog_cache_size-and-row-based-binary-logging/

데이터베이스를 생성하기 위해 아래의 스크립트를 순차적으로 실행합니다. (2xlarge ~ 16xlarge 까지 테스트할 예정이므로, 인스턴스 사이즈에 맞게 아래 스크립트를 변경한 후 실행합니다.)

```
$ aws rds describe-db-engine-versions --default-only --engine aurora-mysql
5.7.mysql_aurora.2.09.2

$ aws rds describe-db-engine-versions --query "DBEngineVersions[].DBParameterGroupFamily"
aurora-mysql5.7

$ aws rds create-db-parameter-group \
     --db-parameter-group-name pg-aurora-mysql \
     --db-parameter-group-family aurora-mysql5.7 \
     --description "My Aurora MySQL new parameter group"

$ aws rds modify-db-parameter-group \
    --db-parameter-group-name pg-aurora-mysql \
    --parameters "ParameterName='innodb_buffer_pool_size',ParameterValue=42949672960,ApplyMethod=pending-reboot" \
                 "ParameterName='max_connections',ParameterValue=2000,ApplyMethod=pending-reboot"  \
                 "ParameterName='query_cache_type',ParameterValue=0,ApplyMethod=pending-reboot"  

$ aws ec2 create-security-group --group-name sg_aurora_mysql --description "aurora mysql security group"
{
    "GroupId": "sg-0518761208b6e516f"
}

$ aws ec2 authorize-security-group-ingress --group-name sg_aurora_mysql --protocol tcp --port 3306 --cidr 0.0.0.0/0

$ sleep 10       #   (10초 대기)                    
                                        
$ aws rds create-db-cluster \
    --db-cluster-identifier aurora-mysql-graviton2-12x \
    --engine aurora-mysql \
    --engine-version 5.7.mysql_aurora.2.09.2 \
    --master-username myadmin \
    --master-user-password myadmin1234 \
    --vpc-security-group-ids sg-0518761208b6e516f          

$ aws rds create-db-instance \
    --db-cluster-identifier aurora-mysql-graviton2-12x \
    --db-instance-identifier aurora-mysql-graviton2-12x-1 \
    --db-instance-class db.r6g.12xlarge \
    --engine aurora-mysql \
    --db-parameter-group-name pg-aurora-mysql \
    --availability-zone=ap-northeast-2b
    
    
$ aws rds create-db-cluster \
    --db-cluster-identifier aurora-mysql-x64-12x \
    --engine aurora-mysql \
    --engine-version 5.7.mysql_aurora.2.09.2 \
    --master-username myadmin \
    --master-user-password myadmin1234 \
    --vpc-security-group-ids sg-0518761208b6e516f
    
$ aws rds create-db-instance \
    --db-cluster-identifier aurora-mysql-x64-12x \
    --db-instance-identifier aurora-mysql-x64-12x-1 \
    --db-instance-class db.r5.12xlarge \
    --engine aurora-mysql \
    --db-parameter-group-name pg-aurora-mysql \
    --availability-zone=ap-northeast-2b
```

(참고) 데이터베이스 생성시 aws rds create-db-instance의 옵션으로 --availability-zone 를 사용하면(예시, --availability-zone=ap-northeast-2b) 데이터베이스가 생성되는 AZ를 선택할 수 있다. 


### Aurora 엔드포인트 확인하기 ###

```
$ aws rds describe-db-instances --db-instance-identifier aurora-mysql-graviton2-16x-1 --query DBInstances[].Endpoint.Address
[
    "aurora-mysql-graviton2-16x-1.cwhptybasok6.ap-northeast-2.rds.amazonaws.com"
]

$ aws rds describe-db-instances --db-instance-identifier aurora-mysql-x64-16x-1 --query DBInstances[].Endpoint.Address
[
    "aurora-mysql-x64-16x-1.cwhptybasok6.ap-northeast-2.rds.amazonaws.com"
]
```


### 성능 테스트 준비하기 ###

https://github.com/gnosia93/postgres-terraform/blob/main/appendix/postgres-ec2-graviton2.md 에서 생성한 cl_stress_gen 으로 로그인 한 후, 아래의 명령어를 차례로 수행한다. 

mysql 클라이언로 aurora-mysql-graviton2-8x-1, aurora-mysql-x64-8x-1 에 각각 접속하여 테스트 유저와 데이터베이스 및 권한을 만든다. 

```
ubuntu@ip-172-31-45-65:~$ sudo apt-get install mysql-client

ubuntu@ip-172-31-45-65:~$ mysql -V
mysql  Ver 8.0.23-0ubuntu0.20.04.1 for Linux on x86_64 ((Ubuntu))

ubuntu@ip-172-31-45-65:~$ mysql -h aurora-mysql-graviton2-16x-1.cwhptybasok6.ap-northeast-2.rds.amazonaws.com -u myadmin -pmyadmin1234
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 12
Server version: 5.7.12 MySQL Community Server (GPL)

Copyright (c) 2000, 2021, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> select version();
+-----------+
| version() |
+-----------+
| 5.7.12    |
+-----------+
1 row in set (0.01 sec)

mysql> show variables like 'innodb_buffer%';
+-------------------------------------+----------------+
| Variable_name                       | Value          |
+-------------------------------------+----------------+
| innodb_buffer_pool_chunk_size       | 1342177280     |
| innodb_buffer_pool_dump_at_shutdown | OFF            |
| innodb_buffer_pool_dump_now         | OFF            |
| innodb_buffer_pool_dump_pct         | 25             |
| innodb_buffer_pool_filename         | ib_buffer_pool |
| innodb_buffer_pool_instances        | 32             |
| innodb_buffer_pool_load_abort       | OFF            |
| innodb_buffer_pool_load_at_startup  | OFF            |
| innodb_buffer_pool_load_now         | OFF            |
| innodb_buffer_pool_size             | 42949672960    |
+-------------------------------------+----------------+

mysql> CREATE USER sbtest@'%' identified by 'sbtest';
Query OK, 0 rows affected (0.01 sec)

mysql> CREATE DATABASE sbtest;
Query OK, 1 row affected (0.01 sec)

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sbtest             |
| sys                |
+--------------------+
5 rows in set (0.00 sec)

mysql> GRANT ALL PRIVILEGES ON sbtest.* TO sbtest@'%';
Query OK, 0 rows affected (0.01 sec)

mysql> flush privileges;  

mysql> quit
Bye
```

성능 테스트 아래의 내용으로 perf.sh 파일을 만들고, 대상 데이터베이스의 주소를 변경한 다음 실행합니다. 
```
#! /bin/sh
TARGET_DB=aurora-mysql-graviton2-8x-1.cwhptybasok6.ap-northeast-2.rds.amazonaws.com
TEST_TIME=60
TABLE_SIZE=5000000
REPORT_INTERVAL=10

# prepare
sysbench --db-driver=mysql \
--table-size=$TABLE_SIZE --tables=32 \
--threads=32 \
--mysql-host=$TARGET_DB --mysql-port=3306 \
--mysql-user=sbtest \
--mysql-password=sbtest \
--mysql-db=sbtest \
/usr/share/sysbench/oltp_read_write.lua prepare

# remove old sysbench.log
rm sysbench.log 2> /dev/null

# run
THREAD="2 4 8 16 32 64 128 256 512 1024"
printf "%4s %10s %10s %10s %8s %9s %10s %7s %10s %10s %10s %10s\n" "thc" "elaptime" "reads" "writes" "others" "tps" "qps" "errs" "min" "avg" "max" "p95"
for THREAD_COUNT in $THREAD
do
  filename=result_$THREAD_COUNT

  sysbench --db-driver=mysql --report-interval=$REPORT_INTERVAL \
  --table-size=$TABLE_SIZE --tables=32 \
  --threads=$THREAD_COUNT \
  --time=$TEST_TIME \
  --mysql-host=$TARGET_DB --mysql-port=3306 \
  --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest \
  --db-ps-mode=disable \
  /usr/share/sysbench/oltp_read_write.lua run | tee -a $filename >> sysbench.log

  while read line
  do
   case "$line" in
      *read:*)  read=$(echo $line | cut -d ' ' -f2) ;;
      *write:*) write=$(echo $line | cut -d ' ' -f2) ;;
      *other:*) other=$(echo $line | cut -d ' ' -f2) ;;
      *transactions:*) tps=$(echo $line | cut -d ' ' -f3 | cut -d '(' -f2) ;;
      *queries:*) qps=$(echo $line | cut -d ' ' -f3 | cut -d '(' -f2) ;;
      *ignored" "errors:*) err=$(echo $line | cut -d ' ' -f3) ;;
      *total" "time:*) ttime=$(echo $line | cut -d ' ' -f3) ;;
      *min:*)  min=$(echo $line | cut -d ' ' -f2) ;;
      *avg:*)  avg=$(echo $line | cut -d ' ' -f2) ;;
      *max:*)  max=$(echo $line | cut -d ' ' -f2) ;;
      *95th" "percentile:*) p95=$(echo $line | cut -d ' ' -f3) ;;
   esac
  done < $filename

  #echo $THREAD_COUNT $ttime $read $write $other $tps $qps $err $min $avg $max $p95 
  printf "%4s %10s %10s %10s %8s %9s %10s %7s %10s %10s %10s %10s\n" $THREAD_COUNT $ttime $read $write $other $tps $qps $err $min $avg $max $p95

done

# cleanup
sysbench --db-driver=mysql --report-interval=$REPORT_INTERVAL \
--table-size=$TABLE_SIZE --tables=32 \
--threads=1 \
--time=$TEST_TIME \
--mysql-host=$TARGET_DB --pgsql-port=5432 \
--mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest \
/usr/share/sysbench/oltp_read_write.lua cleanup
```
MySQL 의 경우 preapred statement 에러를 방지하기 위해서 --db-ps-mode=disable 파라미터를 설정한다. prepared statment 를 disable 하지 않고 테스트하면 아래와 같이 에러가 발생하게 되고, 제대로 된 부하 테스트를 수행할 수 없게 된다. 
```
FATAL: MySQL error: 1461 "Can't create more than max_prepared_stmt_count statements (current value: 16382)"
```

### sysbench OLTP 시나리오 ##

* /usr/share/sysbench 의 oltp_common.lua 확인


### 테스트 결과 ###

* X64

[aurora-mysql-x64-2x-1] - cpu 94%
```
thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0162s      64120      18320     9160     76.31    1526.22       0      24.66      26.21      31.09      27.17
   4   60.0073s     126728      36208    18104    150.84    3016.90       0      23.92      26.51      54.08      27.66
   8   60.0135s     246470      70420    35210    293.34    5866.87       0      24.40      27.27      55.57      28.16
  16   60.0117s     472402     134972    67486    562.26   11245.22       0      24.83      28.45      59.10      29.72
  32   60.0190s     871402     248972   124486   1037.03   20740.60       0      25.07      30.85      66.62      33.12
  64   60.0271s    1502802     429370   214685   1788.18   35763.95       1      26.84      35.78     104.28      39.65
 128   60.0382s    2004856     572804   286404   2385.09   47702.93       4      30.07      53.64     135.27      64.47
 256   60.0810s    2287194     653466   326734   2718.98   54381.86       8      30.12      94.08     267.92     125.52
 512   60.1650s    2374008     678264   339136   2818.25   56367.09       8      35.31     181.39     599.86     235.74
1024   60.4763s    2423274     692329   346168   2861.83   57240.36      14      57.55     356.27    1298.80     467.30
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```


[aurora-mysql-x64-4x-1] - cpu 75%
```
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0274s      63378      18108     9054     75.41    1508.28       0      24.58      26.51      39.94      27.66
   4   60.0164s     125734      35924    17962    149.64    2992.78       0      24.57      26.73      55.32      27.66
   8   60.0185s     243278      69508    34754    289.52    5790.41       0      24.54      27.63      56.39      28.67
  16   60.0133s     460936     131696    65848    548.60   10971.98       0      24.98      29.16      60.92      30.81
  32   60.0181s     865802     247372   123686   1030.38   20607.65       0      25.35      31.05      69.75      33.12
  64   60.0275s    1653316     472376   236188   1967.29   39345.71       0      25.80      32.52      71.76      35.59
 128   60.0525s    2755424     787251   393626   3277.22   65546.16       6      27.52      39.04      79.03      44.98
 256   60.0955s    3759000    1073968   536985   4467.54   89354.93      15      29.09      57.24     284.64      64.47
 512   60.1499s    4334890    1238492   619251   5147.28  102950.89      19      32.66      99.31     422.93     123.28
1024   60.3048s    4580282    1308580   654299   5424.58  108498.92      27      46.39     188.14     809.12     248.83
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2) 
```


[aurora-mysql-x64-8x-1] - cpu 83%
```
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0215s      64540      18440     9220     76.80    1536.08       0      24.59      26.04      30.33      27.17
   4   60.0117s     127232      36352    18176    151.43    3028.67       0      24.52      26.41      54.00      27.66
   8   60.0186s     248500      71000    35500    295.73    5914.70       0      24.23      27.05      55.93      28.16
  16   60.0249s     473298     135228    67614    563.20   11264.07       0      24.81      28.41      58.26      29.72
  32   60.0246s     866600     247600   123800   1031.22   20624.39       0      25.35      31.02      66.86      33.72
  64   60.0432s    1665524     475860   237930   1981.26   39625.81       2      25.51      32.29      75.78      36.89
 128   60.0386s    2993676     855318   427659   3561.38   71230.11       9      26.21      35.92      88.86      42.61
 256   60.0604s    4802518    1372113   686058   5711.13  114227.14      16      30.48      44.79     242.59      53.85
 512   60.1142s    6468910    1848153   924085   7685.52  153722.84      45      27.82      66.50     522.42      81.48
1024   60.2581s    8186276    2338772  1169411   9702.65  194068.15      57      27.24     105.17     925.32     153.02
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```


[aurora-mysql-x64-12x-1] - cpu 66%
```
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0122s      64876      18536     9268     77.22    1544.32       0      24.37      25.90      29.92      26.68
   4   60.0164s     130116      37176    18588    154.85    3097.08       0      23.89      25.83      53.06      26.68
   8   60.0225s     253106      72316    36158    301.20    6023.94       0      23.81      26.56      54.34      27.66
  16   60.0242s     480270     137220    68610    571.51   11430.13       0      23.93      27.99      57.16      29.72
  32   60.0208s     909496     259856   129928   1082.33   21646.64       0      24.28      29.56      64.10      31.94
  64   60.0141s    1760612     503030   251515   2095.41   41908.52       1      24.33      30.53      68.02      33.72
 128   60.0428s    3165862     904518   452259   3766.00   75321.90       7      24.72      33.97      73.49      40.37
 256   60.0847s    5331158    1523147   761576   6337.22  126749.44      18      25.88      40.36     258.91      49.21
 512   60.1343s    7495026    2141306  1070665   8901.63  178047.09      53      26.02      57.42     484.17      74.46
1024   60.3209s   10146430    2898841  1449444  12013.78  240287.80      46      25.87      84.95     908.85     170.48
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```



[aurora-mysql-x64-16x-1] - cpu 51%
```
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0260s      65268      18648     9324     77.66    1553.29       0      24.41      25.75      40.46      26.68
   4   60.0064s     127792      36512    18256    152.11    3042.27       0      24.52      26.29      52.43      27.17
   8   60.0193s     253610      72460    36230    301.81    6036.25       0      24.23      26.50      53.22      27.66
  16   60.0280s     490742     140212    70106    583.93   11678.60       0      24.25      27.40      56.51      28.67
  32   60.0356s     921228     263208   131604   1096.02   21920.46       0      24.53      29.19      64.07      31.37
  64   60.0133s    1758848     502520   251260   2093.29   41866.85       4      24.78      30.57      66.63      33.72
 128   60.0518s    3122070     892011   446006   3713.39   74268.85       4      25.29      34.45      77.76      40.37
 256   60.0921s    5086970    1453373   726689   6046.15  120928.77      21      27.29      42.30     302.65      52.89
 512   60.1540s    7130522    2037159  1018597   8465.96  169332.50      49      26.85      60.37     289.68      75.82
1024   60.2437s   10614254    3032449  1516254  12583.46  251687.42      68      29.46      81.05     437.95     108.68
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```



* graviton2   

[aurora-mysql-graviton2-2x-1] - cpu 83%
```
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0213s      62594      17884     8942     74.49    1489.77       0      25.42      26.85      44.84      27.66
   4   60.0276s     124740      35640    17820    148.43    2968.56       0      25.01      26.95      55.37      27.66
   8   60.0289s     242564      69304    34652    288.62    5772.41       0      25.07      27.72      59.50      28.67
  16   60.0068s     468230     133780    66890    557.34   11146.81       0      25.27      28.70      85.74      30.26
  32   60.0304s     863002     246567   123284   1026.81   20536.66       2      25.95      31.16     106.00      33.72
  64   60.0547s    1411578     403304   201653   1678.86   33577.50       1      26.37      38.11     135.94      46.63
 128   60.0533s    1965922     561681   280841   2338.17   46764.76       5      27.29      54.72     175.99      69.29
 256   60.1080s    2256758     644762   322383   2681.54   53633.92      11      27.36      95.39     455.55     134.90
 512   60.2165s    2398956     685378   342693   2845.31   56910.38      15      31.84     179.65     581.47     240.02
1024   60.3209s   10146430    2898841  1449444  12013.78  240287.80      46      25.87      84.95     908.85     170.48
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```



[aurora-mysql-graviton2-4x-1] - cpu 85%
```
thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0271s      63098      18028     9014     75.08    1501.62       0      25.06      26.64      34.69      27.66
   4   60.0143s     125090      35740    17870    148.88    2977.55       0      24.90      26.87      54.60      27.66
   8   60.0283s     245644      70184    35092    292.29    5845.77       0      25.21      27.37      55.93      28.16
  16   60.0302s     470428     134408    67204    559.74   11194.76       0      25.44      28.58      59.01      29.72
  32   60.0118s     877520     250716   125358   1044.40   20888.65       2      26.34      30.63      64.34      32.53
  64   60.0282s    1655962     473130   236565   1970.39   39408.15       1      26.11      32.47      64.65      36.24
 128   60.0493s    2720956     777397   388699   3236.35   64729.49       9      26.89      39.53     133.34      48.34
 256   60.0724s    3843560    1098142   549071   4569.89   91400.42       9      26.98      55.98     323.12      80.03
 512   60.1356s    4465860    1275890   637953   5303.94  106086.16      27      30.11      96.38     362.82     125.52
1024   60.2673s    4726442    1350302   675164   5600.92  112029.91      42      37.99     182.17     642.94     235.74
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2) 
```



[aurora-mysql-graviton2-8x-1] - cpu 73%
```
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0129s      61964      17704     8852     73.75    1474.98       0      25.34      27.12      31.55      27.66
   4   60.0127s     122542      35012    17506    145.85    2916.98       0      25.03      27.42      32.06      28.16
   8   60.0033s     240632      68752    34376    286.44    5728.89       0      25.29      27.93      55.13      29.19
  16   60.0196s     461566     131876    65938    549.29   10985.82       0      25.13      29.12      65.00      30.81
  32   60.0159s     835548     238728   119364    994.41   19888.28       0      25.88      32.17      70.95      34.33
  64   60.0335s    1607382     459250   229625   1912.42   38248.67       1      25.95      33.46      76.68      37.56
 128   60.0461s    2971108     848873   424437   3534.12   70684.27       7      26.81      36.20      83.68      42.61
 256   60.0802s    5032426    1437802   718904   5982.61  119656.12      14      28.96      42.75     102.21      52.89
 512   60.1298s    7313068    2089327  1044675   8686.22  173737.91      49      28.26      58.83     317.06      80.03
1024   60.2750s    8903888    2543773  1271913  10550.07  211020.57      71      30.55      96.67     571.22     132.49
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```

[aurora-mysql-graviton2-12x-1] - cpu 46%
```
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0236s      61572      17592     8796     73.27    1465.39       0      25.19      27.29      36.64      28.16
   4   60.0062s     119406      34116    17058    142.13    2842.64       0      25.35      28.14      42.60      29.72
   8   60.0227s     232302      66372    33186    276.44    5528.78       0      25.29      28.94      41.75      30.26
  16   60.0261s     438354     125244    62622    521.61   10432.21       0      25.62      30.67      62.31      31.94
  32   60.0386s     802130     229180   114590    954.28   19085.59       0      26.56      33.53      70.35      36.89
  64   60.0176s    1593144     455178   227589   1895.95   37919.83       3      25.95      33.74      70.22      37.56
 128   60.0434s    2977044     850565   425283   3541.31   70828.63       9      29.72      36.13      82.25      41.85
 256   60.0643s    5223554    1492389   746196   6211.28  124232.91      26      28.14      41.18     299.75      50.11
 512   60.1187s    8435882    2410121  1205073  10021.76  200449.82      53      27.69      51.00     335.26      66.84
1024   60.2589s   12644492    3612461  1806271  14986.50  299752.65      85      32.08      68.07     561.37      97.55
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2) 
```


[aurora-mysql-graviton2-16x-1] - cpu 45%
```
thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0278s      61964      17704     8852     73.73    1474.62       0      25.20      27.12      32.27      27.66
   4   60.0225s     120750      34500    17250    143.69    2873.85       0      25.35      27.83      35.37      29.19
   8   60.0088s     235214      67204    33602    279.97    5599.38       0      25.33      28.57      45.50      30.26
  16   60.0240s     448644     128184    64092    533.87   10677.49       0      25.83      29.96      60.97      31.37
  32   60.1746s     812742     232210   116105    964.70   19294.34       1      26.30      33.09     176.40      35.59
  64   60.0196s    1594614     455602   227801   1897.67   37953.64       1      26.34      33.72      70.81      37.56
 128   60.0388s    2990582     854434   427217   3557.68   71156.16       9      28.50      35.96      78.83      41.85
 256   60.0630s    5120864    1463055   731531   6089.38  121793.47      21      28.79      42.00     307.37      51.02
 512   60.1336s    7884352    2252534  1126283   9364.17  187297.91      53      27.13      54.57     300.94      69.29
1024   60.2749s   13420568    3834279  1917160  15902.56  318068.54      64      30.27      64.14     499.83      92.42
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2) 
```



