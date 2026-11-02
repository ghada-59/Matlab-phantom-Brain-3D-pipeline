function phantom = generateEllipsoidPhantom(varargin)
%GENERATEELLIPSOIDPHANTOM Synthetic 3D ellipsoid phantom in Hounsfield units.
%
%   PHANTOM = generateEllipsoidPhantom(Name, Value, ...) voxelises a solid
%   ellipsoid. The analytic volume (mm^3) is
%
%       V = 4/3 * pi * a * b * c
%
%   where a, b, c are the semi-axes in millimetres. The numeric volume is
%   the number of voxel centres that fall inside the ellipsoid times the
%   voxel volume. It is a raster reference, not a segmentation result.
%
%   Array layout matches MATLAB images:
%     dimension 1 = row    = y
%     dimension 2 = column = x
%     dimension 3 = slice  = z
%   spacingMM is [sy sx sz] in millimetres.
%   semiAxesMM is [a b c] along [x y z] = [column row slice].
%
%   Name-value arguments
%     SemiAxesMM       [a b c] in mm. Omit it to draw random semi-axes.
%     RandomAxes       Logical. true draws semi-axes and forbids SemiAxesMM.
%                      A call with no arguments also draws random semi-axes.
%     VoxelSpacingMM   [sy sx sz] in mm. Default [1 1 1].
%     NoiseSigmaHU     Standard deviation of Gaussian noise in HU. Default 0.
%                      Noise is added after the mask is built, so the mask
%                      and both volumes stay geometric.
%     BackgroundHU     Default -1000 (simulated air). This is a setting.
%     BoneHU           Default 1000 (simulated bone). This is a setting.
%     MarginMM         Padding around the ellipsoid, in mm. Default 6.
%     Seed             RNG seed for the random axes and the noise. Default 42.
%                      The previous RNG state is restored on exit.
%
%   Random semi-axes are drawn uniformly from [12, 36] mm. That interval is
%   a generator setting, not a measurement.
%
%   The phantom is academic. It does not come from a scanner and it is not
%   a clinical image.

    minAxisMM = 12;
    maxAxisMM = 36;

    parser = inputParser;
    parser.FunctionName = 'generateEllipsoidPhantom';
    parser.addParameter('SemiAxesMM', []);
    parser.addParameter('RandomAxes', false);
    parser.addParameter('VoxelSpacingMM', [1 1 1]);
    parser.addParameter('NoiseSigmaHU', 0);
    parser.addParameter('BackgroundHU', -1000);
    parser.addParameter('BoneHU', 1000);
    parser.addParameter('MarginMM', 6);
    parser.addParameter('Seed', 42);
    parser.parse(varargin{:});
    opt = parser.Results;

    spacing = double(opt.VoxelSpacingMM(:)');
    if numel(spacing) ~= 3 || any(~isfinite(spacing)) || any(spacing <= 0)
        error('generateEllipsoidPhantom:InvalidSpacing', ...
            'VoxelSpacingMM must be a positive 3-vector [sy sx sz] in mm.');
    end

    noiseSigma = double(opt.NoiseSigmaHU);
    if ~isscalar(noiseSigma) || ~isfinite(noiseSigma) || noiseSigma < 0
        error('generateEllipsoidPhantom:InvalidNoise', ...
            'NoiseSigmaHU must be a finite scalar greater than or equal to 0.');
    end

    margin = double(opt.MarginMM);
    if ~isscalar(margin) || ~isfinite(margin) || margin < 0
        error('generateEllipsoidPhantom:InvalidMargin', ...
            'MarginMM must be a finite scalar greater than or equal to 0.');
    end

    seed = double(opt.Seed);
    if ~isscalar(seed) || ~isfinite(seed)
        error('generateEllipsoidPhantom:InvalidSeed', 'Seed must be a finite scalar.');
    end

    backgroundHU = double(opt.BackgroundHU);
    boneHU = double(opt.BoneHU);
    if ~isscalar(backgroundHU) || ~isscalar(boneHU) || ~isfinite(backgroundHU) || ~isfinite(boneHU)
        error('generateEllipsoidPhantom:InvalidHU', ...
            'BackgroundHU and BoneHU must be finite scalars.');
    end
    if backgroundHU == boneHU
        error('generateEllipsoidPhantom:InvalidHU', ...
            'BackgroundHU and BoneHU must differ so the ellipsoid is visible.');
    end

    previousRng = rng;
    rngRestore = onCleanup(@() rng(previousRng)); %#ok<NASGU>
    rng(seed, 'twister');

    [semi, axesAreRandom] = resolveSemiAxes(opt.SemiAxesMM, logical(opt.RandomAxes), ...
        minAxisMM, maxAxisMM);

    % a along x (columns), b along y (rows), c along z (slices).
    a = semi(1);
    b = semi(2);
    c = semi(3);

    extentY = b + margin;
    extentX = a + margin;
    extentZ = c + margin;
    ny = max(3, ceil(2 * extentY / spacing(1)) + 1);
    nx = max(3, ceil(2 * extentX / spacing(2)) + 1);
    nz = max(3, ceil(2 * extentZ / spacing(3)) + 1);

    y = ((1:ny) - (ny + 1) / 2) * spacing(1);
    x = ((1:nx) - (nx + 1) / 2) * spacing(2);
    z = ((1:nz) - (nz + 1) / 2) * spacing(3);

    if max(abs(y)) + 1e-9 < b || max(abs(x)) + 1e-9 < a || max(abs(z)) + 1e-9 < c
        error('generateEllipsoidPhantom:GridTooSmall', ...
            'The voxel grid does not cover the ellipsoid.');
    end

    % ndgrid matches image indexing: dim 1 = y, dim 2 = x, dim 3 = z.
    [Y, X, Z] = ndgrid(y, x, z);
    mask = (X ./ a).^2 + (Y ./ b).^2 + (Z ./ c).^2 <= 1;

    volumeHU = backgroundHU * ones(ny, nx, nz);
    volumeHU(mask) = boneHU;
    if noiseSigma > 0
        volumeHU = volumeHU + noiseSigma * randn(ny, nx, nz);
    end

    phantom = struct();
    phantom.volumeHU = volumeHU;
    phantom.mask = mask;
    phantom.spacingMM = spacing;
    phantom.semiAxesMM = semi;
    phantom.axesAreRandom = axesAreRandom;
    phantom.numericVolumeMM3 = nnz(mask) * prod(spacing);
    % Analytic volume of an ellipsoid. a, b, c are semi-axes in mm.
    phantom.analyticVolumeMM3 = (4 / 3) * pi * a * b * c;
    phantom.yMM = y;
    phantom.xMM = x;
    phantom.zMM = z;
    phantom.noiseSigmaHU = noiseSigma;
    phantom.backgroundHU = backgroundHU;
    phantom.boneHU = boneHU;
    phantom.marginMM = margin;
    phantom.seed = seed;
    phantom.axisOrder = '[a b c] along [x y z] = [column row slice]';
    phantom.spacingOrder = '[sy sx sz] = [row column slice]';
end

function [semi, axesAreRandom] = resolveSemiAxes(requested, randomAxes, minAxisMM, maxAxisMM)
    hasAxes = ~isempty(requested);
    if hasAxes && randomAxes
        error('generateEllipsoidPhantom:ConflictingAxes', ...
            'Pass SemiAxesMM or RandomAxes true, not both.');
    end
    if ~hasAxes
        semi = minAxisMM + (maxAxisMM - minAxisMM) * rand(1, 3);
        axesAreRandom = true;
        return;
    end
    semi = double(requested(:)');
    if numel(semi) ~= 3 || any(~isfinite(semi)) || any(semi <= 0)
        error('generateEllipsoidPhantom:InvalidAxes', ...
            'SemiAxesMM must be a positive 3-vector [a b c] in mm.');
    end
    axesAreRandom = false;
end
