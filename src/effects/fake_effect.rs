use crate::{AbstractEffect, AudioAnalysis, LEDChannel};

pub struct FakeEffect {}

impl Default for FakeEffect {
    fn default() -> Self {
        unimplemented!()
    }
}

impl AbstractEffect for FakeEffect {
    fn update(&self, channel: &mut LEDChannel, analysis: &AudioAnalysis) {
        unimplemented!()
    }
}
