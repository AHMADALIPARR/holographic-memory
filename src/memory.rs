use crate::{circular_convolution, Vector};

pub fn bind_role_filler(role: &Vector, filler: &Vector) -> Vector {
    Vector::from_values(circular_convolution(&role.values, &filler.values))
}

pub fn encode_sequence(sequence: &[Vector]) -> Vec<f64> {
    if sequence.is_empty() {
        return vec![];
    }

    let dim = sequence[0].len();
    let mut accumulated = vec![0.0; dim];
    for item in sequence {
        assert_eq!(item.len(), dim);
        for (idx, value) in item.values.iter().enumerate() {
            accumulated[idx] += value;
        }
    }
    accumulated
}

pub fn make_symbol_codebook(symbols: Vec<String>, dim: usize) -> Vec<Vector> {
    use rand::Rng;
    let mut rng = rand::thread_rng();
    symbols
        .into_iter()
        .map(|_| {
            let mut values = Vec::with_capacity(dim);
            for _ in 0..dim {
                values.push(rng.gen::<f64>() * 0.7071067811865476);
            }
            Vector::from_values(values)
        })
        .collect()
}
