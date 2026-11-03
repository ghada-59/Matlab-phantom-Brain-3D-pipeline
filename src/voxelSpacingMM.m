function [spacingMM, source] = voxelSpacingMM(pixelSpacing, spacingBetweenSlices, positions, orientation)
%VOXELSPACINGMM Physical voxel size [row column slice] in millimetres.
%
%   [SPACINGMM, SOURCE] = voxelSpacingMM(PIXELSPACING, SPACINGBETWEENSLICES, ...
%   POSITIONS, ORIENTATION)
%
%   PIXELSPACING is [row column] in mm (DICOM PixelSpacing).
%   SPACINGBETWEENSLICES is the DICOM spacing between slice centres, or [].
%   POSITIONS is N-by-3 ImagePositionPatient, in mm, or [].
%   ORIENTATION is the 6-vector ImageOrientationPatient (row cosines, then
%   column cosines), or [].
%
%   The slice spacing is the distance between slice centres along the slice
%   normal. SliceThickness is intentionally not an argument: it is the
%   thickness of one slab, not the distance between centres, and it is not
%   used here.
%
%   SOURCE is 'image-position' when the positions determine the slice step,
%   'spacing-between-slices' when that tag is the fallback, or '' when the
%   slice step is unknown. Missing components stay NaN. The caller must
%   refuse to assume 1 mm.

    spacingMM = [NaN NaN NaN];
    source = '';

    pixelSpacing = double(pixelSpacing(:));
    if numel(pixelSpacing) >= 2 && all(isfinite(pixelSpacing(1:2))) && all(pixelSpacing(1:2) > 0)
        spacingMM(1) = pixelSpacing(1);
        spacingMM(2) = pixelSpacing(2);
    end

    fromPositions = sliceStepAlongNormal(positions, orientation);
    between = double(spacingBetweenSlices);
    if isfinite(fromPositions) && fromPositions > 0
        spacingMM(3) = fromPositions;
        source = 'image-position';
    elseif isscalar(between) && isfinite(between) && between > 0
        spacingMM(3) = between;
        source = 'spacing-between-slices';
    end
end

function stepMM = sliceStepAlongNormal(positions, orientation)
    stepMM = NaN;
    positions = normalizePositions(positions);
    if size(positions, 1) < 2
        return;
    end
    normal = sliceNormal(orientation, positions);
    if isempty(normal)
        return;
    end
    coordinates = sort(positions * normal(:));
    deltas = abs(diff(coordinates));
    deltas = deltas(isfinite(deltas) & deltas > 0);
    if ~isempty(deltas)
        stepMM = median(deltas);
    end
end

function positions = normalizePositions(positions)
    if isempty(positions)
        positions = zeros(0, 3);
        return;
    end
    positions = double(positions);
    if size(positions, 2) ~= 3 && size(positions, 1) == 3
        positions = positions.';
    end
    if size(positions, 2) ~= 3
        positions = zeros(0, 3);
    end
end

function normal = sliceNormal(orientation, positions)
    normal = [];
    orientation = double(orientation(:));
    if numel(orientation) >= 6 && all(isfinite(orientation(1:6)))
        row = orientation(1:3).';
        column = orientation(4:6).';
        crossed = cross(row, column);
        magnitude = norm(crossed);
        if magnitude >= 1e-8
            normal = crossed / magnitude;
            return;
        end
    end
    % No usable orientation. The step direction is the largest displacement
    % between the first two positions. This is only a direction, not a
    % licence to substitute SliceThickness.
    step = positions(2, :) - positions(1, :);
    [~, axis] = max(abs(step));
    if ~isfinite(step(axis)) || step(axis) == 0
        return;
    end
    normal = zeros(1, 3);
    normal(axis) = sign(step(axis));
end
