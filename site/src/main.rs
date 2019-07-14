use std::path::PathBuf;
use actix_files as fs;
use actix_files::NamedFile;
use actix_web::{web, App, HttpRequest, HttpServer, Responder};
use runtime::repl::{read_eval, read_multi, eval, format};
use runtime::interpreter::{interpret_all};

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

    let mut inputs: Vec<String> = Vec::with_capacity(results.len());
    for cell in &req.body {
        // results.push(CellResponse { id: cell.id.clone(), output: read_eval(String::from(cell.input.clone())), error: "".to_string() });
        inputs.push(cell.input.clone())
    }

    // let program_wat = read_multi(inputs);
    // let eval_res = eval(program_wat);
    let eval_res = interpret_all(inputs);

    let size = req.body.len();
    for i in 0..size {
        let cell = &req.body[i];
        let cell_result = eval_res[i];
        results.push(CellResponse { id: cell.id.clone(), output: format(cell_result), error: "".to_string() });
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