use serde::{Serialize, Deserialize};

mod ledchannel;
pub use ledchannel::LEDChannel;
mod ledarray;
pub use ledarray::LEDArray;

trait AbstractChannel {}
trait AbstractController {}
trait AbstractLEDStrip {}

type LEDAddress = u32;

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct ChannelMapping {
    controller_id: LEDAddress,
    strip_id: LEDAddress,
    start: LEDAddress,
    end: LEDAddress,
}