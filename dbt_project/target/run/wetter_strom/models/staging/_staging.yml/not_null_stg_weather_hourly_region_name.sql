select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select region_name
from "wetter_strom"."public_staging"."stg_weather_hourly"
where region_name is null



      
    ) dbt_internal_test