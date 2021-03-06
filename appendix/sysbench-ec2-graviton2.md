## CPU / Memory / FileIO 성능  ##

- https://github.com/akopytov/sysbench
- https://wiki.gentoo.org/wiki/Sysbench#cite_note-1

### 테스트 대상 서버 ###

amazon linux2 가 탑재된 EC2 인스턴스를 대상으로 한다. 

* r6g.4xlarge: 16 vCPU / 128 GB / Network 최대 10 Gbps 4,750 Mbps / EBS IO1 30,000 IPOS (Graviton2)
* r5.4xlarge: 16 vCPU / 128 GB / Network 최대 10 Gbps 4,750 Mbps / EBS IO1 30,000 IPOS (X86-64)



### sysbench 설치 ###

아마존 리눅스용 sysbench 바이너리가 존재하지 않으므로, 아래와 같이 컴파일 한다. 이때 mysql 드라이버는 제거한다. 

- https://zenliu.medium.com/sysbench-1-1-installation-for-aws-ec2-instance-running-amazon-linux-a330b1cce7a7

```
[ec2-user@ip-172-31-28-94 ~]$ sudo yum -y install git gcc make automake libtool openssl-devel ncurses-compat-libs

[ec2-user@ip-172-31-28-94 ~]$ git clone https://github.com/akopytov/sysbench

[ec2-user@ip-172-31-28-94 ~]$ cd sysbench
[ec2-user@ip-172-31-28-94 sysbench]$ ./autogen.sh
[ec2-user@ip-172-31-28-94 sysbench]$ ./configure --without-mysql
[ec2-user@ip-172-31-28-94 sysbench]$ make; sudo make install

[ec2-user@ip-172-31-28-94 sysbench]$ sysbench --version
sysbench 1.1.0-bbee5d5
```

### CPU 성능 측정 ###

10만개의 소수를 계산하는 로직을 1만회 수행하는데 소요되는 시간을 계산한다. 즉 한번 실행시 10만개의 소수를 계산하는 함수를 1만번 호출하다는 의미로, elapsed time 값이 작으면 작을 수록 빠른 CPU 연산이 수행된다는 의미이다. 소수는 컴퓨터 암호화 알고리즘에 사용된다(비대칭키 RSA)

[소수와 컴퓨터 암호](http://blog.naver.com/PostView.nhn?blogId=weizmann_why&logNo=220799483125&parentCategoryNo=112&categoryNo=31&viewDate=&isShowPopularPosts=false&from=postView)

https://github.com/akopytov/sysbench/issues/140
```
[ec2-user@ip-172-31-28-94 ~]$ sysbench cpu --cpu-max-prime=100000 \
                                           --threads=1 \
                                           --time=0 --events=10000 run                                     
                                                                                      
```
아래 테스트 결과에서 알수 있는 바와 같이 그라비톤은 총 소요시간이 87초, X64 는 220 초로 그라비톤이 2.5배 정도 빠르게 연산을 수행한다는 것을 볼 수 있다.

- graviton2
```
CPU speed:
    events per second:   114.02             (10만개의 소수 계산을 114회/ 수행했다는 의미)

Throughput:
    events/s (eps):                      114.0161
    time elapsed:                        87.7069s       (총 소요시간)
    total number of events:              10000

Latency (ms):
         min:                                    8.76
         avg:                                    8.77
         max:                                    8.79
         95th percentile:                        8.74
         sum:                                87705.26

Threads fairness:
    events (avg/stddev):           10000.0000/0.00
    execution time (avg/stddev):   87.7053/0.00
```

- X64
```
CPU speed:
    events per second:    45.36

Throughput:
    events/s (eps):                      45.3573
    time elapsed:                        220.4715s
    total number of events:              10000

Latency (ms):
         min:                                   22.02
         avg:                                   22.05
         max:                                   22.16
         95th percentile:                       21.89
         sum:                               220468.57

Threads fairness:
    events (avg/stddev):           10000.0000/0.00
    execution time (avg/stddev):   220.4686/0.00
```


* 추가테스트 (쓰레드 갯수가 32/16/6 인 경우)  
쓰레드 개수를 증가시키면 더 빠르게 수행하고 순차적으로 쓰레드의 개수를 늘렸을때 32 까지는 성능이 향상되고, 32 이상인 경우는 수행시간에 변화가 없다.
``` 
sysbench cpu --cpu-max-prime=100000 --threads=32 --time=0 --events=10000 run
graviton2 - 2.745s, X64 - 7.95s

sysbench cpu --cpu-max-prime=100000 --threads=16 --time=0 --events=10000 run
graviton2 -  5.48s, X64 - 18.80s

sysbench cpu --cpu-max-prime=100000 --threads=8 --time=0 --events=10000 run
graviton2 - 10.96s, X64 - 27.56s
```

### FILE IO 성능 측정 ###

https://imcreator.tistory.com/89 

랜덤 및 시퀀셜 IO 모두 그라비톤이 X64에 비해 약간 빠른 성능을 보여주고 있다. 


1. 시스템의 메모리가 128GB 이므로, 총용량이 256GB 인 파일들(2.56G 100개)을 만든 다음, 랜덤 Read / Write 의 성능을 측정한다. 

```
[ec2-user@ip-172-31-15-22]$ sysbench fileio --file-total-size=256G prepare

[ec2-user@ip-172-31-15-22]$ sysbench fileio --file-total-size=256G --file-test-mode=rndrw --time=120 run

[ec2-user@ip-172-31-15-22]$ sysbench fileio --file-total-size=256G cleanup
```

* graviton2
```
Throughput:
         read:  IOPS=2366.91 36.98 MiB/s (38.78 MB/s)
         write: IOPS=1577.94 24.66 MiB/s (25.85 MB/s)
         fsync: IOPS=5050.32

Latency (ms):
         min:                                  0.00
         avg:                                  0.11
         max:                                 14.24
         95th percentile:                      0.69
         sum:                             119728.66

```

* X64
```
Throughput:
         read:  IOPS=2199.83 34.37 MiB/s (36.04 MB/s)
         write: IOPS=1466.55 22.91 MiB/s (24.03 MB/s)
         fsync: IOPS=4693.73

Latency (ms):
         min:                                  0.00
         avg:                                  0.12
         max:                                 42.14
         95th percentile:                      0.72
         sum:                             119236.26
```


2. 시스템의 메모리가 128GB 이므로, 총용량이 256GB 인 파일들(2.56G 100개)을 만든 다음, 시퀀셜 Read / Write 의 성능을 측정한다. 
```
[ec2-user@ip-172-31-15-22]$ sysbench fileio --file-total-size=256G prepare

[ec2-user@ip-172-31-15-22]$ sysbench fileio --file-total-size=256G --file-test-mode=seqrd --time=120 run

[ec2-user@ip-172-31-15-22]$ sysbench fileio --file-total-size=256G --file-test-mode=seqwr --time=120 run

[ec2-user@ip-172-31-15-22]$ sysbench fileio --file-total-size=256G cleanup
```

* graviton2
```
Throughput:
         read:  IOPS=41755.70 652.43 MiB/s (684.13 MB/s)
         write: IOPS=0.00 0.00 MiB/s (0.00 MB/s)
         fsync: IOPS=0.00

Latency (ms):
         min:                                  0.00
         avg:                                  0.02
         max:                                 36.78
         95th percentile:                      0.02
         sum:                             118855.52
         

Throughput:
         read:  IOPS=0.00 0.00 MiB/s (0.00 MB/s)
         write: IOPS=25128.68 392.64 MiB/s (411.71 MB/s)
         fsync: IOPS=32164.91

Latency (ms):
         min:                                  0.00
         avg:                                  0.02
         max:                                 41.71
         95th percentile:                      0.01
         sum:                             118593.02
```

* X64
```
Throughput:
         read:  IOPS=34849.51 544.52 MiB/s (570.97 MB/s)
         write: IOPS=0.00 0.00 MiB/s (0.00 MB/s)
         fsync: IOPS=0.00

Latency (ms):
         min:                                  0.00
         avg:                                  0.03
         max:                                125.08
         95th percentile:                      0.02
         sum:                             119049.65


Throughput:
         read:  IOPS=0.00 0.00 MiB/s (0.00 MB/s)
         write: IOPS=24222.87 378.48 MiB/s (396.87 MB/s)
         fsync: IOPS=31005.47

Latency (ms):
         min:                                  0.00
         avg:                                  0.02
         max:                                 44.58
         95th percentile:                      0.01
         sum:                             118570.03
```


### 메모리 테스트 ###

```
[ec2-user@ip-172-31-28-94 ~]$ sysbench memory help
sysbench 1.1.0-bbee5d5 (using bundled LuaJIT 2.1.0-beta3)

memory options:
  --memory-block-size=SIZE    size of memory block for test [1K]
  --memory-total-size=SIZE    total size of data to transfer [100G]
  --memory-scope=STRING       memory access scope {global,local} [global]
  --memory-hugetlb[=on|off]   allocate memory from HugeTLB pool [off]
  --memory-oper=STRING        type of memory operations {read, write, none} [write]
  --memory-access-mode=STRING memory access mode {seq,rnd} [seq]

Running memory speed test with the following options:
  block size: 1KiB
  total size: 102400MiB
  operation: write
  scope: global

[ec2-user@ip-172-31-28-94 ~]$ sysbench memory --threads=8 run
```

메모리 테스트의 경우 쓰레드 개수가 16 인 경우 거의 성능이 동일하고, 32인 경우에는 X86 이 더 빠르다. 아래는 쓰레드가 8인 경우의 결과 수치이다. 

* graviton2
```
Total operations: 89194940 (8919408.08 per second)

87104.43 MiB transferred (8710.36 MiB/sec)
```

* X64
```
Total operations: 61748299 (6174771.53 per second)

60301.07 MiB transferred (6030.05 MiB/sec)
```

### Mutex ###

* https://minervadb.com/index.php/2018/03/27/benchmarking-cpu-memory-file-i-o-and-mutex-performance-using-sysbench/


32개의 쓰레드를 생성해서 쓰레드당 mutext lock 을 50만회, mutex lock을 획득하지 않는 empty loop 를 10만회 수행하는데 걸리는 시간을 측정한다.
```
[ec2-user@ip-172-31-28-94 ~]$ sysbench mutex --threads=32 --mutex-locks=500000 --mutex-loops=100000 run
```

* graviton2
```
Throughput:
    events/s (eps):                      1.3442
    time elapsed:                        23.8054s
    total number of events:              32

Latency (ms):
         min:                                23722.03
         avg:                                23770.96
         max:                                23803.06
         95th percentile:                    23680.40
         sum:                               760670.80

Threads fairness:
    events (avg/stddev):           1.0000/0.00
    execution time (avg/stddev):   23.7710/0.02
```

* x64
```
Throughput:
    events/s (eps):                      0.9857
    time elapsed:                        32.4637s
    total number of events:              32

Latency (ms):
         min:                                32448.79
         avg:                                32456.82
         max:                                32463.52
         95th percentile:                    32745.49
         sum:                              1038618.11

Threads fairness:
    events (avg/stddev):           1.0000/0.00
    execution time (avg/stddev):   32.4568/0.00
```

* 추가테스트
```
sysbench mutex --threads=8 --mutex-locks=500000 --mutex-loops=100000 run
graviton2 - 23.77s  x86 - 16.32s

sysbench mutex --threads=16 --mutex-locks=500000 --mutex-loops=100000 run
graviton2 - 23.78s  x86 - 16.32s

sysbench mutex --threads=64 --mutex-locks=500000 --mutex-loops=100000 run
graviton2 - 47.93s  x86 - 65.02s

```

 


