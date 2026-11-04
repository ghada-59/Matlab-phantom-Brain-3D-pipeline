function seg = segmentBone(hu, spacingMM, varargin)
%SEGMENTBONE Threshold, clean, and keep the largest 3-D component.
%
%   Steps, in order:
%     1. Optional imgaussfilt3. Sigma is converted from millimetres to
%        voxels with the anisotropic spacing, so a 1 mm filter is not one
%        voxel when the grid is not isotropic.
%     2. Otsu threshold from multithresh, also computed when a fixed HU
%        threshold is the one applied. The fixed default, 300 HU, is a
%        conventional bone setting, not a measured result.
%     3. imopen, then imclose, with a ball whose radius is in millimetres.
%        A radius of 0 skips that step. Opening removes a shell and biases
%        the volume; the default radius is therefore 0, and validation can
%        turn it on.
%     4. imfill of holes.
%     5. bwareaopen below MinVolumeMM3.
%     6. Largest 26-connected component (bwconncomp). A scanner table that
%        is brighter than the threshold but smaller than the bone is dropped
%        here. If the table touches the bone, the component is no longer
%        separable and the volume is biased. The function does not claim to
%        detect that case.
%
%   The mask is logical and has the same size as HU.

    assertImageToolbox();
    parser = inputParser;
    parser.FunctionName = 'segmentBone';
    parser.KeepUnmatched = true;
    parser.addParameter('SigmaMM', 0);
    parser.addParameter('OpenRadiusMM', 0);
    parser.addParameter('CloseRadiusMM', 0);
    parser.addParameter('MinVolumeMM3', 0);
    parser.addParameter('Method', 'otsu');
    parser.addParameter('FixedThresholdHU', 300);
    parser.parse(varargin{:});
    opt = parser.Results;

    hu = double(hu);
    if ndims(hu) ~= 3 || isempty(hu) || any(~isfinite(hu(:)))
        error('segmentBone:InvalidVolume', ...
            'HU volume must be a finite, non-empty 3-D array.');
    end
    spacing = double(spacingMM(:)');
    if numel(spacing) ~= 3 || any(~isfinite(spacing)) || any(spacing <= 0)
        error('segmentBone:InvalidSpacing', ...
            'spacingMM must be a positive 3-vector [sy sx sz] in mm.');
    end
    if ~isscalar(opt.FixedThresholdHU) || ~isfinite(double(opt.FixedThresholdHU))
        error('segmentBone:InvalidThreshold', 'FixedThresholdHU must be a finite scalar.');
    end
    sigmaMM = scalarOption(opt.SigmaMM, 'segmentBone:InvalidSigma', ...
        'SigmaMM must be a non-negative finite scalar.', 0);
    openRadiusMM = scalarOption(opt.OpenRadiusMM, 'segmentBone:InvalidRadius', ...
        'OpenRadiusMM must be a non-negative finite scalar in mm.', 0);
    closeRadiusMM = scalarOption(opt.CloseRadiusMM, 'segmentBone:InvalidRadius', ...
        'CloseRadiusMM must be a non-negative finite scalar in mm.', 0);
    minVolumeMM3 = scalarOption(opt.MinVolumeMM3, 'segmentBone:InvalidVolume', ...
        'MinVolumeMM3 must be a non-negative finite scalar in mm^3.', 0);

    smoothed = hu;
    if sigmaMM > 0
        % imgaussfilt3 expects sigma in voxels, one value per array axis.
        sigmaVoxels = sigmaMM ./ spacing;
        smoothed = imgaussfilt3(hu, sigmaVoxels);
    end

    intensityMin = min(smoothed(:));
    intensityMax = max(smoothed(:));
    if intensityMax <= intensityMin
        error('segmentBone:Constant', ...
            'The volume is constant. Otsu has no boundary to find.');
    end

    try
        otsuThreshold = double(multithresh(smoothed, 1));
    catch ME
        error('segmentBone:Otsu', 'multithresh failed (%s).', ME.message);
    end
    if numel(otsuThreshold) ~= 1 || ~isfinite(otsuThreshold) ...
            || otsuThreshold <= intensityMin || otsuThreshold >= intensityMax
        % Keep a separating cut if Otsu returns an endpoint of the range.
        otsuThreshold = (intensityMin + intensityMax) / 2;
    end

    method = lower(char(opt.Method));
    switch method
        case 'otsu'
            usedThreshold = otsuThreshold;
        case 'fixed'
            usedThreshold = double(opt.FixedThresholdHU);
        otherwise
            error('segmentBone:BadMethod', 'Method must be ''otsu'' or ''fixed''.');
    end

    mask = smoothed >= usedThreshold;
    if openRadiusMM > 0
        mask = imopen(mask, ballStrel(openRadiusMM, spacing));
    end
    if closeRadiusMM > 0
        mask = imclose(mask, ballStrel(closeRadiusMM, spacing));
    end
    mask = imfill(mask, 'holes');

    if minVolumeMM3 > 0
        minVoxels = max(1, round(minVolumeMM3 / prod(spacing)));
        mask = bwareaopen(mask, minVoxels, 26);
    end

    components = bwconncomp(mask, 26);
    objectsBefore = components.NumObjects;
    if objectsBefore == 0
        error('segmentBone:Empty', ...
            'Segmentation produced an empty mask. The threshold may be above every voxel.');
    end
    counts = cellfun(@numel, components.PixelIdxList);
    [~, largest] = max(counts);
    maskOut = false(size(mask));
    maskOut(components.PixelIdxList{largest}) = true;

    seg = struct();
    seg.mask = maskOut;
    seg.spacingMM = spacing;
    seg.threshold = struct( ...
        'otsuHU', otsuThreshold, ...
        'fixedHU', double(opt.FixedThresholdHU), ...
        'usedHU', usedThreshold, ...
        'method', method);
    seg.objectsBeforeLargest = objectsBefore;
    seg.sigmaMM = sigmaMM;
    seg.openRadiusMM = openRadiusMM;
    seg.closeRadiusMM = closeRadiusMM;
end

function value = scalarOption(value, identifier, message, minimum)
    value = double(value);
    if ~isscalar(value) || ~isfinite(value) || value < minimum
        error(identifier, '%s', message);
    end
end

function element = ballStrel(radiusMM, spacing)
% Ball of physical radius, sampled on the anisotropic voxel grid.
    if ~isscalar(radiusMM) || ~isfinite(radiusMM) || radiusMM <= 0
        error('segmentBone:InvalidRadius', 'Morphological radius must be a positive scalar in mm.');
    end
    sy = spacing(1);
    sx = spacing(2);
    sz = spacing(3);
    ry = max(1, ceil(radiusMM / sy));
    rx = max(1, ceil(radiusMM / sx));
    rz = max(1, ceil(radiusMM / sz));
    [Y, X, Z] = ndgrid((-ry:ry) * sy, (-rx:rx) * sx, (-rz:rz) * sz);
    element = strel('arbitrary', (X.^2 + Y.^2 + Z.^2) <= radiusMM^2);
end
