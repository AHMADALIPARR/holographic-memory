use crate::{cleanup_nearest_neighbor, circular_correlation, Vector};

pub struct Memory {
    dim: usize,
    bindings: Vec<Vector>,
}

impl Memory {
    pub fn new(dim: usize) -> Self {
        Self { dim, bindings: Vec::new() }
    }

    pub fn store_role_filler(&mut self, role: &Vector, filler: &Vector) {
        assert_eq!(role.len(), self.dim);
        assert_eq!(filler.len(), self.dim);
        let binding = crate::convolution::bind_role_filler(role, filler);
        self.bindings.push(binding);
    }

    pub fn recover_filler(&self, role: &Vector, codebook: &[Vector]) -> (String, f64) {
        let mut superposed = vec![0.0; self.dim];

        for binding in &self.bindings {
            for (idx, value) in binding.values.iter().enumerate() {
                superposed[idx] += value;
            }
        }

        let recovered = circular_correlation(&role.values, &superposed);
        let probe = Vector::from_values(recovered);
        cleanup_nearest_neighbor(&probe, codebook)
    }
}
