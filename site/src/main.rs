use std::path::PathBuf;
use actix_files as fs;
use actix_files::NamedFile;
use actix_web::{web, App, HttpRequest, HttpServer, Responder};
use runtime::repl::{read_eval};

#[macro_use]
extern crate serde_derive;

#[derive(Serialize)]
struct CellResult {
    id: String,
    output: String,
    error: String
}

#[derive(Serialize)]
struct EvalResponse {
    results: Vec<CellResult>
}

fn home(req: HttpRequest) -> actix_web::Result<NamedFile> {
    // let path: PathBuf = req.match_info().query("filename").parse().unwrap();
    return Ok(NamedFile::open("templates/index.html")?)
}

fn evaluate(req: HttpRequest) -> impl Responder {
    let mut results: Vec<CellResult> = Vec::new();
    results.push(CellResult { id: "id01".to_string(), output: "42".to_string(), error: "".to_string() });
    results.push(CellResult { id: "id02".to_string(), output: "1".to_string(), error: "".to_string() });
    results.push(CellResult { id: "id03".to_string(), output: "4".to_string(), error: "".to_string() });

    return web::Json(EvalResponse{results: results} )
}

fn eval_expr(req: HttpRequest) -> impl Responder {
    let q = req.uri().query().unwrap();
    return read_eval(String::from(q))
}

pub fn main() {
    HttpServer::new(|| {
        App::new()
        .route("/", web::get().to(home))
        .route("/evaluate", web::get().to(evaluate))
        .route("/api/evaluate", web::post().to(evaluate))
        .service(fs::Files::new("/static", "static/dist/static").show_files_listing())
        // .route("/eval", web::get().to(eval_expr))
    })
    .bind("127.0.0.1:9000")
    .expect("Can not bind to port 8000")
    .run()
    .unwrap();
}