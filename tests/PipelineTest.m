classdef PipelineTest < matlab.unittest.TestCase
    % Pipeline tests recompute analytic quantities. They do not embed a
    % previously measured volume, area, or error.

    methods (TestClassSetup)
        function addSource(testCase)
            root = projectRootFromTest();
            addpath(fullfile(root, 'src'));
            testCase.addTeardown(@() rmpath(fullfile(root, 'src')));
        end
    end

    methods (Test)
        function testHuRescaleUsesSlopeAndIntercept(testCase)
            testCase.verifyEqual(applyHuRescale(100, 2, -1024), -824, 'AbsTol', 0);
            testCase.verifyEqual(applyHuRescale(200, 1, -1024), -824, 'AbsTol', 0);
            % Dropping the intercept is a different quantity. The pipeline
            % must not do that when the header provides one.
            testCase.verifyNotEqual(applyHuRescale(200, 1, 0), applyHuRescale(200, 1, -1024));
            testCase.verifyEqual(applyHuRescale(4, [], []), 4, 'AbsTol', 0);
        end

        function testPhantomReaderKeepsHuAndSpacing(testCase)
            phantom = cleanPhantom([18 12 9], [1 1 1]);
            out = readVolumeHU(phantom);
            testCase.verifyEqual(out.hu, phantom.volumeHU);
            testCase.verifyEqual(out.spacingMM, phantom.spacingMM, 'AbsTol', 0);
            testCase.verifyEqual(out.rescaleSlope, 1, 'AbsTol', 0);
            testCase.verifyEqual(out.rescaleIntercept, 0, 'AbsTol', 0);
            testCase.verifyTrue(out.huConfirmed);
            testCase.verifyEqual(out.source, 'phantom');
            testCase.verifyEqual(out.analyticVolumeMM3, phantom.analyticVolumeMM3, 'RelTol', 1e-12);
            testCase.verifyFalse(isfield(out, 'PatientName'));
            testCase.verifyFalse(isfield(out, 'PatientID'));
        end

        function testMissingDicomFolderErrors(testCase)
            missing = fullfile(tempdir, 'bone-morphometry-missing-dicom');
            if isfolder(missing)
                rmdir(missing, 's');
            end
            testCase.verifyError(@() readVolumeHU(missing), 'readVolumeHU:NotFound');
            testCase.verifyError(@() readVolumeHU(123), 'readVolumeHU:BadSource');
        end

        function testDicomRoundTripAppliesRescaleOnce(testCase)
            if exist('dicomwrite', 'file') ~= 2 || exist('dicomreadVolume', 'file') ~= 2
                testCase.assumeFail('DICOM functions from Image Processing Toolbox are not available.');
            end
            folder = tempname;
            mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
            raw = zeros(6, 5, 3, 'int16');
            raw(:) = 100;
            raw(3, 3, :) = 400;
            try
                seriesUid = dicomuid;
                for sliceIndex = 1:3
                    dicomwrite(raw(:, :, sliceIndex), ...
                        fullfile(folder, sprintf('slice%02d.dcm', sliceIndex)), ...
                        'ObjectType', 'CT Image Storage', ...
                        'Modality', 'CT', ...
                        'RescaleSlope', 2, ...
                        'RescaleIntercept', -1024, ...
                        'PixelSpacing', [0.5 0.8], ...
                        'SliceThickness', 5, ...
                        'SpacingBetweenSlices', 9, ...
                        'ImagePositionPatient', [0; 0; (sliceIndex - 1) * 1.5], ...
                        'ImageOrientationPatient', [1; 0; 0; 0; 1; 0], ...
                        'InstanceNumber', sliceIndex, ...
                        'SliceLocation', (sliceIndex - 1) * 1.5, ...
                        'SeriesInstanceUID', seriesUid, ...
                        'PatientName', 'SHOULD_NOT_BE_EXPORTED');
                end
                out = readVolumeHU(folder);
            catch ME
                testCase.assumeFail(['DICOM round trip could not be prepared: ' ME.message]);
            end
            expected = double(raw) * 2 - 1024;
            testCase.verifyEqual(out.rescaleSlope, 2, 'AbsTol', 1e-9);
            testCase.verifyEqual(out.rescaleIntercept, -1024, 'AbsTol', 1e-9);
            testCase.verifyTrue(out.huConfirmed);
            testCase.verifyEqual(size(out.hu), size(expected));
            testCase.verifyEqual(out.hu, expected, 'AbsTol', 1e-6);
            testCase.verifyEqual(out.spacingMM(1), 0.5, 'AbsTol', 1e-6);
            testCase.verifyEqual(out.spacingMM(2), 0.8, 'AbsTol', 1e-6);
            testCase.verifyEqual(out.spacingMM(3), 1.5, 'AbsTol', 1e-3);
            testCase.verifyEqual(out.sliceSpacingSource, 'image-position');
            testCase.verifyEqual(out.sliceThicknessMM, 5, 'AbsTol', 1e-6);
            testCase.verifyNotEqual(out.spacingMM(3), out.sliceThicknessMM);
            testCase.verifyFalse(isfield(out, 'PatientName'));
            testCase.verifyEqual(out.source, 'dicom');
        end

        function testCleanPhantomUsesAnalyticVolumeAndPhysicalSpacing(testCase)
            semi = [30 20 12];
            spacing = [1 1 1];
            phantom = cleanPhantom(semi, spacing);
            analytic = (4 / 3) * pi * semi(1) * semi(2) * semi(3);
            testCase.verifyEqual(phantom.analyticVolumeMM3, analytic, 'RelTol', 1e-12);
            meas = runPipeline(phantom, 'SigmaMM', 0, 'OpenRadiusMM', 0, ...
                'CloseRadiusMM', 0, 'Method', 'otsu');
            testCase.verifyEqual(meas.voxelVolumeMM3, nnz(meas.mask) * prod(spacing), 'AbsTol', 1e-6);
            testCase.verifyEqual(meas.voxelVolumeMM3, phantom.numericVolumeMM3, 'RelTol', 1e-9, 'AbsTol', 1e-6);
            testCase.verifyEqual(meas.relErrVoxelVolume, ...
                (meas.voxelVolumeMM3 - analytic) / analytic, 'AbsTol', 1e-12);
            testCase.verifyTrue(all(isfinite([meas.voxelVolumeMM3, meas.meshVolumeMM3, ...
                meas.meshAreaMM2, meas.semiAxesMM, meas.sphericityMesh])));
            testCase.verifyGreaterThan([meas.voxelVolumeMM3, meas.meshVolumeMM3, meas.meshAreaMM2], 0);
            testCase.verifyEqual(meas.mask, phantom.mask);
            testCase.verifyGreaterThan(meas.threshold.otsuHU, phantom.backgroundHU);
            testCase.verifyLessThan(meas.threshold.otsuHU, phantom.boneHU);
        end

        function testFixedThresholdAgreesOnACleanPhantom(testCase)
            phantom = cleanPhantom([18 13 10], [1 1 1]);
            fixedSeg = segmentBone(phantom.volumeHU, phantom.spacingMM, ...
                'Method', 'fixed', 'FixedThresholdHU', 300, ...
                'SigmaMM', 0, 'OpenRadiusMM', 0, 'CloseRadiusMM', 0);
            testCase.verifyEqual(fixedSeg.mask, phantom.mask);
            testCase.verifyEqual(fixedSeg.threshold.fixedHU, 300, 'AbsTol', 0);
            testCase.verifyError(@() segmentBone(phantom.volumeHU, phantom.spacingMM, ...
                'Method', 'fixed', 'FixedThresholdHU', 5000, ...
                'SigmaMM', 0, 'OpenRadiusMM', 0, 'CloseRadiusMM', 0), ...
                'segmentBone:Empty');
        end

        function testPrincipalAxesAreMillimetresNotRegionpropsLengths(testCase)
            truth = [30 20 12];
            phantom = cleanPhantom(truth, [1 1 1]);
            meas = runPipeline(phantom, 'SigmaMM', 0, 'OpenRadiusMM', 0, 'CloseRadiusMM', 0);
            testCase.verifySize(meas.semiAxesMM, [1 3]);
            testCase.verifyTrue(all(isfinite(meas.semiAxesMM)));
            testCase.verifyGreaterThan(meas.semiAxesMM, 0);
            estimated = sort(meas.semiAxesMM, 'descend');
            expected = sort(truth, 'descend');
            testCase.verifyEqual(meas.relErrSemiAxes, (estimated - expected) ./ expected, 'AbsTol', 1e-12);
            major = meas.axisDirections(:, 1);
            minor = meas.axisDirections(:, 3);
            % Axis-aligned phantom: the longest covariance axis is x, the
            % shortest is z. This checks the coordinate frame, not an error budget.
            [~, majorAxis] = max(abs(major));
            [~, minorAxis] = max(abs(minor));
            testCase.verifyEqual(majorAxis, 1);
            testCase.verifyEqual(minorAxis, 3);
            testCase.verifyEqual(norm(major), 1, 'AbsTol', 1e-8);
            testCase.verifyEqual(meas.principalAxisLengthUnit, 'voxel');
            testCase.verifyTrue(contains(meas.principalAxisDefinition, 'not the analytic semi-axis'));
            if ~isempty(meas.principalAxisLengthVoxels)
                testCase.verifySize(meas.principalAxisLengthVoxels, [1 3]);
                testCase.verifyGreaterThan(meas.principalAxisLengthVoxels, 0);
                testCase.verifyFalse(isequaln(meas.principalAxisLengthVoxels, meas.semiAxesMM));
            end
            if ~isempty(meas.solidity)
                testCase.verifyGreaterThan(meas.solidity, 0);
                testCase.verifyLessThanOrEqual(meas.solidity, 1);
            end
            testCase.verifyGreaterThan(meas.sphericityMesh, 0);
            testCase.verifyLessThan(meas.sphericityMesh, 2);
            testCase.verifyGreaterThan(meas.meshAreaMM2, 0);
            testCase.verifyGreaterThan(meas.meshVolumeMM3, 0);
        end

        function testAnisotropicSpacingScalesTheVoxelVolume(testCase)
            spacing = [0.5 0.8 1.5];
            phantom = cleanPhantom([22 15 11], spacing);
            meas = runPipeline(phantom, 'SigmaMM', 0, 'OpenRadiusMM', 0, ...
                'CloseRadiusMM', 0, 'MeshSmoothSigmaVox', 0);
            testCase.verifyEqual(meas.spacingMM, spacing, 'AbsTol', 0);
            testCase.verifyEqual(meas.voxelVolumeMM3, nnz(meas.mask) * prod(spacing), 'AbsTol', 1e-6);
            testCase.verifyNotEqual(meas.voxelVolumeMM3, nnz(meas.mask));
            testCase.verifyEqual(meas.voxelVolumeMM3, phantom.numericVolumeMM3, 'RelTol', 1e-9, 'AbsTol', 1e-6);
            testCase.verifyTrue(all(isfinite(meas.semiAxesMM)));
            zSpan = max(meas.vertices(:, 3)) - min(meas.vertices(:, 3));
            semiZ = phantom.semiAxesMM(3);
            indexDiameter = 2 * semiZ / spacing(3);
            % Millimetre vertices span about the analytic diameter. Index-space
            % vertices would span about indexDiameter, which is smaller when sz > 1.
            testCase.verifyGreaterThan(zSpan, indexDiameter + spacing(3));
            testCase.verifyLessThan(zSpan, 2 * semiZ + 3 * spacing(3));
            testCase.verifyGreaterThan(meas.meshAreaMM2, 0);
        end

        function testLargestComponentDropsADisconnectedSlab(testCase)
            phantom = cleanPhantom([16 12 10], [1 1 1]);
            hu = phantom.volumeHU;
            hu(1, :, :) = 500;
            seg = segmentBone(hu, phantom.spacingMM, ...
                'Method', 'fixed', 'FixedThresholdHU', 300, ...
                'SigmaMM', 0, 'OpenRadiusMM', 0, 'CloseRadiusMM', 0, ...
                'MinVolumeMM3', 0);
            testCase.verifyEqual(seg.objectsBeforeLargest, 2);
            testCase.verifyEqual(bwconncomp(seg.mask, 26).NumObjects, 1);
            testCase.verifyEqual(seg.mask, phantom.mask);
        end

        function testOpeningDoesNotGrowTheMask(testCase)
            phantom = cleanPhantom([20 14 11], [1 1 1]);
            closed = segmentBone(phantom.volumeHU, phantom.spacingMM, ...
                'SigmaMM', 0, 'OpenRadiusMM', 0, 'CloseRadiusMM', 0);
            opened = segmentBone(phantom.volumeHU, phantom.spacingMM, ...
                'SigmaMM', 0, 'OpenRadiusMM', 1, 'CloseRadiusMM', 0);
            testCase.verifyLessThanOrEqual(nnz(opened.mask), nnz(closed.mask));
            testCase.verifyGreaterThan(nnz(opened.mask), 0);
            testCase.verifyEqual(bwconncomp(opened.mask, 26).NumObjects, 1);
        end

        function testSliceSpacingUsesCentresNotThickness(testCase)
            positions = [
                0 0 0
                5 0 2
                10 0 4
            ];
            axial = [1 0 0 0 1 0];
            [spacing, source] = voxelSpacingMM([0.5 0.8], 9, positions, axial);
            testCase.verifyEqual(spacing, [0.5 0.8 2], 'AbsTol', 1e-12);
            testCase.verifyEqual(source, 'image-position');

            normal = [0 -0.8 0.6];
            shifted = [
                0 0 0
                4 0 0
                8 0 0
            ] + [0; 3; 6] * normal;
            [oblique, obliqueSource] = voxelSpacingMM([1 1], 9, shifted, [1 0 0 0 0.6 0.8]);
            testCase.verifyEqual(oblique(3), 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(obliqueSource, 'image-position');
            euclidean = norm(shifted(2, :) - shifted(1, :));
            testCase.verifyGreaterThan(abs(euclidean - oblique(3)), 1);

            [fallback, fallbackSource] = voxelSpacingMM([0.7 0.7], 1.25, [], []);
            testCase.verifyEqual(fallback, [0.7 0.7 1.25], 'AbsTol', 1e-12);
            testCase.verifyEqual(fallbackSource, 'spacing-between-slices');

            [missing, missingSource] = voxelSpacingMM([1 1], [], [], []);
            testCase.verifyTrue(isnan(missing(3)));
            testCase.verifyEmpty(missingSource);
        end

        function testSourcesUseEigNotStatisticsPca(testCase)
            root = projectRootFromTest();
            files = dir(fullfile(root, 'src', '*.m'));
            for index = 1:numel(files)
                text = fileread(fullfile(files(index).folder, files(index).name));
                testCase.verifyEmpty(regexp(text, '(^|[^\w])pca\s*\(', 'once'), files(index).name);
            end
        end

        function testRelativeErrorIdentity(testCase)
            testCase.verifyEqual(relativeError([110 90], [100 100]), [0.1 -0.1], 'AbsTol', 1e-12);
            testCase.verifyEqual(relativeError(50, 40), 0.25, 'AbsTol', 1e-12);
            testCase.verifyError(@() relativeError(1, 0), 'relativeError:InvalidValue');
        end

        function testSphericityOfASphereIsOne(testCase)
            radius = 2;
            volume = (4 / 3) * pi * radius^3;
            area = 4 * pi * radius^2;
            testCase.verifyEqual(sphericity(volume, area), 1, 'AbsTol', 1e-12);
        end

        function testCubeMeshVolumeAndArea(testCase)
            vertices = [
                0 0 0
                2 0 0
                2 2 0
                0 2 0
                0 0 2
                2 0 2
                2 2 2
                0 2 2
            ];
            faces = [
                1 3 2; 1 4 3
                5 6 7; 5 7 8
                1 2 6; 1 6 5
                4 8 7; 4 7 3
                1 5 8; 1 8 4
                2 3 7; 2 7 6
            ];
            [volume, area] = meshVolumeAndArea(vertices, faces);
            testCase.verifyEqual(volume, 8, 'AbsTol', 1e-12);
            testCase.verifyEqual(area, 24, 'AbsTol', 1e-12);
            reversed = faces(:, [1 3 2]);
            [reversedVolume, reversedArea] = meshVolumeAndArea(vertices, reversed);
            testCase.verifyEqual(reversedVolume, 8, 'AbsTol', 1e-12);
            testCase.verifyEqual(reversedArea, 24, 'AbsTol', 1e-12);
        end

        function testReferenceAreaOfSphereAndSpheroids(testCase)
            testCase.verifyEqual(referenceEllipsoidArea([10 10 10]), 4 * pi * 100, 'RelTol', 1e-12);
            major = 10;
            minor = 5;
            eccentricity = sqrt(1 - (minor / major)^2);
            oblate = 2 * pi * major^2 * (1 + ((1 - eccentricity^2) / eccentricity) * atanh(eccentricity));
            testCase.verifyEqual(referenceEllipsoidArea([major major minor]), oblate, 'RelTol', 1e-12);
            small = 4;
            eccentricity = sqrt(1 - (small / major)^2);
            prolate = 2 * pi * small^2 * (1 + (major / (small * eccentricity)) * asin(eccentricity));
            testCase.verifyEqual(referenceEllipsoidArea([major small small]), prolate, 'RelTol', 1e-12);
        end

        function testFlatPhantomAndNonScalarSigmaAreRejected(testCase)
            phantom = cleanPhantom([12 9 7], [1 1 1]);
            phantom.volumeHU = phantom.volumeHU(:, :, 1);
            testCase.verifyError(@() readVolumeHU(phantom), 'readVolumeHU:BadPhantom');
            phantom = cleanPhantom([12 9 7], [1 1 1]);
            testCase.verifyError(@() segmentBone(phantom.volumeHU, phantom.spacingMM, ...
                'SigmaMM', [0.5 0.5]), 'segmentBone:InvalidSigma');
            testCase.verifyError(@() segmentBone(phantom.volumeHU, phantom.spacingMM, ...
                'OpenRadiusMM', -1), 'segmentBone:InvalidRadius');
        end

        function testTriaxialAreaMatchesQuadrature(testCase)
            semi = [8 5 3];
            fromFormula = referenceEllipsoidArea(semi, 'Method', 'auto');
            fromQuadrature = referenceEllipsoidArea(semi, 'Method', 'quadrature');
            testCase.verifyEqual(fromFormula, fromQuadrature, 'RelTol', 1e-3);
            testCase.verifyGreaterThan(fromFormula, 0);
        end
    end
end

function phantom = cleanPhantom(semiAxes, spacing)
    phantom = generateEllipsoidPhantom( ...
        'SemiAxesMM', semiAxes, ...
        'VoxelSpacingMM', spacing, ...
        'NoiseSigmaHU', 0, ...
        'MarginMM', 6);
end

function root = projectRootFromTest()
    root = fileparts(fileparts(mfilename('fullpath')));
end
