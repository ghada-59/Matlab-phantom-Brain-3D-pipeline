function value = jsonSafeNumber(value)
%JSONSAFENUMBER Replace non-finite numbers with [] so JSON encodes null.
%   jsonencode maps NaN and Inf to null as well, but doing it here keeps the
%   MATLAB payload and the file identical for the unit test.

    if isempty(value) || ~isnumeric(value)
        value = [];
        return;
    end
    if any(~isfinite(value(:)))
        value = [];
    end
end
