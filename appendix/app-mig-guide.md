## 어플리케이션 변환 가이드 ##

Oracle 데이터베이스를 PostgreSQL 로 변환시 어플리케이션 영역에서 고려가 필요한 내용에 대해 정리합니다. 

### Data types ###

![datatypes](https://github.com/gnosia93/postgres-terraform/blob/main/appendix/images/app_datatypes.png)


### NULL ###

In Oracle, empty strings and NULL values in string context are the same. The concatenation of NULL and string obtain string as a result. In PostgreSQL the concatenation result is null in this case. In Oracle IS NULL operator is used to check whether string is empty or not but in PostgreSQL result is FALSE for empty string and TRUE for NULL.

### NVL ###

[oracle]
```
sql> select nvl(user_id, 0) from tb_user;
```

[postgresql]
```
psql> select coalesce(user_id, 0) from tb_user;
```

### UNIQUE, DISTINCT ###

[oracle]
```
sql> select unique 
```

[postgresql]
```
psql> select distinct
```


### DECODE, CASE ###

[oracle]
```
sql> select decode
```

[postgresql]
```
psql> select case when  ~ then
```

### ROWID, CTID & Identity columns ###

- Oracle 에서 ROWID 는 테이블의 행 주소를 반환하는 Peudo 칼럼(유니크함). 
- PostgreSQL에는 트랜잭션ID 를 관리하기 위한 CTID 라고하는 내부 칼럼이 있으나 VACUUM 기능 후에 CTID가 변경됨 (CTID 는 4byte)/
- Identity를 이용하여 ROWID 칼럼 생성.


[oracle]
```
sql> select rowid, order_no, order_price from shop.tb_order;
ROWID              ORDER_NO             ORDER_PRICE
------------------ -------------------- -----------
AAAR1oAAOAAAV/jAAA 20210202000000000061        2000
AAAR1oAAOAAAV/jAAB 20210202000000000068        4000
AAAR1oAAOAAAV/jAAC 20210202000000000060        5000
AAAR1oAAOAAAV/jAAD 20210202000000000074        5000
AAAR1oAAOAAAV/jAAE 20210202000000000087        4000
```
[postgresql]
```
psql> create table tb_order2
(
   order_no       varchar(20) not null primary key,
   order_price    decimal(19,3) not null,
   rowid	  bigint GENERATED ALWAYS AS IDENTITY
);

psql> insert into tb_order2(order_no, order_price) 
select order_no, order_price from shop.tb_order;

psql> select ROWID, order_no, order_price from tb_order2;
```

### ROWNUM, LIMIT & OFFSET (페이징처리) ###

- Oracle 에서 ROWNUM은 쿼리의 결과에 1부터 하나씩 값을 증가하여 출력 가상 컬럼(웹 페이징 처리시 사용).
- PostgreSQL 의 경우 LIMIT 와 OFFSET 을 사용하여 동일한 결과를 출력함.
- LIMIT는 출력 갯수 이며, OFFSET 시작 위치를 나타냄(OFFSET 는 0 부터 시작).

[oracle]
```
sql> select order_no, order_price from ( 
    select rownum as rn, order_no, order_price 
    from shop.tb_order 
    order by order_no 
) where rn between 11 and 15;
ORDER_NO             ORDER_PRICE
-------------------- -----------
20210202000000000109        1000
20210202000000000112        3000
20210202000000000131        2000
20210202000000000132        1000
20210202000000000135        4000
```
[postgresql]
```
psql> select order_no, order_price 
from shop.tb_order 
order by order_no
limit 5 offset 10;
```


### ROWNUM 사용하기 ###

* http://www.devkuma.com/books/pages/860

[oracle]
```
sql> select rownum, user_id from tb_user;
```

[postgresql]
```
psql> select (row_number() over()) as rownum, user_id from tb_user;
```



### Sequence (시퀀스) ###

- 시퀀스란 자동으로 순차적으로 증가하는 순번을 반환하는 데이터베이스 객체. 
- 보통 PK 값에 중복값을 방지하기위해 사용.
- Oracle / PostgreSQL 모두 시퀀스 지원.

[oracle]
```
sql> create sequence shop.seq_order_order_id
start with 1 increment by 1 nomaxvalue nocycle cache 20;

sql> select shop.seq_order_order_id.nextval from dual;
   NEXTVAL
----------
  32790982

sql> select shop.seq_order_order_id.currval from dual;
   CURRVAL
----------
  32790982
```
[postgresql]
```
psql> create sequence  shop.seq_order_order_id
start 1 increment 1 maxvalue 9223372036854775807 cache 20;

psql> select nextval('shop.seq_order_order_id');

psql> select currval('shop.seq_order_order_id');
```

### DUAL 테이블 ###

- PostgreSQL 은 오라클과 달리 DUAL 테이블이 존재하지 않고, SELECT 시 칼럼명만 나열함.
- DUAL 테이블이 필요하다면, 아래와 같이 dummy 테이블 하나 만들어서 사용. 

[oracle]
```
sql> select sysdate from dual;
```

[postgresql]
```
psql>create table dual 
(
	x int,
	y timestamp
);

psql>insert into dual values(1, now());

psql>select current_timestamp, now();
psql>select current_timestamp, now() from dual;
```

### START WITH..CONNECT BY ###
- ..

[oracle]
```
sql> SELECT
    restaurant_name, 
    city_name 
FROM
    restaurants rs 
START WITH rs.city_name = 'TOKYO'
CONNECT BY PRIOR rs.restaurant_name = rs.city_name;
```

[postgresql]
```
psql> WITH RECURSIVE tmp AS (SELECT restaurant_name, city_name
                                 FROM restaurants
                                WHERE city_name = 'TOKYO'
                                UNION
                               SELECT m.restaurant_name, m.city_name
                                 FROM restaurants m
                                 JOIN tmp ON tmp.restaurant_name = m.city_name)
SELECT restaurant_name, city_name FROM tmp;
```




### Outer 조인 ###

- PostgreSQL 은 SQL 표준 조인만 지원.
- 오라클의 경우 Orale-specific 문법 및 SQL 표준 모두 지원.
- LEFT / RIGHT / FULL OUTER JOIN

[oracle]
```
SELECT a1.name1, a2.name2
     FROM a1, a2
     WHERE a1.code = a2.code (+);
```

[postgresql]
```
SELECT a1.name1, a2.name2
    FROM a1
    LEFT OUTER JOIN a2 ON a1.code = a2.code;
```

### RANDOM ###

[oracle]
```
sql> SELECT column FROM ( SELECT column FROM table ORDER BY dbms_random.value ) WHERE rownum = 1;
```

[postgresql]
```
psql> SELECT column FROM table ORDER BY RANDOM() LIMIT 1;
```

### DELETE ###

- PostgreSQL 의 DELETE 문장은 FROM 키워드를 포함한다.

[oracle]
```
sql> DELETE table_name WHERE column_name = 'Col_value';
```

[postgresql]
```
psql> DELETE FROM table_name WHERE column_name = 'Col_value';
```



### SubQuery (서브쿼리) ###

- PostgreSQL 의 서브쿼리는 오라클과는 달리 명시적으로 서브쿼리 결과값에 대한 alias 를 지정해야 함.
- 서브쿼리 절의 as 는 생략가능.

[oracle]

```
sql> select order_no, order_price from (
select order_no, order_price from shop.tb_order );
```

[postgresql]
```
psql> select order_no, order_price from (
select order_no, order_price from shop.tb_order ) t;

psql> select order_no, order_price from (
select order_no, order_price from shop.tb_order ) as t;
```

### TO_DATE ###

The to_date() function in both Oracle and PostgreSQL return the date data type. However, PostgreSQL’s date data type provides the date (year, month, day), while Oracle’s date data type value provides the date and time (year, month, day, hour, minute, second). To avoid this incompatibility, use PostgreSQL’s to_timestamp(). 

The solution for this incompatibility is to convert TO_DATE() to TO_TIMESTAMP(). If you use Orafce tool then it is not necessary to change anything because Orafce implemented this function so we get the same result as Oracle.


Oracle:

SELECT TO_DATE ('20180314121212','yyyymmddhh24miss') FROM dual;

PostgreSQL:

SELECT TO_TIMESTAMP ('20180314121212','yyyymmddhh24miss')::TIMESTAMP(0);


### SYSDATE ###

- [PostgreSQL날짜 및 시간관련 함수 및 연산자](https://m.blog.naver.com/PostView.nhn?blogId=dev4unet&logNo=220602540023&proxyReferer=https:%2F%2Fwww.google.com%2F)

[oracle]
```
sql> select sysdate, to_char(sysdate, 'yyyy/mm/dd hh24:mi:ss') from dual;
SYSDATE  TO_CHAR(SYSDATE,'YY
-------- -------------------
21/02/27 2021/02/27 14:20:53
```

[postgresql]
```
psql> select date(current_timestamp), current_timestamp;
```



### AWS SCT extension pack (확장내장함수) ###

- 오라클 내장 함수를 PostgreSQL에서 그대로 사용할 수 있도록 구현해 놓은 코드 확장팩. 
- SCT 에 의해 타겟 데이터베이스의 aws_oracle_ext 스키마에 설치됨.
- SCT 는 오라클의 사용자 정의 코드성 오브젝트(프로시저, 함수 등)를 PostgreSQL 용으로 변환시 이 확장팩을 사용함.
- https://docs.aws.amazon.com/SchemaConversionTool/latest/userguide/CHAP_ExtensionPack.html (https://github.com/orafce/orafce)

[oracle]
```
sql> select add_months('2021-02-01', 1) from dual;
ADD_MONT
--------
21/03/01

sql> select add_months(to_date('2021-02-01'), 1) from dual;
ADD_MONT
--------
21/03/01

sql> select TO_DATE('20210227101259','yyyymmddhh24miss') from dual;
TO_DATE(
--------
21/02/27
```

[postgresql]
```
psql> select aws_oracle_ext.add_months('2021-02-01', 1);

psql> select aws_oracle_ext.add_months(date '2021-02-01', 1);

psql> select aws_oracle_ext.TO_DATE('20210227101259','yyyymmddhh24miss');
```
![sct_extpack](https://github.com/gnosia93/postgres-terraform/blob/main/appendix/images/app_sct_extpack.png)


### PL/SQL 변환 ###

- 기본적으로 AWS SCT 를 이용하여 오라클의 PLSQL 코드를 PostgreSQL 로 자동 변환함. 
- 자동 변환이 실패하는 경우 [PostgreSQL plpgsql 포팅가이드](https://www.postgresql.org/docs/current/plpgsql-porting.html) 를 참조하여 수정. 


### 패키지 / Synonyms ###

- PostgreSQL 은 오라클 패키지와 Synonyms를 지원하지 않는다.
- 오라클 패키지는 PostgreSQL 의 스키마로 대체한다. 즉 스키마를 먼저 만들고 해당 스키마 안에 프로시저 및 함수와 같은 코드성 오브젝트를 생성한다.



## 유용한 링크 ##

* [MERGE INTO 구현](https://m.blog.naver.com/wiseyoun07/221146431131)

* [계층쿼리](https://m.blog.naver.com/wiseyoun07/221135850258)

* [열을 행으로 전환](https://m.blog.naver.com/wiseyoun07/221136671840)

* [Orafce - Oracle’s compatibility functions and packages](https://access.crunchydata.com/documentation/orafce/3.11.1/)



## 레퍼런스 ##

- https://uple.net/1601
 
- https://www.pgcon.org/2008/schedule/track/Tutorial/62.en.html

- https://wiki.postgresql.org/wiki/Converting_from_other_Databases_to_PostgreSQL#Oracle

- [The Complete Oracle to PostgreSQL Migration Guide: Move and convert Schema, Application & Data](https://www.enterprisedb.com/blog/the-complete-oracle-to-postgresql-migration-guide-tutorial-move-convert-database-oracle-alternative?gclid=CjwKCAiAouD_BRBIEiwALhJH6EYfjIYgfljHPqXSBbnmgypKWRxzegJ7hbYfSb_vAxrj2ywcVu1C7xoCOpwQAvD_BwE&utm_campaign=Q42020_APAC&utm_medium=cpc&utm_source=google)
