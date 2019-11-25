use runtime::interpreter::interpret_all;
use runtime::structs::CellResponse;
use runtime::structs::EvalRequest;
pub use r2d2;
use r2d2_postgres::PostgresConnectionManager;
use postgres::{NoTls, Client};
use dotenv::dotenv;
use std::env;
use actix_web::HttpResponse;
use actix_web::web::Data;
use actix_web::http::StatusCode;
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

    
pub fn dispatch(view: View) -> HttpResponse {
    if view.mime_type == "text/html" {
        let content = view.content.unwrap();
        return HttpResponse::with_body(StatusCode::OK, Body::from(content));
    }
     else if view.mime_type == "application/aasm" && view.content.is_some() {
        let req: EvalRequest = serde_json::from_str(&view.content.unwrap()).unwrap();
        let results: Vec<CellResponse> = Vec::new();

        let mut inputs: Vec<String> = Vec::with_capacity(results.len());
        for cell in &req.body {
            inputs.push(cell.input.clone())
        }
    
        let eval_res = interpret_all(req);
        println!("{:?}", eval_res);
        
        let response_content = serde_json::to_string(&eval_res).unwrap();
        return HttpResponse::with_body(StatusCode::OK, Body::from(response_content))
    }
     else {
        // Should not happen
        // let mut response = Response::new(Body::from("AppAssembly Server Error"));
        // return response;
        // return String::from("AppAssembly Server Error");
        return HttpResponse::with_body(StatusCode::OK, Body::from("AppAssembly Server Error"))
    }
}

