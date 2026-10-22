use crate::Vector;

pub fn circular_convolution(left: &[f64], right: &[f64]) -> Vec<f64> {
    assert_eq!(left.len(), right.len());
    let dim = left.len();
    let mut out = vec![0.0; dim];

    for k in 0..dim {
        let mut acc = 0.0;
        for j in 0..dim {
            let idx = (k - j).rem_euclid(dim);
            acc += left[j] * right[idx];
        }
        out[k] = acc;
    }
    out
}

pub fn circular_correlation(left: &[f64], right: &[f64]) -> Vec<f64> {
    assert_eq!(left.len(), right.len());
    let dim = left.len();
    let mut out = vec![0.0; dim];

    for k in 0..dim {
        let mut acc = 0.0;
        for j in 0..dim {
            let idx = (j + k).rem_euclid(dim);
            acc += left[j] * right[idx];
        }
        out[k] = acc;
    }
    out
}

pub fn bind_role_filler(role: &Vector, filler: &Vector) -> Vector {
    Vector::from_values(circular_convolution(&role.values, &filler.values))
}
