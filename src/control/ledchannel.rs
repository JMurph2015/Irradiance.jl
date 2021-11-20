use candela::Pixel;
use serde::{Deserialize, Serialize};

use super::ChannelMapping;

use std::{
    ops::{Index, IndexMut},
    slice::SliceIndex,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LEDChannel {
    map: Vec<ChannelMapping>,
    virtual_mem: Vec<Pixel>,
    precision: usize,
}

impl<I> Index<I> for LEDChannel
where
    I: SliceIndex<[Pixel]>,
{
    type Output = I::Output;

    fn index(&self, index: I) -> &Self::Output {
        return self.virtual_mem.index(index);
    }
}

impl<I> IndexMut<I> for LEDChannel
where
    I: SliceIndex<[Pixel]>,
{
    fn index_mut(&mut self, index: I) -> &mut Self::Output {
        return self.virtual_mem.index_mut(index);
    }
}

impl<'a> IntoIterator for &'a LEDChannel {
    type Item = &'a Pixel;
    type IntoIter = std::slice::Iter<'a, Pixel>;

    fn into_iter(self) -> std::slice::Iter<'a, Pixel> {
        self.virtual_mem.iter()
    }
}

impl<'a> IntoIterator for &'a mut LEDChannel {
    type Item = &'a mut Pixel;
    type IntoIter = std::slice::IterMut<'a, Pixel>;

    fn into_iter(self) -> std::slice::IterMut<'a, Pixel> {
        self.virtual_mem.iter_mut()
    }
}
