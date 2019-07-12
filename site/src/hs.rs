extern crate hyper;
extern crate futures;
extern crate hyper_staticfile;
extern crate runtime;
#[macro_use]
extern crate serde_derive;

use serde_json;
use std::path::Path;
use std::io::Error;
use futures::{Async::*, Future, Poll, future};
use http::response::Builder as ResponseBuilder;
use http::{Request, Response, StatusCode, header};
use hyper::{Server, Body};
use hyper_staticfile::{Static, StaticFuture};
use runtime::repl::{read_eval};

static REQ_ERR: &'static str = "Unable to build response";
static CONTENT_TYPE: &'static str = "Content-Type";

#[derive(Serialize, Deserialize)]
pub struct CellResult {
    pub output: String,
    pub error: String
}

fn eval_expr(req: &Request<Body>) -> Poll<Response<Body>, Error> {
    let expr = String::from(req.uri().query().unwrap());
    let evaluated = read_eval(String::from(expr));
    let res = ResponseBuilder::new()
    .body(Body::from(evaluated))
    .expect(REQ_ERR);
    Ok(Ready(res))
}

fn evaluate(req: &Request<Body>) -> Poll<Response<Body>, Error> {
    let cell_result = CellResult {
        output: "42".to_owned(),
        error: "".to_owned(),
    };
    let result_str = serde_json::to_string(&cell_result)?;
    println!("{:?}", result_str);
    let res = ResponseBuilder::new()
    .status(StatusCode::OK)
    .body(Body::from("result_str"))
    .expect(REQ_ERR);
    
    return Ok(Ready(res))

    // res.headers_mut()
    //     .insert(SERVER, HeaderValue::from_static("Actix"));
    // res.headers_mut()
    //     .insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    // res
}

enum MainFuture {
    Root,
    ArevelEval(Request<Body>),
    Static(StaticFuture<Body>),
}

impl Future for MainFuture {
    type Item = Response<Body>;
    type Error = Error;

    fn poll(&mut self) -> Poll<Self::Item, Self::Error> {
        match *self {
            MainFuture::Root => {
                let res = ResponseBuilder::new()
                    .status(StatusCode::NOT_FOUND)
                    .body(Body::from("Not Found"))
                    .expect("unable to build response");
                Ok(Ready(res))
            },
            MainFuture::ArevelEval(ref req) => {
                eval_expr(req)
            },
            MainFuture::Static(ref mut future) => {
                future.poll()
            }
        }
    }
}

/// Hyper `Service` implementation that serves all requests.
struct MainService {
    template_: Static,
    static_: Static,
}

impl MainService {
    fn new() -> MainService {
        MainService {
            template_: Static::new(Path::new("templates/")),
            static_: Static::new(Path::new("static/dist/"))
        }
    }
}

impl hyper::service::Service for MainService {
    type ReqBody = Body;
    type ResBody = Body;
    type Error = Error;
    type Future = MainFuture;

    fn call(&mut self, req: Request<Body>) -> MainFuture {
        if req.uri().path() == "/" {
            MainFuture::Static(self.template_.serve(req))
        } else if req.uri().path().starts_with("/static") {
            MainFuture::Static(self.static_.serve(req))
        } else if req.uri().path().starts_with("/eval") {
            MainFuture::ArevelEval(req)
        } else {
            MainFuture::Root
        }
    }
}



fn hyper_main() {
    let addr = ([127, 0, 0, 1], 9000).into();
    let resp = read_eval(String::from("1 + 1"));

    // let new_svc = || {
    //     service_fn(echo)
    // };

    let server = Server::bind(&addr)
        .serve(|| future::ok::<_, Error>(MainService::new()))
        // .serve(new_svc)
        .map_err(|e| eprintln!("server error: {}", e));

    hyper::rt::run(server);
}

