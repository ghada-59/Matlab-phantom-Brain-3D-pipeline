classdef DashboardContractTest < matlab.unittest.TestCase
    % File-level contract between the MATLAB export and the dashboard.
    % It does not require a MATLAB graphics device or a measured result.

    methods (Test)
        function testSentinelIsTheEmDash(testCase)
            root = projectRootFromTest();
            addpath(fullfile(root, 'src'));
            testCase.addTeardown(@() rmpath(fullfile(root, 'src')));
            testCase.verifyEqual(unmeasuredSentinel(), char(8212));
            formatText = fileread(fullfile(root, 'dashboard', 'src', 'utils', 'format.js'));
            testCase.verifyTrue(contains(formatText, '\u2014'));
        end

        function testStatusSaysNothingWasMeasured(testCase)
            root = projectRootFromTest();
            statusText = fileread(fullfile(root, 'dashboard', 'public', 'data', 'status.json'));
            testCase.verifyTrue(contains(statusText, '"executed": false'));
            testCase.verifyTrue(contains(statusText, '"intensity": "HU"'));
            testCase.verifyFalse(contains(statusText, 'voxelVolumeMM3'));
        end

        function testSchemaUnitsMatchTheStatusFile(testCase)
            root = projectRootFromTest();
            addpath(fullfile(root, 'src'));
            testCase.addTeardown(@() rmpath(fullfile(root, 'src')));
            schema = resultSchema();
            testCase.verifyEqual(schema.version, '1.0');
            testCase.verifyEqual(schema.units.intensity, 'HU');
            testCase.verifyEqual(schema.units.length, 'mm');
            testCase.verifyEqual(schema.units.volume, 'mm^3');
            testCase.verifyEqual(schema.sentinel, char(8212));
        end

        function testColorbarsStateTheirUnitAndDoNotUseJet(testCase)
            root = projectRootFromTest();
            colorbarText = fileread(fullfile(root, 'dashboard', 'src', 'components', 'ColorbarSVG.jsx'));
            testCase.verifyTrue(contains(colorbarText, 'unit'));
            testCase.verifyTrue(contains(colorbarText, 'statedUnit'));
            denoiseText = fileread(fullfile(root, 'dashboard', 'src', 'features', 'denoise', 'CompareGrid.jsx'));
            coupesText = fileread(fullfile(root, 'dashboard', 'src', 'features', 'viewer', 'MprViewer.jsx'));
            testCase.verifyTrue(contains(denoiseText, 'unit="HU"'));
            testCase.verifyTrue(contains(coupesText, 'unit="HU"'));
            files = listSourceFiles(fullfile(root, 'dashboard', 'src'));
            testCase.verifyGreaterThan(numel(files), 0);
            pattern = 'colormap\s*\(\s*jet|[''"]jet[''"]|rainbow\(';
            for index = 1:numel(files)
                text = fileread(files{index});
                testCase.verifyEmpty(regexp(text, pattern, 'once'), files{index});
            end
        end

        function testReadmeGivesTheWindowsCommandAndSaysNothingRan(testCase)
            root = projectRootFromTest();
            readme = fileread(fullfile(root, 'README.md'));
            testCase.verifyTrue(contains(readme, 'matlab -batch "runtests(''tests'')"'));
            testCase.verifyTrue(contains(readme, 'Aucun script n''a été exécuté'));
            testCase.verifyTrue(contains(readme, 'non clinique'));
        end
    end
end

function root = projectRootFromTest()
    root = fileparts(fileparts(mfilename('fullpath')));
end

function paths = listSourceFiles(folder)
    entries = dir(folder);
    paths = cell(1, 0);
    for index = 1:numel(entries)
        name = entries(index).name;
        if strcmp(name, '.') || strcmp(name, '..')
            continue;
        end
        path = fullfile(folder, name);
        if entries(index).isdir
            paths = [paths, listSourceFiles(path)]; %#ok<AGROW>
        elseif endsWith(name, {'.jsx', '.js', '.css'})
            paths{end + 1} = path; %#ok<AGROW>
        end
    end
end
