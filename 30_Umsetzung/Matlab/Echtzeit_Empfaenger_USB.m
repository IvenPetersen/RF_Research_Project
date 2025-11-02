%% ======================================================
% Echtzeit-Empfänger: ADC-Daten vom Arduino Due empfangen,
% Zeitsignal + FFT anzeigen
% ======================================================

%% --- Konfiguration ---
fsADC      = 25000;          % Effektive ADC-Samplingrate (nach 10x Downsampling im Arduino)
blockSize  = 64;            % Anzahl Samples pro USB-Paket (wie im Arduino eingestellt)
baudRate   = 2000000;        % Baudrate des USB-Serial Kanals
comPort    = "COM3";         % Native USB-Port des Arduino DUE

%% --- Serielle Verbindung öffnen ---
try
    arduinoPort = serialport(comPort, baudRate);
    flush(arduinoPort);      % Puffer leeren
catch
    error("Kann den COM-Port nicht öffnen. Prüfe Verbindung und Native USB Port.");
end

disp('Empfang läuft...');

%% --- Plot vorbereiten ---
figure(1); clf;

% Zeitsignal-Plot
subplot(2,1,1);
timeLine = animatedline('Color','r');
xlabel('Sample');
ylabel('ADC-Wert (0–4095)');
title('ADC-Zeitsignal (Arduino Due)');
grid on;
ylim([0 4095]);

% FFT-Plot
subplot(2,1,2);
fftLine = plot(nan, nan, 'b');
xlabel('Frequenz (Hz)');
ylabel('Amplitude');
title('FFT des ADC-Signals');
grid on;

%% --- Hauptschleife ---
bytesPerSample = 2;  % 16 Bit pro ADC-Sample
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
    % 2) Rohdaten vom Arduino lesen
    % ------------------------------
    rawData = read(arduinoPort, blockSize * bytesPerSample, 'uint8');
    adcSamples = typecast(uint8(rawData), 'uint16');  % Little Endian → 16-bit Werte
    adcData = double(adcSamples);                     % Für Plot und FFT

    % ------------------------------
    % 3) Zeitsignal aktualisieren
    % ------------------------------
    if isvalid(timeLine)
        clearpoints(timeLine);
        addpoints(timeLine, 1:length(adcData), adcData);
        drawnow limitrate;
    end

    % ------------------------------
    % 4) FFT berechnen
    % ------------------------------
    N = length(adcData);
    Y = fft(adcData);
    P2 = abs(Y / N);                 % zweiseitiges Spektrum
    P1 = P2(1:floor(N/2) + 1);       % einseitiges Spektrum
    P1(2:end-1) = 2 * P1(2:end-1);   % Leistung auf positive Frequenzen verdoppeln
    f = fsADC * (0:(N/2)) / N;

    % ------------------------------
    % 5) FFT-Plot aktualisieren
    % ------------------------------
    if isvalid(fftLine)
        set(fftLine, 'XData', f, 'YData', P1);
        drawnow limitrate;
    end
end