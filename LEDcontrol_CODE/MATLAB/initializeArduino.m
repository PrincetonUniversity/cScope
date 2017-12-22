function ardCOM = initializeArduino(port)

if nargin < 1
    port = LEDparams.arduinoPort;
end
% Reset communication if necessary
inst = instrfindall;
if ~isempty(inst)
    for ii = 1:length(inst)
        fclose(inst(ii));
        delete(inst(ii));
    end
    clear inst
end

ardCOM = serial(port);
set(ardCOM,'BaudRate',9600);
fopen(ardCOM);
end
