function report = compareDenoising(phantom, varargin)
%COMPAREDENOISING Denoising methods and their effect on volume error.
%
%   Methods: gaussian (imgaussfilt3), median (medfilt3), bilateral
%   (imbilatfilt), non-local means (imnlmfilt), Wiener (wiener2).
%   PSNR uses the noiseless phantom (mask painted with BoneHU / BackgroundHU)
%   as the reference. SSIM is the mean of slice-wise ssim on that same
%   normalized range, skipping slices that are constant in the reference.
%   Volume error is (voxelVolume - analyticVolume) / analyticVolume after
%   Otsu segmentation with no extra morphological opening.
%
%   A high PSNR is not treated as proof that the boundary was preserved.
%   The volume error is the quantity that matters for this project.
%   Values are computed from the arrays passed in. They are not constants.

    assertImageToolbox();
    parser = inputParser;
    parser.FunctionName = 'compareDenoising';
    parser.addParameter('Methods', {'gaussian', 'median', 'bilateral', 'nlm', 'wiener'});
    parser.addParameter('SigmaMM', 0.8);
    parser.addParameter('OutDir', '');
    parser.parse(varargin{:});
    opt = parser.Results;

    if ~isstruct(phantom) || ~isfield(phantom, 'volumeHU') || ~isfield(phantom, 'mask')
        error('compareDenoising:BadPhantom', ...
            'Pass a phantom struct that still has volumeHU and mask.');
    end
    hu = double(phantom.volumeHU);
    spacing = double(phantom.spacingMM(:)');
    reference = double(phantom.backgroundHU) * ones(size(hu));
    reference(logical(phantom.mask)) = double(phantom.boneHU);
    analytic = phantom.analyticVolumeMM3;

    midRow = max(1, round(size(hu, 1) / 2));
    midSlice = max(1, round(size(hu, 3) / 2));
    if isfield(phantom, 'xMM') && numel(phantom.xMM) == size(hu, 2)
        positionMM = double(phantom.xMM(:).');
    else
        positionMM = (0:size(hu, 2) - 1) * spacing(2);
    end

    before = measureVolume(hu, spacing, analytic);
    methods = cell(1, numel(opt.Methods));
    for index = 1:numel(opt.Methods)
        name = char(opt.Methods{index});
        denoised = denoiseVolume(hu, name, spacing, opt.SigmaMM);
        measured = measureVolume(denoised, spacing, analytic);
        methods{index} = struct( ...
            'name', string(name), ...
            'sigmaMM', opt.SigmaMM, ...
            'psnrHU', psnrHU(reference, denoised), ...
            'ssimMean', meanSliceSsim(reference, denoised), ...
            'voxelVolumeMM3', measured.voxelVolumeMM3, ...
            'relErrVoxelVolume', measured.relErrVoxelVolume, ...
            'note', string(measured.note), ...
            'profileHU', double(denoised(midRow, :, midSlice)));
    end

    report = struct();
    report.version = resultSchema().version;
    report.executed = true;
    report.clinical = false;
    report.units = resultSchema().units;
    report.reference = 'noiseless phantom painted from the known mask';
    report.voxelVolumeBeforeMM3 = before.voxelVolumeMM3;
    report.relErrVoxelVolumeBefore = before.relErrVoxelVolume;
    report.profile = struct( ...
        'positionMM', positionMM, ...
        'unitPosition', 'mm', ...
        'unitIntensity', 'HU', ...
        'referenceHU', reference(midRow, :, midSlice), ...
        'noisyHU', hu(midRow, :, midSlice));
    report.methods = [methods{:}];
    report.jsonPath = '';
    report.differencePng = '';

    if ~isempty(opt.OutDir)
        if ~exist(opt.OutDir, 'dir')
            mkdir(opt.OutDir);
        end
        report.jsonPath = fullfile(opt.OutDir, 'denoise.json');
        payload = report;
        payload.jsonPath = 'denoise.json';
        for index = 1:numel(payload.methods)
            payload.methods(index).psnrHU = jsonSafeNumber(payload.methods(index).psnrHU);
            payload.methods(index).ssimMean = jsonSafeNumber(payload.methods(index).ssimMean);
            payload.methods(index).voxelVolumeMM3 = jsonSafeNumber(payload.methods(index).voxelVolumeMM3);
            payload.methods(index).relErrVoxelVolume = jsonSafeNumber(payload.methods(index).relErrVoxelVolume);
        end
        writeJson(payload, report.jsonPath);
        first = denoiseVolume(hu, report.methods(1).name, spacing, opt.SigmaMM);
        difference = first(:, :, midSlice) - reference(:, :, midSlice);
        report.differencePng = fullfile(opt.OutDir, 'denoise_difference.png');
        try
            renderDifference(difference, spacing, report.differencePng);
        catch ME
            report.differencePng = '';
            report.differenceNote = ME.message;
        end
    end
end

function measured = measureVolume(hu, spacing, analytic)
    % NaN means this particular segmentation was not produced.
    measured = struct('voxelVolumeMM3', NaN, 'relErrVoxelVolume', NaN, 'note', '');
    try
        seg = segmentBone(hu, spacing, 'SigmaMM', 0, 'OpenRadiusMM', 0, ...
            'CloseRadiusMM', 0, 'Method', 'otsu');
        measured.voxelVolumeMM3 = nnz(seg.mask) * prod(spacing);
        if ~isempty(analytic) && isfinite(analytic)
            measured.relErrVoxelVolume = relativeError(measured.voxelVolumeMM3, analytic);
        end
    catch ME
        measured.note = ME.message;
    end
end

function value = meanSliceSsim(reference, denoised)
    value = NaN;
    if exist('ssim', 'file') ~= 2 && exist('ssim', 'builtin') ~= 5
        return;
    end
    lo = min(reference(:));
    hi = max(reference(:));
    if hi <= lo
        return;
    end
    scores = [];
    for sliceIndex = 1:size(reference, 3)
        ref = (reference(:, :, sliceIndex) - lo) ./ (hi - lo);
        den = (denoised(:, :, sliceIndex) - lo) ./ (hi - lo);
        den = min(1, max(0, den));
        if max(ref(:)) - min(ref(:)) < 1e-6
            continue;
        end
        try
            scores(end + 1) = ssim(den, ref); %#ok<AGROW>
        catch
            value = NaN;
            return;
        end
    end
    if ~isempty(scores)
        value = mean(scores);
    end
end

function renderDifference(differenceHU, spacing, outFile)
    cols = (0:size(differenceHU, 2) - 1) * spacing(2);
    rows = (0:size(differenceHU, 1) - 1) * spacing(1);
    figureHandle = figure('Visible', 'off', 'Color', 'w');
    cleanup = onCleanup(@() closeIfOpen(figureHandle)); %#ok<NASGU>
    axesHandle = axes('Parent', figureHandle);
    imagesc(axesHandle, cols, rows, differenceHU);
    axis(axesHandle, 'image');
    colormap(axesHandle, divergingColormap(256));
    colorbarHandle = colorbar(axesHandle);
    colorbarHandle.Label.String = 'Difference (HU)';
    xlabel(axesHandle, 'x (mm)');
    ylabel(axesHandle, 'y (mm)');
    title(axesHandle, 'Denoise moins reference');
    exportgraphics(figureHandle, outFile, 'Resolution', 120);
end

function writeJson(payload, outFile)
    try
        text = jsonencode(payload, 'PrettyPrint', true);
    catch
        text = jsonencode(payload);
    end
    fid = fopen(outFile, 'w', 'n', 'UTF-8');
    if fid < 0
        error('compareDenoising:Write', 'Could not write %s.', outFile);
    end
    closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', text);
end

function closeIfOpen(figureHandle)
    if ~isempty(figureHandle) && isgraphics(figureHandle)
        close(figureHandle);
    end
end
