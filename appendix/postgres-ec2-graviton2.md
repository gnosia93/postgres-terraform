## Performance of PostgreSQL 11 on AWS Graviton2 EC2 Instance ##

이번 챕터에서는 RDS 가 아닌 EC2 인스턴스 위에 PostgreSQL 을 직접 설치하여 AWS Graviton2 의 성능을 테스트하고자 합니다. 
PostgreSQL 은 ARM 아키텍처를 8.1 부터 지원하고 있다. 아마존 EC2 역시 Graviton2 인스턴스를 통해서 ARM 아키텍처를 지원하고 있고, RDS for Aurora 역시 graviton2 를 지원하고 있다. 이번 챕터에서는 그라비톤 상의 PostgreSQL의 성능을 테스트하여 X86 과 비교하고 비용 효율성을 검증하고자 한다.  

- https://aws.amazon.com/ko/about-aws/whats-new/2020/10/achieve-up-to-52-percent-better-price-performance-with-amazon-rds-using-new-graviton2-instances/


#### Supported Version of Linux Distributions ####

* Unbutu 의 경우 - PostgreSQL 12 까지 지원
  https://www.postgresql.org/download/linux/ubuntu/
* CentOS 의 경우 - PostgreSQL 13 까지 지원
  https://www.postgresql.org/download/linux/redhat/ 
* Amazon Linux 2 의 경우 - PostgreSQL 11 까지 지원
  Amazon Linux2 버전에서 지원되는 PostgreSQL 의 최신버전은 PostgreSQL 11.5 이다.
* Amazon Aurora 의 경우 - PostgreSQL 12 까지 지원

### 테스트 아키텍처 ###

![pef_architecture](https://github.com/gnosia93/postgres-terraform/blob/main/appendix/images/postgres_perf_graviton2.png)

성능 테스트시 적용되는 PostgreSQL 데이터베이스의 파리미터 값입니다. 인프라 빌드시 아래의 파라미터값은 자동으로 설정됩니다. 
```
[postgresql.conf]
  shared_buffers = 40GB
  max_wal_size = 30GB
  min_wal_size = 30GB
  max_connections = 2000
  listen_addresses = '*'
```

(참고) 이미지 조회하기
```
aws ec2 describe-images --image-ids ami-00f1068284b9eca92
```

### 인프라 빌드하기 ###

Graviton2 과 X86 용 PostgreSQL 11 의 성능 비교를 위해 아키텍처 다이어그램에 나와 있는 것 처럼, 아래 스크립트를 이용하여 인프라를 빌드합니다.
R6g 타입의 인스턴스는 AWS 그라비톤2 프로세스를 탑재하고 있는데, X86 대비 최대 40% 까지 저렴합니다.(https://aws.amazon.com/ko/ec2/instance-types/r6/)  
테스트에 사용되는 인스턴스의 타입과 사양은 아래와 같습니다. 좀 더 정확한 테스트를 위해서는 vCPU 의 갯수를 늘려줄 필요는 있으나, 8x 사이즈 부터는 EBS의 대역폭이 서로 상이하여 이 예제에서는 4xlarge를 대상으로 테스트합니다. 

 - r6g.4xlarge: 16 vCPU / 128 GB / Network 최대 10 Gbps	4,750 Mbps / EBS IO1 30,000 IPOS (Graviton2)
 - r5.4xlarge:  16 vCPU / 128 GB / Network 최대 10 Gbps	4,750 Mbps / EBS IO1 30,000 IPOS (X86-64) 

로컬 PC 에서 신규 터미널을 오픈한 후, 아래의 스크립트를 copy 하여 AWS 클라우드에 인프라를 빌드합니다. 

```
SG_ID=`aws ec2 describe-security-groups --group-names tf_sg_pub --query "SecurityGroups[0].{GroupId:GroupId}" --output text`; echo $SG_ID

ARM_AMI_ID=`aws ec2 describe-images \
                  --owners amazon \
                  --filters "Name=name, Values=amzn2-ami-hvm-2.0.20210303.0-arm64-gp2" \
                  --query "Images[0].{ImageId:ImageId}" --output text`; \
                  echo $ARM_AMI_ID

X64_AMI_AMZN2_ID=`aws ec2 describe-images \
                  --owners amazon \
                  --filters "Name=name, Values=amzn2-ami-hvm-2.0.20210303.0-x86_64-gp2" \
                  --query "Images[0].{ImageId:ImageId}" --output text`; \
                  echo $X64_AMI_AMZN2_ID

X64_AMI_UBUNTU_ID=`aws ec2 describe-images \
                  --owners 099720109477 \
                  --filters "Name=name, Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20210223" \
                  --query "Images[0].{ImageId:ImageId}" --output text`; \
                  echo $X64_AMI_UBUNTU_ID


USER_DATA=`cat <<EOF | base64
#! /bin/bash
sudo amazon-linux-extras install postgresql11 epel -y
sudo yum install postgresql-server postgresql-contrib postgresql-devel -y
sudo -u ec2-user postgres --version >> /home/ec2-user/postgres.out
sudo postgresql-setup --initdb

sudo -u postgres sed -e "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" -i /var/lib/pgsql/data/postgresql.conf
sudo -u postgres sed -e "s/max_connections = 100/max_connections = 2000/" -i /var/lib/pgsql/data/postgresql.conf
sudo -u postgres sed -e "s/shared_buffers = 128MB/shared_buffers = 40GB/" -i /var/lib/pgsql/data/postgresql.conf
sudo -u postgres sed -e "s/max_wal_size = 1GB/max_wal_size = 30GB/" -i /var/lib/pgsql/data/postgresql.conf
sudo -u postgres sed -e "s/min_wal_size = 80MB/min_wal_size = 30GB/" -i /var/lib/pgsql/data/postgresql.conf

sudo -u postgres sed -i -e "/is for Unix domain socket connections only/a\local   all             shop                        md5" /var/lib/pgsql/data/pg_hba.conf
sudo -u postgres echo "host    all             all             0.0.0.0/0               md5" >> /var/lib/pgsql/data/pg_hba.conf

sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo -u ec2-user ps aux | grep postgres >> /home/ec2-user/postgres.out
EOF`

aws ec2 run-instances \
  --image-id $ARM_AMI_ID \
  --count 1 \
  --instance-type r6g.8xlarge \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=600, VolumeType=io1, Iops=30000}'   \
  --key-name tf_key \
  --security-group-ids $SG_ID \
  --monitoring Enabled=true \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cl_postgres_arm64}]' \
  --user-data $USER_DATA
  
aws ec2 run-instances \
  --image-id $X64_AMI_AMZN2_ID \
  --count 1 \
  --instance-type r5.8xlarge \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=600, VolumeType=io1, Iops=30000}'   \
  --key-name tf_key \
  --security-group-ids $SG_ID \
  --monitoring Enabled=true \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cl_postgres_x86-64}]' \
  --user-data $USER_DATA
  
aws ec2 run-instances \
  --image-id $X64_AMI_UBUNTU_ID \
  --count 1 \
  --instance-type r5.4xlarge \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=50}'   \
  --key-name tf_key \
  --security-group-ids $SG_ID \
  --monitoring Enabled=true \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cl_stress-gen}]' \
  --user-data $USER_DATA    
```

### PostgreSQL 초기화 하기 ###

우선 cl_postgres_arm64 와 cl_postgres_x86-64 로 각각 접속하여, sbtest 라는 이름의 데이터베이스와 DB 유저를 생성합니다. 
```
$ aws ec2 describe-instances --filters "Name=tag:Name,Values=cl_postgres_arm64,cl_postgres_x86-64"  --query "Reservations[].Instances[*].{InstanceId:InstanceId, PublicIpAddress:PublicIpAddress, Name:Tags[0].Value}" --output table
------------------------------------------------------------------
|                        DescribeInstances                       |
+---------------------+----------------------+-------------------+
|     InstanceId      |        Name          |  PublicIpAddress  |
+---------------------+----------------------+-------------------+
|  i-09448b53c5f22c9df|  cl_postgres_x86-64  |  13.125.223.230   |
|  i-03a75f2694036edd1|  cl_postgres_arm64   |  3.35.4.152       |
+---------------------+----------------------+-------------------+

$ ssh -i ~/.ssh/tf_key ec2-user@3.35.4.152

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
No packages needed for security; 1 packages available
Run "sudo yum update" to apply all updates.

[ec2-user@ip-172-31-37-85 ~]$ uname -a
Linux ip-172-31-37-85.ap-northeast-2.compute.internal 4.14.219-164.354.amzn2.aarch64 #1 SMP Mon Feb 22 21:18:49 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux

[ec2-user@ip-172-31-37-85 ~]$ sudo su - postgres
-bash-4.2$ psql
psql (11.5)
Type "help" for help.

postgres=# CREATE USER sbtest WITH PASSWORD 'sbtest';
CREATE ROLE
postgres=# CREATE DATABASE sbtest;
CREATE DATABASE
postgres=# GRANT ALL PRIVILEGES ON DATABASE sbtest TO sbtest;
GRANT
postgres=# \q
```

### sysbench 설치하기 ###

* https://severalnines.com/database-blog/how-benchmark-postgresql-performance-using-sysbench  
* https://sarc.io/index.php/os/1708-too-many-open-files

아래의 명령어를 참고하여 테스트 트래픽을 발생시키는 cl_stress-gen 인스턴스에 sysbench를 설치합니다. PostgreSQL 설치되는 EC2 가 amazon linux2 를 사용하는데 반해, 스트레스 트패릭을
생성하는 cl_stress-gen 서버는 우분투 입니다. 또한 아래와 같이 .bash_profile 에 ulimit 를 이용하여 최대로 열수 있는 파일 갯수를 증가시켜 줍니다. 우분투의 기본값은 1024 입니다.  

```
$ aws ec2 describe-instances --filters "Name=tag:Name,Values=cl_stress-gen"  --query "Reservations[].Instances[*].{InstanceId:InstanceId, PublicIpAddress:PublicIpAddress, Name:Tags[0].Value}" --output table
-------------------------------------------------------------
|                     DescribeInstances                     |
+---------------------+-----------------+-------------------+
|     InstanceId      |      Name       |  PublicIpAddress  |
+---------------------+-----------------+-------------------+
|  i-01296b0081a5a653d|  cl_stress-gen  |  3.35.131.217     |
+---------------------+-----------------+-------------------+

$ ssh -i ~/.ssh/tf_key ubuntu@3.35.131.217

ubuntu@ip-172-31-1-64:~$ curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash

ubuntu@ip-172-31-1-64:~$ sudo apt -y install sysbench

ubuntu@ip-172-31-1-64:~$ sysbench --version
sysbench 1.0.20

ubuntu@ip-172-31-1-64:~$ vi .bash_profile
#! /bin/sh
ulimit -n 40960

ubuntu@ip-172-31-1-64:~$ . .bash_profile

ubuntu@ip-172-31-1-64:~$ ulimit -a
core file size          (blocks, -c) 0
data seg size           (kbytes, -d) unlimited
scheduling priority             (-e) 0
file size               (blocks, -f) unlimited
pending signals                 (-i) 509408
max locked memory       (kbytes, -l) 65536
max memory size         (kbytes, -m) unlimited
open files                      (-n) 40960
pipe size            (512 bytes, -p) 8
POSIX message queues     (bytes, -q) 819200
real-time priority              (-r) 0
stack size              (kbytes, -s) 8192
cpu time               (seconds, -t) unlimited
max user processes              (-u) 509408
virtual memory          (kbytes, -v) unlimited
file locks                      (-x) unlimited
```

### 성능 테스트 하기 ###

성능 테스트 대상 데이터베이스 인스턴스는 cl_postgres_x86-64 와 cl_postgres_arm64 입니다. 아래와 같이 AWS CLI 명령어를 이용하여 대상 서버들의 사설 IP를 조회하거나 AWS EC2 콘솔을 이용하여
사설 IP 를 조회합니다. 
```
$ aws ec2 describe-instances --filters "Name=tag:Name,Values=cl_postgres_arm64,cl_postgres_x86-64"  --query "Reservations[].Instances[*].{InstanceId:InstanceId, PrivateIpAddress:PrivateIpAddress, Name:Tags[0].Value}" --output table
------------------------------------------------------------------
|                        DescribeInstances                       |
+---------------------+----------------------+-------------------+
|     InstanceId      |        Name          |  PrivateIpAddress  |
+---------------------+----------------------+-------------------+
|  i-09448b53c5f22c9df|  cl_postgres_x86-64  |  172.31.9.169     |
|  i-03a75f2694036edd1|  cl_postgres_arm64   |  172.31.37.85     |
+---------------------+----------------------+-------------------+
```

아래의 스크립트를 실행하여 각 데이터베이스별 성능을 측정합니다. 이 때 TARGET_DB 는 성능 측정의 대상이 되는 PostgreSQL 의 IP로 반드시 위에서 찾은 EC2 인스턴스의 사설 IP 를 입력해야 합니다.
THREAD_COUNT 는 sysbench 가 테스트를 위해 내부적으로 생성하는 쓰레드의 수로, 데이터베이스 커넥션수와 같습니다.
쓰레드 수를 32 을 시작으로 64, 128, 256, 512 까지 두배씩 증가 시키면서 두 데이터베이스의 성능을 측정한 후 비교하도록 합니다.   
참고로 아래 테스트 스크립트를 보면 prepare, run, cleanup 이라는 키워드를 볼 수 있은데, prepare 은 테스트를 위한 스키마 빌드 작업을 하는 단계이고, 실제 테스트는 run 단계에서 
수행됩니다. cleanup 명령어를 사용하면 prepare 단계에서 생성한 각종 DB오브젝트를 삭제합니다.
```
ubuntu@ip-172-31-1-64:~$ export TARGET_DB=172.31.37.85  
ubuntu@ip-172-31-1-64:~$ export THREAD_COUNT=32
ubuntu@ip-172-31-1-64:~$ export TEST_TIME=300

ubuntu@ip-172-31-1-64:~$ sysbench \
--db-driver=pgsql \
--table-size=5000000 \
--tables=32 \
--threads=32 \
--pgsql-host=$TARGET_DB \
--pgsql-port=5432 \
--pgsql-user=sbtest \
--pgsql-password=sbtest \
--pgsql-db=sbtest \
/usr/share/sysbench/oltp_read_write.lua prepare

ubuntu@ip-172-31-1-64:~$ sysbench \
--db-driver=pgsql \
--report-interval=10 \
--table-size=5000000 \
--tables=32 \
--threads=$THREAD_COUNT \
--time=$TEST_TIME \
--pgsql-host=$TARGET_DB \
--pgsql-port=5432 \
--pgsql-user=sbtest \
--pgsql-password=sbtest \
--pgsql-db=sbtest \
/usr/share/sysbench/oltp_read_write.lua run

ubuntu@ip-172-31-1-64:~$ sysbench \
--db-driver=pgsql \
--report-interval=10 \
--table-size=5000000 \
--tables=32 \
--threads=$THREAD_COUNT \
--time=$TEST_TIME \
--pgsql-host=$TARGET_DB \
--pgsql-port=5432 \
--pgsql-user=sbtest \
--pgsql-password=sbtest \
--pgsql-db=sbtest \
/usr/share/sysbench/oltp_read_write.lua cleanup
```

- 테스트 결과
```
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)

Running the test with following options:
Number of threads: 32
Report intermediate results every 10 second(s)
Initializing random number generator from current time


Initializing worker threads...

Threads started!

[ 10s ] thds: 32 tps: 1494.03 qps: 29936.46 (r/w/o: 20958.26/5987.03/2991.17) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 20s ] thds: 32 tps: 1470.84 qps: 29389.32 (r/w/o: 20574.88/5872.66/2941.78) lat (ms,95%): 23.52 err/s: 0.00 reconn/s: 0.00
[ 30s ] thds: 32 tps: 1506.60 qps: 30160.43 (r/w/o: 21109.82/6037.41/3013.20) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 40s ] thds: 32 tps: 1501.30 qps: 30015.38 (r/w/o: 21018.48/5994.10/3002.80) lat (ms,95%): 22.69 err/s: 0.00 reconn/s: 0.00
[ 50s ] thds: 32 tps: 1506.30 qps: 30097.69 (r/w/o: 21059.79/6025.10/3012.80) lat (ms,95%): 22.69 err/s: 0.10 reconn/s: 0.00
[ 60s ] thds: 32 tps: 1498.30 qps: 30008.22 (r/w/o: 21006.92/6004.60/2996.70) lat (ms,95%): 22.69 err/s: 0.10 reconn/s: 0.00
[ 70s ] thds: 32 tps: 1499.30 qps: 29950.58 (r/w/o: 20965.78/5986.10/2998.70) lat (ms,95%): 22.69 err/s: 0.00 reconn/s: 0.00
[ 80s ] thds: 32 tps: 1499.30 qps: 29993.58 (r/w/o: 20992.29/6002.70/2998.60) lat (ms,95%): 22.69 err/s: 0.00 reconn/s: 0.00
[ 90s ] thds: 32 tps: 1502.00 qps: 30043.41 (r/w/o: 21036.61/6002.80/3004.00) lat (ms,95%): 22.69 err/s: 0.00 reconn/s: 0.00
[ 100s ] thds: 32 tps: 1502.80 qps: 30082.24 (r/w/o: 21055.03/6021.41/3005.80) lat (ms,95%): 22.69 err/s: 0.10 reconn/s: 0.00
[ 110s ] thds: 32 tps: 1493.00 qps: 29854.28 (r/w/o: 20902.09/5966.20/2986.00) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 120s ] thds: 32 tps: 1491.10 qps: 29821.26 (r/w/o: 20876.87/5962.19/2982.20) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 130s ] thds: 32 tps: 1494.10 qps: 29856.73 (r/w/o: 20894.32/5974.21/2988.20) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 140s ] thds: 32 tps: 1489.60 qps: 29770.59 (r/w/o: 20835.70/5958.20/2976.70) lat (ms,95%): 22.69 err/s: 0.00 reconn/s: 0.00
[ 150s ] thds: 32 tps: 1487.50 qps: 29795.71 (r/w/o: 20866.61/5951.60/2977.50) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 160s ] thds: 32 tps: 1488.30 qps: 29724.80 (r/w/o: 20797.60/5951.60/2975.60) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 170s ] thds: 32 tps: 1482.60 qps: 29684.89 (r/w/o: 20788.29/5930.40/2966.20) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 180s ] thds: 32 tps: 1480.00 qps: 29611.90 (r/w/o: 20725.10/5926.80/2960.00) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 190s ] thds: 32 tps: 1489.10 qps: 29775.29 (r/w/o: 20846.29/5950.80/2978.20) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 200s ] thds: 32 tps: 1484.00 qps: 29661.78 (r/w/o: 20758.98/5934.80/2968.00) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 210s ] thds: 32 tps: 1481.90 qps: 29633.95 (r/w/o: 20742.23/5927.81/2963.90) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 220s ] thds: 32 tps: 1484.10 qps: 29667.88 (r/w/o: 20763.08/5936.60/2968.20) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 230s ] thds: 32 tps: 1479.80 qps: 29645.64 (r/w/o: 20755.13/5930.91/2959.60) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 240s ] thds: 32 tps: 1492.50 qps: 29819.97 (r/w/o: 20877.18/5957.79/2985.00) lat (ms,95%): 22.69 err/s: 0.00 reconn/s: 0.00
[ 250s ] thds: 32 tps: 1489.60 qps: 29821.33 (r/w/o: 20872.12/5970.01/2979.20) lat (ms,95%): 22.69 err/s: 0.00 reconn/s: 0.00
[ 260s ] thds: 32 tps: 1489.20 qps: 29783.09 (r/w/o: 20848.20/5956.60/2978.30) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 270s ] thds: 32 tps: 1485.40 qps: 29659.49 (r/w/o: 20758.40/5930.10/2971.00) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 280s ] thds: 32 tps: 1471.40 qps: 29466.88 (r/w/o: 20636.49/5887.60/2942.80) lat (ms,95%): 23.52 err/s: 0.00 reconn/s: 0.00
[ 290s ] thds: 32 tps: 1476.20 qps: 29490.91 (r/w/o: 20635.71/5902.80/2952.40) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
[ 300s ] thds: 32 tps: 1476.60 qps: 29570.92 (r/w/o: 20702.11/5915.70/2953.10) lat (ms,95%): 23.10 err/s: 0.00 reconn/s: 0.00
SQL statistics:
    queries performed:
        read:                            6256670
        write:                           1787610
        other:                           893814
        total:                           8938094
    transactions:                        446902 (1489.44 per sec.)
    queries:                             8938094 (29788.95 per sec.)
    ignored errors:                      3      (0.01 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          300.0459s
    total number of events:              446902

Latency (ms):
         min:                                   17.83
         avg:                                   21.48
         max:                                  104.71
         95th percentile:                       23.10
         sum:                              9599723.30

Threads fairness:
    events (avg/stddev):           13965.6875/281.88
    execution time (avg/stddev):   299.9914/0.01
```

### 테스트 자동화하기 ###

아래의 내용으로 perf.sh 이라는 파일을 만든 후, TARGET_DB 의 값을 여러분들의 DB 서버 주소로 바꾼 다음 perf.sh 을 실행합니다. 
```
#! /bin/sh
TARGET_DB=172.31.37.85  
TEST_TIME=60
TABLE_SIZE=5000000
REPORT_INTERVAL=10

# prepare
sysbench --db-driver=pgsql \
--table-size=$TABLE_SIZE --tables=32 \
--threads=32 \
--pgsql-host=$TARGET_DB --pgsql-port=5432 \
--pgsql-user=sbtest \
--pgsql-password=sbtest \
--pgsql-db=sbtest \
/usr/share/sysbench/oltp_read_write.lua prepare

# remove old sysbench.log
rm sysbench.log 2> /dev/null

# run
THREAD="2 4 8 16 32 64 128 256 512 1024"
printf "%4s %10s %10s %10s %8s %9s %10s %7s %10s %10s %10s %10s\n" "thc" "elaptime" "reads" "writes" "others" "tps" "qps" "errs" "min" "avg" "max" "p95"
for THREAD_COUNT in $THREAD
do
  filename=result_$THREAD_COUNT

  sysbench --db-driver=pgsql --report-interval=$REPORT_INTERVAL \
  --table-size=$TABLE_SIZE --tables=32 \
  --threads=$THREAD_COUNT \
  --time=$TEST_TIME \
  --pgsql-host=$TARGET_DB --pgsql-port=5432 \
  --pgsql-user=sbtest --pgsql-password=sbtest --pgsql-db=sbtest \
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
sysbench --db-driver=pgsql --report-interval=$REPORT_INTERVAL \
--table-size=$TABLE_SIZE --tables=32 \
--threads=1 \
--time=$TEST_TIME \
--pgsql-host=$TARGET_DB --pgsql-port=5432 \
--pgsql-user=sbtest --pgsql-password=sbtest --pgsql-db=sbtest \
/usr/share/sysbench/oltp_read_write.lua cleanup
```

```
ubuntu@ip-172-31-1-64:~$ sh perf.sh
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2    4.0125s       6300       1799      901    112.11    2242.18       0      17.30      17.81      20.09      18.28
   4    4.0141s      12460       3553     1781    220.89    4431.31       3      17.18      18.08      60.80      18.95
  16    4.0180s      37520      10620     5411    660.80   13323.14      24      17.39      24.15    1035.78      20.74
  24    4.1995s      58604      16541     8474    984.55   19904.96      50      17.37      24.28    1035.28      21.50
  ...
```


### 테스트 결과 ###

아래는 PostgreSQL 데이터베이스의 벤치마킹 결과 입니다. 현재의 인프라 설정으로는 쓰레드 갯수가 128인 경우 가장 좋은 성능이 나오는 것을 확인할 수 있으며, 
X86 및 ARM 의 TPS/QPS (saturation point기준) 차이는 거의 없는 것을 확인할 수 있습니다. 한가지 특이한 점은 X86의 경우 쓰레드 개수와 상관없이 min latency 값은 작지만, ARM 의 경우 상대적으로 
약간 더 큰 latency 를 보여주고 있습니다. 

* X86-64
```
 thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0034s     370958     105988    52994    441.58    8831.62       0       2.40       4.53     130.31       7.56
   4   60.0034s    1040046     297156   148578   1238.05   24761.02       0       2.45       3.23      45.07       3.96
   8   60.0040s    1833664     523904   261952   2182.74   43654.73       0       2.57       3.66     209.87       4.41
  16   60.0066s    3065762     875930   437968   3649.23   72984.51       0       2.68       4.38      89.31       5.09
  32   60.0266s    5170326    1477231   738621   6152.26  123045.43       1       3.13       5.20      48.35       6.09
  64   60.0589s    5686478    1624684   812358   6762.66  135256.14      10       3.32       9.46     443.46      12.98  
 128   60.0927s    5679310    1622645   811339   6750.45  135009.88       3       4.18      18.94     296.16      27.17   <----- 성능최대치
 256   60.1407s    5085486    1452975   726507   6039.74  120796.65       6       4.36      42.32     323.33      56.84
 512   60.2641s    4307114    1230573   615323   5104.84  102098.27       5       5.12     100.02     692.73     137.35
1024   60.2641s    4307114    1230573   615323   5104.84  102098.27       5       5.12     100.02     692.73     137.35
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```

* ARM64
```
thc   elaptime      reads     writes   others       tps        qps    errs        min        avg        max        p95
   2   60.0133s     112056      32016    16008    133.37    2667.35       0      13.58      14.99     100.27      18.28
   4   60.0121s     231434      66124    33062    275.45    5509.09       0      13.55      14.52      58.95      17.95
   8   60.0115s     462966     132276    66138    551.03   11020.64       0      13.52      14.52      59.30      15.27
  16   60.0113s     874384     249823   124913   1040.71   20814.29       0      13.78      15.37     230.01      16.41
  32   60.0437s    1673462     478130   239068   1990.72   39814.40       0      14.11      16.07      63.75      17.63
  64   60.1006s    3181346     908949   454479   3780.84   75617.72       3      14.48      16.90     105.25      18.28
 128   60.1390s    5532828    1580792   790410   6571.25  131426.45       5      14.95      19.44     143.43      23.10
 256   60.4553s    5665800    1618769   809417   6693.93  133880.74       7      14.25      38.01    1528.09      55.82   <---- 성능최대치
 512   60.5090s    4849292    1385374   692828   5723.73  114484.46      33      15.57      88.91    1020.20     164.45
1024   60.5090s    4849292    1385374   692828   5723.73  114484.46      33      15.57      88.91    1020.20     164.45
sysbench 1.0.20 (using bundled LuaJIT 2.1.0-beta2)
```

또한 pgbench 를 이용하여 percona 사에서 PostgreSQL 13 버전을 대상으로 테스트 한 자료는 아래의 URL 에서 확인하실 수 있습니다.   
https://www.percona.com/blog/2021/01/22/postgresql-on-arm-based-aws-ec2-instances-is-it-any-good/


### 인프라 삭제하기 ###

```
$ aws ec2 describe-instances --filters "Name=tag:Name,Values=cl_postgres_arm64,cl_postgres_x86-64, cl_stress-gen"  --query "Reservations[].Instances[*].{InstanceId:InstanceId}" --output text

$ aws ec2 terminate-instances --instance-ids i-0d443b5abcaaa67a3 i-05e2c3aead57755a4 i-09d6fc9492658bda9
```

## 비용 비교 ##

* 그라비톤이 20 % 정도 비용이 싸다..
![r6g](https://github.com/gnosia93/postgres-terraform/blob/main/appendix/images/cost_r6g_4x.png)
![r5](https://github.com/gnosia93/postgres-terraform/blob/main/appendix/images/cost_r5_4x.png)

