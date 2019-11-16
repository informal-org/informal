use actix_web::{web, App, HttpRequest, HttpServer, Responder, HttpResponse};
use crate::services::{AasmData, AasmState};
use actix_web::http::StatusCode;
use actix_web::dev::Body;


/*

        app.put(prefix + 'apps', Core.createApp)
        app.get(prefix + 'apps', Core.getApps)
        app.get(prefix + 'apps/:appId', Core.getApp)
        app.post(prefix + 'apps/:appId', Core.updateApp)
        app.delete(prefix + 'apps/:appId', Core.deleteApp)
        
        app.put(prefix + 'views', Core.createView)
        app.get(prefix + 'views', Core.getViews)
        app.get(prefix + 'views/:viewId', Core.getView)
        app.post(prefix + 'views/:viewId', Core.updateView)
        app.delete(prefix + 'views/:viewId', Core.deleteView)
        
        app.put(prefix + 'routes', Core.createRoute)
        app.get(prefix + 'routes', Core.getRoutes)
        app.get(prefix + 'routes/:routeId', Core.getRoute)
        app.post(prefix + 'routes/:routeId', Core.updateRoute)
        app.delete(prefix + 'routes/:routeId', Core.deleteRoute)

*/

fn create_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

fn get_apps(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

fn get_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

fn update_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

fn delete_app(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

// Note: Routes and views are intertwined in our implementation.

fn create_view(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

fn get_views(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

fn get_view(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

fn update_view(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}

fn delete_view(req: HttpRequest, data: AasmData) -> HttpResponse {
    return HttpResponse::with_body(StatusCode::OK, Body::from("OK"))
}