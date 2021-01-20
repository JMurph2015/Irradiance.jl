#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct LEDArray<T> {
    controllers: HashMap<LEDAddress, LEDController<T>>,
    inactive_channels: Vec<LEDChannel<T>>,
    channels: Vec<LEDChannel<T>>,
}