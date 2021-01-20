trait AbstractChannel {}
trait AbstractController {}
trait AbstractLEDStrip {}

type Pixel = [u8; 3];
type LEDAddress = u32;

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct ChannelMapping {
    controller_id: LEDAddress,
    strip_id: LEDAddress,
    start: LEDAddress,
    end: LEDAddress,
}