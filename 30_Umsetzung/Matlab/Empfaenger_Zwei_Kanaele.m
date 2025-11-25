%% ======================================================
% Arduino Due: I/Q mit Audio und FFT nur vom I-Kanal
%% ======================================================

clc; clear; close all force;

%% --- Konfiguration ---
port = "COM14";
baud = 2000000;
BLOCK_SIZE = 512;        % Samples pro Kanal
SAMPLE_RATE = 80000;     % Gesamtrate (I+Q)
plotWindow = 500;        % Samples für Zeitplot
fftLength = 4096;        % FFT-Länge
fftLengthZP = 16384;     % Zero-Padding FFT
audioGain = 0.5;         % Audio Normalisierung

Vref = 3.3;
adcMax = 4095;

%% --- Serielle Verbindung ---
s = serialport(port, baud);
flush(s);

%% --- Audio Player (nur I-Kanal) ---
player = audioDeviceWriter('SampleRate', SAMPLE_RATE/2, ... % 40 kHz pro Kanal
    'SupportVariableSizeInput', true, ...
    'BufferSize', BLOCK_SIZE);

%% --- Live-Plot Setup ---
xI = zeros(plotWindow,1);
xQ = zeros(plotWindow,1);
tPlot = (0:plotWindow-1)/(SAMPLE_RATE/2);

figure;

subplot(3,1,1);
hTimeI = plot(tPlot, xI, 'b');
xlabel('Zeit [s]'); ylabel('Spannung [V]');
ylim([0 Vref]); grid on; title('I-Kanal Zeitbereich');

subplot(3,1,2);
hTimeQ = plot(tPlot, xQ, 'r');
xlabel('Zeit [s]'); ylabel('Spannung [V]');
ylim([0 Vref]); grid on; title('Q-Kanal Zeitbereich');

subplot(3,1,3);
f = (0:(fftLengthZP/2)) * (SAMPLE_RATE/2/fftLengthZP); % FFT nur auf I-Kanal
hFFT = plot(f, zeros(length(f),1));
xlabel('Frequenz [Hz]'); ylabel('Amplitude [V]');
grid on; title('FFT I-Kanal');

%% --- FFT Rolling Buffer (nur I) ---
fftBuffer = zeros(fftLength,1);

%% --- Main Loop ---
running = true;
while running
    nAvailable = floor(s.NumBytesAvailable/2);
    if nAvailable >= BLOCK_SIZE*2
        data = double(read(s, BLOCK_SIZE*2, "uint16"));
        data = data(:);

        % Interleaved I/Q entpacken
        I = (data(1:2:end)/adcMax) * Vref;
        Q = (data(2:2:end)/adcMax) * Vref;

        %% --- Audio nur vom I-Kanal ---
        dataAudio = (I - 0.5)*2*audioGain;
        step(player, dataAudio);

        %% --- Rolling Buffer Zeitbereich ---
        if length(xI) >= plotWindow
            xI = [xI(length(I)+1:end); I];
            xQ = [xQ(length(Q)+1:end); Q];
        else
            xI = [xI; I];
            xQ = [xQ; Q];
        end

        %% --- FFT nur auf I-Kanal ---
        fftBuffer = [fftBuffer(length(I)+1:end); I];  % nur I
        fftSamples = fftBuffer - mean(fftBuffer);
        fftIn = [fftSamples; zeros(fftLengthZP - fftLength,1)];
        Y = fft(fftIn);
        P2 = abs(Y/fftLength);
        P1 = P2(1:fftLengthZP/2+1);
        P1(2:end-1) = 2*P1(2:end-1);

        % FFT-Plot aktualisieren
        set(hFFT,'XData',f,'YData',P1);

        % Zeitplots aktualisieren
        tPlot = (0:length(xI)-1)/(SAMPLE_RATE/2);
        set(hTimeI,'XData',tPlot,'YData',xI);
        set(hTimeQ,'XData',tPlot,'YData',xQ);

        drawnow limitrate;
    end
end

%% --- Cleanup ---
release(player);
clear player;
flush(s);
