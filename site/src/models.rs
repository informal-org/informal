use std::time::SystemTime;
use crate::schema::*;

#[derive(Identifiable, Queryable, PartialEq, Debug)]
pub struct App {
    pub id: i32,
    pub app_name: String,
    pub domain: String,
    pub environment: i16,
    
    pub created_at: SystemTime,
    pub updated_at: SystemTime,
}

#[derive(Identifiable, Queryable, PartialEq, Debug, Associations)]
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


#[derive(Identifiable, Queryable, PartialEq, Debug, Associations)]
#[belongs_to(App, Route)]
pub struct Route {
    pub id: i32,
    pub app_id: i32, 
    pub route_name: Option<String>,
    
    pub pattern: String,
    pub pattern_regex: String,

    pub method_get: bool, 
    pub method_post: bool, 
    pub extra_methods: Option<Vec<i16>>,

    pub view_id: i32
}

