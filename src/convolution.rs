use rand::Rng;

#[derive(Clone, Debug, PartialEq)]
pub struct Vector {
    pub values: Vec<f64>,
}

impl Vector {
    pub fn new(dim: usize, value: f64) -> Self {
        Self {
            values: vec![value; dim],
        }
    }

    pub fn from_values(values: Vec<f64>) -> Self {
        Self { values }
    }

    pub fn random_normal(dim: usize) -> Self {
        let mut rng = rand::thread_rng();
        let mut values = Vec::with_capacity(dim);
        for _ in 0..dim {
            values.push(rng.gen::<f64>() * 0.7071067811865476);
        }
        Self { values }
    }

    pub fn add(&self, other: &Self) -> Self {
        let dim = self.values.len();
        assert_eq!(dim, other.values.len());
        Self {
            values: self
                .values
                .iter()
                .zip(other.values.iter())
                .map(|(a, b)| a + b)
                .collect(),
        }
    }

    pub fn add_assign(&mut self, other: &Self) {
        assert_eq!(self.values.len(), other.values.len());
        for (left, right) in self.values.iter_mut().zip(other.values.iter()) {
            *left += *right;
        }
    }

    pub fn scale(&self, factor: f64) -> Self {
        Self {
            values: self.values.iter().map(|v| v * factor).collect(),
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

    pub fn zero(dim: usize) -> Self {
        Self::new(dim, 0.0)
    }

    pub fn len(&self) -> usize {
        self.values.len()
    }
}

impl std::fmt::Display for Vector {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Vector(len={})", self.values.len())
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

pub fn generate_normal_vector(dim: usize) -> Vector {
    Vector::random_normal(dim)
}

pub fn make_symbol_codebook(symbols: Vec<String>, dim: usize) -> Vec<Vector> {
    let mut rng = rand::thread_rng();
    symbols
        .into_iter()
        .map(|_| {
            let mut vals = Vec::with_capacity(dim);
            for _ in 0..dim {
                vals.push(rng.gen::<f64>() * 0.7071067811865476);
            }
            Vector { values: vals }
        })
        .collect()
}
