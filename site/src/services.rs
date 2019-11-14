use actix_web::{HttpRequest, Responder, http::StatusCode};
use diesel::query_builder::functions::sql_query;
use diesel::prelude::*;
// use diesel::pg::PgConnection;
use dotenv::dotenv;
use std::env;
use diesel::prelude::*;
use diesel::sql_types::Text;
use diesel::result::Error as err;
use diesel::r2d2::{self, ConnectionManager};
use actix_web::web::Data;

use crate::schema;
use crate::models::*;
use std::sync::Arc;

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

    let app_filter = apps::table.filter(apps::domain.eq(host_lower)).first::<App>(pg_conn).unwrap();
    let mut results: Vec<(View, Route)> = View::belonging_to(&app_filter).inner_join(
        routes::table.on(
            views::id.eq(routes::view_id).and(
                routes::pattern.eq(q_path)
            )
        )
    ).limit(1)
    .load(pg_conn)
    .expect("Error loading apps");

    // println!("PG result {:?}", results);
    
    if results.len() > 0 {
        let result = results.pop().unwrap();
        return Some(result.0);
    }

    return None;
}

pub fn dispatch(view: View) -> HttpResponse {
    if view.mime_type == "text/html" {
        // let mut response = Response::new();
        // response.headers_mut().insert(header::CONTENT_TYPE, "text/html; charset=UTF-8".parse().unwrap());
        // return response;
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

