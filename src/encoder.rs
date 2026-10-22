use crate::{generate_symbol, Vector};

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

pub fn symbol_codebook(names: &[String], dim: usize) -> Vec<Vector> {
    names.iter().map(|name| generate_symbol(name, dim)).collect()
}
