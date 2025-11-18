%% ======================================================
% Echtzeit-Empfänger: ADC-Daten vom Arduino Due empfangen
% Stabile Audio-Ausgabe + Zeitsignal in Volt + FFT in Volt
%% ======================================================

% --- Konfiguration ---
fsADC       = 100000;      % Samplingrate des ADC
blockSize   = 1024;        % USB-Paketgröße
baudRate    = 2000000;     % Native USB
comPort     = "COM3";      % COM-Port Arduino Due
audioGain   = 0.5;         % Lautstärke (0–1)
audioBlock  = 1024;        % Schrittgröße für AudioDeviceWriter
plotInterval = 0.1;        % Zeit zwischen Plot-Updates [s]

% --- ADC-Konstanten für Umrechnung auf Volt ---
Vref   = 3.3;     % Referenzspannung des ADC
adcMax = 4095;    % 12-bit ADC

% --- Serielle Verbindung öffnen ---
try
    arduinoPort = serialport(comPort, baudRate);
    flush(arduinoPort);  % Puffer leeren
catch
    error("Kann den COM-Port nicht öffnen. Prüfe Verbindung und Native USB Port.");
end
disp('Empfang läuft...');

% --- Plot vorbereiten ---
figure(1); clf;

% Zeitsignal (in Volt)
subplot(2,1,1);
timeLine = animatedline('Color','r');
xlabel('Sample'); 
ylabel('Amplitude [V]');
title('ADC-Zeitsignal (in Volt)');
grid on; 
ylim([-Vref/2 Vref/2]);   % symmetrisch um 0V

% FFT (Amplitude in Volt)
subplot(2,1,2);
fftLine = plot(nan, nan, 'b');
xlabel('Frequenz (Hz)'); 
ylabel('Amplitude [V]');
title('FFT des ADC-Signals (Zero-Padding, Volt)');
grid on;

% --- Audio-Ausgabe vorbereiten ---
deviceWriter = audioDeviceWriter('SampleRate', fsADC);

% Ringpuffer für kontinuierliche Audio-Ausgabe
ringBufferSize = 10 * audioBlock * 4;
audioBuffer = zeros(ringBufferSize,1);
writeIdx = 1;
readIdx  = 1;

bytesPerSample = 2; % 16-bit pro ADC-Sample
lastPlotTime = tic;

% --- Hauptschleife ---
while true

    % 1) Prüfen, ob genügend Bytes vorhanden sind
    numAvailable = arduinoPort.NumBytesAvailable;
    if numAvailable < blockSize * bytesPerSample
        pause(0.001);
        continue;
    end

    % 2) Rohdaten lesen
    rawData = read(arduinoPort, blockSize * bytesPerSample, 'uint8');
    adcSamples = typecast(uint8(rawData), 'uint16');
    adcData = double(adcSamples);

    % 3) Plot-Update (Zeitsignal + FFT)
    if toc(lastPlotTime) > plotInterval

        % --- ZEITSIGNAL IN VOLT ---
        adcVoltTime = (adcData - mean(adcData)) / adcMax * Vref;  % wie FFT

        if isvalid(timeLine)
            clearpoints(timeLine);
            addpoints(timeLine, 1:length(adcVoltTime), adcVoltTime);
        end

        % --- FFT ---
        N = length(adcData);
        adcZeroDC = adcData - mean(adcData);
        adcVolt = adcZeroDC / adcMax * Vref;

        fftSize = 4*N;                         % Zero-Padding
        Y = fft(adcVolt, fftSize);
        P2 = abs(Y / N);
        P1 = P2(1:floor(fftSize/2)+1);
        P1(2:end-1) = 2*P1(2:end-1);
        f = fsADC * (0:(fftSize/2)) / fftSize;

        if isvalid(fftLine)
            set(fftLine, 'XData', f, 'YData', P1);
        end

        drawnow limitrate;
        lastPlotTime = tic;
    end

    % 4) Audio vorbereiten
    audioSignal = adcData - mean(adcData);
    audioSignal = audioSignal / 2048;   % normalisieren auf ±1
    audioSignal = audioSignal * audioGain;
    audioSignal = audioSignal(:);

    % 5) In Ringpuffer schreiben
    n = length(audioSignal);
    idx = writeIdx:writeIdx+n-1;
    idx = mod(idx-1, ringBufferSize)+1;
    audioBuffer(idx) = audioSignal;
    writeIdx = mod(writeIdx+n-1, ringBufferSize)+1;

    % 6) Kontinuierlich ausgeben
    available = mod(writeIdx - readIdx, ringBufferSize);
    while available >= audioBlock
        idx = readIdx:readIdx+audioBlock-1;
        idx = mod(idx-1, ringBufferSize)+1;
        step(deviceWriter, audioBuffer(idx));
        readIdx = mod(readIdx+audioBlock-1, ringBufferSize)+1;
        available = mod(writeIdx - readIdx, ringBufferSize);
    end
end
