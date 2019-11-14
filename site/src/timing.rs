use std::time::Instant;

pub struct Timer {
    pub checkpoint: Instant, 
}

impl Timer {
    pub fn new() -> Timer {
        return Timer {
            checkpoint: Instant::now()
        }
    }

    pub fn checkpoint(&mut self, msg: &str) {
        let start = self.checkpoint;
        self.checkpoint = Instant::now();
        println!("{:?}: {:?}", msg, self.checkpoint.duration_since(start));
    }
}