function runProject()
%RUNPROJECT Compute phantoms, validation, exports, and denoising.
%
%   Run from the project root in MATLAB R2022b+ with Image Processing Toolbox:
%
%       runProject
%
%   Results are written to results/. They are not created until this function
%   runs. Copy the files listed at the end into dashboard/public/data if you
%   want the dashboard to show them. Until then the dashboard shows an em dash.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'src'));
    outDir = fullfile(root, 'results');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fprintf('Validation sweep: voxel sizes 0.5, 1 and 2 mm. Errors are computed now.\n');
    validatePhantoms('OutDir', outDir);

    fprintf('Batch of 10 random phantoms.\n');
    runBatch('NumPhantoms', 10, 'OutDir', outDir);

    phantom = generateEllipsoidPhantom( ...
        'SemiAxesMM', [24 16 12], ...
        'VoxelSpacingMM', [1 1 1], ...
        'NoiseSigmaHU', 40, ...
        'MarginMM', 8, ...
        'Seed', 42);
    meas = runPipeline(phantom, 'SigmaMM', 0.5);
    exportResults(meas, outDir, 'WriteVideo', true, 'WriteFigures', true);
    compareDenoising(phantom, 'OutDir', outDir);

    mirrorDashboard(outDir, fullfile(root, 'dashboard', 'public', 'data'));
    fprintf('Exports written to %s\n', outDir);
    fprintf('No clinical claim is made from these synthetic phantoms.\n');
end

function mirrorDashboard(outDir, publicData)
    if ~exist(publicData, 'dir')
        return;
    end
    names = {'results.json', 'validation.csv', 'batch.csv', 'denoise.json', 'bone.stl', 'rotation.mp4'};
    for index = 1:numel(names)
        source = fullfile(outDir, names{index});
        if isfile(source)
            copyfile(source, fullfile(publicData, names{index}));
        end
    end
    sliceSource = fullfile(outDir, 'slices');
    if isfolder(sliceSource)
        sliceTarget = fullfile(publicData, 'slices');
        if ~exist(sliceTarget, 'dir')
            mkdir(sliceTarget);
        end
        copyfile(fullfile(sliceSource, '*'), sliceTarget);
    end
    figureSource = fullfile(outDir, 'figures');
    if isfolder(figureSource)
        figureTarget = fullfile(publicData, 'figures');
        if ~exist(figureTarget, 'dir')
            mkdir(figureTarget);
        end
        copyfile(fullfile(figureSource, '*'), figureTarget);
    end
end
