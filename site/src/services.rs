use actix_web::http::StatusCode;
use diesel::prelude::*;
// use diesel::pg::PgConnection;
use dotenv::dotenv;
use std::env;
use diesel::r2d2::{self, ConnectionManager};
use actix_web::web::Data;

use crate::schema;
use crate::models::*;
use crate::schema::{apps, views, routes};


use actix_web::HttpResponse;
use actix_web::dev::Body;


#[derive(Clone)]
pub struct AasmState {
    pub id: i32,
    pub db: DBPool
}


pub type DBPool = r2d2::Pool<ConnectionManager<PgConnection>>;
pub type AasmData = Data<AasmState>;

pub fn establish_connection() -> DBPool {
    dotenv().ok();

    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    let manager = ConnectionManager::<PgConnection>::new(database_url);

    // PgConnection::establish(&database_url)
    //     .expect(&format!("Error connecting to {}", database_url))

    let pool = r2d2::Pool::builder()
        .build(manager)
        .expect("Failed to create pool.");

    return pool;

}


pub fn resolve(pg_conn: &PgConnection, q_method: String, q_host: String, q_path: String) -> Option<View> {
    // use schema::apps::dsl::*;
    // use schema::routes::dsl::*;
    // use schema::views::dsl::*;
    use schema::*;

    println!("Method: {} host {} path {}", q_method, q_host, q_path);
    let host_lower = q_host.to_lowercase();

    let app_filter_result = apps::table.filter(apps::domain.eq(host_lower)).first::<App>(pg_conn);
    if let Err(_) = app_filter_result {
        println!("Error loading apps");
        return None;
    }
    let app_filter = app_filter_result.unwrap();


    let views_result = View::belonging_to(&app_filter).inner_join(
        routes::table.on(
            views::id.eq(routes::view_id).and(
                routes::pattern.eq(q_path)
            )
        )
    ).limit(1)
    .load(pg_conn);

    if let Err(_) = views_result {
        println!("Error loading view");
        return None;
    }
    let mut views: Vec<(View, Route)> = views_result.unwrap();

    println!("PG result {:?}", views);
    
    if views.len() > 0 {
        let result = views.pop().unwrap();
        return Some(result.0);
    }

    return None;
}

pub fn dispatch(view: View) -> HttpResponse {
    if view.mime_type == "text/html" {
        let content = view.content.unwrap();
        return HttpResponse::with_body(StatusCode::OK, Body::from(content));
    }
    //  else if view.mime_type == "application/javascript" {
    //     let content = exec_view(view);
    //     return HttpResponse::with_body(StatusCode::OK, Body::from(content))
    // }
     else {
        // Should not happen
        // let mut response = Response::new(Body::from("AppAssembly Server Error"));
        // return response;
        // return String::from("AppAssembly Server Error");
        return HttpResponse::with_body(StatusCode::OK, Body::from("AppAssembly Server Error"))
    }
}



#[derive(Insertable)]
#[table_name="views"]
pub struct NewView {
    pub app_id: i32,
    pub view_name: Option<String>,
    pub mime_type: String
}

pub fn new_view(conn: &PgConnection, app_id: i32, view_name: Option<String>, mime_type: String) -> View {
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


#[derive(Insertable)]
#[table_name="apps"]
pub struct NewApp {
    pub app_name: String,
    pub domain: String,
}

