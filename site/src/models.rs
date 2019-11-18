use std::time::SystemTime;
use crate::schema::*;
use diesel::pg::PgConnection;
use diesel::prelude::*;


#[derive(Identifiable, Queryable, PartialEq, Debug, AsChangeset, Serialize, Deserialize)]
pub struct App {
    pub id: i32,
    pub app_name: String,
    pub domain: String,
    pub environment: String,
    
    #[serde(with = "serde_millis")]
    pub created_at: SystemTime,
    
    #[serde(with = "serde_millis")]
    pub updated_at: SystemTime,
}

impl App {
    pub fn read(conn: &PgConnection) -> Vec<App> {
        return apps::table.limit(10).load::<App>(conn).unwrap()
    }
}

#[derive(Insertable)]
#[table_name="apps"]
pub struct NewApp {
    pub app_name: String,
    pub domain: String,
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
    
    #[serde(with = "serde_millis")]
    pub created_at: SystemTime,
    
    #[serde(with = "serde_millis")]
    pub updated_at: SystemTime,
}

#[derive(Insertable)]
#[table_name="views"]
pub struct NewView {
    pub app_id: i32,
    pub view_name: Option<String>,
    pub mime_type: String
}

pub fn create_view(conn: &PgConnection, app_id: i32, view_name: Option<String>, mime_type: String) -> View {
    use crate::schema::views;

    let new_view = NewView {
        app_id: app_id,
        view_name: view_name,
        mime_type: mime_type
    };

    diesel::insert_into(views::table)
        .values(&new_view)
        .get_result(conn)
        .expect("Error saving new view")
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
    pub extra_methods: Option<Vec<String>>
}

