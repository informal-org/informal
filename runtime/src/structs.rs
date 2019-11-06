#[derive(Serialize, PartialEq, Debug, Eq, Ord, PartialOrd)]
pub struct CellResponse {
    pub id: u64,
    pub output: String,
    pub error: String
}

#[derive(Serialize, PartialEq, Debug)]
pub struct EvalResponse {
    pub results: Vec<CellResponse>
}

#[derive(Deserialize,Debug)]
pub struct CellRequest {
    pub id: u64,
    pub input: String,
    pub name: Option<String>
}


#[derive(Deserialize,Debug)]
pub struct AvHttpRequest {
    pub path: String,
    pub method: String,
    pub query: Option<String>
}


#[derive(Deserialize,Debug)]
pub struct EvalRequest {
    pub body: Vec<CellRequest>,
    pub input: Option<AvHttpRequest>
}
