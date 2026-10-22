function [bits_hat, coef, stat] = hydra_wm_extract_ls(frame, nbits, key_seed, mask)
% HYDRA_WM_EXTRACT_LS  Watermark extraction by joint least squares.
%
%   [bits_hat, coef, stat] = hydra_wm_extract_ls(frame, nbits, key_seed, mask)
%
% For heavy localized damage (a cropped frame), correlation detectors
% — spectral or matched-filter — are swamped by the host's smooth
% background: restricted to the surviving pixels, that background is
% no longer orthogonal to the watermark templates, and its spectral
% leakage through the damage edge lands inside the watermark band.
%
% This detector models the situation explicitly. Over the surviving
% pixels (mask > 0) it regresses the frame onto
%   [ phat_1, phat_2, and the remaining templates, low-frequency nuisance basis ]
% where phat_b are the keyed spatial watermark templates and the
% nuisance basis is every Fourier mode with radius < r_lo (the band
% below the watermark annulus, cos and sin parts). The host's smooth
% content — including its leakage manifestation on the surviving
% support — lives in that nuisance span, while the templates are
% band-separated from it, so the joint fit separates mark from host.
% The sign of each template coefficient is the bit decision.
%
% coef is in raw template-amplitude units (the embedded per-bit
% amplitude is alpha*||F_band||/sqrt(nbits)); stat.detector is
% mean |coef| and is NOT commensurate with the correlator statistic
% in hydra_wm_extract — compare it against the wrong-key control
% computed with the same detector.

[N, M] = size(frame);
assert(N == M, 'frame must be square');
if nargin < 4 || isempty(mask)
    mask = ones(N, N);
end
p = hydra_wm_params(N);
supp = mask(:) > 0;
ns = nnz(supp);
y = frame(supp);

% templates over the support
T = zeros(ns, nbits);
for b = 1:nbits
    P = hydra_wm_pattern(N, b, key_seed, p);
    phat = real(ifft2(P));
    T(:, b) = phat(supp);
end

% low-frequency nuisance basis over the support
[yy, xx] = ind2sub([N, N], find(supp));
x = xx - 1; yv = yy - 1;
cols = {};
f = (0:N-1);
f(f > N/2) = f(f > N/2) - N;
for iu = 1:N
    for iv = 1:N
        u = f(iu); v = f(iv);
        if sqrt(u^2 + v^2) < p.r_lo && ~(u == 0 && v == 0)
            ph = 2 * pi * (u * x + v * yv) / N;
            cols{end+1} = cos(ph);
            cols{end+1} = sin(ph);
        end
    end
end
% DC term (cos only)
cols{end+1} = ones(ns, 1);
B = zeros(ns, numel(cols));
for c = 1:numel(cols)
    B(:, c) = cols{c};
end

A = [T, B];
sol = A \ y;
coef = sol(1:nbits).';
bits_hat = double(coef > 0);
stat.detector = mean(abs(coef));
stat.n_nuisance = size(B, 2);
stat.residual = norm(y - A * sol) / sqrt(ns);
end
