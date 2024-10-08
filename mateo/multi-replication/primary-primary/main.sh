#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o posix

docker compose up -d
sleep 20
docker exec sql-primary01 bash -c "mariadb -uroot -ph -e \"STOP SLAVE;\" mydb2"
docker exec sql-primary02 bash -c "mariadb -uroot -ph -e \"STOP SLAVE;\" mydb2"

docker exec sql-primary01 bash -c "mariadb -uroot -ph -e \"ALTER USER 'replication_user'@'%' IDENTIFIED VIA mysql_native_password USING PASSWORD('h')\" mydb2"
docker exec sql-primary02 bash -c "mariadb -uroot -ph -e \"ALTER USER 'replication_user'@'%' IDENTIFIED VIA mysql_native_password USING PASSWORD('h')\" mydb2"

docker exec sql-primary01 bash -c "mariadb -uroot -ph -e \"CHANGE MASTER TO MASTER_HOST='sql-primary02', MASTER_USER='replication_user', MASTER_PASSWORD='h', MASTER_PORT=3306, MASTER_USE_GTID=slave_pos, MASTER_CONNECT_RETRY=10;\" mydb2"
docker exec sql-primary02 bash -c "mariadb -uroot -ph -e \"CHANGE MASTER TO MASTER_HOST='sql-primary01', MASTER_USER='replication_user', MASTER_PASSWORD='h', MASTER_PORT=3306, MASTER_USE_GTID=slave_pos, MASTER_CONNECT_RETRY=10;\" mydb2"

docker exec sql-primary01 bash -c "mariadb -uroot -ph -e \"START SLAVE;\" mydb2"
docker exec sql-primary02 bash -c "mariadb -uroot -ph -e \"START SLAVE;\" mydb2"

docker exec sql-primary01 bash -c "mariadb -uroot -ph -e \"SHOW SLAVE STATUS\\G\" mydb2"
docker exec sql-primary02 bash -c "mariadb -uroot -ph -e \"SHOW SLAVE STATUS\\G\" mydb2"

docker exec sql-primary01 bash -c "mariadb -uroot -ph -e \"CREATE TABLE IF NOT EXISTS test_table (id INT PRIMARY KEY, value VARCHAR(100)); INSERT INTO test_table (id,value) VALUES (1, 'Test from primary01');\" mydb2"

sleep 5

docker exec sql-primary02 bash -c "mariadb -uroot -ph -e \"SELECT * FROM test_table;\" mydb2"
docker exec sql-primary02 bash -c "mariadb -uroot -ph -e \"INSERT INTO test_table (id, value) VALUES (2, 'Test from primary02');\" mydb2"

sleep 5

docker exec sql-primary01 bash -c "mariadb -uroot -ph -e \"SELECT * FROM test_table;\" mydb2"

