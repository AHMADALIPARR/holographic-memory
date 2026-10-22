use crate::{bind_role_filler, circular_convolution, Vector};

pub fn make_symbol_codebook(symbols: Vec<String>, dim: usize) -> Vec<Vector> {
    symbols
        .into_iter()
        .map(|name| crate::vector::symbol_vector(&name, dim))
        .collect()
}

pub fn symbol_vector(name: &str, dim: usize) -> Vector {
    crate::vector::symbol_vector(name, dim)
}

pub fn encode_sequence(sequence: &[Vector]) -> Vec<f64> {
    if sequence.is_empty() {
        return vec![];
    }
    let dim = sequence[0].len();
    let mut acc = vec![0.0; dim];
    for vector in sequence {
        assert_eq!(vector.len(), dim);
        for (idx, value) in vector.values.iter().enumerate() {
            acc[idx] += value;
        }
    }
    acc
}
