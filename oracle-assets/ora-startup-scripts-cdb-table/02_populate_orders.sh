#!/bin/sh

echo 'Populating ORDERS table'

sqlplus C\#\#MYUSER/mypassword@//localhost:1521/ORCLCDB  <<- EOF

insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (1, ABC123, '97815.52', 'Honda', 'Accord Crosstour', 'Ortiz-Herzog', '1237 Lakewood Gardens Circle', 'Dallas', 'TX', '75358');
insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (2, 546, '167579.06', 'Ford', 'Tempo', 'Jacobson-Kiehn', '539 Fisk Park', 'Dallas', 'TX', '75205');
insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (3, 274, '15007.98', 'Audi', 'A4', 'Gleason Inc', '22 Mockingbird Hill', 'Lubbock', 'TX', '79491');
insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (4, 2, '38717.84', 'Isuzu', 'Ascender', 'Reichel, Murphy and Mann', '8330 Novick Hill', 'El Paso', 'TX', '88558');
insert into ORDERS (order_id, customer_id, order_total_usd, make, model, delivery_company, delivery_address, delivery_city, delivery_state, delivery_zip) values (5, 321, '93684.57', 'Honda', 'Civic', 'Langosh-Rolfson', '01962 Northland Parkway', 'Amarillo', 'TX', '79182');

  exit;
EOF
