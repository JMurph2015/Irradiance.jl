#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
struct LEDStrip<T> {
    name: String,
    subArray: &mut [T],
    idxRange: Range,
}

impl LEDStrip {
    pub fn len(&self) -> usize {
        return self.subArray.len();
    }
}

impl AbstractLEDStrip for LEDStrip<T, U> {}

impl<T, I> Index<I> for LEDStrip<T>
where:
    I: SliceIndex<[T]> {
    type Output = I::Output;
    fn index(&self, index: I) -> &Self::Output {
        return self.subArray[index];
    }
}

impl<T, U, I> IndexMut<I> for LEDStrip<T, U>
where:
    T: AbstractChannel,
    U: AbstractController,
    I: SliceIndex<[Pixel]> {
    type Output = I::Output;
    fn index(&mut self, index: I) -> &mut Self::Output {
        return self.subArray[index];
    }
}

impl<'a, T> IntoIterator for &'a LEDChannel<T> {
    type Item = &'a T;
    type IntoIter = slice::Iter<'a, T>;

    fn into_iter(self) -> slice::Iter<'a, T> {
        self.subArray.iter()
    }
}

impl<'a, T> IntoIterator for &'a mut LEDChannel<T> {
    type Item = &'a mut T;
    type IntoIter = slice::IterMut<'a, T>;

    fn into_iter(self) -> slice::IterMut<'a, T> {
        self.subArray.iter_mut()
    }
}