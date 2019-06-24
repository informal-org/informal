

// fn main() {
//     println!("Hello, world!");
// }


extern crate actix_web;
#[macro_use] extern crate serde_derive;
use actix_web::{server, App, HttpRequest, Responder, Result, Json, http::Method};

#[derive(Serialize)]
struct HealthStatus {
    status: String,
}


fn greet(req: &HttpRequest) -> impl Responder {
    let to = req.match_info().get("name").unwrap_or("World");
    format!("Hello {}!", to)
}

fn health(req: &HttpRequest) -> Result<Json<HealthStatus>> {
    Ok(Json(HealthStatus{status: "OK".to_string()}))
}

fn server() {
    server::new(|| {
        App::new()
            .resource("/_health", |r| r.method(Method::GET).f(health))
            // .resource("/", |r| r.f(greet))
            // .resource("/{name}", |r| r.f(greet))
    })
    .bind("127.0.0.1:8000")
    .expect("Can not bind to port 8000")
    .run();
}
