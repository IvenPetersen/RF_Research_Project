clear; close all; clc

Fsa = 48e3;
Tsa = 1 / Fsa;

rolloff = 0.8;           % Rolloff-Faktor
span = 10;               % Filterlänge in Symbolen
sps = 50;                % Samples pro Symbol

coeffs = rcosdesign(rolloff, span, sps);

data = [(1+1i) -1 (1-1i) -1 1 1 1 -1 1 -1 (1+1i) -1 (1-1i) -1 1 1 1 -1 1 -1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];

N = length(data)*sps;        % Anzahl der gesamten Samples

input = upsample(data, sps);

buffer_I = zeros(1, length(coeffs));
buffer_Q = zeros(1, length(coeffs));

pulsed_I = zeros(1, length(coeffs));
pulsed_Q = zeros(1, length(coeffs));

for i = 1:N

    buffer_I = circshift(buffer_I, 1);
    buffer_Q = circshift(buffer_Q, 1);

    buffer_I(1) = real(input(i));
    buffer_Q(1) = imag(input(i));
    
    pulsed_I(i) = sum(buffer_I .* coeffs);
    pulsed_Q(i) = sum(buffer_Q .* coeffs);
end

figure;
subplot(1,2,1);
plot(pulsed_I);
hold on;
stem(real(input));
hold off;
title("I - Data");
xlabel("Zeit t");
legend("Pulsgeformte Symbole", "Digitale Symbole");

subplot(1,2,2);
plot(pulsed_Q);
hold on;
stem(imag(input));
hold off;
title("Q - Data");
xlabel("Zeit t");
legend("Pulsgeformte Symbole", "Digitale Symbole");

%% Senden
fc = 10e3; 
t = (0:N-1)*Tsa; 
f = (-N/2:N/2-1)*Fsa/N;

signal = pulsed_I .* cos(2*pi*t) - pulsed_Q .* sin(2*pi*t);
hf = pulsed_I .* cos(2*pi*fc*t) - pulsed_Q .* sin(2*pi*fc*t);

SIGNAL = abs(fftshift(fft(signal)));
HF = abs(fftshift(fft(hf)));

figure;
sgtitle("Gesendetes Signal");

subplot(1,2,1);
plot(t,signal);
hold on;
plot(t,hf);
hold off;
xlabel("Zeit t");
title("Zeitsignal");
legend("TP-Signal", "BP-Signal");

subplot(1,2,2);
plot(f, SIGNAL);
hold on;
plot(f, HF);
hold off;
xlabel("Frequenz f");
title("Frequenzspektrum");
legend("TP-Signal", "BP-Signal");

%% Empfangen

SNR_dB = 0;  % z. B. 20 dB Signal-Rausch-Verhältnis
hf_noise = awgn(hf, SNR_dB, 'measured');

% Heruntermischen
rx_I = hf_noise .* cos(2*pi*fc*t);
rx_Q = - hf_noise .* sin(2*pi*fc*t);

rx = rx_I + rx_Q;

buffer_I = zeros(1, length(coeffs));
buffer_Q = zeros(1, length(coeffs));

matched_I = zeros(1, length(coeffs));
matched_Q = zeros(1, length(coeffs));

for i = 1:N

    buffer_I = circshift(buffer_I, 1);
    buffer_Q = circshift(buffer_Q, 1);

    buffer_I(1) = rx_I(i);
    buffer_Q(1) = rx_Q(i);
    
    matched_I(i) = sum(buffer_I .* coeffs);
    matched_Q(i) = sum(buffer_Q .* coeffs);
end

figure;
sgtitle("Empfangendes Signal");

subplot(1,3,1);
plot(t, rx);
xlabel("Zeit t");
title("Zeitsignal Heruntergemischt");

subplot(1,3,2);
plot(t, matched_I);
xlabel("Zeit t");
title("I - Zeitsignal Matched");

subplot(1,3,3);
plot(t, matched_Q);
xlabel("Zeit t");
title("Q - Zeitsignal Matched");