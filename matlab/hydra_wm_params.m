function p = hydra_wm_params(N)
% HYDRA_WM_PARAMS  Shared parameters for the HYDRA holographic watermark.
%
% The watermark lives in the mid-frequency annulus of the host frame's
% 2-D DFT: low frequencies are left alone (they carry the image's
% visible structure), high frequencies are left alone (they are the
% first thing compression and sensor noise destroy). Every payload bit
% is spread over the ENTIRE annulus by a keyed pattern, so the mark is
% global: destroying part of the frame degrades the recovered payload
% gracefully instead of erasing specific bits.
%
%   N - frame size (frames are N x N, N a power of two)

p.N = N;
p.r_lo = N / 8;        % inner radius of the watermark annulus
p.r_hi = N / 3;        % outer radius of the watermark annulus
p.alpha = 0.35;        % embedding strength, relative to the band norm ||F_band||
end
