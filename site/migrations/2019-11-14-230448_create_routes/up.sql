CREATE TABLE routes (
    id SERIAL PRIMARY KEY, 
    app_id integer REFERENCES apps NOT NULL,
    view_id integer REFERENCES views NOT NULL,
    
    route_name Text,
    
    pattern VARCHAR NOT NULL,
    pattern_regex VARCHAR NOT NULL,
    
    method_get boolean default TRUE NOT NULL,
    method_post boolean default TRUE NOT NULL,
    extra_methods Text[]
)
