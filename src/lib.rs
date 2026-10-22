//! Holographic memory engine (HRR): the Rust crate is the functor
//! layer plus f64 host glue. All bulk arithmetic lives in the
//! WebAssembly module `wasm/hrr_kernels.wat` (compiled to
//! `wasm/hrr_kernels.wasm`, embedded in this crate):
//!
//!   conv(n)     circular convolution, OUT[k] = sum_j A[j]*B[(k-j) mod n]
//!   corr(n)     circular correlation, OUT[k] = sum_j A[j]*B[(j-k) mod n]
//!   fft_conv(n) convolution via the radix-2 FFT in the module
//!   dot_ab(n)   dot product of the A and B regions
//!   add_a_to_out(n), zero_out(n)   superposition accumulation
//!
//! What stays in Rust, by design: the Vector type and its f64
//! plumbing, the functors (bind, unbind, superimpose, cleanup,
//! codebook generation, Memory), and the wasmi host that moves
//! vectors between Rust memory and the module's linear memory
//! (fixed regions: A at 0, B at 131072, OUT at 262144; the module
//! header documents the full layout). Maximum dimension 16384.
//!
//! Convention notes (repairs from the original pure-Rust code,
//! carried over so the history is not lost): the convolution index
//! is the signed (k - j) mod n — an earlier usize version underflowed
//! for k < j and returned wrong values at non-power-of-two sizes
//! (n = 3 gave [30, 25, 28] for the true [31, 31, 28]). The
//! correlation index is (j - k) mod n, the standard HRR form that
//! recovers the bound operand itself rather than its involution.

use std::f64::consts::PI;
use std::sync::{Mutex, MutexGuard, OnceLock};

use rand::Rng;

pub const MAX_DIM: usize = 16384;

const OFF_A: usize = 0;
const OFF_B: usize = 131_072;
const OFF_OUT: usize = 262_144;

const WASM: &[u8] = include_bytes!("../wasm/hrr_kernels.wasm");

// ----------------------------------------------------------------
// Wasm host (private): one instance, serialized access.

struct Host {
    store: wasmi::Store<()>,
    mem: wasmi::Memory,
    conv: wasmi::TypedFunc<i32, ()>,
    corr: wasmi::TypedFunc<i32, ()>,
    fft_conv: wasmi::TypedFunc<i32, ()>,
    dot_ab: wasmi::TypedFunc<i32, f64>,
    add_a_to_out: wasmi::TypedFunc<i32, ()>,
    zero_out: wasmi::TypedFunc<i32, ()>,
}

static HOST: OnceLock<Mutex<Host>> = OnceLock::new();

fn host() -> MutexGuard<'static, Host> {
    HOST.get_or_init(|| Mutex::new(Host::start())).lock().unwrap()
}

impl Host {
    fn start() -> Host {
        let engine = wasmi::Engine::default();
        let module = wasmi::Module::new(&engine, WASM).expect("embedded hrr_kernels.wasm parses");
        let mut store = wasmi::Store::new(&engine, ());
        let mut linker = wasmi::Linker::new(&engine);
        linker
            .func_wrap("env", "cos", |x: f64| x.cos())
            .expect("host cos link");
        linker
            .func_wrap("env", "sin", |x: f64| x.sin())
            .expect("host sin link");
        let instance = linker
            .instantiate(&mut store, &module)
            .expect("instantiate hrr_kernels")
            .start(&mut store)
            .expect("start hrr_kernels");
        Host {
            mem: instance.get_memory(&store, "mem").expect("mem export"),
            conv: instance.get_typed_func(&store, "conv").expect("conv export"),
            corr: instance.get_typed_func(&store, "corr").expect("corr export"),
            fft_conv: instance
                .get_typed_func(&store, "fft_conv")
                .expect("fft_conv export"),
            dot_ab: instance
                .get_typed_func(&store, "dot_ab")
                .expect("dot_ab export"),
            add_a_to_out: instance
                .get_typed_func(&store, "add_a_to_out")
                .expect("add_a_to_out export"),
            zero_out: instance
                .get_typed_func(&store, "zero_out")
                .expect("zero_out export"),
            store,
        }
    }

    fn write_region(&mut self, offset: usize, values: &[f64]) {
        let mut bytes = Vec::with_capacity(values.len() * 8);
        for value in values {
            bytes.extend_from_slice(&value.to_le_bytes());
        }
        self.mem
            .write(&mut self.store, offset, &bytes)
            .expect("write wasm memory");
    }

    fn read_out(&mut self, n: usize) -> Vec<f64> {
        let mut bytes = vec![0u8; n * 8];
        self.mem
            .read(&self.store, OFF_OUT, &mut bytes)
            .expect("read wasm memory");
        bytes
            .chunks_exact(8)
            .map(|chunk| f64::from_le_bytes(chunk.try_into().unwrap()))
            .collect()
    }

    fn binary_op(&mut self, func: wasmi::TypedFunc<i32, ()>, a: &[f64], b: &[f64]) -> Vec<f64> {
        assert_eq!(a.len(), b.len());
        assert!(a.len() <= MAX_DIM, "dimension exceeds wasm region capacity");
        self.write_region(OFF_A, a);
        self.write_region(OFF_B, b);
        func.call(&mut self.store, a.len() as i32).expect("wasm kernel call");
        self.read_out(a.len())
    }

    fn dot(&mut self, a: &[f64], b: &[f64]) -> f64 {
        assert_eq!(a.len(), b.len());
        assert!(a.len() <= MAX_DIM, "dimension exceeds wasm region capacity");
        self.write_region(OFF_A, a);
        self.write_region(OFF_B, b);
        self.dot_ab
            .call(&mut self.store, a.len() as i32)
            .expect("wasm dot_ab call")
    }

    fn accumulate(&mut self, vectors: &[&[f64]]) -> Vec<f64> {
        let n = vectors[0].len();
        assert!(n <= MAX_DIM, "dimension exceeds wasm region capacity");
        self.zero_out.call(&mut self.store, n as i32).expect("wasm zero_out call");
        for vector in vectors {
            assert_eq!(vector.len(), n);
            self.write_region(OFF_A, vector);
            self.add_a_to_out
                .call(&mut self.store, n as i32)
                .expect("wasm add_a_to_out call");
        }
        self.read_out(n)
    }
}

// ----------------------------------------------------------------
// Vector: the f64 value type of the functor layer.

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
        assert_eq!(self.len(), other.len());
        let mut h = host();
        let sum = h.accumulate(&[&self.values.clone(), &other.values]);
        self.values = sum;
    }

    pub fn dot(&self, other: &Self) -> f64 {
        host().dot(&self.values, &other.values)
    }

    pub fn norm(&self) -> f64 {
        self.dot(self).sqrt()
    }

    pub fn cosine_similarity(&self, other: &Self) -> f64 {
        cosine_similarity(&self.values, &other.values)
    }

    pub fn len(&self) -> usize {
        self.values.len()
    }

    pub fn is_empty(&self) -> bool {
        self.values.is_empty()
    }
}

pub fn cosine_similarity(left: &[f64], right: &[f64]) -> f64 {
    let mut h = host();
    let dot = h.dot(left, right);
    let left_norm = h.dot(left, left).sqrt();
    let right_norm = h.dot(right, right).sqrt();
    if left_norm == 0.0 || right_norm == 0.0 {
        0.0
    } else {
        dot / (left_norm * right_norm)
    }
}

// ----------------------------------------------------------------
// The functors: bind, unbind, superimpose, encode, cleanup.

pub fn circular_convolution(a: &[f64], b: &[f64]) -> Vec<f64> {
    let mut h = host();
    let func = h.conv;
    h.binary_op(func, a, b)
}

pub fn circular_correlation(a: &[f64], b: &[f64]) -> Vec<f64> {
    let mut h = host();
    let func = h.corr;
    h.binary_op(func, a, b)
}

pub fn convolution_fft(a: &[f64], b: &[f64]) -> Vec<f64> {
    assert_eq!(a.len(), b.len());
    assert!(
        a.len().is_power_of_two(),
        "FFT convolution requires power-of-two length"
    );
    let mut h = host();
    let func = h.fft_conv;
    h.binary_op(func, a, b)
}

pub fn bind_role_filler(role: &Vector, filler: &Vector) -> Vector {
    Vector::from_values(circular_convolution(&role.values, &filler.values))
}

pub fn approximate_unbind(memory: &Vector, cue: &Vector) -> Vector {
    Vector::from_values(circular_correlation(&memory.values, &cue.values))
}

pub fn superimpose(vectors: &[Vector]) -> Vector {
    if vectors.is_empty() {
        return Vector::new(0);
    }
    let slices: Vec<&[f64]> = vectors.iter().map(|v| v.values.as_slice()).collect();
    Vector::from_values(host().accumulate(&slices))
}

pub fn encode_sequence(sequence: &[Vector]) -> Vec<f64> {
    if sequence.is_empty() {
        return vec![];
    }
    superimpose(sequence).values
}

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

// ----------------------------------------------------------------
// Codebook generation: deterministic, seeded by symbol name.

pub fn generate_symbol(name: &str, dim: usize) -> Vector {
    let mut seed = 0u64;
    for byte in name.as_bytes() {
        seed = seed.wrapping_mul(131).wrapping_add(*byte as u64);
    }
    random_vector(dim, seed)
}

pub fn random_vector(dim: usize, seed: u64) -> Vector {
    use rand::SeedableRng;
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

pub fn symbol_codebook(names: &[String], dim: usize) -> Vec<Vector> {
    names.iter().map(|name| generate_symbol(name, dim)).collect()
}

// ----------------------------------------------------------------
// Memory: a set of bindings with superposition retrieval.

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
        self.bindings.push(bind_role_filler(role, filler));
    }

    pub fn store_binding(&mut self, binding: &Vector) {
        assert_eq!(binding.len(), self.dim);
        self.bindings.push(binding.clone());
    }

    pub fn retrieve(&self, cue: &Vector, codebook: &[Vector]) -> (String, f64) {
        let state = if self.bindings.is_empty() {
            vec![0.0; self.dim]
        } else {
            let slices: Vec<&[f64]> = self.bindings.iter().map(|b| b.values.as_slice()).collect();
            host().accumulate(&slices)
        };
        let recovered = circular_correlation(&state, &cue.values);
        let probe = Vector::from_values(recovered);
        cleanup_nearest_neighbor(&probe, codebook)
    }
}
