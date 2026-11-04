function meas = runPipeline(source, varargin)
%RUNPIPELINE Read a phantom or a DICOM series, segment it, and measure it.
%
%   MEASUREMENTS = runPipeline(PHANTOM_OR_FOLDER, Name, Value, ...) chains
%   readVolumeHU, segmentBone, and meshAndMeasure. Name-value arguments are
%   forwarded to both measurement stages (unknown names are ignored by the
%   stage that does not define them).
%
%   When the source is a phantom, analytic volume and true semi-axes are
%   copied onto the result and relative errors are computed. Those errors
%   are empty when the reference is unknown (a real DICOM series).
%
%   The mask and the HU volume stay on the struct so a later export can
%   write slices. They are not clinical findings.

    volume = readVolumeHU(source);
    segmentation = segmentBone(volume.hu, volume.spacingMM, varargin{:});
    meas = meshAndMeasure(segmentation.mask, volume.spacingMM, varargin{:});

    meas.spacingMM = volume.spacingMM;
    meas.sliceSpacingSource = '';
    meas.sliceThicknessMM = [];
    if isfield(volume, 'sliceSpacingSource')
        meas.sliceSpacingSource = volume.sliceSpacingSource;
    end
    if isfield(volume, 'sliceThicknessMM')
        meas.sliceThicknessMM = volume.sliceThicknessMM;
    end
    meas.source = volume.source;
    meas.huConfirmed = volume.huConfirmed;
    meas.rescaleSlope = volume.rescaleSlope;
    meas.rescaleIntercept = volume.rescaleIntercept;
    meas.threshold = segmentation.threshold;
    meas.objectsBeforeLargest = segmentation.objectsBeforeLargest;
    meas.backgroundHU = volume.backgroundHU;
    meas.boneHU = volume.boneHU;
    meas.mask = segmentation.mask;
    meas.hu = volume.hu;

    meas.analyticVolumeMM3 = volume.analyticVolumeMM3;
    meas.numericRasterVolumeMM3 = volume.numericVolumeMM3;
    meas.semiAxesTrueMM = volume.semiAxesMM;
    meas.referenceAreaMM2 = [];
    meas.relErrVoxelVolume = [];
    meas.relErrMeshVolume = [];
    meas.relErrArea = [];
    meas.relErrSemiAxes = [];

    if ~isempty(volume.analyticVolumeMM3) && isfinite(volume.analyticVolumeMM3)
        meas.relErrVoxelVolume = relativeError(meas.voxelVolumeMM3, volume.analyticVolumeMM3);
        meas.relErrMeshVolume = relativeError(meas.meshVolumeMM3, volume.analyticVolumeMM3);
    end
    if ~isempty(volume.semiAxesMM) && numel(volume.semiAxesMM) == 3 && all(volume.semiAxesMM > 0)
        meas.semiAxesTrueMM = double(volume.semiAxesMM(:)');
        meas.referenceAreaMM2 = referenceEllipsoidArea(meas.semiAxesTrueMM);
        meas.relErrArea = relativeError(meas.meshAreaMM2, meas.referenceAreaMM2);
        % eig stores a row; the phantom reference may be a column.
        % Force both to 1-by-3. relativeError is unchanged and still
        % errors when the two sizes differ.
        estimated = sort(double(meas.semiAxesMM(:).'), 'descend');
        truth = sort(double(meas.semiAxesTrueMM(:).'), 'descend');
        meas.relErrSemiAxes = relativeError(estimated, truth);
    end
end
