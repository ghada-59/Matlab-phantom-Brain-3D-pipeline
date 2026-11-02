classdef ExportTest < matlab.unittest.TestCase
    % Export and validation tests compare files to values just computed in
    % the same run. They do not expect a stored numeric result.

    methods (TestClassSetup)
        function addSource(testCase)
            root = projectRootFromTest();
            addpath(fullfile(root, 'src'));
            testCase.addTeardown(@() rmpath(fullfile(root, 'src')));
        end
    end

    methods (Test)
        function testExportMatchesThePipelineValues(testCase)
            phantom = generateEllipsoidPhantom( ...
                'SemiAxesMM', [14 10 8], ...
                'VoxelSpacingMM', [1 1 1], ...
                'NoiseSigmaHU', 0, ...
                'MarginMM', 4, ...
                'Seed', 3);
            meas = runPipeline(phantom, 'SigmaMM', 0, 'OpenRadiusMM', 0, ...
                'CloseRadiusMM', 0, 'MeshSmoothSigmaVox', 0);
            outDir = tempname;
            mkdir(outDir);
            cleanup = onCleanup(@() rmdir(outDir, 's')); %#ok<NASGU>

            payload = exportResults(meas, outDir, 'WriteVideo', true, 'WriteFigures', true);
            testCase.verifyTrue(payload.executed);
            testCase.verifyEqual(payload.units.intensity, 'HU');
            testCase.verifyEqual(payload.units.volume, 'mm^3');
            testCase.verifyEqual(payload.measurements.voxelVolumeMM3, meas.voxelVolumeMM3, 'AbsTol', 1e-6);
            testCase.verifyEqual(payload.measurements.meshAreaMM2, meas.meshAreaMM2, 'AbsTol', 1e-6);
            testCase.verifyEqual(payload.measurements.relErrVoxelVolume, ...
                (meas.voxelVolumeMM3 - phantom.analyticVolumeMM3) / phantom.analyticVolumeMM3, ...
                'AbsTol', 1e-12);

            jsonText = fileread(fullfile(outDir, 'results.json'));
            testCase.verifyFalse(contains(jsonText, 'PatientName'));
            testCase.verifyFalse(contains(jsonText, 'volumeHU'));
            decoded = jsondecode(jsonText);
            testCase.verifyEqual(decoded.version, '1.0');
            testCase.verifyEqual(decoded.measurements.voxelVolumeMM3, meas.voxelVolumeMM3, 'AbsTol', 1e-6);

            stlInfo = dir(fullfile(outDir, 'bone.stl'));
            testCase.verifyGreaterThan(stlInfo.bytes, 84);

            axialJson = jsondecode(fileread(fullfile(outDir, 'slices', 'axial.json')));
            expectedHu = reshape(meas.hu(:, :, axialJson.index).', 1, []);
            testCase.verifyEqual(double(axialJson.hu(:).'), expectedHu, 'AbsTol', 1e-6);
            testCase.verifyEqual(axialJson.unit, 'HU');
            testCase.verifyEqual(axialJson.rows * axialJson.cols, numel(expectedHu));

            png = imread(fullfile(outDir, 'slices', 'axial.png'));
            level = 400;
            width = 1800;
            low = level - width / 2;
            scaled = (meas.hu(:, :, axialJson.index) - low) ./ width;
            scaled = min(1, max(0, scaled));
            testCase.verifyEqual(png, uint8(round(255 * scaled)));
            coronal = jsondecode(fileread(fullfile(outDir, 'slices', 'coronal.json')));
            sagittal = jsondecode(fileread(fullfile(outDir, 'slices', 'sagittal.json')));
            testCase.verifyEqual([coronal.rows, coronal.cols], [size(meas.hu, 3), size(meas.hu, 2)]);
            testCase.verifyEqual([sagittal.rows, sagittal.cols], [size(meas.hu, 3), size(meas.hu, 1)]);
            testCase.verifyEqual(coronal.unit, 'HU');
            testCase.verifyEqual(sagittal.unit, 'HU');

            if strcmp(payload.video.status, 'generated')
                testCase.verifyTrue(isfile(fullfile(outDir, 'rotation.mp4')));
                testCase.verifyGreaterThan(dir(fullfile(outDir, 'rotation.mp4')).bytes, 0);
            else
                testCase.verifyEqual(payload.video.status, 'not_generated');
                testCase.verifyFalse(isfile(fullfile(outDir, 'rotation.mp4')));
                testCase.verifyNotEmpty(payload.video.reason);
            end
            if ~isempty(payload.figures.mesh)
                testCase.verifyTrue(isfile(fullfile(outDir, payload.figures.mesh)));
            else
                testCase.verifyNotEmpty(payload.figures.notes);
            end
        end

        function testValidationErrorsAreComputed(testCase)
            outDir = tempname;
            mkdir(outDir);
            cleanup = onCleanup(@() rmdir(outDir, 's')); %#ok<NASGU>
            report = validatePhantoms( ...
                'SemiAxesMM', [14 10 8], ...
                'VoxelSizesMM', 2, ...
                'NoiseLevelsHU', 0, ...
                'RotationAnglesDeg', [15 0], ...
                'MarginMM', 16, ...
                'OutDir', outDir);
            testCase.verifyEqual(numel(report.rows), 2);
            testCase.verifyEqual(report.rows(1).rotationDeg, 0);
            testCase.verifyEqual(report.rows(1).volumeRelChangeAfterRotation, 0, 'AbsTol', 0);
            expected = (report.rows(1).voxelVolumeMM3 - report.rows(1).analyticVolumeMM3) ...
                / report.rows(1).analyticVolumeMM3;
            testCase.verifyEqual(report.rows(1).relErrVoxelVolume, expected, 'AbsTol', 1e-12);
            expectedArea = (report.rows(1).meshAreaMM2 - report.rows(1).referenceAreaMM2) ...
                / report.rows(1).referenceAreaMM2;
            testCase.verifyEqual(report.rows(1).relErrArea, expectedArea, 'AbsTol', 1e-12);
            expectedAxis = (report.rows(1).estSemiAxis1MM - report.rows(1).trueSemiAxis1MM) ...
                / report.rows(1).trueSemiAxis1MM;
            testCase.verifyEqual(report.rows(1).relErrAxis1, expectedAxis, 'AbsTol', 1e-12);
            expectedRotation = (report.rows(2).voxelVolumeMM3 - report.rows(1).voxelVolumeMM3) ...
                / report.rows(1).voxelVolumeMM3;
            testCase.verifyEqual(report.rows(2).volumeRelChangeAfterRotation, expectedRotation, 'AbsTol', 1e-12);
            testCase.verifyNotEmpty(report.rows(1).otsuThresholdHU);
            testCase.verifyEqual(report.rows(1).fixedThresholdHU, 300, 'AbsTol', 0);
            csvText = fileread(report.csvPath);
            testCase.verifyTrue(contains(csvText, 'relErrVoxelVolume'));
            testCase.verifyTrue(contains(csvText, 'relErrArea'));
            testCase.verifyTrue(contains(csvText, 'volumeRelChangeAfterRotation'));

            design = validationSettings();
            testCase.verifyEqual(design.voxelSizesMM, [0.5 1 2], 'AbsTol', 0);
            testCase.verifyEqual(design.noiseLevelsHU, [0 100], 'AbsTol', 0);
            testCase.verifyEqual(design.rotationAnglesDeg, [0 30], 'AbsTol', 0);
        end

        function testBatchRelativeErrorIdentity(testCase)
            outDir = tempname;
            mkdir(outDir);
            cleanup = onCleanup(@() rmdir(outDir, 's')); %#ok<NASGU>
            report = runBatch('NumPhantoms', 2, 'VoxelSpacingMM', [2 2 2], ...
                'NoiseSigmaHU', 0, 'Seed', 11, 'OutDir', outDir);
            testCase.verifyEqual(height(report.table), 2);
            for index = 1:2
                row = report.rows(index);
                expected = (row.voxelVolumeMM3 - row.analyticVolumeMM3) / row.analyticVolumeMM3;
                testCase.verifyEqual(row.relErrVoxelVolume, expected, 'AbsTol', 1e-12);
                testCase.verifyGreaterThan(row.analyticVolumeMM3, 0);
            end
            testCase.verifyTrue(isfile(report.csvPath));
        end

        function testDenoiseMetricsMatchTheFormula(testCase)
            phantom = generateEllipsoidPhantom( ...
                'SemiAxesMM', [8 6 5], ...
                'VoxelSpacingMM', [1 1 1], ...
                'NoiseSigmaHU', 25, ...
                'MarginMM', 3, ...
                'Seed', 4);
            report = compareDenoising(phantom, ...
                'Methods', {'gaussian', 'median', 'bilateral', 'nlm', 'wiener'});
            rawNames = {report.methods.name};
            names = cellfun(@char, rawNames, 'UniformOutput', false);
            testCase.verifyEqual(names, {'gaussian', 'median', 'bilateral', 'nlm', 'wiener'});
            reference = phantom.backgroundHU * ones(size(phantom.volumeHU));
            reference(phantom.mask) = phantom.boneHU;
            gaussian = denoiseVolume(phantom.volumeHU, 'gaussian', phantom.spacingMM, report.methods(1).sigmaMM);
            testCase.verifyEqual(size(gaussian), size(phantom.volumeHU));
            testCase.verifyEqual(report.methods(1).psnrHU, psnrHU(reference, gaussian), 'AbsTol', 1e-9);
            for index = 1:numel(report.methods)
                row = report.methods(index);
                testCase.verifyTrue(isfinite(row.psnrHU));
                expected = (row.voxelVolumeMM3 - phantom.analyticVolumeMM3) / phantom.analyticVolumeMM3;
                testCase.verifyEqual(row.relErrVoxelVolume, expected, 'AbsTol', 1e-12);
                testCase.verifyEqual(numel(row.profileHU), numel(report.profile.positionMM));
            end
            testCase.verifyEqual(report.profile.unitIntensity, 'HU');
            testCase.verifyEqual(report.profile.unitPosition, 'mm');
            testCase.verifyEqual(char(report.methods(1).status), 'computed');
        end

        function testWaveletWithoutToolboxDoesNotInventMetrics(testCase)
            phantom = generateEllipsoidPhantom( ...
                'SemiAxesMM', [8 6 5], ...
                'VoxelSpacingMM', [1 1 1], ...
                'NoiseSigmaHU', 0, ...
                'MarginMM', 2, ...
                'Seed', 5);
            report = compareDenoising(phantom, 'Methods', {'wavelet'});
            row = report.methods;
            testCase.verifyEqual(char(row.name), 'wavelet');
            available = exist('wdenoise2', 'file') == 2 || exist('wdenoise2', 'builtin') == 5;
            if available
                testCase.verifyEqual(char(row.status), 'computed');
                testCase.verifyTrue(isfinite(row.psnrHU));
                denoised = denoiseVolume(phantom.volumeHU, 'wavelet', phantom.spacingMM, row.sigmaMM);
                reference = phantom.backgroundHU * ones(size(phantom.volumeHU));
                reference(phantom.mask) = phantom.boneHU;
                testCase.verifyEqual(row.psnrHU, psnrHU(reference, denoised), 'AbsTol', 1e-9);
            else
                testCase.verifyEqual(char(row.status), 'unavailable');
                testCase.verifyFalse(isfinite(row.psnrHU));
                testCase.verifyFalse(isfinite(row.ssimMean));
                testCase.verifyFalse(isfinite(row.voxelVolumeMM3));
                testCase.verifyFalse(isfinite(row.relErrVoxelVolume));
                testCase.verifyEmpty(row.profileHU);
                testCase.verifyFalse(any(isfinite(row.profileHU)));
                testCase.verifyTrue(contains(char(row.note), 'wdenoise2'));
            end
        end

        function testColormapsAndColorbarUnits(testCase)
            sequential = sequentialColormap(8);
            diverging = divergingColormap(8);
            testCase.verifySize(sequential, [8 3]);
            testCase.verifySize(diverging, [8 3]);
            testCase.verifyEqual(sequential(1, :), [250 246 239] / 255, 'AbsTol', 1e-12);
            testCase.verifyEqual(sequential(end, :), [47 111 115] / 255, 'AbsTol', 1e-12);
            testCase.verifyEqual(diverging(1, :), [33 102 172] / 255, 'AbsTol', 1e-12);
            testCase.verifyEqual(diverging(end, :), [178 24 43] / 255, 'AbsTol', 1e-12);

            root = projectRootFromTest();
            figures = fileread(fullfile(root, 'src', 'renderFigures.m'));
            denoise = fileread(fullfile(root, 'src', 'compareDenoising.m'));
            testCase.verifyTrue(contains(figures, 'Intensite (HU)'));
            testCase.verifyTrue(contains(denoise, 'Difference (HU)'));
            testCase.verifyTrue(contains(figures, 'Erreur relative de volume (1)'));

            files = dir(fullfile(root, 'src', '*.m'));
            pattern = 'colormap\s*\(\s*jet|colormap\s*\(\s*''jet''|colormap\s*\(\s*"jet"';
            for index = 1:numel(files)
                text = fileread(fullfile(files(index).folder, files(index).name));
                testCase.verifyEmpty(regexp(text, pattern, 'once'), files(index).name);
            end
        end
    end
end

function root = projectRootFromTest()
    root = fileparts(fileparts(mfilename('fullpath')));
end
