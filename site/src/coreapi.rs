use actix_web::{web, HttpRequest, HttpServer, Responder, HttpResponse};
use crate::services::{AasmData, AasmState};
use crate::models::*;
use actix_web::http::StatusCode;
use actix_web::dev::Body;
use std::any::Any;


#[derive(Serialize, Deserialize, Debug)]
pub struct ResultWrapper<T> {
    pub count: i32,
    pub results: Vec<T>
}


pub fn create_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn get_apps(req: HttpRequest, data: AasmData) -> impl Responder {
    let pg_conn = &data.db.get().unwrap();
    
    // let result = ;
    // println!("{:?}", result);
    // return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))

    let result = ResultWrapper::<App> {
        count: 32,
        results: App::read(&pg_conn)
    };

    return web::Json(result)
}

pub fn get_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn update_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn delete_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

// Note: Routes and views are intertwined in our implementation.

pub fn create_view(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn get_views(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn get_view(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn update_view(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn delete_view(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}