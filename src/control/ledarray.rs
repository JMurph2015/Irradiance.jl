use super::LEDChannel;
use candela::sockets::{CandelaSocketController, CandelaSocketServer};

#[derive(Debug)]
pub struct LEDArray {
    channels: Vec<LEDChannel>,
    inactive_channels: Vec<LEDChannel>,
    server: CandelaSocketServer<Controller = CandelaSocketController>,
}

impl LEDArray {
    pub fn get_channels(&self) -> &Vec<LEDChannel> {
        return &self.channels;
    }

    pub fn get_channels_mut(&mut self) -> &mut Vec<LEDChannel> {
        return &mut self.channels;
    }
}
