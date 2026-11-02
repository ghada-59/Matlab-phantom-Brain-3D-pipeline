function err = relativeError(measured, reference)
%RELATIVEERROR (measured - reference) ./ reference.
%   REFERENCE must be the same size as MEASURED, or a scalar, and none of
%   its entries may be zero. The result is dimensionless.

    measured = double(measured);
    reference = double(reference);
    if ~isscalar(reference) && ~isequal(size(measured), size(reference))
        error('relativeError:Size', ...
            'Measured and reference must be the same size, or reference must be scalar.');
    end
    if any(reference(:) == 0) || any(~isfinite(reference(:))) || any(~isfinite(measured(:)))
        error('relativeError:InvalidValue', ...
            'Relative error needs finite values and a non-zero reference.');
    end
    err = (measured - reference) ./ reference;
end
