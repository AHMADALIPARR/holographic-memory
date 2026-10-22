function [P, band] = hydra_wm_pattern(N, bit_index, key_seed, p)
% HYDRA_WM_PATTERN  Keyed spread-spectrum pattern for one payload bit.
%
% Returns a complex pattern P defined on the mid-frequency annulus of
% an N x N DFT grid, zero outside it, with Hermitian symmetry
%   P(u,v) = conj(P(-u,-v))     (indices modulo N)
% so that adding P to the spectrum of a real frame keeps the inverse
% transform real. The pattern for bit b is a deterministic function of
% (key_seed, b): the key schedule of the watermark.

if nargin < 4
    p = hydra_wm_params(N);
end

% wrapped frequency coordinates: index i (1-based) <-> freq i-1 for
% i <= N/2+1, else i-1-N.
f = (0:N-1);
f(f > N/2) = f(f > N/2) - N;
[U, V] = meshgrid(f, f);
R = sqrt(U.^2 + V.^2);
band = (R >= p.r_lo) & (R <= p.r_hi);

g_re = keyed_randn(N, N, key_seed * 100003 + bit_index * 2);
g_im = keyed_randn(N, N, key_seed * 100003 + bit_index * 2 + 1);
P = (g_re + 1i * g_im) / sqrt(2);
P(~band) = 0;

% Hermitian symmetrization: average P with its conjugate mirror.
% Mirror of index i is mod(-(i-1), N) + 1 in each axis.
idx = mod(-(0:N-1), N) + 1;
P_mirror = conj(P(idx, idx));
P = (P + P_mirror) / sqrt(2);
P(~band) = 0;   % symmetrization preserves the annulus (it is radially symmetric)

% unit energy per pattern so bits embed with equal strength
nrm = sqrt(sum(abs(P(:)).^2));
if nrm > 0
    P = P / nrm;
end
end
