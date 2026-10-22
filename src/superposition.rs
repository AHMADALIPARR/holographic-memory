use crate::Vector;

pub fn circular_convolution(left: &[f64], right: &[f64]) -> Vec<f64> {
    assert_eq!(left.len(), right.len());
    let dim = left.len();
    let mut result = vec![0.0; dim];

    for k in 0..dim {
        let mut acc = 0.0;
        for j in 0..dim {
            let index = (k - j + dim) % dim;
            acc += left[j] * right[index];
        }
        result[k] = acc;
    }

    result
}

pub fn circular_correlation(left: &[f64], right: &[f64]) -> Vec<f64> {
    assert_eq!(left.len(), right.len());
    let dim = left.len();
    let mut result = vec![0.0; dim];

    for k in 0..dim {
        let mut acc = 0.0;
        for j in 0..dim {
            let index = (j + k) % dim;
            acc += left[j] * right[index];
        }
        result[k] = acc;
    }

    result
}

pub fn bind_role_filler(role: &Vector, filler: &Vector) -> Vector {
    Vector::from_values(circular_convolution(&role.values, &filler.values))
}
