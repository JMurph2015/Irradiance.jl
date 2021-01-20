#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct LEDController<T> {
    strips: HashMap<LEDAddress, LEDStrip<T>>,
    addrs: Vec<T>,
    location: SocketAddr,
}