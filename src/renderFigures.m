function files = renderFigures(meas, outDir, validationTable)
%RENDERFIGURES Mesh, HU slice, and optional validation chart.
%
%   The bone is ivory (#E8DCC8) and the principal axes are terracotta
%   (#B8502F). The HU slice uses a grayscale map because a CT slice is not
%   a false-color image. Its colorbar is labeled in HU. The validation
%   chart, when a table is provided, is a boxchart of relative volume error.
%   Axis labels carry the unit. No rainbow scale is used.

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    files = struct('mesh', '', 'axialHu', '', 'volumeError', '', 'notes', '');
    try
        files.mesh = renderMesh(meas, fullfile(outDir, 'mesh.png'));
        files.axialHu = renderAxialHu(meas, fullfile(outDir, 'axial_hu.png'));
        if nargin >= 3 && ~isempty(validationTable) && height(validationTable) > 0 ...
                && ismember('relErrVoxelVolume', validationTable.Properties.VariableNames)
            files.volumeError = renderErrorChart(validationTable, ...
                fullfile(outDir, 'volume_error_box.png'));
        end
    catch ME
        files.notes = ME.message;
        warning('renderFigures:Failed', '%s', ME.message);
    end
end

function outFile = renderMesh(meas, outFile)
    figureHandle = figure('Visible', 'off', 'Color', 'w');
    cleanup = onCleanup(@() closeFigure(figureHandle)); %#ok<NASGU>
    patch('Vertices', meas.vertices, 'Faces', meas.faces, ...
        'FaceColor', [232 220 200] / 255, ...
        'EdgeColor', 'none', ...
        'FaceLighting', 'gouraud', ...
        'AmbientStrength', 0.4, ...
        'DiffuseStrength', 0.7);
    camlight('headlight');
    lighting gouraud;
    hold on;
    if isfield(meas, 'centroidMM') && isfield(meas, 'axisDirections') && isfield(meas, 'semiAxesMM')
        centroid = double(meas.centroidMM(:).');
        directions = double(meas.axisDirections);
        lengths = double(meas.semiAxesMM(:).');
        for axisIndex = 1:min(3, size(directions, 2))
            direction = directions(:, axisIndex).';
            halfLength = lengths(axisIndex);
            endpoints = [centroid - halfLength * direction; centroid + halfLength * direction];
            plot3(endpoints(:, 1), endpoints(:, 2), endpoints(:, 3), ...
                'Color', [184 80 47] / 255, 'LineWidth', 2);
        end
    end
    axis equal;
    xlabel('x (mm)');
    ylabel('y (mm)');
    zlabel('z (mm)');
    title('Maillage osseux synthetique');
    grid on;
    exportgraphics(figureHandle, outFile, 'Resolution', 120);
end

function outFile = renderAxialHu(meas, outFile)
    nSlices = size(meas.hu, 3);
    mid = max(1, round(nSlices / 2));
    slice = meas.hu(:, :, mid);
    cols = (0:size(slice, 2) - 1) * meas.spacingMM(2);
    rows = (0:size(slice, 1) - 1) * meas.spacingMM(1);
    figureHandle = figure('Visible', 'off', 'Color', 'w');
    cleanup = onCleanup(@() closeFigure(figureHandle)); %#ok<NASGU>
    axesHandle = axes('Parent', figureHandle);
    imagesc(axesHandle, cols, rows, slice);
    axis(axesHandle, 'image');
    % Grayscale for HU. A false-color rainbow would not be a CT window.
    colormap(axesHandle, gray(256));
    colorbarHandle = colorbar(axesHandle);
    colorbarHandle.Label.String = 'Intensite (HU)';
    xlabel(axesHandle, 'x (mm)');
    ylabel(axesHandle, 'y (mm)');
    title(axesHandle, 'Coupe axiale, intensite non fenetree');
    exportgraphics(figureHandle, outFile, 'Resolution', 120);
end

function outFile = renderErrorChart(validationTable, outFile)
    figureHandle = figure('Visible', 'off', 'Color', 'w');
    cleanup = onCleanup(@() closeFigure(figureHandle)); %#ok<NASGU>
    axesHandle = axes('Parent', figureHandle);
    groups = categorical(validationTable.voxelSizeMM);
    boxchart(axesHandle, groups, validationTable.relErrVoxelVolume);
    xlabel(axesHandle, 'Taille de voxel (mm)');
    ylabel(axesHandle, 'Erreur relative de volume (1)');
    title(axesHandle, 'Fantômes : erreur de volume');
    grid(axesHandle, 'on');
    exportgraphics(figureHandle, outFile, 'Resolution', 120);
end

function closeFigure(figureHandle)
    if ~isempty(figureHandle) && isgraphics(figureHandle)
        close(figureHandle);
    end
end
