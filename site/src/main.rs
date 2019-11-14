#[macro_use]
extern crate diesel;
extern crate dotenv;

#[macro_use]
extern crate lazy_static;

#[macro_use]
extern crate serde_derive;

#[macro_use]
pub mod schema;
pub mod models;
pub mod services;
pub mod timing;

use actix_files as fs;
use actix_files::NamedFile;
use actix_web::{web, App, HttpRequest, HttpServer, Responder, HttpResponse};
use runtime::format;
use runtime::interpreter::{interpret_all};
use runtime::structs::{CellResponse, EvalRequest, EvalResponse};


use crate::services::{resolve, dispatch, establish_connection};
use futures::future::{ok, Future};
use diesel::pg::PgConnection;

use std::sync::Arc;

use crate::services::{ DBPool, AasmData, AasmState };
use actix_web::http::StatusCode;
use actix_web::dev::Body;



// const TEMPLATE_ROOT = "/var/www/arevelcom/templates/";
// const STATIC_ROOT = "/var/www/arevelcom/static/";


fn landing(_req: HttpRequest) -> actix_web::Result<NamedFile> {
    // let path: PathBuf = req.match_info().query("filename").parse().unwrap();
    return Ok(NamedFile::open("/var/www/arevelcom/templates/landing.html")?)
}

fn arevel(_req: HttpRequest) -> actix_web::Result<NamedFile> {
    // return Ok(NamedFile::open("/var/www/arevelcom/templates/index.html")?)
    return Ok(NamedFile::open("templates/index.html")?)
}

fn slides(_req: HttpRequest) -> impl Responder {
    return HttpResponse::TemporaryRedirect().set_header("location", "https://docs.google.com/presentation/d/19Z9IGLz_NO1PN3LDTi492W_4l68WHTrmVG9Xxou8_lY/edit?usp=sharing").finish();
}

fn health() -> impl Responder {
    return "OK"
}

fn evaluate(req: web::Json<EvalRequest>) -> impl Responder {
    // println!("{:?}", req);
    let mut results: Vec<CellResponse> = Vec::new();

    let mut inputs: Vec<String> = Vec::with_capacity(results.len());
    for cell in &req.body {
        inputs.push(cell.input.clone())
    }

    let eval_res = interpret_all(req.into_inner());
    return web::Json(eval_res)
}



fn serve(req: HttpRequest, data: AasmData) -> HttpResponse {
    println!("Data is {:?}", data.id);

    let host = req.headers().get("host").unwrap().to_str().unwrap().to_string();
    let method = req.method().to_string();
    let path = req.uri().path().to_string();

    let pg_conn = &data.db.get().unwrap();
    let maybe_view = resolve(&pg_conn, method, host, path);
    

    if let Some(view) = maybe_view {
        return dispatch(view);
    } else {
        // let mut response = Response::new(Body::from("Not Found"));
        // let status = resp.status_mut();
        // *response.status_mut() = StatusCode::NOT_FOUND;
        // return "Not Found";
        return HttpResponse::with_body(StatusCode::NOT_FOUND, Body::from("Not Found"))
    }
}


pub fn main() {
    let connection_pool = establish_connection();
    let state = AasmState { id: 1, db: connection_pool };

    HttpServer::new(move || App::new()
    .data(
        state.clone()
    )
    .route("/", web::get().to(landing))
    .route("/arevel", web::get().to(arevel))
    .route("/slides", web::get().to(slides))
    .route("/_info/health", web::get().to(health))
    .route("/api/evaluate", web::post().to(evaluate))    
    .service(
        web::resource("*").to(serve))
    )
    .bind("127.0.0.1:9080")
    .expect("Can not bind to port 9080")
    .run();
}
