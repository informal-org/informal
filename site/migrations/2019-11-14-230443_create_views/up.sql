CREATE TABLE views (
    id SERIAL PRIMARY KEY, 
    app_id integer REFERENCES apps NOT NULL,
    view_name VARCHAR(64),
    
    mime_type VARCHAR(64) NOT NULL,
    asset_url VARCHAR(255),
    content TEXT,

    created_at timestamp default current_timestamp NOT NULL,
    updated_at timestamp default current_timestamp NOT NULL
)
