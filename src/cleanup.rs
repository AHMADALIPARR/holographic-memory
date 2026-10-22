use crate::Vector;

pub fn superimpose(vectors: &[Vector]) -> Vector {
    if vectors.is_empty() {
        return Vector::zero(0);
    }

    let dim = vectors[0].len();
    let mut acc = vec![0.0; dim];
    for vector in vectors {
        assert_eq!(vector.len(), dim);
        for (i, value) in vector.values.iter().enumerate() {
            acc[i] += value;
        }
    }
    Vector::from_values(acc)
}
