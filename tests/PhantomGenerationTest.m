classdef PhantomGenerationTest < matlab.unittest.TestCase
    % Tests for the synthetic ellipsoid phantom. Expected volumes are the
    % analytic formula or a recomputation from the returned grid. No
    % measured pipeline result is hard-coded.

    methods (TestClassSetup)
        function addSource(testCase)
            root = projectRootFromTest();
            addpath(fullfile(root, 'src'));
            testCase.addTeardown(@() rmpath(fullfile(root, 'src')));
        end
    end

    methods (Test)
        function testAnalyticVolumeMatchesFormula(testCase)
            semi = [20 15 10];
            phantom = generateEllipsoidPhantom( ...
                'SemiAxesMM', semi, ...
                'VoxelSpacingMM', [1 1 1], ...
                'NoiseSigmaHU', 0);
            expected = (4 / 3) * pi * semi(1) * semi(2) * semi(3);
            testCase.verifyEqual(phantom.analyticVolumeMM3, expected, 'RelTol', 1e-12);
            testCase.verifyEqual(phantom.semiAxesMM, semi, 'AbsTol', 0);
            testCase.verifyFalse(phantom.axesAreRandom);
        end

        function testNumericVolumeIsVoxelCountTimesSpacing(testCase)
            phantom = generateEllipsoidPhantom( ...
                'SemiAxesMM', [18 13 9], ...
                'VoxelSpacingMM', [0.5 0.8 1.25], ...
                'NoiseSigmaHU', 0, ...
                'MarginMM', 4);
            voxelVolume = prod(phantom.spacingMM);
            testCase.verifyEqual(phantom.numericVolumeMM3, nnz(phantom.mask) * voxelVolume, ...
                'AbsTol', 1e-9);
            testCase.verifyEqual(size(phantom.volumeHU), size(phantom.mask));
            testCase.verifyEqual(size(phantom.mask), ...
                [numel(phantom.yMM) numel(phantom.xMM) numel(phantom.zMM)]);
            testCase.verifyGreaterThan(phantom.numericVolumeMM3, 0);
            testCase.verifyClass(phantom.mask, 'logical');
        end

        function testMaskFollowsEllipsoidEquation(testCase)
            phantom = generateEllipsoidPhantom( ...
                'SemiAxesMM', [16 11 7], ...
                'VoxelSpacingMM', [0.7 1.1 1.4], ...
                'NoiseSigmaHU', 0);
            [Y, X, Z] = ndgrid(phantom.yMM, phantom.xMM, phantom.zMM);
            a = phantom.semiAxesMM(1);
            b = phantom.semiAxesMM(2);
            c = phantom.semiAxesMM(3);
            expected = (X ./ a).^2 + (Y ./ b).^2 + (Z ./ c).^2 <= 1;
            testCase.verifyEqual(phantom.mask, expected);
        end

        function testZeroNoiseUsesTheRequestedIntensities(testCase)
            phantom = generateEllipsoidPhantom( ...
                'SemiAxesMM', [12 10 8], ...
                'BackgroundHU', -1000, ...
                'BoneHU', 800, ...
                'NoiseSigmaHU', 0);
            outside = unique(phantom.volumeHU(~phantom.mask));
            inside = unique(phantom.volumeHU(phantom.mask));
            testCase.verifyEqual(outside, -1000);
            testCase.verifyEqual(inside, 800);
            testCase.verifyEqual(phantom.spacingMM, [1 1 1], 'AbsTol', 0);
        end

        function testNoiseDoesNotChangeGeometryAndIsReproducible(testCase)
            clean = generateEllipsoidPhantom( ...
                'SemiAxesMM', [15 12 9], 'NoiseSigmaHU', 0, 'Seed', 5);
            noisyA = generateEllipsoidPhantom( ...
                'SemiAxesMM', [15 12 9], 'NoiseSigmaHU', 40, 'Seed', 5);
            noisyB = generateEllipsoidPhantom( ...
                'SemiAxesMM', [15 12 9], 'NoiseSigmaHU', 40, 'Seed', 5);
            testCase.verifyEqual(noisyA.mask, clean.mask);
            testCase.verifyEqual(noisyA.analyticVolumeMM3, clean.analyticVolumeMM3, 'RelTol', 1e-12);
            testCase.verifyEqual(noisyA.numericVolumeMM3, clean.numericVolumeMM3, 'AbsTol', 1e-9);
            testCase.verifyGreaterThan(max(abs(noisyA.volumeHU(:) - clean.volumeHU(:))), 0);
            testCase.verifyEqual(noisyA.volumeHU, noisyB.volumeHU);
        end

        function testRandomAxesStayInRangeAndMatchTheFormula(testCase)
            first = generateEllipsoidPhantom('Seed', 7);
            second = generateEllipsoidPhantom('Seed', 7);
            testCase.verifyTrue(first.axesAreRandom);
            testCase.verifyGreaterThanOrEqual(first.semiAxesMM, 12);
            testCase.verifyLessThanOrEqual(first.semiAxesMM, 36);
            expected = (4 / 3) * pi * prod(first.semiAxesMM);
            testCase.verifyEqual(first.analyticVolumeMM3, expected, 'RelTol', 1e-12);
            testCase.verifyEqual(first.semiAxesMM, second.semiAxesMM, 'AbsTol', 0);
            testCase.verifyEqual(first.volumeHU, second.volumeHU);
        end

        function testFinerGridHasMoreVoxelsButTheSameAnalyticVolume(testCase)
            coarse = generateEllipsoidPhantom( ...
                'SemiAxesMM', [18 14 10], 'VoxelSpacingMM', [2 2 2], 'NoiseSigmaHU', 0);
            fine = generateEllipsoidPhantom( ...
                'SemiAxesMM', [18 14 10], 'VoxelSpacingMM', [1 1 1], 'NoiseSigmaHU', 0);
            testCase.verifyEqual(coarse.analyticVolumeMM3, fine.analyticVolumeMM3, 'RelTol', 1e-12);
            testCase.verifyGreaterThan(nnz(fine.mask), nnz(coarse.mask));
            testCase.verifyNotEqual(coarse.numericVolumeMM3, fine.numericVolumeMM3);
        end

        function testInvalidArgumentsError(testCase)
            testCase.verifyError( ...
                @() generateEllipsoidPhantom('SemiAxesMM', [10 0 4]), ...
                'generateEllipsoidPhantom:InvalidAxes');
            testCase.verifyError( ...
                @() generateEllipsoidPhantom('VoxelSpacingMM', [1 1 0]), ...
                'generateEllipsoidPhantom:InvalidSpacing');
            testCase.verifyError( ...
                @() generateEllipsoidPhantom('SemiAxesMM', [10 8 6], 'RandomAxes', true), ...
                'generateEllipsoidPhantom:ConflictingAxes');
        end
    end
end

function root = projectRootFromTest()
    root = fileparts(fileparts(mfilename('fullpath')));
end
