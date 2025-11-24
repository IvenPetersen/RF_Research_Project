%% --- Setup ---
fs = 48000;                  % Samplingrate
BLOCK_SIZE = 1024;           % Blockgröße vom Arduino
BUFFER_SIZE = 8*1024;        % Ringpuffergröße
audioGain = 0.5;             % Lautstärke
port = "COM14";              % COM-Port anpassen
baud = 2000000;              % USB-Baudrate

% --- Ringpuffer initialisieren ---
buffer = zeros(BUFFER_SIZE,1);
bufWriteIdx = 1;
bufReadIdx = 1;

% --- Audio-Player ---
player = audioDeviceWriter('SampleRate', fs, 'SupportVariableSizeInput', true);

% --- Serielle Verbindung ---
s = serialport(port, baud);
flush(s);

fprintf('Starte kontinuierliche Audioausgabe...\n');

%% --- Main Loop ---
running = true;
while running
    % --- Pakete vom Arduino lesen ---
    n = floor(s.NumBytesAvailable/2); % uint16 = 2 Bytes
    if n > 0
        data = double(read(s, n, "uint16"));  % Spaltenvektor
        data = (data - 2048)/2048 * audioGain; % ±1 skalieren

        % --- In Ringpuffer schreiben ---
        idx = bufWriteIdx:bufWriteIdx+n-1;
        buffer(mod(idx-1, BUFFER_SIZE)+1) = data;
        bufWriteIdx = bufWriteIdx + n;
    end

    % --- Audio aus Ringpuffer ausgeben ---
    available = bufWriteIdx - bufReadIdx;
    if available >= BLOCK_SIZE
        idx = bufReadIdx:bufReadIdx+BLOCK_SIZE-1;
        block = buffer(mod(idx-1, BUFFER_SIZE)+1);
        step(player, block);
        bufReadIdx = bufReadIdx + BLOCK_SIZE;
    else
        % Falls zu wenig Daten: Stille ausgeben
        step(player, zeros(BLOCK_SIZE,1));
    end
end

release(player);
clear player;
flush(s);
