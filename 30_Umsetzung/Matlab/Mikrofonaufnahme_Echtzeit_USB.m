% ======================================================
% NF_Echtzeit_upsample: Sprache in Echtzeit aufnehmen,
% auf 250 kHz hochrechnen und blockweise an Arduino Due senden
% ======================================================

%% Konfiguration
fs = 25000;             % Eingangs-Samplingrate (Mikrofon) in Hz
fsDAC = 250000;         % Ziel-Samplingrate (DAC) in Hz
blockSize = 64;        % Samples pro Block vom Mikrofon
baudRate = 2000000;     
comPort = "COM3";       % Native USB Port des Arduino Due

%% Serielle Verbindung zum Arduino
try
    arduinoPort = serialport(comPort, baudRate);
    flush(arduinoPort);  % Puffer leeren
catch
    error("Kann den COM-Port nicht öffnen. Prüfe Verbindung und Native USB Port.");
end

%% Audio-Interface konfigurieren
deviceReader = audioDeviceReader( ...
    'SampleRate', fs, ...
    'SamplesPerFrame', blockSize, ...
    'BitDepth', '16-bit integer', ...
    'OutputDataType', 'double');  % double für einfache Skalierung

disp('Sprich jetzt ins Mikrofon...');

%% Upsampling-Faktor berechnen
upsampleFactor = round(fsDAC / fs);  % 250 kHz / 25 kHz = 10

%% Live-Plot vorbereiten
hPlot = plot(nan(blockSize*upsampleFactor,1)); % Platz für Upsampled Block
ylim([-1 1]);
xlabel('Sample');
ylabel('Amplitude');
title('Upsampled Audio (250 kHz)');
grid on;
drawnow;

%% Hauptschleife
while true
    % 1) Block direkt vom Mikrofo
    audioBlock = deviceReader();  % blockSize Samples bei 25 kHz

    % 2) Auf 250 kHz hochrechnen
    audioUp = resample(audioBlock, upsampleFactor, 1);  % FIR-basiert

    % 3) Live-Plot aktualisieren
    set(hPlot, 'YData', audioUp);
    drawnow limitrate;

    % 4) Signal auf 12-Bit skalieren (0-4095)
    audio12bit = uint16((audioUp + 1) * 2047.5);

    % 5) In Bytes konvertieren (Little Endian)
    byteBlock = reshape(typecast(audio12bit, 'uint8'), [], 1);

    % 7) 1280 Bytes in einem USB-Paket senden (640 Sampels (mit Upsampling))
    write(arduinoPort, byteBlock, 'uint8');
end