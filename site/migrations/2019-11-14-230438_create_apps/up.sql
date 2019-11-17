CREATE TABLE apps (
    id SERIAL PRIMARY KEY, 
    app_name Text NOT NULL,
    domain VARCHAR(64) NOT NULL,  -- Primary domains. Future: extra_domains list
    environment VARCHAR(8) NOT NULL,

    created_at timestamp default current_timestamp NOT NULL,
    updated_at timestamp default current_timestamp NOT NULL
)
