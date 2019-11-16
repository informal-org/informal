use actix_web::{web, App, HttpRequest, HttpServer, Responder, HttpResponse};
use crate::services::{AasmData, AasmState};
use actix_web::http::StatusCode;
use actix_web::dev::Body;




pub fn create_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn get_apps(req: HttpRequest, data: AasmData) -> HttpResponse {
    println!("{:?}", App.read());
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
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