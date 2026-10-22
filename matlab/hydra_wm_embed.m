function [wm_frame, info] = hydra_wm_embed(host, bits, key_seed, alpha)
% HYDRA_WM_EMBED  Embed payload bits as a global frequency-domain
% watermark in a detector frame.
%
%   [wm, info] = hydra_wm_embed(host, bits, key_seed, alpha)
%
%   host     - N x N real frame (N a power of two)
%   bits     - row vector of payload bits (0/1)
%   key_seed - watermark key (integer)
%   alpha    - embedding strength relative to mean band magnitude
%              (default: hydra_wm_params alpha)
%
% Method: F = fft2(host). Each bit b, mapped to s = +1 (bit 1) or
% -1 (bit 0), adds  alpha * ||F_band|| * s * P_b / sqrt(nbits)  to the
% spectrum, where P_b is the keyed UNIT-ENERGY pattern for that bit,
% supported on the mid-frequency annulus only. Scaling by the band
% NORM (not the mean coefficient magnitude) is what makes the mark
% detectable: a unit-energy pattern has per-coefficient amplitude
% ~1/sqrt(band size), and the correlator recovers exactly the total
% embedded energy alpha*||F_band||/sqrt(nbits) against host
% interference of order ||F_band||/sqrt(band size) — the processing
% gain of spread spectrum. The watermarked frame is real(ifft2(F_w)).
% Information is distributed over the whole band and therefore over
% the whole frame: no pixel, and no small set of pixels, "contains"
% any bit.

[N, M] = size(host);
assert(N == M, 'host frame must be square');
p = hydra_wm_params(N);
if nargin < 4 || isempty(alpha)
    alpha = p.alpha;
end
bits = bits(:).';
nb = numel(bits);

F = fft2(host);
[~, band] = hydra_wm_pattern(N, 1, key_seed, p);
band_norm = sqrt(sum(abs(F(band)).^2));

W = zeros(N, N);
for b = 1:nb
    P = hydra_wm_pattern(N, b, key_seed, p);
    s = 2 * bits(b) - 1;
    W = W + s * P;
end
F_w = F + alpha * band_norm / sqrt(nb) * W;
wm_frame = real(ifft2(F_w));

info.band_coeffs = nnz(band);
info.band_norm = band_norm;
info.alpha = alpha;
mse = mean((wm_frame(:) - host(:)).^2);
info.psnr_db = 10 * log10(max(host(:))^2 / mse);
end
