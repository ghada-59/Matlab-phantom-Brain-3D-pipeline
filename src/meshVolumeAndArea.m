function [volume, area] = meshVolumeAndArea(vertices, faces)
%MESHVOLUMEANDAREA Triangle area sum and enclosed volume.
%
%   AREA is the sum of triangle areas. For a triangle (p1, p2, p3),
%
%       area_i = 0.5 * || (p2 - p1) × (p3 - p1) ||.
%
%   VOLUME uses the divergence theorem. With F = (x, 0, 0), div F = 1, so
%   the enclosed volume equals the flux through the closed surface:
%
%       V = (1/6) * sum_i  p1 · (p2 × p3).
%
%   isosurface points its normals toward increasing values. On a mask that
%   is 1 inside and 0 outside those normals point inward, and the signed
%   sum is negative. The absolute value is returned. Units follow the vertex
%   coordinates (millimetres in this project, so mm^3 and mm^2).

    vertices = double(vertices);
    faces = round(double(faces));
    if size(vertices, 2) ~= 3 || size(faces, 2) ~= 3 || isempty(faces)
        error('meshVolumeAndArea:Shape', ...
            'Vertices must be N-by-3 and faces a non-empty M-by-3 index array.');
    end
    if any(faces(:) < 1) || any(faces(:) > size(vertices, 1))
        error('meshVolumeAndArea:Index', 'A face index is outside the vertex list.');
    end

    p1 = vertices(faces(:, 1), :);
    p2 = vertices(faces(:, 2), :);
    p3 = vertices(faces(:, 3), :);
    edgeCross = cross(p2 - p1, p3 - p1, 2);
    area = 0.5 * sum(sqrt(sum(edgeCross.^2, 2)));
    signedVolume = sum(dot(p1, cross(p2, p3, 2), 2)) / 6;
    volume = abs(signedVolume);
end
