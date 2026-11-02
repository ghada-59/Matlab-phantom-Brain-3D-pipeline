function cmap = divergingColormap(n)
%DIVERGINGCOLORMAP Signed difference map, blue-white-red, centered on 0.
%   Endpoints #2166AC and #B2182B. The middle is white. This is the palette
%   required for signed difference images. It is not a rainbow scale.

    if nargin < 1
        n = 256;
    end
    if ~isscalar(n) || n < 2 || n ~= floor(n)
        error('divergingColormap:InvalidN', 'n must be an integer greater than 1.');
    end
    blue = [33 102 172] / 255;
    white = [1 1 1];
    red = [178 24 43] / 255;
    firstHalf = floor(n / 2);
    secondHalf = n - firstHalf;
    t1 = linspace(0, 1, firstHalf).';
    t2 = linspace(0, 1, secondHalf).';
    cmap = [blue + (white - blue) .* t1; white + (red - white) .* t2];
    if size(cmap, 1) > n
        cmap = cmap(1:n, :);
    end
end
