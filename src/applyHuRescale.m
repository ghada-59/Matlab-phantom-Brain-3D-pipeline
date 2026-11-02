function hu = applyHuRescale(raw, slope, intercept)
%APPLYHURESCALE Convert stored DICOM intensities to Hounsfield units.
%
%   HU = storedValue * RescaleSlope + RescaleIntercept.
%
%   A missing slope is treated as 1 and a missing intercept as 0, which is
%   the DICOM default. Callers that read a real header must still record
%   whether RescaleIntercept was actually present: forgetting it shifts
%   every voxel by a constant and the values are no longer Hounsfield units.
%
%   This function does not invent a measured intensity. It only applies the
%   affine transform defined by its arguments.

    if nargin < 2 || isempty(slope) || ~isscalar(slope) || ~isfinite(double(slope))
        slope = 1;
    end
    if nargin < 3 || isempty(intercept) || ~isscalar(intercept) || ~isfinite(double(intercept))
        intercept = 0;
    end
    hu = double(raw) .* double(slope) + double(intercept);
end
