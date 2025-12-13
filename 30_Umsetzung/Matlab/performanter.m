clc;
clear;
close all force;

%% ===================== Configuration =====================
% Serieller Port und Baudrate
port = "COM9";
baud = 2000000;

% Blockgröße für die Verarbeitung und Sample-Rate
BLOCK_SIZE  = 512;
SAMPLE_RATE = 40000;

% FIFO-Einstellungen für Ringpuffer
FIFO_BLOCKS  = 128;                     % Anzahl Blöcke im FIFO
FIFO_CAPACITY = FIFO_BLOCKS * BLOCK_SIZE; % Gesamtkapazität

% Referenzspannung und LSB für ADC -> Volt
Vref  = 3.3;
LSB_V = Vref / 4096;

analogMode = true;   % true = Plots + Audio, false nur Daten erfassen

%% ===================== Serial =====================
% Serielle Schnittstelle initialisieren
s = serialport(port, baud, "Timeout", 0.1);
flush(s);

% UserData Struktur als Ringpuffer für I/Q Samples
ud.I = zeros(FIFO_CAPACITY,1,'int16'); % I-Komponente
ud.Q = zeros(FIFO_CAPACITY,1,'int16'); % Q-Komponente
ud.w = uint32(1);   % Schreibzeiger
ud.r = uint32(1);   % Lesezeiger
ud.n = uint32(0);   % aktuelle Anzahl Samples im FIFO

s.UserData = ud;

% Callback: wird aufgerufen, wenn 1024 Bytes verfügbar sind
configureCallback(s,"byte",1024,@serialCallback);

%% ===================== Audio + Plots =====================
if analogMode
    audioGain = 2;

    % Audio-Player für I/Q Signale (Stereo)
    player = audioDeviceWriter('SampleRate',SAMPLE_RATE,...
        'SupportVariableSizeInput',true,...
        'BufferSize',BLOCK_SIZE*2);

    % Ringbuffer für Plot- und FFT-Daten
    plotWindow  = 500;      % Anzahl Punkte für Zeitbereichs-Plot
    fftLength   = 4096;     % FFT Länge
    fftLengthZP = 16384;    % Zero-Padding Länge für FFT (Auflösung erhöhen)

    xI_buf  = zeros(plotWindow,1); % Zeitbereich I
    xQ_buf  = zeros(plotWindow,1); % Zeitbereich Q
    fftI_buf = zeros(fftLength,1); % FFT-Puffer I
    fftQ_buf = zeros(fftLength,1); % FFT-Puffer Q

    % Indizes für Ringbuffer
    xI_idx = 1; xQ_idx = 1;
    fftI_idx = 1; fftQ_idx = 1;

    % Achsen für Plots
    tPlot = (0:plotWindow-1)/SAMPLE_RATE; % Zeitachse
    f = (0:fftLengthZP/2)*SAMPLE_RATE/fftLengthZP; % Frequenzachse

    % Figure erstellen
    figure('Name','Live I/Q (simplified)','NumberTitle','off');

    subplot(2,2,1);
    hI_time = plot(tPlot,xI_buf); ylim([0 Vref]); grid on; title('I Zeit');

    subplot(2,2,2);
    hI_fft = plot(f,zeros(numel(f),1)); grid on; title('I FFT');

    subplot(2,2,3);
    hQ_time = plot(tPlot,xQ_buf); ylim([0 Vref]); grid on; title('Q Zeit');

    subplot(2,2,4);
    hQ_fft = plot(f,zeros(numel(f),1)); grid on; title('Q FFT');

    drawnow;

    %% ===================== Filter =====================
    % Hochpassfilter (DC-Block)
    fcHP = 5;
    aHP = exp(-2*pi*fcHP/SAMPLE_RATE);

    % Tiefpassfilter (Anti-Aliasing / Audio)
    fcLP = 15000;
    aLP = exp(-2*pi*fcLP/SAMPLE_RATE);
    bLP = 1-aLP;

    % Filterzustände initialisieren
    zi.hpI = 0; zi.hpQ = 0;
    zi.lpI = 0; zi.lpQ = 0;
end

% Debug-Zähler für FIFO-Ausgabe
debugCounter = 0;
DEBUG_DIV = 50;   % alle 50 Blöcke eine Ausgabe

%% ===================== Main Loop =====================
plotCounter = 0;
running = true;

while running
    ud = s.UserData;

    % Wenn genügend Samples im FIFO vorhanden sind
    if ud.n >= BLOCK_SIZE
        % Nächsten Block aus FIFO auslesen
        [dataI,dataQ] = fifo_pop(s,BLOCK_SIZE);
        plotCounter = plotCounter + 1;
        debugCounter = debugCounter + 1;

        % Debug: FIFO-Füllstand alle DEBUG_DIV Blöcke ausgeben
        if mod(debugCounter, DEBUG_DIV) == 0
            ud = s.UserData;        
            fifoFill = 100 * double(ud.n) / double(numel(ud.I));
            fprintf('FIFO: %5.1f %% | samples=%6d | serialBytes=%5d\n', ...
                fifoFill, ud.n, s.NumBytesAvailable);
        end

        if analogMode
            %% ===================== Volt =====================
            voltI = double(dataI)*LSB_V;
            voltQ = double(dataQ)*LSB_V;

            %% ===================== Audio =====================
            xI = double(dataI)/2048*audioGain; % Normalisieren auf [-1,1] evtl
            xQ = double(dataQ)/2048*audioGain;

            % Hochpassfilter (DC entfernen)
            [yI,zi.hpI] = filter([1 -1],[1 -aHP],xI,zi.hpI);
            [yQ,zi.hpQ] = filter([1 -1],[1 -aHP],xQ,zi.hpQ);

            % Tiefpassfilter (Anti-Aliasing / smoothing)
            [yI,zi.lpI] = filter(bLP,[1 -aLP],yI,zi.lpI);
            [yQ,zi.lpQ] = filter(bLP,[1 -aLP],yQ,zi.lpQ);

            % Audio abspielen (Stereo)
            step(player,[yI yQ]);

            %% ===================== Ringbuffer =====================
            [xI_buf,xI_idx]   = ringbuffer_write(xI_buf,voltI,xI_idx);
            [xQ_buf,xQ_idx]   = ringbuffer_write(xQ_buf,voltQ,xQ_idx);
            [fftI_buf,fftI_idx] = ringbuffer_write(fftI_buf,voltI,fftI_idx);
            [fftQ_buf,fftQ_idx] = ringbuffer_write(fftQ_buf,voltQ,fftQ_idx);

            %% ===================== Plots =====================
            % Zeitbereich-Plots alle 5 Blöcke aktualisieren
            if mod(plotCounter,5)==0
                set(hI_time,'YData',ringbuffer_linearize(xI_buf,xI_idx,plotWindow));
                set(hQ_time,'YData',ringbuffer_linearize(xQ_buf,xQ_idx,plotWindow));

                % FFT-Plots alle 10 Blöcke aktualisieren
                if mod(plotCounter,10)==0
                    % FFT I
                    sI = ringbuffer_linearize(fftI_buf,fftI_idx,fftLength);
                    sI = sI-mean(sI); % DC entfernen
                    YI = fft([sI;zeros(fftLengthZP-fftLength,1)]); % Zero-Padding
                    PI = abs(YI/fftLength);
                    PI = PI(1:fftLengthZP/2+1); PI(2:end-1)=2*PI(2:end-1);
                    set(hI_fft,'YData',PI);

                    % FFT Q
                    sQ = ringbuffer_linearize(fftQ_buf,fftQ_idx,fftLength);
                    sQ = sQ-mean(sQ);
                    YQ = fft([sQ;zeros(fftLengthZP-fftLength,1)]);
                    PQ = abs(YQ/fftLength);
                    PQ = PQ(1:fftLengthZP/2+1); PQ(2:end-1)=2*PQ(2:end-1);
                    set(hQ_fft,'YData',PQ);
                end
                drawnow limitrate; % schneller zeichnen ohne GUI-Block
            end
        end
    else
        % FIFO nicht genug gefüllt -> kurze Pause
        pause(0.001);
    end

    % Beenden, wenn Audio-Device nicht mehr gültig
    if analogMode && ~isvalid(player)
        running = false;
    end
end

%% ===================== Cleanup =====================
if analogMode
    release(player); % Audio-Device freigeben
end
flush(s); % Serielle Schnittstelle leeren

%% ===================== Funktionen =====================

% ===================== Serial Callback =====================
function serialCallback(src,~)
    nBytes = src.NumBytesAvailable;
    if nBytes < 4
        return; % nicht genügend Daten für ein I/Q Paar
    end
    nSamples = floor(nBytes/4);        % I/Q Paare
    raw = read(src, nSamples*2, 'int16');

    if isempty(raw)
        return;
    end

    % Samples in FIFO pushen
    fifo_push(src, raw(1:2:end), raw(2:2:end));
end

% ===================== FIFO Push =====================
function fifo_push(s,I,Q)
    ud = s.UserData;
    L = numel(ud.I);
    for k=1:numel(I)
        ud.I(ud.w)=I(k);
        ud.Q(ud.w)=Q(k);
        ud.w = mod(ud.w,L)+1; % Ringpuffer: Schreibzeiger zurücksetzen
        if ud.n<L
            ud.n=ud.n+1; % Füllstand erhöhen
        else
            ud.r=mod(ud.r,L)+1; % bei Überlauf: älteste Daten verwerfen
        end
    end
    s.UserData=ud;
end

% ===================== FIFO Pop =====================
function [I,Q]=fifo_pop(s,n)
    ud=s.UserData;
    n=min(n,ud.n);
    I=zeros(n,1,'int16');
    Q=zeros(n,1,'int16');
    L=numel(ud.I);
    for k=1:n
        I(k)=ud.I(ud.r);
        Q(k)=ud.Q(ud.r);
        ud.r=mod(ud.r,L)+1; % Lesezeiger verschieben
    end
    ud.n=ud.n-n; % Füllstand reduzieren
    s.UserData=ud;
end

% ===================== Ringbuffer Write =====================
function [buf,idx]=ringbuffer_write(buf,data,idx)
    L=numel(buf); n=numel(data);
    if idx+n-1<=L
        buf(idx:idx+n-1)=data;
        idx=mod(idx+n-1,L)+1; % Ringpuffer
    else
        k=L-idx+1;
        buf(idx:end)=data(1:k);
        buf(1:n-k)=data(k+1:end);
        idx=n-k+1;
    end
end

% ===================== Ringbuffer Linearize =====================
function linear=ringbuffer_linearize(buf,idx,len)
    linear=[buf(idx:end);buf(1:idx-1)]; % Ringbuffer "entwirren"
    linear=linear(1:len);
end
