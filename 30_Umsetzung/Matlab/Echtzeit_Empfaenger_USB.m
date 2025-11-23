%% ======================================================
% Arduino Due: Live-Audio + Zeitbereich + FFT (Volt)
% Ringpuffer für kontinuierliche Audio-Ausgabe
%% ======================================================

%% --- Konfiguration ---
port = "COM14";             
baud = 2000000;             
BLOCK_SIZE = 1024;          
SAMPLE_RATE = 48000;        
BUFFER_SIZE = 8*1024;       
audioGain = 0.5;            
plotWindow = 10000;         
plotInterval = 0.1;         
fftLength = 4096;           % echte FFT-Samples
fftLengthZP = 16384;        % Zero-Padded FFT (vierfache Länge)

% ADC Konstanten
Vref   = 3.3;
adcMax = 4095;

%% --- Serielle Verbindung ---
s = serialport(port, baud);
flush(s);

%% --- Ringpuffer ---
audioBuffer = zeros(BUFFER_SIZE,1);
bufWriteIdx = 1;
bufReadIdx  = 1;

%% --- Audio Player ---
player = audioDeviceWriter('SampleRate', SAMPLE_RATE, ...
                          'SupportVariableSizeInput', true);

%% --- Live-Plot Setup ---
x = zeros(plotWindow,1);
tPlot = (0:plotWindow-1)/SAMPLE_RATE;

figure;

%% Zeitplot
subplot(2,1,1);
hTime = plot(tPlot, x);
xlabel('Zeit [s]');
ylabel('Spannung [V]');
ylim([0 Vref]);
grid on;
title('Arduino Live-Zeitbereich (Volt)');

%% FFT-Plot
subplot(2,1,2);
f = (0:(fftLengthZP/2)) * (SAMPLE_RATE/fftLengthZP);
hFFT = plot(f, zeros(length(f),1));
xlabel('Frequenz [Hz]');
ylabel('Amplitude [V]');
grid on;
title('Live-FFT (Zero-Padding, Volt)');

lastPlotTime = tic;

%% --- Main Loop ---
running = true;
while running

    %% --- Daten einlesen ---
    nAvailable = floor(s.NumBytesAvailable/2);
    if nAvailable > 0
        data = double(read(s, nAvailable, "uint16"));
        data = data(:);

        %% Zeitplot in Volt (keine Offsetentfernung)
        dataVoltPlot = (data / adcMax) * Vref;

        %% Audio normalisieren
        dataAudio = (data - 2048) / 2048;
        dataAudio = dataAudio * audioGain;

        %% Ringpuffer schreiben
        idx = bufWriteIdx : (bufWriteIdx + length(dataAudio) - 1);
        audioBuffer(mod(idx-1, BUFFER_SIZE)+1) = dataAudio;
        bufWriteIdx = bufWriteIdx + length(dataAudio);

        %% Rolling Buffer für Zeitplot
        if length(dataVoltPlot) >= plotWindow
            x = dataVoltPlot(end-plotWindow+1:end);
        else
            x = [x(length(dataVoltPlot)+1:end); dataVoltPlot];
        end
    end

    %% --- Audio ausgeben ---
    availableSamples = bufWriteIdx - bufReadIdx;

    if availableSamples >= BLOCK_SIZE
        idx = bufReadIdx:(bufReadIdx+BLOCK_SIZE-1);
        blockOut = audioBuffer(mod(idx-1, BUFFER_SIZE)+1);
        step(player, blockOut);
        bufReadIdx = bufReadIdx + BLOCK_SIZE;
    else
        step(player, zeros(BLOCK_SIZE,1));
    end


    %% --- Plot aktualisieren ---
    if toc(lastPlotTime) > plotInterval

        %% Zeitplot aktualisieren
        tPlot = (0:length(x)-1) / SAMPLE_RATE;
        set(hTime, 'XData', tPlot, 'YData', x);

        %% ---------- FFT mit ZERO PADDING ----------
        if length(dataVoltPlot) >= fftLength

            fftSamples = dataVoltPlot(end-fftLength+1:end);

            % Nur für FFT DC entfernen
            fftSamples = fftSamples - mean(fftSamples);

            N = fftLength;      % Anzahl REALER Samples (NICHT ZP!)
            NZP = fftLengthZP;  % Zero-Padded Länge

            % Zero Padding (Amplitude bleibt korrekt)
            fftIn = [fftSamples; zeros(NZP-N,1)];

            % FFT
            Y = fft(fftIn);

            % Amplitudennormalisierung anhand REALER Samplezahl N
            P2 = abs(Y / N);
            P1 = P2(1:NZP/2+1);
            P1(2:end-1) = 2 * P1(2:end-1);

            % Frequenzachse
            f = SAMPLE_RATE * (0:(NZP/2)) / NZP;

            % Plot aktualisieren
            set(hFFT, 'XData', f, 'YData', P1);
        end

        drawnow limitrate;
        lastPlotTime = tic;
    end
end

%% Cleanup
release(player);    
clear player;
flush(s);
