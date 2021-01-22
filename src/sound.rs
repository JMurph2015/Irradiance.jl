#![allow(unused_variables)]

pub trait IrradianceSoundProvider {
    fn new() -> Self;
    fn init(&mut self);
    /// Read audio from the provider
    /// 
    /// # Arguments
    /// * `length` - The number of milliseconds of audio to get.
    fn read(&mut self, length: u32) -> Vec<u32>;
}

pub struct FakeSoundProvider {}

impl IrradianceSoundProvider for FakeSoundProvider {
    fn new() -> Self {
        unimplemented!()
    }

    fn init(&mut self) {
        unimplemented!();
    }

    fn read(&mut self, length: u32) -> Vec<u32> {
        unimplemented!()
    }
}

pub struct MiniaudioSoundProvider {}

impl IrradianceSoundProvider for MiniaudioSoundProvider {
    fn new() -> Self {
        unimplemented!()
    }

    fn init(&mut self) {
        unimplemented!()
    }

    fn read(&mut self, length: u32) -> Vec<u32> {
        unimplemented!()
    }
}