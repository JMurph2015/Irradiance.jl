#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct LEDChannel<T> {
    map: Vec<ChannelMapping>,
    virtual_mem: Vec<T>,
    precision: usize,
}

impl<I, T> Index<I> for LEDChannel<T>
where:
    I: SliceIndex<[T]> {
    type Output = I::Output;

    fn index(&self, index: I) -> &Self::Output {
        return self.virtual_mem[index];
    }
}

impl<I, T> Index<I> for LEDChannel<T>
where:
    I: SliceIndex<[T]> {
    type Output = I::Output;

    fn index(&mut self, index: I) -> &mut Self::Output {
        return self.virtual_mem[index];
    }
}

impl<'a, T> IntoIterator for &'a LEDChannel<T> {
    type Item = &'a T;
    type IntoIter = slice::Iter<'a, T>;

    fn into_iter(self) -> slice::Iter<'a, T> {
        self.virtual_mem.iter()
    }
}

impl<'a, T> IntoIterator for &'a mut LEDChannel<T> {
    type Item = &'a mut T;
    type IntoIter = slice::IterMut<'a, T>;

    fn into_iter(self) -> slice::IterMut<'a, T> {
        self.virtual_mem.iter_mut()
    }
}