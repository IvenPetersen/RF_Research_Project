fs = 48000;
f0 = 50;
duration = 10;
amplitude = 0.5;

t = (0:1/fs:duration-1/fs)';    % Spaltenvektor
signal = amplitude * sin(2*pi*f0*t);

player = audioDeviceWriter('SampleRate', fs, 'SupportVariableSizeInput', true);

blockSize = 1024;
idx = 1;

while idx <= length(signal)
    idxEnd = min(idx + blockSize - 1, length(signal));
    block = signal(idx:idxEnd);
    step(player, block);
    idx = idxEnd + 1;
end

release(player);
clear player;
