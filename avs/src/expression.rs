use crate::format::fmt_symbols_list;
use core::fmt;
use crate::structs::Atom;


#[derive(PartialEq,Clone)]
pub struct Expression {
    pub cell_id: u64,
    pub symbol: u64,
    pub input: String,
    pub parsed: Vec<Atom>,
    pub used_by: Vec<u64>,
    pub depends_on: Vec<u64>,
    pub unmet_depend_count: i32,     // Internal dependency counter used during ordering.
    pub result: Option<u64>
}


#[cfg(not(target_os = "unknown"))]
impl fmt::Debug for Expression {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut parts = vec![];
        parts.push(String::from("Expression {\n"));
        parts.push(format!("\tid: {:#?}\n", self.cell_id));
        parts.push(format!("\tinput: {:#?}\n", self.input));
        parts.push(format!("\tcell_symbol: {:X}\n", self.symbol));
        parts.push(format!("\tparsed: {:#?}\n", self.parsed));
        parts.push(format!("\tdepends_on: {} \n", fmt_symbols_list(&self.depends_on)));
        parts.push(format!("\tused_by: {}\n", fmt_symbols_list(&self.used_by)));
        parts.push(format!("\tunmet_depend_count: {:#?}\n", self.unmet_depend_count));
        if self.result.is_some() {
            parts.push(format!("\tresult: {:X}\n", self.result.unwrap()));
        }

        parts.push(String::from("}"));
        write!(f, "{}", parts.join(""))
    }
}

impl Expression {
    pub fn new(cell_id: u64, input: String) -> Expression {
        return Expression {
            cell_id: cell_id,
            symbol: 0,
            input: input,
            parsed: Vec::with_capacity(0), 
            depends_on: Vec::with_capacity(0),
            used_by: Vec::with_capacity(0),
            unmet_depend_count: 0,
            result: None
        }
    }

    // pub fn err(cell_id: u64, error: u64) -> Expression {
    //     let mut node = Expression::new(cell_id);
    //     node.result = Some(error);
    //     return node;
    // }

    pub fn set_result(&mut self, result: u64) {
        // Set result only if it wasn't previously set to avoid clobbering errors.
        if self.result.is_none() {
            self.result = Some(result);
        }
    }
}

