%% ======================================================
% Echtzeit-Empfänger: ADC-Daten vom Arduino Due empfangen
% Stabile Audio-Ausgabe + Zeitsignal + FFT
%% ======================================================

%% --- Konfiguration ---
fsADC       = 100000;      % Samplingrate des ADC
blockSize   = 1024;         % USB-Paketgröße
baudRate    = 2000000;     % Native USB
comPort     = "COM3";     % COM-Port Arduino Due
audioGain   = 0.5;         % Lautstärke (0–1)
audioBlock  = 1024;        % Schrittgröße für AudioDeviceWriter
plotInterval = 0.1;       % Zeit zwischen Plot-Updates [s]

%% --- Serielle Verbindung öffnen ---
try
    arduinoPort = serialport(comPort, baudRate);

    flush(arduinoPort);  % Puffer leeren
catch
    error("Kann den COM-Port nicht öffnen. Prüfe Verbindung und Native USB Port.");
end
disp('Empfang läuft...');

%% --- Plot vorbereiten ---
figure(1); clf;

% Zeitsignal
subplot(2,1,1);
timeLine = animatedline('Color','r');
xlabel('Sample'); ylabel('ADC-Wert (0–4095)');
title('ADC-Zeitsignal (Arduino Due)');
grid on; ylim([0 4095]);

% FFT
subplot(2,1,2);
fftLine = plot(nan, nan, 'b');
xlabel('Frequenz (Hz)'); ylabel('Amplitude');
title('FFT des ADC-Signals');
grid on;

%% --- Audio-Ausgabe vorbereiten ---
deviceWriter = audioDeviceWriter('SampleRate', fsADC);

% Ringpuffer für kontinuierliche Audio-Ausgabe
ringBufferSize = 10 * audioBlock * 4;
audioBuffer = zeros(ringBufferSize,1);
writeIdx = 1;
readIdx  = 1;

bytesPerSample = 2; % 16-bit pro ADC-Sample

lastPlotTime = tic; % Timer für Plot-Update

%% --- Hauptschleife ---
while true
    % ------------------------------
    % 1) Prüfen, ob genug Bytes verfügbar sind
    % ------------------------------
    numAvailable = arduinoPort.NumBytesAvailable;
    if numAvailable < blockSize * bytesPerSample
        pause(0.001);
        continue;
    end
    
    % ------------------------------
    % 2) Rohdaten lesen
    % ------------------------------
    rawData = read(arduinoPort, blockSize * bytesPerSample, 'uint8');
    adcSamples = typecast(uint8(rawData), 'uint16');  % Little Endian
    adcData = double(adcSamples);
    
    % ------------------------------
    % 3) Zeitsignal & FFT (nur alle plotInterval Sekunden)
    % ------------------------------
    if toc(lastPlotTime) > plotInterval
        % Zeitsignal
        if isvalid(timeLine)
            clearpoints(timeLine);
            addpoints(timeLine, 1:length(adcData), adcData);
        end
        
        % FFT
        N = length(adcData);
        Y = fft(adcData);
        P2 = abs(Y / N);
        P1 = P2(1:floor(N/2)+1);
        P1(2:end-1) = 2*P1(2:end-1);
        f = fsADC * (0:(N/2)) / N;
        if isvalid(fftLine)
            set(fftLine, 'XData', f, 'YData', P1);
        end
        
        drawnow limitrate;
        lastPlotTime = tic;
    end
    
    % ------------------------------
    % 4) Audio vorbereiten
    % ------------------------------
    audioSignal = adcData - mean(adcData);       % DC entfernen
    audioSignal = audioSignal / 2048;           % Normalisieren auf ±1
    audioSignal = audioSignal * audioGain;      % Lautstärke
    audioSignal = audioSignal(:);               % Spaltenvektor
    
    % ------------------------------
    % 5) Audio in Ringpuffer schreiben
    % ------------------------------
    n = length(audioSignal);
    idx = writeIdx:writeIdx+n-1;
    idx = mod(idx-1, ringBufferSize)+1;  % Ringpuffer-Indexierung
    audioBuffer(idx) = audioSignal;
    writeIdx = mod(writeIdx+n-1, ringBufferSize)+1;
    
    % ------------------------------
    % 6) AudioDeviceWriter kontinuierlich ausgeben
    % ------------------------------
    available = mod(writeIdx - readIdx, ringBufferSize);
    while available >= audioBlock
        idx = readIdx:readIdx+audioBlock-1;
        idx = mod(idx-1, ringBufferSize)+1;
        step(deviceWriter, audioBuffer(idx));
        readIdx = mod(readIdx+audioBlock-1, ringBufferSize)+1;
        available = mod(writeIdx - readIdx, ringBufferSize);
    end
end