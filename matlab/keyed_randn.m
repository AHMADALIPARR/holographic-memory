function out = keyed_randn(rows, cols, seed)
% KEYED_RANDN  Deterministic keyed Gaussian matrix.
%
% Portability is correctness here: a watermark pattern is part of the
% key schedule, so the same seed must yield the same pattern in
% MATLAB and GNU Octave, whose rng streams differ — and whose uint64
% arithmetic saturates instead of wrapping, ruling out integer-hash
% generators. This generator is therefore an LCG carried in doubles:
% with modulus 2^32 and multiplier 1664525, every intermediate product
% stays below 2^53, so all arithmetic is EXACT in IEEE double in both
% environments and the stream is bit-identical across them.
%
% Prototype-grade statistics (documented, not hidden): an LCG is not
% a cryptographic generator. These patterns carry a watermark; the
% cryptography lives in the AEAD layer, not here.

M = 4294967296;            % 2^32
state = mod(double(seed), M);
% warm-up: decorrelate streams drawn from nearby seeds
for i = 1:16
    state = mod(1664525 * state + 1013904223, M);
end
n = rows * cols;
u = zeros(1, n);
for i = 1:n
    state = mod(1664525 * state + 1013904223, M);
    u(i) = state / M;                 % uniform in [0,1)
end
u = max(u, 1e-12);
out = zeros(1, n);
for i = 1:2:n-1                        % Box-Muller
    r = sqrt(-2 * log(u(i)));
    t = 2 * pi * u(i+1);
    out(i) = r * cos(t);
    out(i+1) = r * sin(t);
end
if mod(n, 2) == 1
    out(n) = sqrt(-2 * log(u(n))) * cos(2 * pi * u(1));
end
out = reshape(out, rows, cols);
end
