#!/bin/sh

echo 'Upate ORDERS with order_id = 3'

docker exec -i oracle sqlplus C\#\#MYUSER/mypassword@//localhost:1521/$1 << EOF
  update ORDERS set make = 'Tesla', model = 'Model X' where order_id = 3;
  exit;
EOF
