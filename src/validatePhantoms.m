function report = validatePhantoms(varargin)
%VALIDATEPHANTOMS Relative errors against the analytic ellipsoid.
%
%   The sweep uses cubic voxels. imrotate3 rotates the array, which is a
%   rotation in millimetres only when the spacing is isotropic, so the
%   invariance check is not run on anisotropic grids.
%
%   For each voxel size, noise level, and rotation angle the function
%   builds a phantom, segments it, and records
%     (measured - reference) / reference
%   for the voxel volume, the mesh volume, the mesh area, and the three
%   semi-axes sorted from longest to shortest. The area reference is
%   referenceEllipsoidArea. The volume reference is 4/3*pi*a*b*c.
%
%   Rotation angles other than 0 also record the relative change of the
%   voxel volume against the unrotated run at the same voxel size and noise.
%   That change is an invariance diagnostic. It is not compared to zero here.
%
%   A second segmentation with the fixed HU threshold is stored next to the
%   Otsu result. Nothing in this file is a precomputed error.

    assertImageToolbox();
    design = validationSettings();
    parser = inputParser;
    parser.FunctionName = 'validatePhantoms';
    parser.addParameter('SemiAxesMM', [12 9 7]);
    parser.addParameter('VoxelSizesMM', design.voxelSizesMM);
    parser.addParameter('NoiseLevelsHU', design.noiseLevelsHU);
    parser.addParameter('RotationAnglesDeg', design.rotationAnglesDeg);
    parser.addParameter('MarginMM', []);
    parser.addParameter('Seed', 42);
    parser.addParameter('OutDir', '');
    parser.addParameter('SigmaMM', 0);
    parser.addParameter('OpenRadiusMM', 0);
    parser.addParameter('CloseRadiusMM', 0);
    parser.addParameter('MeshSmoothSigmaVox', 0.5);
    parser.parse(varargin{:});
    opt = parser.Results;

    semi = double(opt.SemiAxesMM(:)');
    if numel(semi) ~= 3 || any(~isfinite(semi)) || any(semi <= 0)
        error('validatePhantoms:InvalidAxes', 'SemiAxesMM must be a positive 3-vector.');
    end
    if isempty(opt.MarginMM)
        margin = max(semi) + 6;
    else
        margin = double(opt.MarginMM);
    end
    voxelSizes = double(opt.VoxelSizesMM(:)');
    noiseLevels = double(opt.NoiseLevelsHU(:)');
    angles = double(opt.RotationAnglesDeg(:)');
    angles = [angles(angles == 0), angles(angles ~= 0)];
    if isempty(angles)
        error('validatePhantoms:NoAngle', 'At least one rotation angle is required.');
    end

    referenceArea = referenceEllipsoidArea(semi);
    truthAxes = sort(semi, 'descend');
    collected = {};

    for voxelSize = voxelSizes
        if ~isscalar(voxelSize) || voxelSize <= 0
            error('validatePhantoms:InvalidVoxel', 'Voxel sizes must be positive.');
        end
        for noiseSigma = noiseLevels
            baselineVolume = [];
            for angle = angles
                phantom = generateEllipsoidPhantom( ...
                    'SemiAxesMM', semi, ...
                    'VoxelSpacingMM', [voxelSize voxelSize voxelSize], ...
                    'NoiseSigmaHU', noiseSigma, ...
                    'MarginMM', margin, ...
                    'Seed', opt.Seed);
                hu = phantom.volumeHU;
                if angle ~= 0
                    % imrotate3 axis order is [row, column, slice].
                    % [0 1 0] rotates about the column direction (x).
                    hu = imrotate3(hu, angle, [0 1 0], 'linear', 'crop', ...
                        'FillValues', phantom.backgroundHU);
                end
                source = phantom;
                source.volumeHU = hu;
                source.mask = [];
                if angle ~= 0
                    source.numericVolumeMM3 = [];
                end
                meas = runPipeline(source, ...
                    'SigmaMM', opt.SigmaMM, ...
                    'OpenRadiusMM', opt.OpenRadiusMM, ...
                    'CloseRadiusMM', opt.CloseRadiusMM, ...
                    'MeshSmoothSigmaVox', opt.MeshSmoothSigmaVox, ...
                    'Method', 'otsu');
                fixedSeg = segmentBone(hu, phantom.spacingMM, ...
                    'SigmaMM', opt.SigmaMM, ...
                    'OpenRadiusMM', opt.OpenRadiusMM, ...
                    'CloseRadiusMM', opt.CloseRadiusMM, ...
                    'Method', 'fixed');
                fixedVolume = nnz(fixedSeg.mask) * prod(phantom.spacingMM);
                estimated = sort(meas.semiAxesMM, 'descend');
                axisError = relativeError(estimated, truthAxes);

                row = struct();
                row.voxelSizeMM = voxelSize;
                row.noiseSigmaHU = noiseSigma;
                row.rotationDeg = angle;
                row.analyticVolumeMM3 = phantom.analyticVolumeMM3;
                row.voxelVolumeMM3 = meas.voxelVolumeMM3;
                row.meshVolumeMM3 = meas.meshVolumeMM3;
                row.meshAreaMM2 = meas.meshAreaMM2;
                row.referenceAreaMM2 = referenceArea;
                row.relErrVoxelVolume = relativeError(meas.voxelVolumeMM3, phantom.analyticVolumeMM3);
                row.relErrMeshVolume = relativeError(meas.meshVolumeMM3, phantom.analyticVolumeMM3);
                row.relErrArea = relativeError(meas.meshAreaMM2, referenceArea);
                row.trueSemiAxis1MM = truthAxes(1);
                row.trueSemiAxis2MM = truthAxes(2);
                row.trueSemiAxis3MM = truthAxes(3);
                row.estSemiAxis1MM = estimated(1);
                row.estSemiAxis2MM = estimated(2);
                row.estSemiAxis3MM = estimated(3);
                row.relErrAxis1 = axisError(1);
                row.relErrAxis2 = axisError(2);
                row.relErrAxis3 = axisError(3);
                row.sphericityMesh = meas.sphericityMesh;
                row.otsuThresholdHU = meas.threshold.otsuHU;
                row.fixedThresholdHU = meas.threshold.fixedHU;
                row.voxelVolumeFixedMM3 = fixedVolume;
                row.relErrVoxelVolumeFixed = relativeError(fixedVolume, phantom.analyticVolumeMM3);
                if angle == 0
                    baselineVolume = meas.voxelVolumeMM3;
                    row.volumeRelChangeAfterRotation = 0;
                elseif isempty(baselineVolume)
                    % No unrotated run in this sweep. NaN means "not computed".
                    row.volumeRelChangeAfterRotation = NaN;
                else
                    row.volumeRelChangeAfterRotation = relativeError(meas.voxelVolumeMM3, baselineVolume);
                end
                collected{end + 1} = row; %#ok<AGROW>
            end
        end
    end

    rows = [collected{:}];
    report = struct();
    report.settings = opt;
    report.settings.marginMM = margin;
    report.settings.units = resultSchema().units;
    report.rows = rows;
    report.table = struct2table(rows, 'AsArray', true);
    report.csvPath = '';
    if ~isempty(opt.OutDir)
        if ~exist(opt.OutDir, 'dir')
            mkdir(opt.OutDir);
        end
        report.csvPath = fullfile(opt.OutDir, 'validation.csv');
        writetable(report.table, report.csvPath);
    end
end
