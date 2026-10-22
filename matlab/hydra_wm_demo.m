% HYDRA_WM_DEMO  Holographic watermark proof, end to end.
%
% Builds a SIMULATED detector frame (smooth interference-like blobs +
% sensor noise; not a physical measurement), embeds a 32-bit payload
% with hydra_wm_embed, then attacks the watermarked frame four ways
% and reports bit-error rate and detector statistic for each:
%
%   clean        - no attack (sanity: BER must be 0)
%   crop-half    - the frame is CUT IN HALF (right half zeroed). The
%                  holographic property: every bit is everywhere, so
%                  the whole payload survives at lower confidence.
%   noise        - additive Gaussian noise, sigma = 5% of frame range
%   quantize     - requantized to 16 gray levels (compression-like)
%   wrong-key    - extraction with the wrong key (control: BER ~ 50%,
%                  detector statistic near zero)
%
% Writes the table to ../results/watermark_matlab.txt and prints it.

here = fileparts(mfilename('fullpath'));
addpath(here);

N = 128;
key_seed = 4242;
nbits = 32;

% --- simulated host frame (deterministic, labeled simulated) ---
base = keyed_randn(N, N, 99);
host = zeros(N, N);
smooth = base;
% crude low-pass by repeated neighbor averaging -> blobby host
for it = 1:60
    smooth = 0.5 * smooth + 0.125 * (circshift(smooth, [1 0]) + circshift(smooth, [-1 0]) + circshift(smooth, [0 1]) + circshift(smooth, [0 -1]));
end
host = 128 + 40 * smooth / max(abs(smooth(:))) + 1.5 * keyed_randn(N, N, 7);

bits = double(keyed_randn(1, nbits, 1234) > 0);
[wm, info] = hydra_wm_embed(host, bits, key_seed, []);

attacks = {};
attacks{end+1} = {'clean', wm, key_seed, []};
crop = wm; crop(:, N/2+1:N) = 0;
% Feathered detector weights for the crop: zero on the destroyed
% half, ramping 0 -> 1 over the 12 surviving columns nearest the cut
% (windowing against spectral leakage from the sharp edge).
crop_mask = zeros(N, N);
ramp = (12:-1:1) / 12;   % smallest weight at the cut edge itself
crop_mask(:, N/2-11:N/2) = repmat(ramp, N, 1);
crop_mask(:, 1:N/2-12) = 1;
attacks{end+1} = {'crop-half', crop, key_seed, crop_mask};
noisy = wm + 0.05 * (max(wm(:)) - min(wm(:))) * keyed_randn(N, N, 555);
attacks{end+1} = {'noise', noisy, key_seed, []};
q = round((wm - min(wm(:))) / (max(wm(:)) - min(wm(:))) * 15) / 15 * (max(wm(:)) - min(wm(:))) + min(wm(:));
attacks{end+1} = {'quantize16', q, key_seed, []};
attacks{end+1} = {'wrong-key', wm, key_seed + 1, []};

out_path = fullfile(here, '..', 'results', 'watermark_matlab.txt');
fid = fopen(out_path, 'w');
fprintf(fid, 'HYDRA holographic watermark - MATLAB/Octave run\n');
fprintf(fid, 'host: SIMULATED detector frame %dx%d, payload %d bits, key %d\n', N, N, nbits, key_seed);
fprintf(fid, 'band coeffs: %d, embed PSNR: %.1f dB\n\n', info.band_coeffs, info.psnr_db);
fprintf(fid, '%-12s %6s %10s\n', 'attack', 'BER', 'detector');
fprintf('%-12s %6s %10s\n', 'attack', 'BER', 'detector');
for a = 1:numel(attacks)
    name = attacks{a}{1}; frame = attacks{a}{2}; k = attacks{a}{3};
    m = attacks{a}{4};
    if strcmp(name, 'crop-half')
        % heavy localized damage: joint least-squares detector with a
        % low-frequency nuisance basis (see hydra_wm_extract_ls)
        [hat, ~, stat] = hydra_wm_extract_ls(frame, nbits, k, m > 0);
    else
        [hat, ~, stat] = hydra_wm_extract(frame, nbits, k, m);
    end
    ber = mean(hat ~= bits);
    fprintf(fid, '%-12s %6.3f %10.4f\n', name, ber, stat.detector);
    fprintf('%-12s %6.3f %10.4f\n', name, ber, stat.detector);
end
fprintf(fid, '\nnote: crop-half is read by the joint least-squares detector (hydra_wm_extract_ls; low-frequency nuisance basis); its detector statistic is in raw template-amplitude units, not the correlator units of the other rows. BER is comparable across all rows.\n');
fclose(fid);
fprintf('results written to %s\n', out_path);
