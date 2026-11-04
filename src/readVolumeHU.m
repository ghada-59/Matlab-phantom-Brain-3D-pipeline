function out = readVolumeHU(source)
%READVOLUMEHU Volume in Hounsfield units and voxel spacing in millimetres.
%
%   OUT = readVolumeHU(PHANTOM) accepts the struct returned by
%   generateEllipsoidPhantom. The intensities are already in HU, so the
%   slope is 1 and the intercept is 0.
%
%   OUT = readVolumeHU(FOLDER) reads a DICOM series with dicomreadVolume.
%   Stored values are converted with
%
%       HU = stored * RescaleSlope + RescaleIntercept.
%
%   Spacing is [row, column, slice] in millimetres. In-plane spacing is
%   PixelSpacing. Slice spacing is the distance between slice centres along
%   the normal given by ImageOrientationPatient. SpacingBetweenSlices is
%   used only when the positions do not determine that distance.
%   SliceThickness is stored when the header has it, and is never used as
%   the distance between centres. The function refuses to assume 1 mm.
%
%   Identifying DICOM attributes (patient name, id, birth date, accession)
%   are never copied into OUT. Gantry tilt is not geometrically corrected;
%   slice spacing is the distance between sorted slice positions.
%
%   Geometry is taken from the spatial struct of dicomreadVolume, because
%   that struct describes the array just returned. MakeIsotropic is not
%   requested: resampling would replace the acquired spacing. A directory
%   that also contains another series is not mixed into the slope or the
%   spacing when the slice positions identify the volume.

    if isstruct(source)
        out = phantomVolume(source);
        return;
    end
    if isstring(source) && isscalar(source)
        source = char(source);
    end
    if ~ischar(source)
        error('readVolumeHU:BadSource', ...
            'Source must be a phantom struct or a DICOM folder path.');
    end
    if ~isfolder(source)
        error('readVolumeHU:NotFound', 'DICOM folder not found: %s', source);
    end
    out = dicomVolume(source);
end

function out = phantomVolume(source)
    if ~isfield(source, 'volumeHU') || ~isfield(source, 'spacingMM')
        error('readVolumeHU:BadPhantom', ...
            'A phantom struct needs volumeHU and spacingMM.');
    end
    spacing = double(source.spacingMM(:)');
    if numel(spacing) ~= 3 || any(~isfinite(spacing)) || any(spacing <= 0)
        error('readVolumeHU:BadPhantom', ...
            'Phantom spacingMM must be a positive 3-vector in mm.');
    end
    hu = double(source.volumeHU);
    volumeSize = size(hu);
    if numel(volumeSize) ~= 3 || any(volumeSize < 1) || any(~isfinite(hu(:)))
        error('readVolumeHU:BadPhantom', ...
            'Phantom volumeHU must be a finite, non-empty 3-D array.');
    end
    out = emptyOutput(hu, spacing);
    out.rescaleSlope = 1;
    out.rescaleIntercept = 0;
    out.huConfirmed = true;
    out.source = 'phantom';
    out.semiAxesMM = optionalField(source, 'semiAxesMM', []);
    out.analyticVolumeMM3 = optionalField(source, 'analyticVolumeMM3', []);
    out.numericVolumeMM3 = optionalField(source, 'numericVolumeMM3', []);
    out.backgroundHU = optionalField(source, 'backgroundHU', []);
    out.boneHU = optionalField(source, 'boneHU', []);
    out.sliceSpacingSource = 'phantom';
    out.sliceThicknessMM = [];
    out.imageOrientationPatient = [];
    if isfield(source, 'mask') && isequal(size(source.mask), size(hu))
        out.mask = logical(source.mask);
    else
        out.mask = [];
    end
end

function out = dicomVolume(folder)
    assertImageToolbox();
    if exist('dicomreadVolume', 'file') ~= 2 && exist('dicomreadVolume', 'builtin') ~= 5
        error('boneMorphometry:NoImageToolbox', ...
            'dicomreadVolume is required to read a DICOM series.');
    end

    headers = readableSlices(folder);
    try
        % Do not pass MakeIsotropic. The default keeps the acquired grid.
        % dicomreadVolume returns stored samples, shaped
        % [rows, columns, samples, slices]. The rescale is applied once below.
        [raw, spatial] = dicomreadVolume(folder);
    catch ME
        error('readVolumeHU:DicomRead', ...
            'dicomreadVolume failed for %s (%s).', folder, ME.message);
    end
    raw = storedVolume(raw);
    meta = reduceHeaders(headersForVolume(headers, spatial));
    hu = applyHuRescale(raw, meta.slope, meta.intercept);
    assertVolumeImageSize(spatial, hu);
    [pixelSpacing, positions, orientation, positionsDescribeVolume] = ...
        geometryFromSpatial(spatial, meta);
    if positionsDescribeVolume && size(positions, 1) ~= size(hu, 3)
        error('readVolumeHU:SliceCount', ...
            'The series has %d slice positions but the volume has %d slices.', ...
            size(positions, 1), size(hu, 3));
    end
    [spacing, sliceSource] = voxelSpacingMM( ...
        pixelSpacing, meta.spacingBetweenSlices, positions, orientation);
    if any(~isfinite(spacing)) || any(spacing <= 0)
        error('readVolumeHU:NoSpacing', ...
            ['Voxel spacing is incomplete (row, column, slice) = [%g %g %g] mm. ', ...
             'SliceThickness, when present, is not the distance between slice ', ...
             'centres. Refusing to assume 1 mm.'], spacing(1), spacing(2), spacing(3));
    end

    out = emptyOutput(hu, spacing);
    out.rescaleSlope = meta.slope;
    out.rescaleIntercept = meta.intercept;
    out.huConfirmed = meta.interceptWasPresent;
    out.sliceSpacingSource = sliceSource;
    out.sliceThicknessMM = meta.sliceThicknessMM;
    out.imageOrientationPatient = orientation;
    out.source = 'dicom';
    out.semiAxesMM = [];
    out.analyticVolumeMM3 = [];
    out.numericVolumeMM3 = [];
    out.backgroundHU = [];
    out.boneHU = [];
    out.mask = [];
    if ~meta.interceptWasPresent
        warning('readVolumeHU:NoIntercept', ...
            ['RescaleIntercept is missing. Intensities were stored with ', ...
             'intercept 0 and are not confirmed Hounsfield units.']);
    end
end

function volume = storedVolume(raw)
% DICOM volumes are [rows, columns, samples, slices]. Drop the sample axis
% only. squeeze would also drop a singleton row or column and swap the axes.
    if ndims(raw) == 4
        if size(raw, 3) ~= 1
            error('readVolumeHU:DicomShape', ...
                'Expected one sample per voxel, got %d.', size(raw, 3));
        end
        raw = reshape(raw, size(raw, 1), size(raw, 2), size(raw, 4));
    end
    if ndims(raw) ~= 3 || size(raw, 3) < 2
        error('readVolumeHU:DicomShape', ...
            ['Expected at least two slices so the inter-slice spacing is defined. ', ...
             'Array size is [%s]. SliceThickness is not a substitute.'], num2str(size(raw)));
    end
    volume = raw;
end

function headers = readableSlices(folder)
    listing = dir(folder);
    listing = listing(~[listing.isdir]);
    if isempty(listing)
        error('readVolumeHU:NoDicom', 'The folder contains no files.');
    end
    headers = struct( ...
        'slope', {}, 'intercept', {}, 'hasIntercept', {}, ...
        'pixelSpacing', {}, 'spacingBetweenSlices', {}, 'sliceThicknessMM', {}, ...
        'position', {}, 'orientation', {});
    for index = 1:numel(listing)
        candidate = fullfile(listing(index).folder, listing(index).name);
        try
            info = dicominfo(candidate);
        catch
            continue;
        end
        headers(end + 1) = headerFromInfo(info); %#ok<AGROW>
    end
    if isempty(headers)
        error('readVolumeHU:NoDicom', 'No DICOM header could be read in %s.', folder);
    end
end

function header = headerFromInfo(info)
    [intercept, hasIntercept] = tagOrPresent(info, 'RescaleIntercept', 0);
    pixel = numericVector(info, 'PixelSpacing', 2);
    between = numericVector(info, 'SpacingBetweenSlices', 1);
    % Recorded only. voxelSpacingMM never receives SliceThickness.
    thickness = numericVector(info, 'SliceThickness', 1);
    position = numericVector(info, 'ImagePositionPatient', 3);
    orientation = numericVector(info, 'ImageOrientationPatient', 6);
    header = struct();
    header.slope = tagOr(info, 'RescaleSlope', 1);
    header.intercept = intercept;
    header.hasIntercept = hasIntercept;
    if numel(pixel) >= 2
        header.pixelSpacing = pixel(1:2).';
    else
        header.pixelSpacing = [];
    end
    if ~isempty(between)
        header.spacingBetweenSlices = between(1);
    else
        header.spacingBetweenSlices = [];
    end
    if ~isempty(thickness)
        header.sliceThicknessMM = thickness(1);
    else
        header.sliceThicknessMM = [];
    end
    if numel(position) >= 3
        header.position = position(1:3).';
    else
        header.position = [];
    end
    if numel(orientation) >= 6
        header.orientation = orientation(1:6).';
    else
        header.orientation = [];
    end
end

function headers = headersForVolume(headers, spatial)
    positions = matrixWithColumns(spatialField(spatial, 'PatientPositions'), 3);
    if size(positions, 1) < 1
        return;
    end
    keep = false(1, numel(headers));
    for index = 1:numel(headers)
        position = headers(index).position;
        if numel(position) < 3
            continue;
        end
        delta = positions - position(1:3);
        keep(index) = any(sum(delta.^2, 2) <= 0.05^2);
    end
    if any(keep)
        headers = headers(keep);
    end
end

function meta = reduceHeaders(headers)
    meta = struct();
    meta.slope = [];
    meta.intercept = [];
    meta.interceptWasPresent = false;
    meta.pixelSpacing = [NaN NaN];
    meta.spacingBetweenSlices = [];
    meta.sliceThicknessMM = [];
    meta.positions = zeros(0, 3);
    meta.orientation = [];
    betweenValues = [];
    thicknessValues = [];
    for index = 1:numel(headers)
        item = headers(index);
        if isempty(meta.slope)
            meta.slope = item.slope;
            meta.intercept = item.intercept;
        elseif abs(item.slope - meta.slope) > 1e-6 || abs(item.intercept - meta.intercept) > 1e-6
            error('readVolumeHU:InconsistentRescale', ...
                'RescaleSlope or RescaleIntercept changes between slices.');
        end
        meta.interceptWasPresent = meta.interceptWasPresent || item.hasIntercept;
        if numel(item.pixelSpacing) >= 2
            candidate = item.pixelSpacing(1:2);
            if any(~isfinite(meta.pixelSpacing))
                meta.pixelSpacing = candidate;
            elseif any(abs(meta.pixelSpacing - candidate) > 1e-4)
                error('readVolumeHU:InconsistentSpacing', ...
                    'PixelSpacing changes between slices of the series.');
            end
        end
        if ~isempty(item.spacingBetweenSlices)
            betweenValues(end + 1) = item.spacingBetweenSlices; %#ok<AGROW>
        end
        if ~isempty(item.sliceThicknessMM)
            thicknessValues(end + 1) = item.sliceThicknessMM; %#ok<AGROW>
        end
        if numel(item.position) >= 3
            meta.positions(end + 1, :) = item.position(1:3); %#ok<AGROW>
        end
        if numel(item.orientation) >= 6
            meta.orientation = consistentOrientation(meta.orientation, item.orientation(1:6));
        end
    end
    if isempty(meta.slope)
        meta.slope = 1;
        meta.intercept = 0;
    end
    % Disagreeing fallbacks are dropped. They are not averaged, and they
    % are not replaced by SliceThickness.
    if ~isempty(betweenValues) && all(abs(betweenValues - betweenValues(1)) <= 1e-4)
        meta.spacingBetweenSlices = betweenValues(1);
    end
    if ~isempty(thicknessValues) && all(abs(thicknessValues - thicknessValues(1)) <= 1e-4)
        meta.sliceThicknessMM = thicknessValues(1);
    end
end

function [pixelSpacing, positions, orientation, positionsDescribeVolume] = ...
        geometryFromSpatial(spatial, meta)
    pixelSpacing = pixelSpacingFromSpatial(spatialField(spatial, 'PixelSpacings'), meta.pixelSpacing);
    positions = matrixWithColumns(spatialField(spatial, 'PatientPositions'), 3);
    positionsDescribeVolume = size(positions, 1) >= 2;
    if ~positionsDescribeVolume
        positions = meta.positions;
    end
    orientation = orientationFromSpatial(spatialField(spatial, 'PatientOrientations'), meta.orientation);
end

function spacing = pixelSpacingFromSpatial(raw, fallback)
    spacing = fallback;
    raw = matrixWithColumns(raw, 2);
    if isempty(raw)
        return;
    end
    valid = all(isfinite(raw), 2) & all(raw > 0, 2);
    raw = raw(valid, :);
    if isempty(raw)
        return;
    end
    if any(max(raw, [], 1) - min(raw, [], 1) > 1e-4)
        error('readVolumeHU:InconsistentSpacing', ...
            'PixelSpacing changes between slices of the volume.');
    end
    spacing = raw(1, :);
end

function orientation = orientationFromSpatial(raw, fallback)
    orientation = fallback;
    if isempty(raw) || ~isnumeric(raw)
        return;
    end
    raw = double(raw);
    if ndims(raw) ~= 3 || size(raw, 1) ~= 2 || size(raw, 2) ~= 3
        return;
    end
    current = [];
    for index = 1:size(raw, 3)
        candidate = [reshape(raw(1, :, index), 1, 3), reshape(raw(2, :, index), 1, 3)];
        if any(~isfinite(candidate))
            continue;
        end
        current = consistentOrientation(current, candidate);
    end
    if ~isempty(current)
        orientation = current;
    end
end

function values = matrixWithColumns(raw, columns)
    values = zeros(0, columns);
    if isempty(raw) || ~isnumeric(raw)
        return;
    end
    raw = double(raw);
    if size(raw, 2) ~= columns && size(raw, 1) == columns
        raw = raw.';
    end
    if size(raw, 2) ~= columns
        return;
    end
    values = raw;
end

function value = spatialField(spatial, name)
    value = [];
    if isstruct(spatial) && isfield(spatial, name)
        value = spatial.(name);
    end
end

function assertVolumeImageSize(spatial, hu)
    expected = matrixRow(spatialField(spatial, 'ImageSize'));
    if isempty(expected)
        return;
    end
    actual = [size(hu, 1), size(hu, 2), size(hu, 3)];
    if numel(expected) == 3 && isequal(expected(1:3), actual)
        return;
    end
    if numel(expected) >= 4 && expected(3) == 1 && isequal(expected([1 2 4]), actual)
        return;
    end
    error('readVolumeHU:DicomShape', ...
        'spatial.ImageSize does not match the HU volume.');
end

function row = matrixRow(raw)
    row = [];
    if isempty(raw) || ~isnumeric(raw)
        return;
    end
    row = double(raw(:).');
end

function orientation = consistentOrientation(current, candidate)
    if isempty(current)
        orientation = candidate(:).';
        return;
    end
    currentNormal = cross(current(1:3), current(4:6));
    candidateNormal = cross(candidate(1:3), candidate(4:6));
    currentMagnitude = norm(currentNormal);
    candidateMagnitude = norm(candidateNormal);
    if currentMagnitude < 1e-8 || candidateMagnitude < 1e-8
        error('readVolumeHU:BadOrientation', ...
            'ImageOrientationPatient does not define a slice normal.');
    end
    alignment = abs(dot(currentNormal, candidateNormal)) / (currentMagnitude * candidateMagnitude);
    if alignment < 0.999
        error('readVolumeHU:InconsistentOrientation', ...
            'ImageOrientationPatient changes between slices.');
    end
    orientation = current;
end

function values = numericVector(info, name, count)
    values = [];
    if ~isfield(info, name) || isempty(info.(name)) || ~isnumeric(info.(name))
        return;
    end
    raw = double(info.(name)(:));
    if numel(raw) < count || any(~isfinite(raw(1:count)))
        return;
    end
    values = raw(1:count);
end

function out = emptyOutput(hu, spacing)
    out = struct();
    out.hu = hu;
    out.spacingMM = spacing;
    out.rescaleSlope = [];
    out.rescaleIntercept = [];
    out.huConfirmed = false;
    out.source = '';
end

function value = optionalField(source, name, defaultValue)
    if isfield(source, name) && ~isempty(source.(name))
        value = source.(name);
    else
        value = defaultValue;
    end
end

function value = tagOr(info, name, defaultValue)
    [value, present] = tagOrPresent(info, name, defaultValue);
    if ~present
        value = defaultValue;
    end
end

function [value, present] = tagOrPresent(info, name, defaultValue)
    present = isfield(info, name) && ~isempty(info.(name));
    if ~present
        value = defaultValue;
        return;
    end
    raw = info.(name);
    if isnumeric(raw)
        value = double(raw(1));
    else
        value = defaultValue;
        present = false;
    end
    if ~isfinite(value)
        value = defaultValue;
        present = false;
    end
end
