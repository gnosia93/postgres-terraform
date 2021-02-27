### 1. 파라미터 확인 ###

postgresql 주요 파라미터에 대한 설명을 나열한 후, 이를 조회하는 방법을 설명한다. 
```
shop_db=# \d pg_settings;
               View "pg_catalog.pg_settings"
     Column      |  Type   | Collation | Nullable | Default 
-----------------+---------+-----------+----------+---------
 name            | text    |           |          | 
 setting         | text    |           |          | 
 unit            | text    |           |          | 
 category        | text    |           |          | 
 short_desc      | text    |           |          | 
 extra_desc      | text    |           |          | 
 context         | text    |           |          | 
 vartype         | text    |           |          | 
 source          | text    |           |          | 
 min_val         | text    |           |          | 
 max_val         | text    |           |          | 
 enumvals        | text[]  |           |          | 
 boot_val        | text    |           |          | 
 reset_val       | text    |           |          | 
 sourcefile      | text    |           |          | 
 sourceline      | integer |           |          | 
 pending_restart | boolean |           |          | 

shop_db=# select name, setting from pg_settings;
                  name                  |               setting               
----------------------------------------+-------------------------------------
 allow_system_table_mods                | off
 application_name                       | psql
 archive_command                        | (disabled)
 archive_mode                           | off
 archive_timeout                        | 0
 array_nulls                            | on
 authentication_timeout                 | 60
 autovacuum                             | on
 autovacuum_analyze_scale_factor        | 0.1
 autovacuum_analyze_threshold           | 50
 autovacuum_freeze_max_age              | 200000000
 autovacuum_max_workers                 | 3
 autovacuum_multixact_freeze_max_age    | 400000000
 autovacuum_naptime                     | 60
 autovacuum_vacuum_cost_delay           | 20
 autovacuum_vacuum_cost_limit           | -1
 autovacuum_vacuum_scale_factor         | 0.2
 autovacuum_vacuum_threshold            | 50
 autovacuum_work_mem                    | -1
 backend_flush_after                    | 0
 backslash_quote                        | safe_encoding
 bgwriter_delay                         | 200
 bgwriter_flush_after                   | 64
 bgwriter_lru_maxpages                  | 100
 bgwriter_lru_multiplier                | 2
 block_size                             | 8192
 bonjour                                | off
 bonjour_name                           | 
 bytea_output                           | hex
 check_function_bodies                  | on
 checkpoint_completion_target           | 0.5
 checkpoint_flush_after                 | 32
 checkpoint_timeout                     | 300
 checkpoint_warning                     | 30
 client_encoding                        | UTF8
 client_min_messages                    | notice
 cluster_name                           | 
 commit_delay                           | 0
 commit_siblings                        | 5
 config_file                            | /var/lib/pgsql/data/postgresql.conf
 constraint_exclusion                   | partition
 cpu_index_tuple_cost                   | 0.005
 cpu_operator_cost                      | 0.0025
 cpu_tuple_cost                         | 0.01
 cursor_tuple_fraction                  | 0.1
 data_checksums                         | off
 data_directory                         | /var/lib/pgsql/data
 data_directory_mode                    | 0700
 data_sync_retry                        | off
 DateStyle                              | ISO, MDY
 db_user_namespace                      | off
 deadlock_timeout                       | 1000
 debug_assertions                       | off
 debug_pretty_print                     | on
 debug_print_parse                      | off
--More--
```

### 2. 데이터베이스 사이즈 확인 ###

```
shop_db=# \d pg_database;
               Table "pg_catalog.pg_database"
    Column     |   Type    | Collation | Nullable | Default 
---------------+-----------+-----------+----------+---------
 datname       | name      |           | not null | 
 datdba        | oid       |           | not null | 
 encoding      | integer   |           | not null | 
 datcollate    | name      |           | not null | 
 datctype      | name      |           | not null | 
 datistemplate | boolean   |           | not null | 
 datallowconn  | boolean   |           | not null | 
 datconnlimit  | integer   |           | not null | 
 datlastsysoid | oid       |           | not null | 
 datfrozenxid  | xid       |           | not null | 
 datminmxid    | xid       |           | not null | 
 dattablespace | oid       |           | not null | 
 datacl        | aclitem[] |           |          | 
Indexes:
    "pg_database_datname_index" UNIQUE, btree (datname), tablespace "pg_global"
    "pg_database_oid_index" UNIQUE, btree (oid), tablespace "pg_global"
Tablespace: "pg_global"

shop_db=# 
shop_db=# select datname, pg_size_pretty(pg_database_size(datname)) as db_size from pg_database;
  datname  | db_size 
-----------+---------
 postgres  | 8037 kB
 demo      | 7973 kB
 template1 | 7973 kB
 template0 | 7833 kB
 shop_db   | 8077 kB
(5 rows)
```



### 3. Session 확인 ###

pg_stat_activity 뷰를 이용하여 세션들에 대한 정보를 확인한다. 이때 state = 'active' 로 설정하는 경우 활성 상태의 세션에 대해서만 죄회할 수 있으며,
query 칼럼을 이용하여 현재 수행중인 SQL 을 확인할 수 있다. 
\watch 3 명령어의 경우 3초 단위로 방금전에 수행한 명령어를 반복적으로 수행하는 명령어이다. 

```
shop_db=# \d pg_stat_activity;
                      View "pg_catalog.pg_stat_activity"
      Column      |           Type           | Collation | Nullable | Default 
------------------+--------------------------+-----------+----------+---------
 datid            | oid                      |           |          | 
 datname          | name                     |           |          | 
 pid              | integer                  |           |          | 
 usesysid         | oid                      |           |          | 
 usename          | name                     |           |          | 
 application_name | text                     |           |          | 
 client_addr      | inet                     |           |          | 
 client_hostname  | text                     |           |          | 
 client_port      | integer                  |           |          | 
 backend_start    | timestamp with time zone |           |          | 
 xact_start       | timestamp with time zone |           |          | 
 query_start      | timestamp with time zone |           |          | 
 state_change     | timestamp with time zone |           |          | 
 wait_event_type  | text                     |           |          | 
 wait_event       | text                     |           |          | 
 state            | text                     |           |          | 
 backend_xid      | xid                      |           |          | 
 backend_xmin     | xid                      |           |          | 
 query            | text                     |           |          | 
 backend_type     | text                     |           |          | 


shop_db=# select datid, datname, pid, usename, application_name, client_addr, wait_event, state, backend_type from pg_stat_activity;
 datid | datname |  pid  | usename  | application_name | client_addr |     wait_event      | state  |         backend_type         
-------+---------+-------+----------+------------------+-------------+---------------------+--------+------------------------------
       |         | 14335 | postgres |                  |             | LogicalLauncherMain |        | logical replication launcher
       |         | 14333 |          |                  |             | AutoVacuumMain      |        | autovacuum launcher
 16386 | shop_db | 14346 | demo     | psql             |             |                     | active | client backend
       |         | 14331 |          |                  |             | BgWriterHibernate   |        | background writer
       |         | 14330 |          |                  |             | CheckpointerMain    |        | checkpointer
       |         | 14332 |          |                  |             | WalWriterMain       |        | walwriter
(6 rows)

shop_db=# 
shop_db=# 
shop_db=# \watch 3
                                            Wed 06 Jan 2021 02:57:37 AM UTC (every 3s)

 datid | datname |  pid  | usename  | application_name | client_addr |     wait_event      | state  |         backend_type         
-------+---------+-------+----------+------------------+-------------+---------------------+--------+------------------------------
       |         | 14335 | postgres |                  |             | LogicalLauncherMain |        | logical replication launcher
       |         | 14333 |          |                  |             | AutoVacuumMain      |        | autovacuum launcher
 16386 | shop_db | 14346 | demo     | psql             |             |                     | active | client backend
       |         | 14331 |          |                  |             | BgWriterHibernate   |        | background writer
       |         | 14330 |          |                  |             | CheckpointerMain    |        | checkpointer
       |         | 14332 |          |                  |             | WalWriterMain       |        | walwriter
(6 rows)

                                            Wed 06 Jan 2021 02:57:40 AM UTC (every 3s)

 datid | datname |  pid  | usename  | application_name | client_addr |     wait_event      | state  |         backend_type         
-------+---------+-------+----------+------------------+-------------+---------------------+--------+------------------------------
       |         | 14335 | postgres |                  |             | LogicalLauncherMain |        | logical replication launcher
       |         | 14333 |          |                  |             | AutoVacuumMain      |        | autovacuum launcher
 16386 | shop_db | 14346 | demo     | psql             |             |                     | active | client backend
       |         | 14331 |          |                  |             | BgWriterHibernate   |        | background writer
       |         | 14330 |          |                  |             | CheckpointerMain    |        | checkpointer
       |         | 14332 |          |                  |             | WalWriterMain       |        | walwriter
(6 rows)

shop_db=# 
```


### 4. buffer hit ratio ##

hit ratio 는 최소 90 % 이상을 유지할 수 있도록 한다. 이 뷰는 누적치를 기록하는 뷰로 stats_reset 칼럼을 이용하여 reset 된 일자를 확인할 수 있다. 
```
shop_db=# \d pg_stat_database;
                     View "pg_catalog.pg_stat_database"
     Column     |           Type           | Collation | Nullable | Default 
----------------+--------------------------+-----------+----------+---------
 datid          | oid                      |           |          | 
 datname        | name                     |           |          | 
 numbackends    | integer                  |           |          | 
 xact_commit    | bigint                   |           |          | 
 xact_rollback  | bigint                   |           |          | 
 blks_read      | bigint                   |           |          | 
 blks_hit       | bigint                   |           |          | 
 tup_returned   | bigint                   |           |          | 
 tup_fetched    | bigint                   |           |          | 
 tup_inserted   | bigint                   |           |          | 
 tup_updated    | bigint                   |           |          | 
 tup_deleted    | bigint                   |           |          | 
 conflicts      | bigint                   |           |          | 
 temp_files     | bigint                   |           |          | 
 temp_bytes     | bigint                   |           |          | 
 deadlocks      | bigint                   |           |          | 
 blk_read_time  | double precision         |           |          | 
 blk_write_time | double precision         |           |          | 
 stats_reset    | timestamp with time zone |           |          | 

shop_db=# 
select sum(blks_hit) * 100 / sum(blks_hit + blks_read) as hit_ratio  from pg_stat_database;
      hit_ratio      
---------------------
 99.0777834896211866
(1 row)
```

### 5. checkpoint 주기 확인 ###

체크 포인트랑 데이터베이스의 메모리와 파일의 동기화하는 것으로, 잦은 체크 포인트를 데이터베이스의 성능을 저하 시키게 된다. 
결과값이,

 checkpoints_req  > checkpoints_timed 일 경우,  Bad !!


postgresql.conf tuning parameter

 - checkpoint_segments

 - checkpoint_timeout

 - checkpoint_completion_target

```
shop_db=# \d pg_stat_bgwriter
                        View "pg_catalog.pg_stat_bgwriter"
        Column         |           Type           | Collation | Nullable | Default 
-----------------------+--------------------------+-----------+----------+---------
 checkpoints_timed     | bigint                   |           |          | 
 checkpoints_req       | bigint                   |           |          | 
 checkpoint_write_time | double precision         |           |          | 
 checkpoint_sync_time  | double precision         |           |          | 
 buffers_checkpoint    | bigint                   |           |          | 
 buffers_clean         | bigint                   |           |          | 
 maxwritten_clean      | bigint                   |           |          | 
 buffers_backend       | bigint                   |           |          | 
 buffers_backend_fsync | bigint                   |           |          | 
 buffers_alloc         | bigint                   |           |          | 
 stats_reset           | timestamp with time zone |           |          | 

shop_db=# 
shop_db=# 
shop_db=# select checkpoints_timed, checkpoints_req from pg_stat_bgwriter;
 checkpoints_timed | checkpoints_req 
-------------------+-----------------
               274 |               4
(1 row)
```

### 6. LOCK ###


### 7. Waitevent ###

* https://www.postgresql.org/docs/10/monitoring-stats.html



### 8. Vacuum ###

* https://m.blog.naver.com/PostView.nhn?blogId=geartec82&logNo=221144534637&proxyReferer=https:%2F%2Fwww.google.com%2F

* https://nrise.github.io/posts/postgresql-autovacuum/  - autovaccum 최적화하기



### 9. 실행 SQL 모니터링 ###

* https://postgresql.kr/docs/9.6/pgstatstatements.html

아래와 같이 postgresql.conf 파일에 SQL 모니터링을 위한 설정을 추가한다.  
```
# postgresql.conf
shared_preload_libraries = 'pg_stat_statements'

pg_stat_statements.max = 10000
pg_stat_statements.track = all
```

create extension pg_stat_statements 명령어를 이용하여, 해당 뷰를 생성하고, 아래 쿼리를 실행하여 실행 완료된 SQL 을 조회한다. 
pg_stat_statements 뷰는 shared buffer 영역의 일정 공간을 차지한다. 
```
shop_db=# CREATE EXTENSION pg_stat_statements;
CREATE EXTENSION

shop_db=# SELECT pg_stat_statements_reset();          # 뷰의 내용을 지운다. 
 pg_stat_statements_reset 
--------------------------
 
(1 row)


shop_db=# select * from tb_order;
 order_id | product_id | product_cnt | product_price |         purchase_date         
----------+------------+-------------+---------------+-------------------------------
        1 |          1 |           1 |           100 | 2021-01-05 10:21:55.661735+00
        2 |          2 |           2 |           200 | 2021-01-05 10:24:42.611459+00
        3 |          2 |           2 |           200 | 2021-01-05 10:24:45.735855+00
        4 |          2 |           2 |           200 | 2021-01-05 10:24:46.666444+00
(4 rows)

shop_db=# select * from tb_order;
 order_id | product_id | product_cnt | product_price |         purchase_date         
----------+------------+-------------+---------------+-------------------------------
        1 |          1 |           1 |           100 | 2021-01-05 10:21:55.661735+00
        2 |          2 |           2 |           200 | 2021-01-05 10:24:42.611459+00
        3 |          2 |           2 |           200 | 2021-01-05 10:24:45.735855+00
        4 |          2 |           2 |           200 | 2021-01-05 10:24:46.666444+00
(4 rows)

shop_db=# SELECT query, calls, total_time, rows, 100.0 * shared_blks_hit /
               nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
          FROM pg_stat_statements ORDER BY total_time DESC LIMIT 5;
                                    query                                     | calls | total_time | rows |     hit_percent      
------------------------------------------------------------------------------+-------+------------+------+----------------------
 SELECT query, calls, total_time, rows, $1 * shared_blks_hit /               +|     2 |   0.174247 |    4 |                     
                nullif(shared_blks_hit + shared_blks_read, $2) AS hit_percent+|       |            |      | 
           FROM pg_stat_statements ORDER BY total_time DESC LIMIT $3          |       |            |      | 
 SELECT pg_stat_statements_reset()                                            |     1 |   0.106694 |    1 |                     
 select * from tb_order                                                       |     2 |   0.037792 |    8 | 100.0000000000000000
(3 rows)
```

## 레퍼런스 ##

* [세션/시스템 기본정보확인](https://www.postgresql.org/docs/current/functions-info.html)

* [모니터링](https://semode.tistory.com/6)

* [세모데](https://semode.tistory.com/category/RDB/PostreSQL)

* [이런디비~저런디비](http://blog.daum.net/initdb/category/PostgreSQL)

* [postgres wiki](https://wiki.postgresql.org/wiki/Monitoring)

* https://github.com/gnosia93/aws-mbp/blob/master/tutorials/postgres/postgres-monitoring.md