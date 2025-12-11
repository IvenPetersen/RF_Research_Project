%% ======================================================
% Arduino Due: Live I+Q – Zeit + FFT (Volt)
% Stereo-Audio: I = links, Q = rechts
% Zeitplots 0…3.3 V, Audio mit Hochpassfilter + Tiefpass (Bandpass)
%% ======================================================

clc; clear; close all force;

%% --- Konfiguration ---
port = "COM9";
baud = 2000000;

BLOCK_SIZE = 512;
SAMPLE_RATE = 40000;
plotWindow = 500;
fftLength = 4096;
fftLengthZP = 16384;
audioGain = 2;

% ADC Konstanten
Vref = 3.3;
LSB_V = Vref / 4096;

%% --- DC-Blocker Setup (Hochpass 5 Hz) ---
xI_prev = 0; yI_prev = 0;
xQ_prev = 0; yQ_prev = 0;

fcHP = 5;                                   % Hochpass-Grenzfrequenz [Hz]
aHP = exp(-2*pi*fcHP/SAMPLE_RATE);          % Filterkoeffizient

%% --- Tiefpass 15 kHz für Bandpass ---
fcLP = 15000;
aLP = exp(-2*pi*fcLP/SAMPLE_RATE);
bLP = 1 - aLP;

yI_lp_prev = 0;
yQ_lp_prev = 0;

%% --- Serielle Verbindung ---
s = serialport(port, baud);
flush(s);

%% --- Audio Player ---
player = audioDeviceWriter('SampleRate', SAMPLE_RATE, ...
    'SupportVariableSizeInput', true, ...
    'BufferSize', BLOCK_SIZE);

%% --- Plot-Puffer (feste Größe, verhindert Fehler) ---
xI = zeros(plotWindow,1);
xQ = zeros(plotWindow,1);

fftI = zeros(fftLength,1);
fftQ = zeros(fftLength,1);

tPlot = (0:plotWindow-1)/SAMPLE_RATE;
f = (0:(fftLengthZP/2)) * (SAMPLE_RATE/fftLengthZP);

%% --- Grafik ---
figure;

subplot(2,2,1);
hI_time = plot(tPlot, xI);
xlabel('Zeit [s]'); ylabel('Volt I'); ylim([0 Vref]);
grid on; title('I – Zeitbereich');

subplot(2,2,2);
hI_fft = plot(f, zeros(length(f),1));
xlabel('Frequenz [Hz]'); ylabel('Amplitude'); grid on;
title('I – FFT');

subplot(2,2,3);
hQ_time = plot(tPlot, xQ);
xlabel('Zeit [s]'); ylabel('Volt Q'); ylim([0 Vref]);
grid on; title('Q – Zeitbereich');

subplot(2,2,4);
hQ_fft = plot(f, zeros(length(f),1));
xlabel('Frequenz [Hz]'); ylabel('Amplitude'); grid on;
title('Q – FFT');

%% --- Main Loop ---
running = true;
debugCounter = 0;

while running

    nAvailable = floor(s.NumBytesAvailable/2);

    if nAvailable >= BLOCK_SIZE*2

        % --- Rohdaten holen ---
        raw = read(s, BLOCK_SIZE*2, "uint16");
        raw = raw(:);

        % --- Zu int16 interpretieren ---
        raw = typecast(uint16(raw), 'int16');

        % --- I/Q entflechten ---
        dataI = raw(1:2:end);
        dataQ = raw(2:2:end);

        % --- Volt für Zeitplot ---
        voltI = double(dataI) * LSB_V;
        voltQ = double(dataQ) * LSB_V;

        %% ================== Audio Stereo mit Bandpass ==================
        xI_in = double(dataI)/2048 * audioGain;
        xQ_in = double(dataQ)/2048 * audioGain;

        yI = zeros(size(xI_in));
        yQ = zeros(size(xQ_in));

        yI_lp = zeros(size(xI_in));
        yQ_lp = zeros(size(xQ_in));

        for n = 1:length(xI_in)

            %% --- Hochpass I (DC-Blocker) ---
            x0 = xI_in(n);
            hp_I = x0 - xI_prev + aHP * yI_prev;
            xI_prev = x0;
            yI_prev = hp_I;

            %% --- Hochpass Q ---
            x0 = xQ_in(n);
            hp_Q = x0 - xQ_prev + aHP * yQ_prev;
            xQ_prev = x0;
            yQ_prev = hp_Q;

            %% --- Tiefpass I (15 kHz) ---
            lp_I = bLP * hp_I + aLP * yI_lp_prev;
            yI_lp_prev = lp_I;

            %% --- Tiefpass Q (15 kHz) ---
            lp_Q = bLP * hp_Q + aLP * yQ_lp_prev;
            yQ_lp_prev = lp_Q;

            %% --- Ergebnis Bandpass ---
            yI(n) = lp_I;
            yQ(n) = lp_Q;

        end

        dataAudio = [yI, yQ];
        step(player, dataAudio);

        %% ================== Rolling Buffer Zeitplots ==================
        xI = [xI(end-plotWindow+1:end); voltI];
        xI = xI(end-plotWindow+1:end);

        xQ = [xQ(end-plotWindow+1:end); voltQ];
        xQ = xQ(end-plotWindow+1:end);

        tPlot = (0:plotWindow-1)/SAMPLE_RATE;
        set(hI_time,'XData',tPlot,'YData',xI);
        set(hQ_time,'XData',tPlot,'YData',xQ);

        ylim(hI_time.Parent,[0 Vref]);
        ylim(hQ_time.Parent,[0 Vref]);

        %% ================== Rolling Buffer FFT ====================
        fftI = [fftI(length(voltI)+1:end); voltI];
        fftQ = [fftQ(length(voltQ)+1:end); voltQ];

        fftI = fftI(end-fftLength+1:end);
        fftQ = fftQ(end-fftLength+1:end);

        % --- FFT I ---
        sI = fftI - mean(fftI); % DC blockweise
        YI = fft([sI; zeros(fftLengthZP - fftLength,1)]);
        P2I = abs(YI/fftLength);
        PI = P2I(1:fftLengthZP/2+1);
        PI(2:end-1) = 2*PI(2:end-1);
        set(hI_fft,'XData',f,'YData',PI);

        % --- FFT Q ---
        sQ = fftQ - mean(fftQ); % DC blockweise
        YQ = fft([sQ; zeros(fftLengthZP - fftLength,1)]);
        P2Q = abs(YQ/fftLength);
        PQ = P2Q(1:fftLengthZP/2+1);
        PQ(2:end-1) = 2*PQ(2:end-1);
        set(hQ_fft,'XData',f,'YData',PQ);

        drawnow limitrate;

        %% Debug-Ausgabe
        debugCounter = debugCounter + 1;
        if mod(debugCounter,50) == 0
            fprintf('Bytes: %d | ZeitWindow=%d | FFT=%d\n', ...
                s.NumBytesAvailable, length(xI), length(fftI));
        end
    end
end

%% --- Cleanup ---
release(player);
clear player;
flush(s);
