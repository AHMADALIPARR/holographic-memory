use std::f64::consts::PI;

#[derive(Clone, Copy, Debug, PartialEq)]
struct Complex {
    re: f64,
    im: f64,
}

impl Complex {
    fn new(re: f64, im: f64) -> Self {
        Self { re, im }
    }

    fn add(self, rhs: Self) -> Self {
        Self::new(self.re + rhs.re, self.im + rhs.im)
    }

    fn sub(self, rhs: Self) -> Self {
        Self::new(self.re - rhs.re, self.im - rhs.im)
    }

    fn mul(self, rhs: Self) -> Self {
        Self::new(
            self.re * rhs.re - self.im * rhs.im,
            self.re * rhs.im + self.im * rhs.re,
        )
    }
}

fn fft(values: &[f64]) -> Vec<Complex> {
    let n = values.len();
    let mut a: Vec<Complex> = values.iter().map(|v| Complex::new(*v, 0.0)).collect();

    let mut j = 0usize;
    for i in 1..n {
        let mut bit = n >> 1;
        while j & bit != 0 {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;
        if i < j {
            a.swap(i, j);
        }
    }

    let mut len = 2usize;
    while len <= n {
        let angle = -2.0 * PI / len as f64;
        let wlen = Complex::new(angle.cos(), angle.sin());
        for i in (0..n).step_by(len) {
            let mut w = Complex::new(1.0, 0.0);
            for k in 0..(len / 2) {
                let u = a[i + k];
                let v = a[i + k + len / 2].mul(w);
                a[i + k] = u.add(v);
                a[i + k + len / 2] = u.sub(v);
                w = w.mul(wlen);
            }
        }
        len <<= 1;
    }

    a
}

fn ifft(values: &[Complex]) -> Vec<f64> {
    let n = values.len();
    let mut a = values.to_vec();

    let mut j = 0usize;
    for i in 1..n {
        let mut bit = n >> 1;
        while j & bit != 0 {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;
        if i < j {
            a.swap(i, j);
        }
    }

    let mut len = 2usize;
    while len <= n {
        let angle = 2.0 * PI / len as f64;
        let wlen = Complex::new(angle.cos(), angle.sin());
        for i in (0..n).step_by(len) {
            let mut w = Complex::new(1.0, 0.0);
            for k in 0..(len / 2) {
                let u = a[i + k];
                let v = a[i + k + len / 2].mul(w);
                a[i + k] = u.add(v);
                a[i + k + len / 2] = u.sub(v);
                w = w.mul(wlen);
            }
        }
        len <<= 1;
    }

    a.into_iter().map(|value| value.re / n as f64).collect()
}

use crate::Vector;

pub fn circular_convolution(a: &[f64], b: &[f64]) -> Vec<f64> {
    assert_eq!(a.len(), b.len());
    let n = a.len();
    let mut out = vec![0.0; n];

    for k in 0..n {
        let mut acc = 0.0;
        for j in 0..n {
            // ASSISTANT REPAIR (2026-10-22, labeled): was
            // `(k - j).rem_euclid(n)` on usize, which underflows in
            // release builds when k < j. For power-of-two n the
            // wrapped index is accidentally correct mod n, masking
            // the bug at the demo dimensions (64, 1024); at n = 3 it
            // returned [30, 25, 28] where the true convolution is
            // [31, 31, 28]. Signed arithmetic is correct for all n
            // and identical wherever the old code was correct.
            let idx = (k as i64 - j as i64).rem_euclid(n as i64) as usize;
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
            // ASSISTANT REPAIR (2026-10-22, labeled): was `(j + k)`,
            // which recovers the index-reversed (involuted) operand:
            // correlating (key (*) value) with key returned
            // value[-k], whose cosine similarity to value is ~0 —
            // the cause of the failing binding/unbinding test. The
            // (j - k) form is the standard HRR correlation and
            // recovers value[k] itself. approximate_unbind swapped
            // its arguments in a way that cancelled this sign error,
            // so the library path's outputs are unchanged by this
            // fix (same sums, reindexed); only the direct function's
            // convention is corrected.
            let idx = (j as i64 - k as i64).rem_euclid(n as i64) as usize;
            acc += a[j] * b[idx];
        }
        out[k] = acc;
    }

    out
}

pub fn convolution_fft(a: &[f64], b: &[f64]) -> Vec<f64> {
    assert_eq!(a.len(), b.len());
    let n = a.len();
    assert!(n.is_power_of_two(), "FFT convolution requires power-of-two length");

    let fa = fft(a);
    let fb = fft(b);
    let product = fa
        .into_iter()
        .zip(fb.into_iter())
        .map(|(lhs, rhs)| lhs.mul(rhs))
        .collect::<Vec<_>>();

    ifft(&product)
}

pub fn bind_role_filler(role: &Vector, filler: &Vector) -> Vector {
    Vector::from_values(circular_convolution(&role.values, &filler.values))
}
