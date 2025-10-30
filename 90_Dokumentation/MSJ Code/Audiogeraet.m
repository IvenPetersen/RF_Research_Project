clear; close all; clc

%% Parameter

Fsa = 48e3;
Tsa = 1 / Fsa;

%% Filter
rolloff = 0.8;           % Rolloff-Faktor
span = 20;               % Filterlänge in Symbolen
sps = 50;                % Samples pro Symbol

coeffs = rcosdesign(rolloff, span, sps, 'sqrt');

data = [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ... 
    (1+1i) -1 (1-1i) -1 1 1 1 -1 1 -1 (1+1i) -1 (1-1i) -1 1 1 1 -1 1 -1 ...
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0];

N = length(data) * sps;        % Anzahl der gesamten Samples

input = upsample(data, sps);

%% Init. Interfaces
outputDevice = 'USB Audio CODEC :1';
inputDevice  = 'USB Audio CODEC :2';

reader = audioDeviceReader('SampleRate', Fsa, ...
                           'SamplesPerFrame', N, ...
                           'Device', inputDevice);

writer = audioDeviceWriter('SampleRate', Fsa, ...
                           'Device', outputDevice);

%% Faltung / Pulsformung

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



%% Senden
fc = 5e3;

t = (0:N-1)*Tsa; 
f = (-N/2:N/2-1)*Fsa/N;

signal = pulsed_I .* cos(2*pi*t) - pulsed_Q .* sin(2*pi*t);



hf = pulsed_I .* cos(2*pi*fc*t) - pulsed_Q .* sin(2*pi*fc*t);


figure(1);
subplot(2,3,1);
plot(t, hf);
title("Gesendetes BP - Signal");
xlabel("Zeit t");

subplot(2,3,2);
plot(t, pulsed_I);
title("Pulsed I - Signal");
xlabel("Zeit t");

subplot(2,3,3);
plot(t, pulsed_Q);
title("Puklsed Q - Signal");
xlabel("Zeit t");

disp('Wiedergabe und Aufnahme starten...');
tic;
writer(hf'); 

%% Empfangen

pause(0.09);

hf_noise = reader()'; 
pause(N * Tsa);            % Warten auf Abspielzeit
toc;

subplot(2,3,4);
plot(t, hf_noise);
title("Empfangendes BP - Signal");
xlabel("Zeit t");

% Heruntermischen
rx_I = hf_noise .* cos(2*pi*fc*t);
rx_Q = - hf_noise .* sin(2*pi*fc*t);

%rx = rx_I + rx_Q;

buffer_I_ = zeros(1, length(coeffs));
buffer_Q_ = zeros(1, length(coeffs));

matched_I = zeros(1, length(coeffs));
matched_Q = zeros(1, length(coeffs));

for i = 1:N

    buffer_I_ = circshift(buffer_I_, 1);
    buffer_Q_ = circshift(buffer_Q_, 1);

    buffer_I_(1) = rx_I(i);
    buffer_Q_(1) = rx_Q(i);
    
    matched_I(i) = sum(buffer_I_ .* coeffs);
    matched_Q(i) = sum(buffer_Q_ .* coeffs);
end

subplot(2,3,5);
plot(t, matched_I);
title("Matched I - Signal");
xlabel("Zeit t");

subplot(2,3,6);
plot(t, matched_Q);
title("Matched Q - Signal");
xlabel("Zeit t");

%% Aufräumen
release(writer);
release(reader);
