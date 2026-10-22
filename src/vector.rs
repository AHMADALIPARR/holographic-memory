// ASSISTANT REPAIR (2026-10-22, labeled per repo convention): added
// the rand trait import below. As published, the file did not compile:
// `seed_from_u64` and `gen` live on traits that were not in scope.
// No logic changed.
use rand::{Rng, SeedableRng};
use std::f64::consts::PI;

#[derive(Clone, Debug, PartialEq)]
pub struct Vector {
    pub values: Vec<f64>,
}

impl Vector {
    pub fn new(dim: usize) -> Self {
        Self {
            values: vec![0.0; dim],
        }
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
        self.values.iter().map(|value| value * value).sum::<f64>().sqrt()
    }

    pub fn cosine_similarity(&self, other: &Self) -> f64 {
        let denom = self.norm() * other.norm();
        if denom == 0.0 {
            0.0
        } else {
            self.dot(other) / denom
        }
    }

    pub fn len(&self) -> usize {
        self.values.len()
    }
}

pub fn cosine_similarity(left: &[f64], right: &[f64]) -> f64 {
    assert_eq!(left.len(), right.len());
    let dot = left.iter().zip(right.iter()).map(|(a, b)| a * b).sum::<f64>();
    let left_norm = left.iter().map(|value| value * value).sum::<f64>().sqrt();
    let right_norm = right.iter().map(|value| value * value).sum::<f64>().sqrt();
    if left_norm == 0.0 || right_norm == 0.0 {
        0.0
    } else {
        dot / (left_norm * right_norm)
    }
}

pub fn generate_symbol(name: &str, dim: usize) -> Vector {
    let mut seed = 0u64;
    for byte in name.as_bytes() {
        seed = seed.wrapping_mul(131).wrapping_add(*byte as u64);
    }

    let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
    let values: Vec<f64> = (0..dim)
        .map(|_| {
            let u1: f64 = rng.gen();
            let u2: f64 = rng.gen();
            let radius = (-2.0 * u1.ln()).sqrt();
            let theta = 2.0 * PI * u2;
            (radius * theta.cos()) / (dim as f64).sqrt()
        })
        .collect();
    Vector { values }
}

pub fn random_vector(dim: usize, seed: u64) -> Vector {
    let mut rng = rand::rngs::StdRng::seed_from_u64(seed);
    let values: Vec<f64> = (0..dim)
        .map(|_| {
            let u1: f64 = rng.gen();
            let u2: f64 = rng.gen();
            let radius = (-2.0 * u1.ln()).sqrt();
            let theta = 2.0 * PI * u2;
            (radius * theta.cos()) / (dim as f64).sqrt()
        })
        .collect();
    Vector { values }
}
