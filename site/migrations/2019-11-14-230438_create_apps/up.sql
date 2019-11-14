CREATE TABLE apps (
    id SERIAL PRIMARY KEY, 
    app_name VARCHAR(64) NOT NULL,
    domain VARCHAR NOT NULL,  -- Primary domains. Future: extra_domains list
    environment smallint default 0 NOT NULL,

    created_at timestamp default current_timestamp NOT NULL,
    updated_at timestamp default current_timestamp NOT NULL
)
