use candela::sockets::{CandelaSocketController, CandelaSocketServer};
use super::LEDChannel;

#[derive(Debug)]
struct LEDArray {
    channels: Vec<LEDChannel>,
    inactive_channels: Vec<LEDChannel>,
    server: CandelaSocketServer<Controller = CandelaSocketController>,
}