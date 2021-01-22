#[allow(unused_imports)]
use irradiance::{
    *,
    sound::{FakeSoundProvider, IrradianceSoundProvider}
};

fn main() {
    let mut provider = FakeSoundProvider::new();
    provider.init();
    loop {
        let sample = provider.read(16);
        let analysis = process_audio(sample);


    }
    println!("Hello World!");
}