mod cleanup;
mod convolution;
mod correlation;
mod encoder;
mod memory;
mod superposition;
mod vector;

pub use cleanup::cleanup_nearest_neighbor;
pub use convolution::{bind_role_filler, circular_convolution, circular_correlation};
pub use correlation::correlation_inverse;
pub use encoder::{encode_sequence, make_symbol_codebook, symbol_vector};
pub use memory::Memory;
pub use superposition::superimpose;
pub use vector::{cosine_similarity, Vector};
