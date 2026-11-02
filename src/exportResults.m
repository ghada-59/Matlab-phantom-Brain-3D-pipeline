function payload = exportResults(meas, outDir, varargin)
%EXPORTRESULTS Write the files a local MATLAB run can actually produce.
%
%   Always attempted:
%     results.json     measurements, units, version, no patient identifiers
%     slices/*.png     preview windowed with the bone display preset
%     slices/*.json    raw HU of the three mid planes
%     bone.stl         triangulation from the isosurface, coordinates in mm
%
%   Best effort, because they need a graphics device:
%     figures/mesh.png, figures/axial_hu.png
%     rotation.mp4
%
%   If a best-effort file is not written, its status is 'not_generated' and
%   the reason is the MATLAB error. A partial video is deleted. validation.csv
%   is written by validatePhantoms, not by this function.
%
%   The bone preview window (width 1800 HU, level 400 HU) is a display
%   preset, recorded under slicePreview, not under measurements.

    parser = inputParser;
    parser.FunctionName = 'exportResults';
    parser.addParameter('WriteVideo', true);
    parser.addParameter('WriteFigures', true);
    parser.parse(varargin{:});
    opt = parser.Results;

    if ~isstruct(meas) || ~isfield(meas, 'hu') || ~isfield(meas, 'vertices')
        error('exportResults:BadMeasurement', ...
            'meas must come from runPipeline and still contain hu and vertices.');
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    sliceDir = fullfile(outDir, 'slices');
    if ~exist(sliceDir, 'dir')
        mkdir(sliceDir);
    end

    schema = resultSchema();
    payload = struct();
    payload.version = schema.version;
    payload.units = schema.units;
    payload.executed = true;
    payload.clinical = false;
    payload.academic = true;
    payload.source = meas.source;
    payload.huConfirmed = logical(meas.huConfirmed);
    payload.spacingMM = double(meas.spacingMM(:).');
    payload.spacingOrder = '[sy sx sz] row, column, slice';
    payload.measurements = measurementBlock(meas);
    payload.threshold = meas.threshold;
    payload.centroidMM = jsonSafeNumber(double(meas.centroidMM(:).'));
    payload.axisDirections = jsonSafeNumber(double(meas.axisDirections));
    payload.axisDirectionLayout = 'JSON rows match MATLAB rows. Each column is one axis in [x; y; z].';
    payload.slicePreview = struct( ...
        'widthHU', 1800, ...
        'levelHU', 400, ...
        'note', 'Bone display preset for the PNG only. Raw HU is in the slice JSON.');
    payload.slices = struct('axial', '', 'coronal', '', 'sagittal', '');
    payload.sliceArrays = struct('axial', '', 'coronal', '', 'sagittal', '');
    payload.stl = '';
    payload.video = struct('file', '', 'status', 'not_generated', 'reason', '');
    payload.figures = struct('mesh', '', 'axialHu', '', 'volumeError', '', 'notes', '');

    planes = slicePlanes(meas.hu, meas.spacingMM);
    names = fieldnames(planes);
    for index = 1:numel(names)
        plane = planes.(names{index});
        pngName = [names{index} '.png'];
        jsonName = [names{index} '.json'];
        imwrite(windowToUint8(plane.hu, payload.slicePreview.levelHU, payload.slicePreview.widthHU), ...
            fullfile(sliceDir, pngName));
        slicePayload = struct( ...
            'plane', names{index}, ...
            'rows', size(plane.hu, 1), ...
            'cols', size(plane.hu, 2), ...
            'spacingMM', plane.spacingMM, ...
            'spacingOrder', '[row col] mm', ...
            'index', plane.index, ...
            'count', plane.count, ...
            'unit', 'HU', ...
            'hu', reshape(double(plane.hu).', 1, []));
        writeJson(slicePayload, fullfile(sliceDir, jsonName));
        payload.slices.(names{index}) = ['slices/' pngName];
        payload.sliceArrays.(names{index}) = ['slices/' jsonName];
    end

    stlPath = fullfile(outDir, 'bone.stl');
    triangulationMesh = triangulation(meas.faces, double(meas.vertices));
    stlwrite(triangulationMesh, stlPath);
    payload.stl = 'bone.stl';

    if opt.WriteFigures
        figureDir = fullfile(outDir, 'figures');
        payload.figures = renderFigures(meas, figureDir);
        payload.figures = relativizeFigurePaths(payload.figures, outDir);
    else
        payload.figures.notes = 'WriteFigures was false.';
    end

    if opt.WriteVideo
        videoPath = fullfile(outDir, 'rotation.mp4');
        [videoFile, status, reason] = writeRotationVideo(meas.vertices, meas.faces, videoPath);
        payload.video.status = status;
        payload.video.reason = reason;
        if strcmp(status, 'generated')
            payload.video.file = 'rotation.mp4';
        else
            payload.video.file = '';
            if isfile(videoPath)
                delete(videoPath);
            end
        end
    else
        payload.video.reason = 'WriteVideo was false.';
    end

    writeJson(payload, fullfile(outDir, 'results.json'));
end

function block = measurementBlock(meas)
    fields = {'voxelVolumeMM3', 'meshVolumeMM3', 'meshAreaMM2', ...
        'analyticVolumeMM3', 'numericRasterVolumeMM3', 'referenceAreaMM2', ...
        'semiAxesMM', 'semiAxesTrueMM', 'sphericityMesh', 'sphericityVoxel', ...
        'solidity', 'principalAxisLengthVoxels', 'relErrVoxelVolume', ...
        'relErrMeshVolume', 'relErrArea', 'relErrSemiAxes'};
    block = struct();
    for index = 1:numel(fields)
        name = fields{index};
        if isfield(meas, name)
            block.(name) = jsonSafeNumber(meas.(name));
        else
            block.(name) = [];
        end
    end
end

function planes = slicePlanes(hu, spacing)
    nRows = size(hu, 1);
    nCols = size(hu, 2);
    nSlices = size(hu, 3);
    iz = max(1, round(nSlices / 2));
    iy = max(1, round(nRows / 2));
    ix = max(1, round(nCols / 2));
    planes.axial = struct( ...
        'hu', hu(:, :, iz), ...
        'spacingMM', [spacing(1) spacing(2)], ...
        'index', iz, 'count', nSlices);
    coronal = permute(squeeze(hu(iy, :, :)), [2 1]);
    planes.coronal = struct( ...
        'hu', coronal, ...
        'spacingMM', [spacing(3) spacing(2)], ...
        'index', iy, 'count', nRows);
    sagittal = permute(squeeze(hu(:, ix, :)), [2 1]);
    planes.sagittal = struct( ...
        'hu', sagittal, ...
        'spacingMM', [spacing(3) spacing(1)], ...
        'index', ix, 'count', nCols);
end

function img = windowToUint8(slice, level, width)
    low = level - width / 2;
    high = level + width / 2;
    scaled = (double(slice) - low) ./ (high - low);
    scaled = min(1, max(0, scaled));
    img = uint8(round(255 * scaled));
end

function [filePath, status, reason] = writeRotationVideo(vertices, faces, outFile)
    filePath = '';
    status = 'not_generated';
    reason = '';
    figureHandle = [];
    writer = [];
    try
        figureHandle = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 640 480]);
        patch('Vertices', vertices, 'Faces', faces, ...
            'FaceColor', [232 220 200] / 255, ...
            'EdgeColor', 'none', ...
            'FaceLighting', 'gouraud');
        camlight('headlight');
        lighting gouraud;
        axis equal off;
        view(3);
        writer = VideoWriter(outFile, 'MPEG-4');
        writer.FrameRate = 24;
        writer.Quality = 85;
        open(writer);
        for azimuth = 0:5:355
            view(azimuth, 18);
            drawnow;
            writeVideo(writer, getframe(figureHandle));
        end
        close(writer);
        writer = [];
        close(figureHandle);
        figureHandle = [];
        filePath = outFile;
        status = 'generated';
    catch ME
        reason = ME.message;
        status = 'not_generated';
        if ~isempty(writer)
            try
                close(writer);
            catch
            end
        end
        if ~isempty(figureHandle) && isgraphics(figureHandle)
            close(figureHandle);
        end
        if isfile(outFile)
            delete(outFile);
        end
    end
end

function figures = relativizeFigurePaths(figures, outDir)
    names = {'mesh', 'axialHu', 'volumeError'};
    prefix = [outDir filesep];
    for index = 1:numel(names)
        value = figures.(names{index});
        if ischar(value) && startsWith(value, prefix)
            figures.(names{index}) = strrep(value(numel(prefix) + 1:end), '\', '/');
        end
    end
end

function writeJson(payload, outFile)
    try
        text = jsonencode(payload, 'PrettyPrint', true);
    catch
        text = jsonencode(payload);
    end
    fid = fopen(outFile, 'w', 'n', 'UTF-8');
    if fid < 0
        error('exportResults:Write', 'Could not write %s.', outFile);
    end
    closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', text);
end
