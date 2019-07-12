use std::path::PathBuf;
use actix_files as fs;
use actix_files::NamedFile;
use actix_web::{web, App, HttpRequest, HttpServer, Responder};
use runtime::repl::{read_eval};

#[macro_use]
extern crate serde_derive;

#[derive(Serialize)]
struct CellResponse {
    id: String,
    output: String,
    error: String
}

#[derive(Serialize)]
struct EvalResponse {
    results: Vec<CellResponse>
}

#[derive(Deserialize)]
struct CellRequest {
    id: String,
    input: String,
}

#[derive(Deserialize)]
struct EvalRequest {
    body: Vec<CellRequest>
}

fn home(req: HttpRequest) -> actix_web::Result<NamedFile> {
    // let path: PathBuf = req.match_info().query("filename").parse().unwrap();
    return Ok(NamedFile::open("templates/index.html")?)
}

fn evaluate(req: web::Json<EvalRequest>) -> impl Responder {
    
    let mut results: Vec<CellResponse> = Vec::new();
    for cell in &req.body {
        results.push(CellResponse { id: cell.id.clone(), output: read_eval(String::from(cell.input.clone())), error: "".to_string() });
    }
    
    // results.push(CellResponse { id: "id02".to_string(), output: "1".to_string(), error: "".to_string() });
    // results.push(CellResponse { id: "id03".to_string(), output: "4".to_string(), error: "".to_string() });

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