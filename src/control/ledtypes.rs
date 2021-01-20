use candela::CandelaStrip;

trait AbstractChannel {}
trait AbstractController {}

type LEDAddress = u32;

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct ChannelMapping {
    controller_id: LEDAddress,
    strip_id: LEDAddress,
    start: LEDAddress,
    end: LEDAddress,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct LEDChannel<T> {
    map: Vec<ChannelMapping>,
    virtual_mem: Vec<[u8; 4]>,
    precision: usize,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct LEDController {
    strips: HashMap<LEDAddress, LEDStrip>,
    //addrs: Vec<LEDAddress>,
    location: SocketAddr,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct LEDArray {
    controllers: HashMap<LEDAddress, LEDController>,
    inactive_channels: Vec<LEDChannel>,
    channels: Vec<LEDChannel>,
}