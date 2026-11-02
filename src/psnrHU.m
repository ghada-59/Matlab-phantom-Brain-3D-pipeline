function value = psnrHU(reference, denoised)
%PSNRHU Peak signal to noise ratio with the reference dynamic range as peak.
%
%   peak = max(reference) - min(reference), in HU.
%   PSNR = 10 * log10(peak^2 / MSE).
%
%   Identical arrays return Inf. A constant reference returns NaN because
%   the peak is zero. Callers convert non-finite values to "not computed"
%   before writing JSON.

    reference = double(reference);
    denoised = double(denoised);
    if ~isequal(size(reference), size(denoised))
        error('psnrHU:Size', 'Reference and denoised volumes must have the same size.');
    end
    mse = mean((denoised(:) - reference(:)).^2);
    if mse == 0
        value = Inf;
        return;
    end
    peak = max(reference(:)) - min(reference(:));
    if ~isfinite(peak) || peak <= 0
        value = NaN;
        return;
    end
    value = 10 * log10((peak^2) / mse);
end
