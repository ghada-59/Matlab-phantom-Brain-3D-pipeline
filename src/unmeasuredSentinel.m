function sentinel = unmeasuredSentinel()
%UNMEASUREDSENTINEL Em dash shown when a metric was not computed.
%   U+2014. The dashboard uses the same character via the escape \u2014.
    sentinel = char(8212);
end
