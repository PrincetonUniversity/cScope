function terminateArduino(ardCOM)

if nargin < 1
    ardCOM = instrfindall;
end

fclose(ardCOM);
delete(ardCOM);
clear ardCOM


end
