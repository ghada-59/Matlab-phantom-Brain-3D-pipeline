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
%   Spacing is [row, column, slice] in millimetres. Slice spacing prefers
%   the distance between ImagePositionPatient entries, then
%   SpacingBetweenSlices, then SliceThickness. The function refuses to
%   assume 1 mm when the spacing is missing: that assumption silently
%   scales every volume.
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

    [slope, intercept, interceptWasPresent, headerSpacing, header] = seriesRescale(folder);
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
    hu = applyHuRescale(raw, slope, intercept);
    spacing = spacingFromMetadata(spatial, header, headerSpacing, size(hu, 3));

    out = emptyOutput(hu, spacing);
    out.rescaleSlope = slope;
    out.rescaleIntercept = intercept;
    out.huConfirmed = interceptWasPresent;
    out.source = 'dicom';
    out.semiAxesMM = [];
    out.analyticVolumeMM3 = [];
    out.numericVolumeMM3 = [];
    out.backgroundHU = [];
    out.boneHU = [];
    out.mask = [];
    if ~interceptWasPresent
        warning('readVolumeHU:NoIntercept', ...
            ['RescaleIntercept is missing. Intensities were stored with ', ...
             'intercept 0 and are not confirmed Hounsfield units.']);
    end
end

function [slope, intercept, interceptWasPresent, headerSpacing, header] = seriesRescale(folder)
    listing = dir(folder);
    listing = listing(~[listing.isdir]);
    if isempty(listing)
        error('readVolumeHU:NoDicom', 'The folder contains no files.');
    end

    slope = [];
    intercept = [];
    interceptWasPresent = false;
    headerSpacing = [NaN NaN NaN];
    header = struct();
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
        if isempty(slope)
            slope = thisSlope;
            intercept = thisIntercept;
            header = info;
            headerSpacing = headerSpacingOf(info);
        elseif abs(thisSlope - slope) > 1e-6 || abs(thisIntercept - intercept) > 1e-6
            error('readVolumeHU:InconsistentRescale', ...
                'RescaleSlope or RescaleIntercept changes between slices.');
        end
        interceptWasPresent = interceptWasPresent || hasIntercept;
    end
    if readable == 0
        error('readVolumeHU:NoDicom', 'No DICOM header could be read in %s.', folder);
    end
end

function spacing = headerSpacingOf(info)
    spacing = [NaN NaN NaN];
    if isfield(info, 'PixelSpacing') && numel(info.PixelSpacing) >= 2
        pixelSpacing = double(info.PixelSpacing(:));
        spacing(1) = pixelSpacing(1);
        spacing(2) = pixelSpacing(2);
    end
    if isfield(info, 'SpacingBetweenSlices') && ~isempty(info.SpacingBetweenSlices)
        spacing(3) = double(info.SpacingBetweenSlices(1));
    elseif isfield(info, 'SliceThickness') && ~isempty(info.SliceThickness)
        spacing(3) = double(info.SliceThickness(1));
    end
end

function spacing = spacingFromMetadata(spatial, header, headerSpacing, nSlices)
    spacing = headerSpacing;
    if isstruct(spatial) && isfield(spatial, 'PixelSpacings')
        pixelSpacing = double(spatial.PixelSpacings);
        if ismatrix(pixelSpacing) && size(pixelSpacing, 2) >= 2
            spacing(1) = median(pixelSpacing(:, 1), 'omitnan');
            spacing(2) = median(pixelSpacing(:, 2), 'omitnan');
        end
    end
    positionSpacing = NaN;
    if isstruct(spatial) && isfield(spatial, 'PatientPositions')
        positionSpacing = sliceSpacingFromPositions(double(spatial.PatientPositions));
    end
    if ~isfinite(positionSpacing) && isfield(header, 'ImagePositionPatient') && nSlices >= 2
        % A single header cannot describe the step. Keep the header fallback.
        positionSpacing = NaN;
    end
    if isfinite(positionSpacing) && positionSpacing > 0
        spacing(3) = positionSpacing;
    end
    if any(~isfinite(spacing)) || any(spacing <= 0)
        error('readVolumeHU:NoSpacing', ...
            ['Voxel spacing is incomplete (row, column, slice) = [%g %g %g] mm. ', ...
             'Refusing to assume 1 mm.'], spacing(1), spacing(2), spacing(3));
    end
end

function spacingZ = sliceSpacingFromPositions(positions)
    spacingZ = NaN;
    if isempty(positions) || size(positions, 2) ~= 3 || size(positions, 1) < 2
        return;
    end
    step = positions(2, :) - positions(1, :);
    [~, axis] = max(abs(step));
    [~, order] = sort(positions(:, axis));
    sorted = positions(order, :);
    deltas = diff(sorted, 1, 1);
    distances = sqrt(sum(deltas.^2, 2));
    distances = distances(isfinite(distances) & distances > 0);
    if ~isempty(distances)
        spacingZ = median(distances);
    end
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
