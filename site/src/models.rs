use std::time::SystemTime;
use crate::schema::*;
use diesel::pg::PgConnection;
use diesel::prelude::*;


#[derive(Identifiable, Queryable, PartialEq, Debug, AsChangeset, Serialize, Deserialize)]
pub struct App {
    pub id: i32,
    pub app_name: String,
    pub domain: String,
    pub environment: i16,
    
    pub created_at: SystemTime,
    pub updated_at: SystemTime,
}

impl App {
    pub static fn read(conn: &PgConnection) -> Vec<App> {
        return apps::table.limit(10).load::<App>(conn).unwrap()
    }
}


#[derive(Identifiable, Queryable, PartialEq, Debug, Associations, AsChangeset, Serialize, Deserialize)]
#[belongs_to(App)]
pub struct View {
    pub id: i32,
    pub app_id: i32,
    pub view_name: Option<String>,

    pub mime_type: String,
    pub asset_url: Option<String>,
    pub content: Option<String>,
    
    pub created_at: SystemTime,
    pub updated_at: SystemTime,
}


#[derive(Identifiable, Queryable, PartialEq, Debug, Associations, AsChangeset, Serialize, Deserialize)]
#[belongs_to(App, View)]
pub struct Route {
    pub id: i32,
    pub app_id: i32, 
    pub view_id: i32,
    pub route_name: Option<String>,
    
    pub pattern: String,
    pub pattern_regex: String,

    pub method_get: bool, 
    pub method_post: bool, 
    pub extra_methods: Option<Vec<i16>>
}

