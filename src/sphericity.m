function psi = sphericity(volume, area)
%SPHERICITY Isoperimetric quotient of a closed shape.
%
%   psi = pi^(1/3) * (6 * V)^(2/3) / A
%
%   V and A must be positive scalars in consistent units (mm^3 and mm^2).
%   A sphere has psi = 1. Every other shape has psi < 1 when V and A are
%   the true volume and surface area. A staircased mesh can push a numerical
%   value slightly away from that ideal, so callers keep the mesh and voxel
%   estimates separate.

    if ~isscalar(volume) || ~isscalar(area) || ~isfinite(volume) || ~isfinite(area) ...
            || volume <= 0 || area <= 0
        error('sphericity:InvalidInput', 'Volume and area must be positive finite scalars.');
    end
    psi = pi^(1/3) * (6 * double(volume))^(2/3) / double(area);
end
