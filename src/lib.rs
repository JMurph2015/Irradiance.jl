pub use candela;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

pub mod control;
pub mod effects;
pub mod sound;

pub use control::{LEDArray, LEDChannel};
pub use effects::{AbstractEffect, FakeEffect};

pub struct AudioAnalysis {}

pub fn process_audio(_sample: Vec<u32>) -> AudioAnalysis {
    unimplemented!()
}
