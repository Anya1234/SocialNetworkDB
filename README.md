# SocialNetworkDB

*Project suggesting simle DB model for Social Network*  
**Implemented on PostgreSQL** 

<ul>
  <li>DDL.sql - creation schema and tables with all restrictions</li>
  <li>inserts.sql - inserting data</li>
  <li>queries.sql - some select queries</li>
  <li>triggers_and_functions.sql - 
    <ul>
          <li>function for getting user by id</li>
          <li>procedure forwarding message with attachment</li>
          <li>trigger: on update or insert of user add new version of them saving old</li>
          <li>trigger: on inserting comment to comment auto fill post id </li>
          <li>triggers for autofilling some other values</li>
    </ul>
    </li>
  <li>view.sql - create some views </li>
</ul>

# Logical model

<img width="896" alt="Логическая модель 3" src="https://user-images.githubusercontent.com/54975860/145679157-ad192349-1f64-4dac-abc8-e9886e6b635b.png">

# Tables Description

![Снимок экрана 2021-12-11 в 16 57 01](https://user-images.githubusercontent.com/54975860/145679245-1c090c03-0056-40a5-b67f-d3964f1888d6.png)
![Снимок экрана 2021-12-11 в 16 55 49](https://user-images.githubusercontent.com/54975860/145679187-f5b6d535-0d0f-4402-8842-0ef181a2d04d.png)
![Снимок экрана 2021-12-11 в 16 55 58](https://user-images.githubusercontent.com/54975860/145679192-ce99c4e9-b4ca-43bc-b171-5ba462f2f2a6.png)
![Снимок экрана 2021-12-11 в 16 56 08](https://user-images.githubusercontent.com/54975860/145679205-5a5201f5-8fff-4752-a62b-538ef8250761.png)
![Снимок экрана 2021-12-11 в 16 56 17](https://user-images.githubusercontent.com/54975860/145679220-6b953f57-650b-44a2-8abb-1e3041d7b8af.png)
![Снимок экрана 2021-12-11 в 16 56 27](https://user-images.githubusercontent.com/54975860/145679223-ec4f9f50-4f48-471e-90b4-91b066c633a7.png)
![Снимок экрана 2021-12-11 в 16 56 45](https://user-images.githubusercontent.com/54975860/145679232-0ad85c6a-5cdf-447d-81b5-1937ab4d1114.png)

