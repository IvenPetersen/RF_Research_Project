%% ======================================================
% Arduino Due: Live-Audio + Zeitbereich + FFT (Volt)
% (angepasst für digitalen Offset-Abzug im Arduino)
%% ======================================================

clc; clear; close all force;

%% --- Konfiguration ---
port = "COM3";             
baud = 2000000;             
BLOCK_SIZE = 512;            % 40 kHz -> 256, 80 kHz -> 512
SAMPLE_RATE = 40000;        
plotWindow = 500;         
fftLength = 4096;           % Anzahl Samples für FFT
fftLengthZP = 16384;        % Zero-Padded FFT
audioGain = 0.5;            

% ADC Konstanten
Vref   = 3.3;
LSB_V  = Vref / 4096;   % 1 LSB = 3.3V/4096 ≈ 0.8 mV

% Kanal auswählen
channel = 'Q';  % 'I' oder 'Q'

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
ylim([-Vref/2 Vref/2]);   % jetzt zentriert ±1.65V
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
fftBuffer = zeros(fftLength,1);

%% --- Main Loop ---
running = true;
debugCounter = 0;

while running
    %% --- Prüfen, ob genug Daten angekommen sind ---
    nAvailable = floor(s.NumBytesAvailable/2);
    
    if nAvailable >= BLOCK_SIZE*2
        %% --- Rohdaten holen (uint16) ---
        data = read(s, BLOCK_SIZE*2, "uint16");
        data = data(:);

        %% --- Rohdaten zu int16 interpretieren ---
        % Arduino sendet OFFSET-CORRECTED signed 16-bit Werte:
        % [-2048 ... +2047]
        data = typecast(uint16(data), 'int16');

        %% --- Nur I oder Q extrahieren ---
        switch channel
            case 'I'
                data = data(1:2:end);
            case 'Q'
                data = data(2:2:end);
        end

        %% --- Umrechnung in Volt ---
        % 1 LSB = 3.3/4096 V
        dataVolt = double(data) * LSB_V;

        %% --- Audio normalisieren ---
        % signed 16-bit Bereich: ±2048 entspricht ±1.65 V
        dataAudio = double(data)/2048 * audioGain;

        %% --- Audio ausgeben ---
        step(player, dataAudio);

        %% --- Rolling Buffer Zeitplot ---
        if length(x) >= plotWindow
            x = [x(length(dataVolt)+1:end); dataVolt];
        else
            x = [x; dataVolt];
        end

        %% --- Rolling Buffer FFT ---
        fftBuffer = [fftBuffer(length(dataVolt)+1:end); dataVolt];

        %% --- FFT ---
        fftSamples = fftBuffer - mean(fftBuffer);  % Gleichanteil weg
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
            fprintf('NumBytesAvailable: %d | Zeitplot: %d Samples | FFT: %d Samples\n', ...
                    s.NumBytesAvailable, length(x), length(fftBuffer));
        end
    end
end

%% --- Cleanup ---
release(player);
clear player;
flush(s);
