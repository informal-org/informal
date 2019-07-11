#[macro_use]
extern crate serde_derive;

#[derive(Serialize, Deserialize)]
pub struct CellResult {
    pub output: String,
    pub error: String
}

// fn evaluate(_req: HttpRequest) -> {
//     let cell_result = CellResult {
//         output: "1",
//         error: "",
//     };

//     let result_str = serde_json::to_string(&cell_result);

//     let mut body = BytesMut::with_capacity(SIZE);
//     serde_json::to_writer(Writer(&mut body), &message).unwrap();

//     let mut res = HttpResponse::with_body(StatusCode::OK, Body::Bytes(body.freeze()));
//     res.headers_mut()
//         .insert(SERVER, HeaderValue::from_static("Actix"));
//     res.headers_mut()
//         .insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
//     res

// }

// fn index(_req: HttpRequest) -> Result<NamedFile> {
//     Ok(NamedFile::open("templates/index.html")?)
// }

// fn main() -> std::io::Result<()> {
//     HttpServer::new(
//         || App::new().service(
//               web::resource("/{id}/{name}/index.html").to(hello))
//               .service(fs::Files::new("/static", "static/dist").show_files_listing())           // TODO: Disable this in prod.
//               .route("/", web::get().to(index))
//         )
//         .bind("localhost:9000")?
//         .run()
// }
extern crate hyper;
extern crate futures;
extern crate hyper_staticfile;



// use futures::future;
// use hyper::{Body, Request, Response, Server};
// use hyper::rt::Future;
// use hyper::service::service_fn_ok;
// use hyper::{Method, StatusCode};
// use hyper::service::service_fn;

use hyper::{Server};

use futures::{Async::*, Future, Poll, future};
use http::response::Builder as ResponseBuilder;
use http::{Request, Response, StatusCode, header};
use hyper::Body;
use hyper_staticfile::{Static, StaticFuture};
use std::path::Path;
use std::io::Error;

enum MainFuture {
    Root,
    Static(StaticFuture<Body>),
}

type BoxFut = Box<dyn Future<Item=Response<Body>, Error=hyper::Error> + Send>;

impl Future for MainFuture {
    type Item = Response<Body>;
    type Error = Error;

    fn poll(&mut self) -> Poll<Self::Item, Self::Error> {
        match *self {
            MainFuture::Root => {
                let res = ResponseBuilder::new()
                    // .status(StatusCode::MOVED_PERMANENTLY)
                    // .header(header::LOCATION, "/hyper_staticfile/")
                    .body(Body::empty())
                    .expect("unable to build response");
                Ok(Ready(res))
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
        } else {
            MainFuture::Root
        }
    }
}




static TEXT: &str = "Hello, World!";


// fn echo(req: Request<Body>) -> BoxFut {
//     let mut response = Response::new(Body::empty());

//     // TODO: move this out
//     let static_ = hyper_staticfile::Static::new("templates/");

//     match (req.method(), req.uri().path()) {
//         (&Method::GET, "/") => {
//             *response.body_mut() = {
//                 static_.serve(req)
//                 // Body::from("Try POSTing data to /echo");
//             }
//         },
//         (&Method::GET, "/echo") => {
//             *response.body_mut() = {

//                 let (parts, body) = req.into_parts();
//                 Body::from(parts.uri.to_string())
//             }
//         },
//         _ => {
//             *response.status_mut() = StatusCode::NOT_FOUND;
//         },
//     };

//     Box::new(future::ok(response))
// }



fn main() {
    let addr = ([127, 0, 0, 1], 9000).into();

    // let new_svc = || {
    //     service_fn(echo)
    // };

    let server = Server::bind(&addr)
        .serve(|| future::ok::<_, Error>(MainService::new()))
        // .serve(new_svc)
        .map_err(|e| eprintln!("server error: {}", e));

    hyper::rt::run(server);
}

