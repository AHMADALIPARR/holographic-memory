use rand::Rng;

#[derive(Clone, Debug)]
pub struct Vector {
    pub values: Vec<f64>,
}

impl Vector {
    pub fn new(dim: usize) -> Self {
        Self { values: vec![0.0; dim] }
    }

    pub fn from_values(values: Vec<f64>) -> Self {
        Self { values }
    }

    pub fn add_assign(&mut self, other: &Self) {
        assert_eq!(self.values.len(), other.values.len());
        for (lhs, rhs) in self.values.iter_mut().zip(other.values.iter()) {
            *lhs += *rhs;
        }
    }

    pub fn dot(&self, other: &Self) -> f64 {
        assert_eq!(self.values.len(), other.values.len());
        self.values
            .iter()
            .zip(other.values.iter())
            .map(|(a, b)| a * b)
            .sum()
    }

    pub fn norm(&self) -> f64 {
        self.values.iter().map(|v| v * v).sum::<f64>().sqrt()
    }

    pub fn len(&self) -> usize {
        self.values.len()
    }
}

pub fn cosine_similarity(left: &[f64], right: &[f64]) -> f64 {
    assert_eq!(left.len(), right.len());

    let dot = left.iter().zip(right.iter()).map(|(a, b)| a * b).sum::<f64>();
    let left_norm = left.iter().map(|v| v * v).sum::<f64>().sqrt();
    let right_norm = right.iter().map(|v| v * v).sum::<f64>().sqrt();

    if left_norm == 0.0 || right_norm == 0.0 {
        0.0
    } else {
        dot / (left_norm * right_norm)
    }
}

pub fn symbol_codebook(names: &[String], dim: usize) -> Vec<Vector> {
    names.iter().map(|name| generate_symbol(name, dim)).collect()
}

fn generate_symbol(name: &str, dim: usize) -> Vector {
    let mut seed = 0u64;
    for byte in name.as_bytes() {
        seed = seed.wrapping_mul(131).wrapping_add(*byte as u64);
    }

    let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
    let values: Vec<f64> = (0..dim)
        .map(|_| {
            let u1: f64 = rng.gen();
            let u2: f64 = rng.gen();
            let r = (-2.0 * u1.ln()).sqrt();
            let theta = 2.0 * std::f64::consts::PI * u2;
            (r * theta.cos()) / (dim as f64).sqrt()
        })
        .collect();
    Vector { values }
}
