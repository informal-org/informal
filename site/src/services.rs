// use actix_web::http::StatusCode;
use dotenv::dotenv;
use std::env;
use actix_web::web::Data;
// use r2d2_postgres::PostgresConnectionManager;
// use postgres::{NoTls, Client};

pub use r2d2;
use r2d2_postgres::PostgresConnectionManager;
use r2d2::ManageConnection;
use postgres::{NoTls, Client};

use actix_web::HttpResponse;
use actix_web::dev::Body;

#[derive(Clone)]
pub struct AasmState {
    pub id: i32,
    pub db: DBPool
}

#[derive(Debug)]
pub struct View {
    pub id: i32,
    pub name: String,
    pub mime_type: String,
    pub remote_url: Option<String>,
    pub content: Option<String>,
    pub pattern: String,
    pub pattern_regex: String,
    pub method_get: bool,
    pub method_post: bool
}

pub type DBPool = r2d2::Pool<PostgresConnectionManager<postgres::tls::NoTls>>;
pub type AasmData = Data<AasmState>;


/*
Setup a database connection pool to the postgres db. 
A new instance of the client is created per request typically
*/
pub fn establish_connection() -> DBPool {
    dotenv().ok();
    
    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");

    let manager = PostgresConnectionManager::new(
        database_url.parse().unwrap(),
        NoTls
    );

    let pool = r2d2::Pool::new(manager).unwrap();
    return pool
} 

// , 
const Q_VIEW_RESOLVE: &'static str = "SELECT editor_view.id, editor_view.name, editor_view.mime_type, editor_view.remote_url, 
editor_view.content, editor_view.pattern, editor_view.pattern_regex, editor_view.method_get, editor_view.method_post 
FROM editor_view 
INNER JOIN editor_app ON editor_view.app_id = editor_app.id
WHERE editor_app.domain = $1 AND editor_view.pattern = $2
LIMIT 1";
// TODO: Method

pub fn resolve(pg_client: &mut Client, q_method: String, q_host: String, q_path: String) -> Option<View> {
    for row in &pg_client.query(Q_VIEW_RESOLVE, &[&q_host, &q_path]).unwrap() {
        println!("Found view");
        let view = View {
            id: row.get(0),
            name: row.get(1),
            mime_type: row.get(2),
            remote_url: row.get(3),
            content: row.get(4), 
            pattern: row.get(5),
            pattern_regex: row.get(6),
            method_get: row.get(7),
            method_post: row.get(8)
        };
        
        return Some(view)
    }
    return None

}

    



//     // use schema::apps::dsl::*;
//     // use schema::routes::dsl::*;
//     // use schema::views::dsl::*;
//     use schema::*;

//     println!("Method: {} host {} path {}", q_method, q_host, q_path);
//     let host_lower = q_host.to_lowercase();

//     let app_filter_result = apps::table.filter(apps::domain.eq(host_lower)).first::<App>(pg_conn);
//     if let Err(_) = app_filter_result {
//         println!("Error loading apps");
//         return None;
//     }
//     let app_filter = app_filter_result.unwrap();


//     let views_result = View::belonging_to(&app_filter).inner_join(
//         routes::table.on(
//             views::id.eq(routes::view_id).and(
//                 routes::pattern.eq(q_path)
//             )
//         )
//     ).limit(1)
//     .load(pg_conn);

//     if let Err(_) = views_result {
//         println!("Error loading view");
//         return None;
//     }
//     let mut views: Vec<(View, Route)> = views_result.unwrap();

//     println!("PG result {:?}", views);
    
//     if views.len() > 0 {
//         let result = views.pop().unwrap();
//         return Some(result.0);
//     }

//     return None;
// }

// pub fn dispatch(view: View) -> HttpResponse {
//     if view.mime_type == "text/html" {
//         let content = view.content.unwrap();
//         return HttpResponse::with_body(StatusCode::OK, Body::from(content));
//     }
//     //  else if view.mime_type == "application/javascript" {
//     //     let content = exec_view(view);
//     //     return HttpResponse::with_body(StatusCode::OK, Body::from(content))
//     // }
//      else {
//         // Should not happen
//         // let mut response = Response::new(Body::from("AppAssembly Server Error"));
//         // return response;
//         // return String::from("AppAssembly Server Error");
//         return HttpResponse::with_body(StatusCode::OK, Body::from("AppAssembly Server Error"))
//     }
// }

