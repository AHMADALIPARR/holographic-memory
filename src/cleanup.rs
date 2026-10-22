use crate::{cosine_similarity, Vector};

pub fn cleanup_nearest_neighbor(target: &Vector, codebook: &[Vector]) -> (String, f64) {
    let mut best_index = 0usize;
    let mut best_score = f64::NEG_INFINITY;

    for (idx, candidate) in codebook.iter().enumerate() {
        let score = cosine_similarity(&target.values, &candidate.values);
        if score > best_score {
            best_score = score;
            best_index = idx;
        }
    }

    (format!("symbol_{}", best_index), best_score)
}
