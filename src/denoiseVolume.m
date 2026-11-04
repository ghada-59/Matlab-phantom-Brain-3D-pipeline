function denoised = denoiseVolume(hu, method, spacingMM, sigmaMM)
%DENOISEVOLUME One denoising method on a 3-D HU volume.
%
%   gaussian  imgaussfilt3, sigma in millimetres converted per axis
%   median    medfilt3, 3-by-3-by-3 neighbourhood, on HU
%   bilateral imbilatfilt, on intensities stretched to [0, 1], then stretched back
%   nlm       imnlmfilt, same stretch. A slice with a side shorter than 21
%             is reflectively padded to 21, filtered, then cropped.
%   wiener    wiener2 slice by slice, same stretch
%   wavelet   wdenoise2 slice by slice, on HU, only if that function exists
%
%   Bilateral, non-local means, and Wiener are applied slice by slice. In the
%   targeted toolbox those functions are 2-D. A 3-D non-local means on a full
%   CT is a different algorithm and is not used here.
%   Wavelet denoising needs the Wavelet Toolbox (wdenoise2). If it is missing
%   this function errors with identifier denoiseVolume:WaveletToolboxMissing.
%   It does not return a copy of the input and it does not invent a PSNR.
%   Stretching to [0, 1] uses the min and max of THIS volume. Those bounds are
%   properties of the input array, computed here, not published constants.

    assertImageToolbox();
    if nargin < 4 || isempty(sigmaMM)
        sigmaMM = 0.8;
    end
    hu = double(hu);
    spacing = double(spacingMM(:)');
    if ndims(hu) ~= 3 || any(~isfinite(hu(:)))
        error('denoiseVolume:InvalidVolume', 'HU volume must be a finite 3-D array.');
    end
    if numel(spacing) ~= 3 || any(spacing <= 0)
        error('denoiseVolume:InvalidSpacing', 'spacingMM must be a positive 3-vector.');
    end

    switch lower(char(method))
        case 'gaussian'
            if ~isscalar(sigmaMM) || ~isfinite(sigmaMM) || sigmaMM <= 0
                error('denoiseVolume:InvalidSigma', 'SigmaMM must be a positive finite scalar.');
            end
            denoised = imgaussfilt3(hu, sigmaMM ./ spacing);
        case 'median'
            denoised = medfilt3(hu, [3 3 3]);
        case 'bilateral'
            denoised = denoiseSlicewise(hu, @imbilatfilt);
        case 'nlm'
            denoised = denoiseSlicewise(hu, @nlmFiltSlice);
        case 'wiener'
            denoised = denoiseSlicewise(hu, @(slice) wiener2(slice, [3 3]));
        case 'wavelet'
            if ~waveletDenoiseAvailable()
                error('denoiseVolume:WaveletToolboxMissing', ...
                    ['wdenoise2 is not on the path. Wavelet Toolbox is required. ', ...
                     'No denoised volume and no PSNR are produced.']);
            end
            denoised = denoiseEachSlice(hu, @wdenoise2);
        otherwise
            error('denoiseVolume:UnknownMethod', ...
                'Method must be gaussian, median, bilateral, nlm, wiener, or wavelet.');
    end
end

function available = waveletDenoiseAvailable()
    available = exist('wdenoise2', 'file') == 2 || exist('wdenoise2', 'builtin') == 5;
end

function out = denoiseSlicewise(hu, filterFcn)
    [normed, lo, hi, unchanged] = stretchToUnit(hu);
    if unchanged
        out = hu;
        return;
    end
    filtered = denoiseEachSlice(normed, filterFcn);
    out = filtered .* (hi - lo) + lo;
end

function filtered = nlmFiltSlice(slice)
%IMNLMFILT rejects an image smaller than 21-by-21 (its default search
%window). Only this path pads. The crop restores the slice size so PSNR
%and the voxel count stay on the original grid.
    minimumSide = 21;
    rows = size(slice, 1);
    cols = size(slice, 2);
    deficit = [max(0, minimumSide - rows), max(0, minimumSide - cols)];
    if all(deficit == 0)
        filtered = imnlmfilt(slice);
        return;
    end
    pre = floor(deficit / 2);
    post = deficit - pre;
    padded = padarray(slice, pre, 'symmetric', 'pre');
    padded = padarray(padded, post, 'symmetric', 'post');
    padded = imnlmfilt(padded);
    filtered = padded(pre(1) + (1:rows), pre(2) + (1:cols));
end

function filtered = denoiseEachSlice(normed, filterFcn)
    filtered = zeros(size(normed));
    for sliceIndex = 1:size(normed, 3)
        filtered(:, :, sliceIndex) = filterFcn(normed(:, :, sliceIndex));
    end
end

function [normed, lo, hi, unchanged] = stretchToUnit(hu)
    lo = min(hu(:));
    hi = max(hu(:));
    unchanged = ~isfinite(lo) || ~isfinite(hi) || hi <= lo;
    if unchanged
        normed = hu;
        return;
    end
    normed = (hu - lo) ./ (hi - lo);
end
