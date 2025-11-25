%% ======================================================
% Arduino Due: Live-Audio + Zeitbereich + FFT (Volt)
% Audio, Zeitplot und FFT synchron mit Buffer-Diagnose
%% ======================================================

clc; clear; close all force;

%% --- Konfiguration ---
port = "COM14";             
baud = 2000000;             
BLOCK_SIZE = 512;            % 40 kHz -> 256, 80 kHz -> 512
SAMPLE_RATE = 40000;        
plotWindow = 500;         
fftLength = 4096;           % Anzahl Samples für FFT
fftLengthZP = 16384;        % Zero-Padded FFT
audioGain = 0.5;            

% ADC Konstanten
Vref   = 3.3;
adcMax = 4095;

% Welchen Kanal anzeigen
channel = 'I';  % 'I' oder 'Q'

%% --- Serielle Verbindung ---
s = serialport(port, baud);
flush(s);

%% --- Audio Player ---
player = audioDeviceWriter('SampleRate', SAMPLE_RATE, ...
                          'SupportVariableSizeInput', true, ...
                          'BufferSize', BLOCK_SIZE);

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

%% --- FFT Rolling Buffer ---
fftBuffer = zeros(fftLength,1);  % speichert letzte fftLength Samples

%% --- Main Loop ---
running = true;
debugCounter = 0;  % Zähler für limitierte Debug-Ausgabe

while running
    %% --- Daten einlesen ---
    nAvailable = floor(s.NumBytesAvailable/2); 
    
    if nAvailable >= BLOCK_SIZE*2
        data = double(read(s, BLOCK_SIZE*2, "uint16"));
        data = data(:);

        %% --- Nur einen Kanal extrahieren ---
        switch channel
            case 'I'
                data = data(1:2:end);  % I-Samples
            case 'Q'
                data = data(2:2:end);  % Q-Samples
        end

        %% --- Zeitbereich in Volt ---
        dataVolt = (data / adcMax) * Vref;

        %% --- Audio normalisieren ---
        dataAudio = (data - 2048)/2048 * audioGain;

        %% --- Audio ausgeben ---
        step(player, dataAudio);

        %% --- Rolling Buffer für Zeitplot ---
        if length(x) >= plotWindow
            x = [x(length(dataVolt)+1:end); dataVolt];
        else
            x = [x; dataVolt];
        end

        %% --- Rolling Buffer für FFT ---
        fftBuffer = [fftBuffer(length(dataVolt)+1:end); dataVolt];

        %% --- FFT berechnen ---
        fftSamples = fftBuffer - mean(fftBuffer);
        fftIn = [fftSamples; zeros(fftLengthZP - fftLength,1)];
        Y = fft(fftIn);
        P2 = abs(Y/fftLength);
        P1 = P2(1:fftLengthZP/2+1);
        P1(2:end-1) = 2*P1(2:end-1);

        % FFT-Plot aktualisieren
        set(hFFT,'XData',f,'YData',P1);

        %% --- Zeitplot aktualisieren ---
        tPlot = (0:length(x)-1)/SAMPLE_RATE;
        set(hTime,'XData',tPlot,'YData',x);

        drawnow limitrate;

        %% --- Debug-Ausgabe alle 50 Pakete ---
        debugCounter = debugCounter + 1;
        if mod(debugCounter,50) == 0
            fprintf('NumBytesAvailable: %d | Zeitplot Samples: %d | FFT-Buffer Samples: %d\n', ...
                    s.NumBytesAvailable, length(x), length(fftBuffer));
        end
    end
end

%% --- Cleanup ---
release(player);
clear player;
flush(s);
