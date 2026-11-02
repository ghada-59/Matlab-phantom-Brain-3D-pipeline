function assertImageToolbox()
%ASSERTIMAGETOOLBOX Stop with a clear error when the toolbox is missing.
%   Toolbox functions used by this project live in .m files (exist == 2)
%   or, less often, as builtins (exist == 5). license('test', ...) is left
%   to the user so this helper does not check out a license by itself.

    present = exist('multithresh', 'file') == 2 || exist('multithresh', 'builtin') == 5;
    if ~present
        error('boneMorphometry:NoImageToolbox', ...
            ['Image Processing Toolbox is required. In MATLAB run ', ...
             'license(''test'', ''Image_Toolbox'') and ver.']);
    end
end
