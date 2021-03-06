## Performance of Amazon RDS for PostgreSQL(X64 Only) ##

### 데이터베이스 생성 ###

아래와 같은 사양한 RDS PostgreSQL 데이터베이스를 각각 생성합니다. RDS 역시 graviton2 용 인스턴스와 X86 용 인스턴스의 EBS Network 대역폭이 4xlarge 만 동일하고 다른 타입은 서로 상이한 관계로 4xlarge 에 대해 테스트 합니다.  

- r6g.4xlarge: 16 vCPU / 128 GB / Network 최대 10 Gbps / EBS Network 4,750 Mbps / EBS n/a IPOS (Graviton2)   -- 한국리전 미지원
- r5.4xlarge: 16 vCPU / 128 GB / Network 최대 10 Gbps / EBS Network 4,750 Mbps / EBS n/a IPOS (X86-64)

성능 테스트시 적용되는 PostgreSQL 데이터베이스의 파리미터 값으로 EC2 PostgreSQL 에서 적용한 값과 동일한 값을 적용합니다. 
```
[postgresql.conf]
  shared_buffers = 5242880      -- 8K 블록 이므로 40GB 로 설정됨
  max_wal_size = 30720          -- MB 단위로 지정(30GB)
  min_wal_size = 30720          -- MB 단위로 지정(30GB)
  max_connections = 2000
  listen_addresses = '*'        -- default / 수정 불필요
```

아래의 스크립트를 순차적으로 실행합니다. 

```
$ aws rds describe-db-engine-versions --engine postgres
12.4

$ aws rds describe-db-engine-versions --query "DBEngineVersions[].DBParameterGroupFamily" | grep postgres
postgres12

$ aws rds create-db-parameter-group \
    --db-parameter-group-name pg-rds-postgres \
    --db-parameter-group-family postgres12 \
    --description "My RDS PostgreSQL new parameter group"

$ aws rds modify-db-parameter-group \
    --db-parameter-group-name pg-rds-postgres \
    --parameters "ParameterName='shared_buffers',ParameterValue=5242880,ApplyMethod=pending-reboot" \
                 "ParameterName='max_connections',ParameterValue=2000,ApplyMethod=pending-reboot" \
                 "ParameterName='max_wal_size',ParameterValue=30720,ApplyMethod=pending-reboot"  \
                 "ParameterName='min_wal_size',ParameterValue=30720,ApplyMethod=pending-reboot"  


$ aws ec2 create-security-group --group-name sg_rds_postgres --description "rds postgres security group"
{
    "GroupId": "sg-0976d787e21a0eb07"
}

$ aws ec2 authorize-security-group-ingress --group-name sg_rds_postgres --protocol tcp --port 5432 --cidr 0.0.0.0/0

$ sleep 10       #   (10초 대기)                    

# RDS 의 그라비톤2는 지원하지 않으므로 x86 만 생성한다. 

$ aws rds create-db-instance \
    --db-instance-identifier rds-postgres-x64 \
    --db-instance-class db.r5.4xlarge \
    --engine postgres \
    --engine-version 12.4 \
    --db-parameter-group-name pg-rds-postgres \
    --master-username postgres \
    --master-user-password postgres \
    --iops 30000 \
    --storage-type io1 \
    --allocated-storage 600 \
    --vpc-security-group-ids sg-0976d787e21a0eb07 \
    --no-multi-az \
    --no-deletion-protection        
```

### RDS 엔드포인트 확인하기 ###
```
$ aws rds describe-db-instances --db-instance-identifier rds-postgres-x64 --query DBInstances[].Endpoint.Address
[
    "rds-postgres-x64.cwhptybasok6.ap-northeast-2.rds.amazonaws.com"
]
```


### 성능 테스트 준비하기 ###
https://github.com/gnosia93/postgres-terraform/blob/main/appendix/postgres-ec2-graviton2.md 에서 생성한 cl_stress_gen 으로 로그인 한 후, 아래의 명령어를 차례로 수행한다.

psql 클라이언트 프로램으로 rds-postgres-x64 에 접속하여 테스트 유저와 데이터베이스 및 권한을 만든다.

```
ubuntu@ip-172-31-45-65:~$ sudo apt-get install postgresql-client

ubuntu@ip-172-31-45-65:~$ psql -V
psql (PostgreSQL) 12.6 (Ubuntu 12.6-0ubuntu0.20.04.1)

ubuntu@ip-172-31-45-65:~$ psql -h rds-postgres-x64.cwhptybasok6.ap-northeast-2.rds.amazonaws.com -U postgres
Password for user postgres: 
psql (12.6 (Ubuntu 12.6-0ubuntu0.20.04.1), server 12.4)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

postgres=> select version();
                                                   version                                                   
-------------------------------------------------------------------------------------------------------------
 PostgreSQL 12.4 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-11), 64-bit
(1 row)

postgres=> CREATE USER sbtest WITH PASSWORD 'sbtest';
CREATE ROLE
postgres=> CREATE DATABASE sbtest;
CREATE DATABASE
postgres=> GRANT ALL PRIVILEGES ON DATABASE sbtest TO sbtest;
GRANT
postgres=> \q
```

성능 테스트 방법은 기존과 동일하다. [테스트 자동화하기] 섹션에 나온대로 perf.sh 파일을 만들고, 대상 데이터베이스의 주소를 변경한 다음 실행한다.


