clc;
clear;
close all force;

%% ---------------- Configuration ----------------
port = "COM9";
baud = 2000000;

BLOCK_SIZE = 512;
SAMPLE_RATE = 40000;

FIFO_BLOCKS = 256;
FIFO_CAPACITY = FIFO_BLOCKS * BLOCK_SIZE;

Vref = 3.3;
LSB_V = Vref / 4096;

%% ---------------- Mode Selection ----------------
% true = analog (Plots + Audio)
% false = digital (I/Q weiterverarbeiten)
analogMode = true;

%% ---------------- Serialport + Callback ----------------
s = serialport(port, baud, "Timeout", 0.1);
flush(s);

bytesPerBlock = BLOCK_SIZE * 4;

ud = struct();
ud.fifoI = zeros(FIFO_CAPACITY, 1, 'int16');
ud.fifoQ = zeros(FIFO_CAPACITY, 1, 'int16');
ud.writePos = uint32(1);
ud.readPos = uint32(1);
ud.count = uint32(0);
ud.lock = false;

s.UserData = ud;
configureCallback(s, "byte", bytesPerBlock, @(src,evt) serialCallback(src, evt, BLOCK_SIZE));

%% ---------------- Audio + Plots (nur analog) ----------------
if analogMode
    audioGain = 2;

    player = audioDeviceWriter('SampleRate', SAMPLE_RATE);
    player.SupportVariableSizeInput = true;
    player.BufferSize = BLOCK_SIZE*2;

    plotWindow = 500;
    fftLength = 4096;
    fftLengthZP = 16384;

    xI_buf = zeros(plotWindow,1);
    xQ_buf = zeros(plotWindow,1);
    fftI_buf = zeros(fftLength,1);
    fftQ_buf = zeros(fftLength,1);

    xI_idx = 1;
    xQ_idx = 1;
    fftI_idx = 1;
    fftQ_idx = 1;

    tPlot = (0:plotWindow-1)/SAMPLE_RATE;
    f = (0:(fftLengthZP/2)) * (SAMPLE_RATE/fftLengthZP);

    figure('Name','Live I/Q Efficient + FFT','NumberTitle','off');

    subplot(2,2,1);
    hI_time = plot(tPlot, xI_buf);
    ylim([0 Vref]);
    xlabel('Zeit [s]');
    ylabel('I [V]');
    grid on;
    title('I Zeitbereich');

    subplot(2,2,2);
    hI_fft = plot(f, zeros(length(f),1));
    xlabel('Frequenz [Hz]');
    ylabel('Amplitude');
    grid on;
    title('I FFT');

    subplot(2,2,3);
    hQ_time = plot(tPlot, xQ_buf);
    ylim([0 Vref]);
    xlabel('Zeit [s]');
    ylabel('Q [V]');
    grid on;
    title('Q Zeitbereich');

    subplot(2,2,4);
    hQ_fft = plot(f, zeros(length(f),1));
    xlabel('Frequenz [Hz]');
    ylabel('Amplitude');
    grid on;
    title('Q FFT');

    drawnow;

    %% ---------------- Filter settings ----------------
    fcHP = 5;
    aHP = exp(-2*pi*fcHP/SAMPLE_RATE);

    fcLP = 15000;
    aLP = exp(-2*pi*fcLP/SAMPLE_RATE);
    bLP = 1 - aLP;

    zi_hpI = 0;
    zi_hpQ = 0;
    zi_lpI = 0;
    zi_lpQ = 0;
end

%% ---------------- Main Loop ----------------
running = true;
plotCounter = 0;

try
    while running
        ud = s.UserData;
        available = double(ud.count);

        if available >= BLOCK_SIZE
            [dataI, dataQ] = fifo_pop(s, BLOCK_SIZE);

            if numel(dataI) < BLOCK_SIZE
                dataI(end+1:BLOCK_SIZE) = int16(0);
            end

            if numel(dataQ) < BLOCK_SIZE
                dataQ(end+1:BLOCK_SIZE) = int16(0);
            end

            plotCounter = plotCounter + 1;

            if analogMode
                voltI = double(dataI) * LSB_V;
                voltQ = double(dataQ) * LSB_V;

                xI_in = double(dataI)/2048 * audioGain;
                xQ_in = double(dataQ)/2048 * audioGain;

                [yI_hp, zi_hpI] = filter([1 -1], [1 -aHP], xI_in, zi_hpI);
                [yQ_hp, zi_hpQ] = filter([1 -1], [1 -aHP], xQ_in, zi_hpQ);

                [yI_lp, zi_lpI] = filter(bLP, [1 -aLP], yI_hp, zi_lpI);
                [yQ_lp, zi_lpQ] = filter(bLP, [1 -aLP], yQ_hp, zi_lpQ);

                step(player, [yI_lp, yQ_lp]);

                [xI_buf, xI_idx] = ringbuffer_write(xI_buf, voltI, xI_idx);
                [xQ_buf, xQ_idx] = ringbuffer_write(xQ_buf, voltQ, xQ_idx);
                [fftI_buf, fftI_idx] = ringbuffer_write(fftI_buf, voltI, fftI_idx);
                [fftQ_buf, fftQ_idx] = ringbuffer_write(fftQ_buf, voltQ, fftQ_idx);

                if mod(plotCounter, 5) == 0
                    set(hI_time, 'YData', ringbuffer_linearize(xI_buf, xI_idx, plotWindow));
                    set(hQ_time, 'YData', ringbuffer_linearize(xQ_buf, xQ_idx, plotWindow));

                    if mod(plotCounter, 10) == 0
                        sI = ringbuffer_linearize(fftI_buf, fftI_idx, fftLength);
                        sI = sI - mean(sI);
                        YI = fft([sI; zeros(fftLengthZP-fftLength,1)]);
                        P2I = abs(YI/fftLength);
                        PI = P2I(1:fftLengthZP/2+1);
                        PI(2:end-1) = 2*PI(2:end-1);
                        set(hI_fft,'YData', PI);

                        sQ = ringbuffer_linearize(fftQ_buf, fftQ_idx, fftLength);
                        sQ = sQ - mean(sQ);
                        YQ = fft([sQ; zeros(fftLengthZP-fftLength,1)]);
                        P2Q = abs(YQ/fftLength);
                        PQ = P2Q(1:fftLengthZP/2+1);
                        PQ(2:end-1) = 2*PQ(2:end-1);
                        set(hQ_fft,'YData', PQ);
                    end

                    drawnow limitrate;
                end
            end

            %% ---------------- FIFO Status Output ----------------
            if mod(plotCounter, 50) == 0
                fprintf('FIFO count: %d / %d | writePos=%d readPos=%d\n', ...
                    ud.count, FIFO_CAPACITY, ud.writePos, ud.readPos);
            end
        else
            pause(0.001);
        end

        if analogMode
            if ~isvalid(player)
                running = false;
            end
        end
    end
catch ME
    disp(ME.message);
end

%% ---------------- Cleanup ----------------
if analogMode
    release(player);
end

flush(s);

%% ---------------- Ringbuffer Helper ----------------
function [buf, idx] = ringbuffer_write(buf, data, idx)
    L = numel(buf);
    n = numel(data);
    if idx+n-1 <= L
        buf(idx:idx+n-1) = data;
        idx = mod(idx+n-1, L)+1;
    else
        firstPart = L-idx+1;
        buf(idx:end) = data(1:firstPart);
        buf(1:n-firstPart) = data(firstPart+1:end);
        idx = n-firstPart+1;
    end
end

function linear = ringbuffer_linearize(buf, idx, len)
    linear = [buf(idx:end); buf(1:idx-1)];
    if numel(linear) < len
        linear = [linear; zeros(len-numel(linear),1)];
    else
        linear = linear(1:len);
    end
end

%% ---------------- FIFO Helper ----------------
function serialCallback(src, ~, BLOCK_SIZE)
    raw = read(src, BLOCK_SIZE*2, 'int16');
    if isempty(raw)
        return;
    end
    dataI = raw(1:2:end);
    dataQ = raw(2:2:end);
    fifo_push(src, dataI, dataQ);
end

function fifo_push(sobj, dataI, dataQ)
    ud = sobj.UserData;
    n = numel(dataI);
    if n == 0
        return;
    end
    tries = 0;
    while ud.lock && tries < 5
        pause(0.0005);
        ud = sobj.UserData;
        tries = tries + 1;
    end
    ud.lock = true;
    capacity = numel(ud.fifoI);
    free = capacity - double(ud.count);
    if free < n
        drop = n - free;
        ud.readPos = mod(double(ud.readPos-1+drop), capacity)+1;
        ud.count = max(0, double(ud.count)-drop);
    end
    wp = double(ud.writePos);
    if wp+n-1 <= capacity
        ud.fifoI(wp:wp+n-1) = dataI;
        ud.fifoQ(wp:wp+n-1) = dataQ;
        wp = wp+n;
    else
        firstPart = capacity-wp+1;
        ud.fifoI(wp:end) = dataI(1:firstPart);
        ud.fifoQ(wp:end) = dataQ(1:firstPart);
        secondPart = n-firstPart;
        ud.fifoI(1:secondPart) = dataI(firstPart+1:end);
        ud.fifoQ(1:secondPart) = dataQ(firstPart+1:end);
        wp = secondPart+1;
    end
    ud.writePos = mod(wp-1, capacity)+1;
    ud.count = ud.count + n;
    ud.lock = false;
    sobj.UserData = ud;
end

function [dataI, dataQ] = fifo_pop(sobj, n)
    ud = sobj.UserData;
    capacity = numel(ud.fifoI);
    n = min(n, double(ud.count));
    if n == 0
        dataI = zeros(0,1,'int16');
        dataQ = zeros(0,1,'int16');
        return;
    end
    tries = 0;
    while ud.lock && tries < 5
        pause(0.0005);
        ud = sobj.UserData;
        tries = tries + 1;
    end
    ud.lock = true;
    rp = double(ud.readPos);
    if rp+n-1 <= capacity
        dataI = ud.fifoI(rp:rp+n-1);
        dataQ = ud.fifoQ(rp:rp+n-1);
        rp = rp+n;
    else
        firstPart = capacity-rp+1;
        dataI = [ud.fifoI(rp:end); ud.fifoI(1:n-firstPart)];
        dataQ = [ud.fifoQ(rp:end); ud.fifoQ(1:n-firstPart)];
        rp = n-firstPart+1;
    end
    ud.readPos = mod(rp-1, capacity)+1;
    ud.count = ud.count - n;
    ud.lock = false;
    sobj.UserData = ud;
end


