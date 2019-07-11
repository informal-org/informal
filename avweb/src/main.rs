use actix_web::{web, App, HttpServer, Responder};
use actix_web::{HttpRequest, Result};
use actix_files as fs;
use actix_files::NamedFile;


fn hello(info: web::Path<(u32, String)>) -> impl Responder {
    format!("Hello {}! id:{}", info.1, info.0)
}

fn index(_req: HttpRequest) -> Result<NamedFile> {
    Ok(NamedFile::open("templates/index.html")?)
}

fn main() -> std::io::Result<()> {
    HttpServer::new(
        || App::new().service(
              web::resource("/{id}/{name}/index.html").to(hello))
              .service(fs::Files::new("/static", "static").show_files_listing())           // TODO: Disable this in prod.
              .route("/", web::get().to(index))
        )
        .bind("localhost:9000")?
        .run()
}
