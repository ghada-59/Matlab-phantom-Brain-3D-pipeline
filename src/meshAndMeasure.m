function meas = meshAndMeasure(mask, spacingMM, varargin)
%MESHANDMEASURE Isosurface, areas, volumes, and principal semi-axes.
%
%   Voxel volume is nnz(mask) * sy * sx * sz. The product of the three
%   spacings is required: using a single spacing, or a count of voxels,
%   is wrong as soon as the grid is anisotropic.
%
%   The triangle mesh comes from isosurface on the mask (optionally smoothed
%   by imgaussfilt3 for the mesh only). Mesh area is the sum of triangle
%   areas. Mesh volume is the absolute divergence-theorem volume. Smoothing
%   the mesh does not change the voxel volume.
%
%   Principal semi-axes are estimated from the covariance of the voxel-centre
%   coordinates in millimetres, with eig (base MATLAB). The Statistics
%   Toolbox function pca is not used. For a uniformly filled ellipsoid the
%   coordinate variance along a principal axis equals (semi-axis)^2 / 5, so
%
%       semiAxis = sqrt(5 * eigenvalue).
%
%   Sheppard's correction adds s^2/12 on the matching diagonal to account
%   for the finite voxel. Eigenvectors are unit directions in (x, y, z) =
%   (column, row, slice). They are sorted from the longest semi-axis to the
%   shortest. These semi-axes are the quantities compared with the analytic
%   a, b, c, both in millimetres.
%
%   regionprops3 PrincipalAxisLength is a different definition: the full
%   length of the equivalent-ellipsoid axes, in isotropic voxel units. It is
%   not a, b, or c, and it is not converted with one spacing. Solidity comes
%   from the same call. Orientation is in degrees and is not a clinical angle.

    assertImageToolbox();
    parser = inputParser;
    parser.FunctionName = 'meshAndMeasure';
    parser.KeepUnmatched = true;
    parser.addParameter('MeshSmoothSigmaVox', 0.75);
    parser.addParameter('IsoValue', 0.5);
    parser.parse(varargin{:});
    opt = parser.Results;

    if ~islogical(mask)
        mask = mask ~= 0;
    end
    if ndims(mask) ~= 3 || isempty(mask)
        error('meshAndMeasure:InvalidMask', 'Mask must be a non-empty 3-D array.');
    end
    spacing = double(spacingMM(:)');
    if numel(spacing) ~= 3 || any(~isfinite(spacing)) || any(spacing <= 0)
        error('meshAndMeasure:InvalidSpacing', ...
            'spacingMM must be a positive 3-vector [sy sx sz] in mm.');
    end
    if ~isscalar(opt.MeshSmoothSigmaVox) || ~isfinite(opt.MeshSmoothSigmaVox) || opt.MeshSmoothSigmaVox < 0
        error('meshAndMeasure:InvalidSigma', 'MeshSmoothSigmaVox must be a non-negative finite scalar.');
    end

    nRows = size(mask, 1);
    nCols = size(mask, 2);
    nSlices = size(mask, 3);
    % Origin at the first voxel centre. Absolute origin cancels in PCA.
    y = (0:nRows - 1) * spacing(1);
    x = (0:nCols - 1) * spacing(2);
    z = (0:nSlices - 1) * spacing(3);

    voxelVolumeMM3 = nnz(mask) * prod(spacing);
    if voxelVolumeMM3 <= 0
        error('meshAndMeasure:Empty', 'Mask is empty.');
    end

    [row, col, slc] = ind2sub(size(mask), find(mask));
    % ind2sub returns columns, and indexing the coordinate rows with those
    % columns keeps one point per row: [x, y, z] in millimetres.
    points = [x(col), y(row), z(slc)];
    centroidMM = mean(points, 1);
    centered = points - centroidMM;
    covariance = (centered.' * centered) / size(centered, 1);
    % Sheppard's correction, in mm^2, on x, y, z respectively.
    covariance(1, 1) = covariance(1, 1) + spacing(2)^2 / 12;
    covariance(2, 2) = covariance(2, 2) + spacing(1)^2 / 12;
    covariance(3, 3) = covariance(3, 3) + spacing(3)^2 / 12;
    covariance = (covariance + covariance.') / 2;
    [vectors, eigenValues] = eig(covariance);
    lambda = max(real(diag(eigenValues)), 0);
    [lambda, order] = sort(lambda, 'descend');
    vectors = real(vectors(:, order));
    for axisIndex = 1:3
        [~, pivot] = max(abs(vectors(:, axisIndex)));
        if vectors(pivot, axisIndex) < 0
            vectors(:, axisIndex) = -vectors(:, axisIndex);
        end
    end
    semiAxesMM = sqrt(5 * lambda).';

    [solidity, principalAxisLengthVoxels, orientationDeg, centroidVoxels] = ...
        regionProperties(mask);

    shape = double(mask);
    if opt.MeshSmoothSigmaVox > 0
        shape = imgaussfilt3(shape, opt.MeshSmoothSigmaVox);
    end
    % meshgrid(x, y, z) has size (nRows, nCols, nSlices), matching the mask:
    % index (row, col, slice) <-> (y, x, z).
    [gridX, gridY, gridZ] = meshgrid(x, y, z);
    surfaceMesh = isosurface(gridX, gridY, gridZ, shape, opt.IsoValue);
    if ~isfield(surfaceMesh, 'faces') || isempty(surfaceMesh.faces)
        error('meshAndMeasure:NoSurface', 'isosurface did not produce a triangle mesh.');
    end
    [meshVolumeMM3, meshAreaMM2] = meshVolumeAndArea(surfaceMesh.vertices, surfaceMesh.faces);

    meas = struct();
    meas.voxelVolumeMM3 = voxelVolumeMM3;
    meas.meshVolumeMM3 = meshVolumeMM3;
    meas.meshAreaMM2 = meshAreaMM2;
    meas.semiAxesMM = semiAxesMM;
    meas.axisDirections = vectors;
    meas.centroidMM = centroidMM;
    meas.sphericityMesh = sphericity(meshVolumeMM3, meshAreaMM2);
    meas.sphericityVoxel = sphericity(voxelVolumeMM3, meshAreaMM2);
    meas.solidity = solidity;
    meas.principalAxisLengthVoxels = principalAxisLengthVoxels;
    meas.principalAxisLengthUnit = 'voxel';
    meas.principalAxisDefinition = ['regionprops3 PrincipalAxisLength is the full ', ...
        'axis length of the equivalent ellipsoid, in isotropic voxel units. ', ...
        'It is not the analytic semi-axis a, b, or c in mm, and it is not ', ...
        'scaled by a single spacing. semiAxesMM comes from eig of the ', ...
        'covariance in millimetres.'];
    meas.orientationDeg = orientationDeg;
    meas.centroidVoxels = centroidVoxels;
    meas.vertices = surfaceMesh.vertices;
    meas.faces = surfaceMesh.faces;
    meas.spacingMM = spacing;
    meas.meshSmoothSigmaVox = opt.MeshSmoothSigmaVox;
    meas.coordinateNote = ['centroidMM is [x y z] in mm from the first voxel centre. ', ...
        'axisDirections columns are unit vectors in (x, y, z).'];
end

function [solidity, lengths, orientation, centroidVox] = regionProperties(mask)
    solidity = [];
    lengths = [];
    orientation = [];
    centroidVox = [];
    available = exist('regionprops3', 'file') == 2 || exist('regionprops3', 'builtin') == 5;
    if ~available
        return;
    end
    try
        stats = regionprops3(mask, 'Volume', 'PrincipalAxisLength', ...
            'Orientation', 'Centroid', 'Solidity');
    catch ME
        warning('meshAndMeasure:RegionProps', '%s', ME.message);
        return;
    end
    if isempty(stats)
        return;
    end
    solidity = firstScalar(stats.Solidity);
    lengths = firstRow(stats.PrincipalAxisLength);
    orientation = firstRow(stats.Orientation);
    centroidVox = firstRow(stats.Centroid);
end

function value = firstScalar(column)
    row = firstRow(column);
    if isempty(row)
        value = [];
    else
        value = row(1);
    end
end

function row = firstRow(column)
    if iscell(column)
        if isempty(column)
            row = [];
            return;
        end
        column = column{1};
    end
    if istable(column)
        column = table2array(column);
    end
    column = double(column);
    if isempty(column)
        row = [];
    elseif isvector(column)
        row = column(:).';
    else
        row = column(1, :);
    end
end
