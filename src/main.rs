#[allow(unused_imports)]
use irradiance::{
    sound::{FakeSoundProvider, IrradianceSoundProvider},
    *,
};

use std::thread;
use std::sync::mpsc::{channel, Sender, Receiver};

enum ControlMessage {
    Stop(),
}

fn main() {
    let (tx, rx): (Sender<ControlMessage>, Receiver<ControlMessage>) = channel();
    thread::spawn(move || {
        audio_processing_thread();
    });
    handle_command_line();
    println!("Hello World!");
}

fn audio_processing_thread() {
    let mut array = init_led_array();
    let mut provider = FakeSoundProvider::new();
    let mut effect: Box<dyn AbstractEffect> = Box::new(FakeEffect::default());
    provider.init();
    loop {
        let sample = provider.read(16);
        let analysis = process_audio(sample);
        update_channels(&mut array, &analysis, &mut effect);
    }
}

fn update_channels(
    array: &mut LEDArray,
    analysis: &AudioAnalysis,
    effect: &mut Box<dyn AbstractEffect>,
) {
    effect.pre_update(analysis);
    for channel in array.get_channels_mut() {
        effect.update(channel, analysis);
    }
    effect.post_update(analysis);
}

fn init_led_array() -> LEDArray {
    unimplemented!()
}

fn handle_command_line() {}
