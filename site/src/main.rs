use actix_files as fs;
use actix_files::NamedFile;
use actix_web::{web, App, HttpRequest, HttpServer, Responder, HttpResponse};
use runtime::format;
use runtime::interpreter::{interpret_all};
use runtime::structs::{CellResponse, EvalRequest, EvalResponse};

fn landing(_req: HttpRequest) -> actix_web::Result<NamedFile> {
    // let path: PathBuf = req.match_info().query("filename").parse().unwrap();
    return Ok(NamedFile::open("/var/www/arevelcom/templates/landing.html")?)
}

fn arevel(_req: HttpRequest) -> actix_web::Result<NamedFile> {
    return Ok(NamedFile::open("/var/www/arevelcom/templates/index.html")?)
}

fn slides(_req: HttpRequest) -> impl Responder {
    return HttpResponse::TemporaryRedirect().set_header("location", "https://docs.google.com/presentation/d/19Z9IGLz_NO1PN3LDTi492W_4l68WHTrmVG9Xxou8_lY/edit?usp=sharing").finish();
}

fn health() -> impl Responder {
    return "OK"
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
        .route("/", web::get().to(landing))
        .route("/arevel", web::get().to(arevel))
        .route("/slides", web::get().to(slides))
        .route("/_info/health", web::get().to(health))
        .route("/api/evaluate", web::post().to(evaluate))
        .service(fs::Files::new("/static", "/var/www/arevelcom/static/"))  // static/dist/static
    })
    .bind("0.0.0.0:9080")
    .expect("Can not bind to port 9080")
    .run()
    .unwrap();
}
