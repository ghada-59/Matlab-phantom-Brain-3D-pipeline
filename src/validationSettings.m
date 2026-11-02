function settings = validationSettings()
%VALIDATIONSETTINGS Design of the phantom sweep. These are inputs, not errors.
%
%   Voxel sizes 0.5, 1 and 2 mm, two noise levels in HU, and a rotation
%   check. Relative errors are computed by validatePhantoms when that
%   function is run. They are not stored in this function.

    settings.voxelSizesMM = [0.5 1 2];
    settings.noiseLevelsHU = [0 100];
    settings.rotationAnglesDeg = [0 30];
end
