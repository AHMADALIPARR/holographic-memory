use crate::{cleanup_nearest_neighbor, circular_correlation, Vector};

pub struct Memory {
    dim: usize,
    bindings: Vec<Vector>,
}

impl Memory {
    pub fn new(dim: usize) -> Self {
        Self {
            dim,
            bindings: Vec::new(),
        }
    }

    pub fn store_role_filler(&mut self, role: &Vector, filler: &Vector) {
        assert_eq!(role.len(), self.dim);
        assert_eq!(filler.len(), self.dim);
        self.bindings.push(crate::convolution::bind_role_filler(role, filler));
    }

    pub fn store_binding(&mut self, binding: &Vector) {
        assert_eq!(binding.len(), self.dim);
        self.bindings.push(binding.clone());
    }

    pub fn retrieve(&self, cue: &Vector, codebook: &[Vector]) -> (String, f64) {
        let mut memory_state = vec![0.0; self.dim];
        for binding in &self.bindings {
            for (idx, value) in binding.values.iter().enumerate() {
                memory_state[idx] += value;
            }
        }

        let recovered = circular_correlation(&cue.values, &memory_state);
        let probe = Vector::from_values(recovered);
        cleanup_nearest_neighbor(&probe, codebook)
    }
}
