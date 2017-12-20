%written by SAK 

function rebinned = rebin(data, grouping, dimensions, aggregateFcn, varargin)

  if nargin < 3 || isempty(dimensions)
    [~,dimensions]          = max(size(data));
  end
  if nargin < 4 || isempty(aggregateFcn)
    aggregateFcn            = @mean;
  end
  
  for dim = dimensions
    original                = size(data);
    standardized            = [ prod(original(1:dim-1))               ...
                              , original(dim)                         ...
                              , prod(original(dim+1:end))             ...
                              ];
    data                    = reshape(data, standardized);

    numGroups               = ceil(original(dim) / grouping);
    if islogical(data)
      rebinned              = false(standardized(1), numGroups, standardized(end));
    elseif isinteger(data)
      rebinned              = zeros(standardized(1), numGroups, standardized(end), 'like', data);
    else
      rebinned              = nan(standardized(1), numGroups, standardized(end), 'like', data);
    end
    iSource                 = 1;
    for iGroup = 1:numGroups
      rebinned(:,iGroup,:)  = aggregateFcn(data(:,iSource:min(iSource+grouping-1, end),:), 2, varargin{:});
      iSource               = iSource + grouping;
    end
    rebinned                = reshape(rebinned, [original(1:dim-1), numGroups, original(dim+1:end)]);
    
    data                    = rebinned;
  end
  
end
