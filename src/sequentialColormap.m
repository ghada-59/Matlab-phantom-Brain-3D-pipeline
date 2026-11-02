function cmap = sequentialColormap(n)
%SEQUENTIALCOLORMAP Sand to petroleum ramp for positive error maps.
%   Endpoints are the project palette (#FAF6EF to #2F6F73). The ramp is
%   sequential. It is not a rainbow scale.

    if nargin < 1
        n = 256;
    end
    if ~isscalar(n) || n < 2 || n ~= floor(n)
        error('sequentialColormap:InvalidN', 'n must be an integer greater than 1.');
    end
    light = [250 246 239] / 255;
    dark = [47 111 115] / 255;
    t = linspace(0, 1, n).';
    cmap = light + (dark - light) .* t;
end
