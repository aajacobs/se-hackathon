#!/bin/sh

echo 'Deleting ORDERS with order_id=7'

docker exec -i oracle sqlplus C\#\#MYUSER/mypassword@//localhost:1521/$1 << EOF
  delete from ORDERS where order_id = 7;
  exit;
EOF
