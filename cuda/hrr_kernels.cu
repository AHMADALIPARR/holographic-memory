// hrr_kernels.cu - HYDRA HRR kernels for CUDA GPUs (double precision).
//
// Full GPU implementation of the engine's arithmetic, mirroring the
// CPU definitions used everywhere else in this repository:
//   circular convolution  c_k = sum_j a_j * b_{(k-j) mod n}
//   circular correlation  r_k = sum_j a_j * b_{(j-k) mod n}
//   superposition         elementwise accumulation
//   cleanup               cosine similarity against codebook columns
// plus an FFT convolution path (iterative radix-2, one kernel launch
// per butterfly stage) that mirrors the CPU FFT operation order.
//
// The host driver is self-verifying: it checks the GPU direct
// convolution against a CPU direct convolution (max abs diff), the
// GPU FFT convolution against the GPU direct convolution, and then
// runs the standard retrieval experiment (D = 1024, 16-symbol
// codebook, 4 superposed bindings, correlate + cleanup per binding)
// printing recovered symbols and cosines.
//
// Codebook recipe matches the Fortran and MATLAB layers: a
// double-precision LCG (modulus 2^32, multiplier 1664525) drives a
// Box-Muller transform; columns are unit-normalized on the host.
//
// Build: make            (nvcc, see Makefile)
// Run:   ./hrr_kernels

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#define CUDA_OK(call)                                                     \
    do {                                                                  \
        cudaError_t err__ = (call);                                       \
        if (err__ != cudaSuccess) {                                       \
            std::fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__,   \
                         __LINE__, cudaGetErrorString(err__));            \
            std::exit(1);                                                 \
        }                                                                 \
    } while (0)

namespace {

constexpr int kThreads = 256;

// ------------------------------------------------------------------
// Direct kernels: one thread per output component, grid-stride loop.

__global__ void conv_kernel(const double* a, const double* b, double* out, int n) {
    for (int k = blockIdx.x * blockDim.x + threadIdx.x; k < n; k += gridDim.x * blockDim.x) {
        double acc = 0.0;
        for (int j = 0; j < n; ++j) {
            int idx = k - j;
            if (idx < 0) idx += n;
            acc += a[j] * b[idx];
        }
        out[k] = acc;
    }
}

__global__ void corr_kernel(const double* a, const double* b, double* out, int n) {
    for (int k = blockIdx.x * blockDim.x + threadIdx.x; k < n; k += gridDim.x * blockDim.x) {
        double acc = 0.0;
        for (int j = 0; j < n; ++j) {
            int idx = j - k;
            if (idx < 0) idx += n;
            acc += a[j] * b[idx];
        }
        out[k] = acc;
    }
}

__global__ void add_kernel(double* out, const double* a, int n) {
    for (int j = blockIdx.x * blockDim.x + threadIdx.x; j < n; j += gridDim.x * blockDim.x) {
        out[j] += a[j];
    }
}

__global__ void zero_kernel(double* out, int n) {
    for (int j = blockIdx.x * blockDim.x + threadIdx.x; j < n; j += gridDim.x * blockDim.x) {
        out[j] = 0.0;
    }
}

// Block-partial dot product; the host sums the per-block partials.
__global__ void dot_kernel(const double* a, const double* b, double* partial, int n) {
    __shared__ double sdata[kThreads];
    double acc = 0.0;
    for (int j = blockIdx.x * blockDim.x + threadIdx.x; j < n; j += gridDim.x * blockDim.x) {
        acc += a[j] * b[j];
    }
    sdata[threadIdx.x] = acc;
    __syncthreads();
    for (int stride = kThreads / 2; stride > 0; stride >>= 1) {
        if (threadIdx.x < stride) sdata[threadIdx.x] += sdata[threadIdx.x + stride];
        __syncthreads();
    }
    if (threadIdx.x == 0) partial[blockIdx.x] = sdata[0];
}

// ------------------------------------------------------------------
// FFT path on double2 arrays: bit reversal, then one butterfly
// kernel launch per stage (twiddle recurrence runs inside a block
// segment exactly as in the CPU code: w starts at 1 for each
// segment and is multiplied by wlen after every butterfly).

__global__ void bit_reverse_kernel(double2* x, int n, int logn) {
    for (int i = blockIdx.x * blockDim.x + threadIdx.x; i < n; i += gridDim.x * blockDim.x) {
        int j = 0;
        for (int b = 0; b < logn; ++b) {
            if (i & (1 << b)) j |= 1 << (logn - 1 - b);
        }
        if (j > i) {
            double2 tmp = x[i];
            x[i] = x[j];
            x[j] = tmp;
        }
    }
}

__global__ void butterfly_kernel(double2* x, int n, int len, double wlen_re, double wlen_im) {
    int half = len / 2;
    int segments = n / len;
    for (int seg = blockIdx.x; seg < segments; seg += gridDim.x) {
        double wr = 1.0, wi = 0.0;
        int base = seg * len;
        for (int k = 0; k < half; ++k) {
            double2 u = x[base + k];
            double2 v0 = x[base + k + half];
            double vr = v0.x * wr - v0.y * wi;
            double vi = v0.x * wi + v0.y * wr;
            x[base + k] = make_double2(u.x + vr, u.y + vi);
            x[base + k + half] = make_double2(u.x - vr, u.y - vi);
            double nwr = wr * wlen_re - wi * wlen_im;
            double nwi = wr * wlen_im + wi * wlen_re;
            wr = nwr;
            wi = nwi;
        }
    }
}

__global__ void real_to_complex_kernel(const double* in, double2* out, int n) {
    for (int j = blockIdx.x * blockDim.x + threadIdx.x; j < n; j += gridDim.x * blockDim.x) {
        out[j] = make_double2(in[j], 0.0);
    }
}

__global__ void complex_mul_kernel(double2* a, const double2* b, int n) {
    for (int j = blockIdx.x * blockDim.x + threadIdx.x; j < n; j += gridDim.x * blockDim.x) {
        double2 x = a[j];
        double2 y = b[j];
        a[j] = make_double2(x.x * y.x - x.y * y.y, x.x * y.y + x.y * y.x);
    }
}

__global__ void extract_real_scaled_kernel(const double2* in, double* out, int n, double scale) {
    for (int j = blockIdx.x * blockDim.x + threadIdx.x; j < n; j += gridDim.x * blockDim.x) {
        out[j] = in[j].x * scale;
    }
}

int blocks_for(int n) {
    int blocks = (n + kThreads - 1) / kThreads;
    return blocks > 1024 ? 1024 : blocks;
}

void fft_gpu(double2* x, int n, bool inverse, int blocks) {
    int logn = 0;
    while ((1 << logn) < n) ++logn;
    bit_reverse_kernel<<<blocks, kThreads>>>(x, n, logn);
    const double two_pi = 6.283185307179586;
    for (int len = 2; len <= n; len <<= 1) {
        double angle = (inverse ? two_pi : -two_pi) / len;
        butterfly_kernel<<<blocks, kThreads>>>(x, n, len, std::cos(angle), std::sin(angle));
    }
    CUDA_OK(cudaGetLastError());
}

void fft_conv_gpu(const double* a, const double* b, double* out, int n) {
    double2 *fa, *fb;
    CUDA_OK(cudaMalloc(&fa, sizeof(double2) * n));
    CUDA_OK(cudaMalloc(&fb, sizeof(double2) * n));
    int blocks = blocks_for(n);
    real_to_complex_kernel<<<blocks, kThreads>>>(a, fa, n);
    real_to_complex_kernel<<<blocks, kThreads>>>(b, fb, n);
    fft_gpu(fa, n, false, blocks);
    fft_gpu(fb, n, false, blocks);
    complex_mul_kernel<<<blocks, kThreads>>>(fa, fb, n);
    fft_gpu(fa, n, true, blocks);
    extract_real_scaled_kernel<<<blocks, kThreads>>>(fa, out, n, 1.0 / n);
    CUDA_OK(cudaFree(fa));
    CUDA_OK(cudaFree(fb));
}

double dot_gpu(const double* a, const double* b, int n, double* partial, int blocks) {
    dot_kernel<<<blocks, kThreads>>>(a, b, partial, n);
    double host_partial[1024];
    CUDA_OK(cudaMemcpy(host_partial, partial, sizeof(double) * blocks, cudaMemcpyDeviceToHost));
    double total = 0.0;
    for (int i = 0; i < blocks; ++i) total += host_partial[i];
    return total;
}

// ------------------------------------------------------------------
// Host helpers: codebook recipe shared with the Fortran/MATLAB code.

double lcg_next(double& state) {
    state = std::fmod(state * 1664525.0 + 1013904223.0, 4294967296.0);
    return state / 4294967296.0;
}

void conv_cpu(const double* a, const double* b, double* out, int n) {
    for (int k = 0; k < n; ++k) {
        double acc = 0.0;
        for (int j = 0; j < n; ++j) {
            int idx = k - j;
            if (idx < 0) idx += n;
            acc += a[j] * b[idx];
        }
        out[k] = acc;
    }
}

}  // namespace

int main() {
    int device = 0;
    CUDA_OK(cudaGetDevice(&device));
    cudaDeviceProp prop;
    CUDA_OK(cudaGetDeviceProperties(&prop, device));
    std::printf("device: %s (sm_%d%d)\n", prop.name, prop.major, prop.minor);

    const int D = 1024, NS = 16, NB = 4;
    const int blocks = blocks_for(D);

    // Codebook on the host, then to the device as one flat array.
    double* codebook = new double[(size_t)D * NS];
    double state = 1234567.0;
    for (int s = 0; s < NS; ++s) {
        double norm = 0.0;
        for (int i = 0; i < D; ++i) {
            double u1 = lcg_next(state);
            if (u1 < 1e-12) u1 = 1e-12;
            double u2 = lcg_next(state);
            double v = std::sqrt(-2.0 * std::log(u1)) * std::cos(6.283185307179586 * u2);
            codebook[(size_t)s * D + i] = v;
            norm += v * v;
        }
        norm = std::sqrt(norm);
        for (int i = 0; i < D; ++i) codebook[(size_t)s * D + i] /= norm;
    }

    double *d_cb, *d_trace, *d_bound, *d_probe, *d_partial;
    CUDA_OK(cudaMalloc(&d_cb, sizeof(double) * D * NS));
    CUDA_OK(cudaMalloc(&d_trace, sizeof(double) * D));
    CUDA_OK(cudaMalloc(&d_bound, sizeof(double) * D));
    CUDA_OK(cudaMalloc(&d_probe, sizeof(double) * D));
    CUDA_OK(cudaMalloc(&d_partial, sizeof(double) * 1024));
    CUDA_OK(cudaMemcpy(d_cb, codebook, sizeof(double) * D * NS, cudaMemcpyHostToDevice));

    // Verification 1: GPU direct convolution vs CPU direct.
    {
        double* ref = new double[D];
        double* got = new double[D];
        conv_cpu(codebook, codebook + D, ref, D);
        conv_kernel<<<blocks, kThreads>>>(d_cb, d_cb + D, d_bound, D);
        CUDA_OK(cudaMemcpy(got, d_bound, sizeof(double) * D, cudaMemcpyDeviceToHost));
        double maxdiff = 0.0;
        for (int i = 0; i < D; ++i) maxdiff = std::max(maxdiff, std::fabs(ref[i] - got[i]));
        std::printf("check direct conv gpu-vs-cpu: max abs diff %.3e\n", maxdiff);
        delete[] ref;
        delete[] got;
    }

    // Verification 2: GPU FFT convolution vs GPU direct convolution.
    {
        double* got = new double[D];
        fft_conv_gpu(d_cb, d_cb + D, d_bound, D);
        CUDA_OK(cudaMemcpy(got, d_bound, sizeof(double) * D, cudaMemcpyDeviceToHost));
        double* ref = new double[D];
        conv_cpu(codebook, codebook + D, ref, D);
        double maxdiff = 0.0;
        for (int i = 0; i < D; ++i) maxdiff = std::max(maxdiff, std::fabs(ref[i] - got[i]));
        std::printf("check fft conv gpu-vs-cpu:    max abs diff %.3e\n", maxdiff);
        delete[] ref;
        delete[] got;
    }

    // Retrieval experiment: NB bindings of (odd -> even) symbols.
    zero_kernel<<<blocks, kThreads>>>(d_trace, D);
    for (int k = 0; k < NB; ++k) {
        conv_kernel<<<blocks, kThreads>>>(d_cb + (2 * k) * D, d_cb + (2 * k + 1) * D, d_bound, D);
        add_kernel<<<blocks, kThreads>>>(d_trace, d_bound, D);
    }
    int recovered = 0;
    for (int k = 0; k < NB; ++k) {
        corr_kernel<<<blocks, kThreads>>>(d_trace, d_cb + (2 * k) * D, d_probe, D);
        double probe_norm = std::sqrt(dot_gpu(d_probe, d_probe, D, d_partial, blocks));
        int best = -1;
        double best_cos = -2.0;
        for (int s = 0; s < NS; ++s) {
            double d = dot_gpu(d_probe, d_cb + s * D, D, d_partial, blocks);
            double cosim = (probe_norm == 0.0) ? 0.0 : d / probe_norm;  // codebook columns are unit-norm
            if (cosim > best_cos) {
                best_cos = cosim;
                best = s;
            }
        }
        bool ok = (best == 2 * k + 1);
        if (ok) ++recovered;
        std::printf("bind %d expect symbol %d got %d cos %.4f %s\n", k, 2 * k + 1, best,
                    best_cos, ok ? "correct" : "WRONG");
    }
    std::printf("hrr_recovered=%d/%d\n", recovered, NB);

    CUDA_OK(cudaFree(d_cb));
    CUDA_OK(cudaFree(d_trace));
    CUDA_OK(cudaFree(d_bound));
    CUDA_OK(cudaFree(d_probe));
    CUDA_OK(cudaFree(d_partial));
    delete[] codebook;
    return recovered == NB ? 0 : 1;
}
