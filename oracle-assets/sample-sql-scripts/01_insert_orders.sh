#!/bin/sh

echo "Populating ORDERS table"

docker exec -i oracle sqlplus C\#\#MYUSER/mypassword@//localhost:1521/$1 << EOF

  insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (6, 54, '123842.70', 'Tesla', '4Runner', 'Huel-Grant', '218 Waxwing Pass', 'Lubbock', 'TX', '79452');
  insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (7, 709, '150508.36', 'Hyundai', 'Elantra', 'Powlowski Group', '26 Reindahl Crossing', 'Austin', 'TX', '78744');
  insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (8, 661, '160019.59', 'Mercedes-Benz', 'C-Class', 'Pfeffer-Harris', '6 Golf View Alley', 'Dallas', 'TX', '75236');

  exit;
EOF