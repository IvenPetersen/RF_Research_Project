%% ======================================================
% Echtzeit-Empfänger: ADC-Daten vom Arduino Due empfangen,
% Zeitsignal + FFT anzeigen
% ======================================================

%% Konfiguration
fsDAC      = 250000;        % ADC-Samplingrate Arduino
fsTarget   = 25000;         % Zielrate für Darstellung / Analyse
blockSize  = 64;            % Blockgröße vom Arduino
baudRate   = 2000000;
comPort    = "COM7";        % Native USB Port des Arduino Due

%% Serielle Verbindung öffnen
try
    arduinoPort = serialport(comPort, baudRate);
    flush(arduinoPort);      % Puffer leeren
catch
    error("Kann den COM-Port nicht öffnen. Prüfe Verbindung und Native USB Port.");
end

disp('Empfang läuft...');

%% Downsampling-Faktor berechnen
downsampleFactor = round(fsDAC / fsTarget);

%% Plot vorbereiten
figure(1); clf;
hTime = subplot(2,1,1); 
timeLine = animatedline('Color','r');
xlabel('Sample'); ylabel('ADC Wert'); 
title('Zeitsignal (ADC)'); 
grid on; ylim([0 4095]);

hFFT = subplot(2,1,2);
fftLine = plot(nan, nan, 'b');
xlabel('Frequenz (Hz)'); ylabel('Amplitude');
title('FFT des ADC-Signals');
grid on;

%% Hauptschleife
while true
    % ------------------------------
    % 1) Prüfen, ob genug Bytes verfügbar sind
    % ------------------------------
    bytesPerSample = 2; % 16-bit ADC
    numAvailable = arduinoPort.NumBytesAvailable;
    if numAvailable < blockSize*bytesPerSample
        pause(0.001);
        continue;
    end

    % ------------------------------
    % 2) Rohdaten vom Arduino lesen
    % ------------------------------
    rawData = read(arduinoPort, blockSize*bytesPerSample, 'uint8');
    adcSamples = typecast(uint8(rawData), 'uint16');

    % ------------------------------
    % 3) Downsampling auf Zielrate
    % ------------------------------
    adcDown = decimate(double(adcSamples), downsampleFactor);

    % ------------------------------
    % 4) Zeitsignal aktualisieren
    % ------------------------------
    if isvalid(timeLine)
        clearpoints(timeLine);
        addpoints(timeLine, 1:length(adcDown), adcDown);
        drawnow limitrate;
    end

    % ------------------------------
    % 5) FFT berechnen
    % ------------------------------
    N = length(adcDown);
    Y = fft(adcDown);
    P2 = abs(Y/N);          % zweiseitiges Spektrum
    P1 = P2(1:floor(N/2)+1); % einseitiges Spektrum
    P1(2:end-1) = 2*P1(2:end-1);
    f = fsTarget*(0:(N/2))/N;

    % ------------------------------
    % 6) FFT-Plot aktualisieren
    % ------------------------------
    if isvalid(fftLine)
        set(fftLine, 'XData', f, 'YData', P1);
        drawnow limitrate;
    end
end
