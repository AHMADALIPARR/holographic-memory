use crate::Vector;

pub fn circular_convolution(a: &[f64], b: &[f64]) -> Vec<f64> {
    assert_eq!(a.len(), b.len());
    let n = a.len();
    let mut out = vec![0.0; n];

    for k in 0..n {
        let mut acc = 0.0;
        for j in 0..n {
            let idx = (k - j).rem_euclid(n);
            acc += a[j] * b[idx];
        }
        out[k] = acc;
    }

    out
}

pub fn circular_correlation(a: &[f64], b: &[f64]) -> Vec<f64> {
    assert_eq!(a.len(), b.len());
    let n = a.len();
    let mut out = vec![0.0; n];

    for k in 0..n {
        let mut acc = 0.0;
        for j in 0..n {
            let idx = (j + k).rem_euclid(n);
            acc += a[j] * b[idx];
        }
        out[k] = acc;
    }

    out
}

pub fn bind_role_filler(role: &Vector, filler: &Vector) -> Vector {
    Vector::from_values(circular_convolution(&role.values, &filler.values))
}
