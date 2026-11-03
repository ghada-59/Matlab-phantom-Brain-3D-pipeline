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
    if ndims(hu) > 3 || isvector(hu)
        error('readVolumeHU:BadPhantom', 'Phantom volumeHU must be a 3-D array.');
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

    meta = seriesMetadata(folder);
    try
        [raw, spatial] = dicomreadVolume(folder);
    catch ME
        error('readVolumeHU:DicomRead', ...
            'dicomreadVolume failed for %s (%s).', folder, ME.message);
    end
    raw = squeeze(raw);
    if ismatrix(raw)
        raw = reshape(raw, size(raw, 1), size(raw, 2), 1);
    end
    if ndims(raw) ~= 3
        error('readVolumeHU:DicomShape', ...
            'Expected a single 3-D series after squeeze, got %d dimensions.', ndims(raw));
    end

    % dicomreadVolume is treated as returning stored pixel values. The
    % rescale is applied exactly once here.
    hu = applyHuRescale(raw, meta.slope, meta.intercept);
    [positions, orientation] = positionsFromSpatial(spatial, meta);
    [spacing, sliceSource] = voxelSpacingMM( ...
        meta.pixelSpacing, meta.spacingBetweenSlices, positions, orientation);
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

function meta = seriesMetadata(folder)
    listing = dir(folder);
    listing = listing(~[listing.isdir]);
    if isempty(listing)
        error('readVolumeHU:NoDicom', 'The folder contains no files.');
    end

    meta = struct();
    meta.slope = [];
    meta.intercept = [];
    meta.interceptWasPresent = false;
    meta.pixelSpacing = [NaN NaN];
    meta.spacingBetweenSlices = [];
    meta.sliceThicknessMM = [];
    meta.positions = zeros(0, 3);
    meta.orientation = [];
    readable = 0;
    for index = 1:numel(listing)
        candidate = fullfile(listing(index).folder, listing(index).name);
        try
            info = dicominfo(candidate);
        catch
            continue;
        end
        readable = readable + 1;
        thisSlope = tagOr(info, 'RescaleSlope', 1);
        [thisIntercept, hasIntercept] = tagOrPresent(info, 'RescaleIntercept', 0);
        if isempty(meta.slope)
            meta.slope = thisSlope;
            meta.intercept = thisIntercept;
        elseif abs(thisSlope - meta.slope) > 1e-6 || abs(thisIntercept - meta.intercept) > 1e-6
            error('readVolumeHU:InconsistentRescale', ...
                'RescaleSlope or RescaleIntercept changes between slices.');
        end
        meta.interceptWasPresent = meta.interceptWasPresent || hasIntercept;

        pixel = numericVector(info, 'PixelSpacing', 2);
        if numel(pixel) >= 2 && any(~isfinite(meta.pixelSpacing))
            meta.pixelSpacing = pixel(1:2).';
        end
        between = numericVector(info, 'SpacingBetweenSlices', 1);
        if ~isempty(between) && isempty(meta.spacingBetweenSlices)
            meta.spacingBetweenSlices = between(1);
        end
        % Recorded only. voxelSpacingMM never receives this value.
        thickness = numericVector(info, 'SliceThickness', 1);
        if ~isempty(thickness) && isempty(meta.sliceThicknessMM)
            meta.sliceThicknessMM = thickness(1);
        end
        position = numericVector(info, 'ImagePositionPatient', 3);
        if numel(position) >= 3
            meta.positions(end + 1, :) = position(1:3).'; %#ok<AGROW>
        end
        orientation = numericVector(info, 'ImageOrientationPatient', 6);
        if numel(orientation) >= 6
            meta.orientation = consistentOrientation(meta.orientation, orientation(1:6).');
        end
    end
    if readable == 0
        error('readVolumeHU:NoDicom', 'No DICOM header could be read in %s.', folder);
    end
end

function [positions, orientation] = positionsFromSpatial(spatial, meta)
    positions = meta.positions;
    orientation = meta.orientation;
    if size(positions, 1) >= 2
        return;
    end
    if ~isstruct(spatial) || ~isfield(spatial, 'PatientPositions')
        return;
    end
    spatialPositions = double(spatial.PatientPositions);
    if size(spatialPositions, 2) ~= 3 && size(spatialPositions, 1) == 3
        spatialPositions = spatialPositions.';
    end
    if size(spatialPositions, 2) == 3 && size(spatialPositions, 1) >= 2
        positions = spatialPositions;
    end
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
