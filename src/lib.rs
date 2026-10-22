mod cleanup;
mod convolution;
mod correlation;
mod encoder;
mod memory;
mod superposition;
mod vector;

pub use cleanup::cleanup_nearest_neighbor;
pub use convolution::{bind_role_filler, circular_convolution, circular_correlation, convolution_fft};
pub use correlation::approximate_unbind;
pub use encoder::{encode_sequence, symbol_codebook};
pub use memory::Memory;
pub use superposition::superimpose;
pub use vector::{cosine_similarity, generate_symbol, random_vector, Vector};
