function [bits_hat, corr_vals, stat] = hydra_wm_extract(frame, nbits, key_seed, mask)
% HYDRA_WM_EXTRACT  Recover watermark payload bits by matched filtering.
%
%   [bits_hat, corr_vals, stat] = hydra_wm_extract(frame, nbits, key_seed [, mask])
%
% For each bit position b the extractor recomputes the keyed pattern
% P_b, forms its spatial template phat_b = real(ifft2(P_b)), and
% correlates over the SURVIVING pixels with per-pixel WEIGHTS
% (mask in [0,1]; default: all ones):
%
%   c_b = <frame, phat_b>_w / <phat_b, phat_b>_w / ||F_band||
%
% With unit weights this is exactly the spectral correlator
% Re <F, P_b> / ||F_band|| (Parseval). With an erasure mask it is the
% matched filter for that damage: the template is compared only where
% data survives, so a frame CUT IN HALF still yields an unbiased
% estimate of every bit — the mark lives in every pixel. A plain
% spectral correlator on the damaged frame is the WRONG detector for
% erasures: zeroing a region convolves the spectrum with the mask's
% transform and decorrelates the band.
%
% The weights should FEATHER to zero at a damage boundary (the demo
% ramps over 12 px): a hard spatial edge has 1/f spectral sidelobes
% that leak the host's strong low frequencies into the watermark
% band; a tapered window rolls that leakage off steeply, at the cost
% of a few pixels of signal.
%
% The sign of c_b is the bit decision. |c_b| is the per-bit
% confidence; mean |c_b| (stat.detector) separates "marked, degraded"
% from "unmarked" when compared against a wrong-key control.

[N, M] = size(frame);
assert(N == M, 'frame must be square');
if nargin < 4 || isempty(mask)
    mask = ones(N, N);
end
mask = double(mask);
p = hydra_wm_params(N);
F = fft2(frame);
[~, band] = hydra_wm_pattern(N, 1, key_seed, p);
band_norm = sqrt(sum(abs(F(band)).^2));

corr_vals = zeros(1, nbits);
for b = 1:nbits
    P = hydra_wm_pattern(N, b, key_seed, p);
    phat = real(ifft2(P));
    num = sum(mask(:) .* frame(:) .* phat(:));
    den = sum(mask(:) .* phat(:).^2);
    corr_vals(b) = num / den / band_norm;
end
bits_hat = double(corr_vals > 0);
stat.detector = mean(abs(corr_vals));
stat.band_norm = band_norm;
end
