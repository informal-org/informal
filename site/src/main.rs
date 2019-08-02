use actix_files as fs;
use actix_files::NamedFile;
use actix_web::{web, App, HttpRequest, HttpServer, Responder};
use runtime::format;
use runtime::interpreter::{interpret_all};
use runtime::structs::{CellResponse, EvalRequest, EvalResponse};

fn home(_req: HttpRequest) -> actix_web::Result<NamedFile> {
    // let path: PathBuf = req.match_info().query("filename").parse().unwrap();
    return Ok(NamedFile::open("templates/index.html")?)
}

fn evaluate(req: web::Json<EvalRequest>) -> impl Responder {
    let mut results: Vec<CellResponse> = Vec::new();

    let mut inputs: Vec<String> = Vec::with_capacity(results.len());
    for cell in &req.body {
        inputs.push(cell.input.clone())
    }

    let eval_res = interpret_all(req.into_inner());
    return web::Json(eval_res)
}

pub fn main() {
    HttpServer::new(|| {
        App::new()
        .route("/", web::get().to(home))
        .route("/api/evaluate", web::post().to(evaluate))
        .service(fs::Files::new("/static", "static/dist/static"))
    })
    .bind("127.0.0.1:9080")
    .expect("Can not bind to port 9080")
    .run()
    .unwrap();
}
