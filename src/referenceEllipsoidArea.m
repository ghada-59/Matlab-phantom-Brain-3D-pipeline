function area = referenceEllipsoidArea(semiAxesMM, varargin)
%REFERENCEELLIPSOIDAREA Surface area of a triaxial ellipsoid (mm^2).
%
%   Semi-axes may be given in any order. The sphere and the spheroids use
%   closed forms. A general ellipsoid uses the incomplete elliptic integrals
%
%       phi = acos(c / a)
%       m   = a^2 (b^2 - c^2) / (b^2 (a^2 - c^2))
%       A   = 2*pi*c^2 + (2*pi*a*b / sin(phi)) * (E(phi,m) sin(phi)^2
%             + F(phi,m) cos(phi)^2)
%
%   with a >= b >= c > 0. F and E are the incomplete elliptic integrals of
%   the first and second kinds (MATLAB parameter m = k^2). If those
%   functions are unavailable, or Method is 'quadrature', the area is the
%   midpoint quadrature of the parametric surface
%
%       r(u, v) = (a sin u cos v, b sin u sin v, c cos u).
%
%   This is a geometric reference computed from the semi-axes, not a mesh
%   measurement.

    parser = inputParser;
    parser.FunctionName = 'referenceEllipsoidArea';
    parser.addParameter('Method', 'auto', @(s) any(strcmpi(s, {'auto', 'quadrature'})));
    parser.parse(varargin{:});

    axesMM = sort(double(semiAxesMM(:)'), 'descend');
    if numel(axesMM) ~= 3 || any(~isfinite(axesMM)) || any(axesMM <= 0)
        error('referenceEllipsoidArea:InvalidAxes', ...
            'semiAxesMM must be a positive 3-vector.');
    end

    major = axesMM(1);
    middle = axesMM(2);
    minor = axesMM(3);
    if strcmpi(parser.Results.Method, 'quadrature')
        area = parametricArea(major, middle, minor);
        return;
    end

    scale = max(major, 1);
    if max(axesMM) - min(axesMM) <= 1e-8 * scale
        area = 4 * pi * major^2;
        return;
    end
    if abs(major - middle) <= 1e-8 * scale
        % Oblate spheroid, equal major axes.
        eccentricity = sqrt(1 - (minor / major)^2);
        area = 2 * pi * major^2 * (1 + ((1 - eccentricity^2) / eccentricity) * atanh(eccentricity));
        return;
    end
    if abs(middle - minor) <= 1e-8 * scale
        % Prolate spheroid, equal minor axes.
        eccentricity = sqrt(1 - (middle / major)^2);
        area = 2 * pi * middle^2 * (1 + (major / (middle * eccentricity)) * asin(eccentricity));
        return;
    end

    phi = acos(minor / major);
    parameter = (major^2 * (middle^2 - minor^2)) / (middle^2 * (major^2 - minor^2));
    parameter = min(max(parameter, 0), 1 - eps);
    if ellipticIntegralsAvailable()
        secondKind = ellipticE(phi, parameter);
        firstKind = ellipticF(phi, parameter);
        area = 2 * pi * minor^2 + (2 * pi * major * middle / sin(phi)) ...
            * (secondKind * sin(phi)^2 + firstKind * cos(phi)^2);
    else
        area = parametricArea(major, middle, minor);
    end
end

function available = ellipticIntegralsAvailable()
    available = exist('ellipticE', 'builtin') == 5 || exist('ellipticE', 'file') == 2;
    available = available && (exist('ellipticF', 'builtin') == 5 || exist('ellipticF', 'file') == 2);
end

function area = parametricArea(major, middle, minor)
    nU = 360;
    nV = 720;
    uEdge = linspace(0, pi, nU + 1);
    vEdge = linspace(0, 2 * pi, nV + 1);
    du = uEdge(2) - uEdge(1);
    dv = vEdge(2) - vEdge(1);
    u = uEdge(1:end-1) + du / 2;
    v = vEdge(1:end-1) + dv / 2;
    [U, V] = ndgrid(u, v);
    sinU = sin(U);
    cosU = cos(U);
    sinV = sin(V);
    cosV = cos(V);
    % Partial derivatives of r(u, v) = (a sin u cos v, b sin u sin v, c cos u).
    rux = major .* cosU .* cosV;
    ruy = middle .* cosU .* sinV;
    ruz = -minor .* sinU;
    rvx = -major .* sinU .* sinV;
    rvy = middle .* sinU .* cosV;
    rvz = zeros(size(U));
    crossX = ruy .* rvz - ruz .* rvy;
    crossY = ruz .* rvx - rux .* rvz;
    crossZ = rux .* rvy - ruy .* rvx;
    area = sum(sqrt(crossX.^2 + crossY.^2 + crossZ.^2), 'all') * du * dv;
end
