#!/bin/sh

echo 'Populating CUSTOMERS table after altering the structure'

docker exec -i oracle sqlplus C\#\#MYUSER/mypassword@//localhost:1521/$1 << EOF
  insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (10, 225, '46692.87', 'Lexus', 'LS', 'Ernser Inc', '6382 Melody Avenue', 'San Antonio', 'TX', '78278');
  insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (11, 587, '117712.29', 'Mazda', 'B-Series', 'Hand-Howe', '0273 Forest Run Circle', 'San Antonio', 'TX', '78225');
  insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (12, 897, '11286.83', 'Mitsubishi', 'Endeavor', 'Gislason-McLaughlin', '9385 Nobel Drive', 'Houston', 'TX', '77260');
  insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (13, 751, '68346.01', 'Porsche', 'Cayenne', 'Bode and Sons', '98143 Tony Court', 'El Paso', 'TX', '88574');
  insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (14, 444, '212654.82', 'Chrysler', '300', 'Reinger, Dach and Donnelly', '064 Del Mar Court', 'Houston', 'TX', '77266');
 
  exit;
EOF
