use crate::{AudioAnalysis, LEDChannel};

pub trait AbstractEffect {
    fn pre_update(&mut self, _analysis: &AudioAnalysis) {}
    fn update(&self, channel: &mut LEDChannel, analysis: &AudioAnalysis);
    fn post_update(&mut self, _analysis: &AudioAnalysis) {}
}