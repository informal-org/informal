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


#[derive(Serialize, Deserialize, Debug)]
pub struct AppSummary {
    pub id: i32,
    pub app_name: String,
    pub domain: String,
    // Ignore environment and timestamps.
    pub views: Vec<ViewSummary>
}


#[derive(Serialize, Deserialize, Debug)]
pub struct ViewSummary {
    pub id: i32,
    pub view_name: Option<String>,
    pub mime_type: String,
    pub asset_url: Option<String>,
    pub routes: Vec<RouteSummary>
}

#[derive(Serialize, Deserialize, Debug)]
pub struct RouteSummary {
    pub id: i32,
    pub route_name: Option<String>,
    pub pattern: String,
    pub pattern_regex: String,

    pub methods: Vec<String>
}

pub fn create_app(req: HttpRequest, data: AasmData) -> impl Responder {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn get_apps(req: HttpRequest, data: AasmData) -> impl Responder {
    let pg_conn = &data.db.get().unwrap();

    let result = ResultWrapper::<App> {
        count: 32,
        results: App::read(&pg_conn)
    };

    return web::Json(result)
}

pub fn get_app(req: HttpRequest, data: AasmData) -> impl Responder {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn update_app(req: HttpRequest, data: AasmData) -> impl Responder {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn delete_app(req: HttpRequest, data: AasmData) -> impl Responder {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

// Note: Routes and views are intertwined in our implementation.

pub fn create_view(req: HttpRequest, data: AasmData) -> impl Responder {
    let pg_conn = &data.db.get().unwrap();

    let v = new_view(&conn, 1, Some(String::from("Test")), String::from("text/html"))

    return web::Json(v);
}

pub fn get_views(req: HttpRequest, data: AasmData) -> impl Responder {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn get_view(req: HttpRequest, data: AasmData) -> impl Responder {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn update_view(req: HttpRequest, data: AasmData) -> impl Responder {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

pub fn delete_view(req: HttpRequest, data: AasmData) -> impl Responder {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}