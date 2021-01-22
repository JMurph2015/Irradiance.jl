pub use candela;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}

pub mod effects;
pub mod control;
pub mod sound;

pub use control::{LEDChannel, LEDArray};
pub use effects::{AbstractEffect};

pub struct AudioAnalysis {}

pub fn process_audio(_sample: Vec<u32>) -> AudioAnalysis {unimplemented!()}

pub fn update_channels(array: &mut LEDArray, analysis: &AudioAnalysis, effect: &mut Box<dyn AbstractEffect>) {
    effect.pre_update(analysis);
    for channel in array.get_channels_mut() {
        effect.update(channel, analysis);
    }
    effect.post_update(analysis);
}