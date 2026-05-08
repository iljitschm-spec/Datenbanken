select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select timestamp
from "wetter_strom"."public_staging"."stg_weather_hourly"
where timestamp is null



      
    ) dbt_internal_test