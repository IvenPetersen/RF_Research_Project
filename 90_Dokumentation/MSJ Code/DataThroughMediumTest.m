clear all;
close all;
clc;

% === PARAMETER ===
fs = 32000;               % Abtastrate in Hz – wie oft pro Sekunde ein Sample erzeugt wird
frameSize = 1024;         % Anzahl der Samples pro Verarbeitungsblock (Frame)
duration = 5;             % Dauer der Übertragung in Sekunden
frequency = 1000;         % Frequenz des Testsignals (1 kHz Sinus)

v_amp = 2;                % Ziel-Amplitude des analogen Signals in V (Spitze)

% === MAXIMALE HARDWARE-SPANNUNG (gemäß Behringer UCA222) ===
V_rms_max = 1.26;                       % 2 dBV entspricht 1.26 V Effektivwert (RMS)
V_amp_max = V_rms_max * sqrt(2);       % Umrechnung in Spitzenwert ≈ 1.78 V

% === DIGITALES TESTSIGNAL ERZEUGEN ===
% Der Sinus wird auf [-1,1] skaliert, wobei "1" der maximalen Ausgangsspannung entspricht.
% Für eine reale Amplitude von v_amp musst du den Sinus entsprechend hochskalieren:
%   digital = (physikalisch / max. physikalisch) * sin(...)
signal_norm = (v_amp / V_amp_max) * sin(2 * pi * frequency * (0:frameSize-1)' / fs);

% === AUDIO-GERÄTE EINRICHTEN ===
% Die Gerätenamen müssen exakt so angegeben werden, wie sie im audiodevinfo auftauchen.
outputName = "Lautsprecher (USB Audio CODEC )";   % Name deines Behringer-Ausgangs
inputName  = "Mikrofon (USB Audio CODEC )";       % Name deines Behringer-Eingangs

% AUDIOAUSGABEGERÄT
deviceWriter = audioDeviceWriter( ...
    'SampleRate', fs, ...          % Abtastrate in Hz
    'Device', outputName);         % Ausgabegerät auswählen

% AUDIOAUFNAHMEGERÄT
deviceReader = audioDeviceReader( ...
    'SampleRate', fs, ...          % gleiche Abtastrate wie Writer
    'SamplesPerFrame', frameSize, ...  % Blockgröße pro Aufnahme
    'Device', inputName);              % Eingabegerät auswählen

% === SPEICHER FÜR GESAMTEN SIGNALVERLAUF ===
numFrames = floor(duration * fs / frameSize);  % Anzahl der Blöcke insgesamt
output_log = zeros(numFrames * frameSize, 1);  % Speicher für gesendetes Signal
input_log  = zeros(numFrames * frameSize, 1);  % Speicher für empfangenes Signal

% === LIVE-PLOTTING VORBEREITEN ===
figure;
subplot(2,1,1);
h1 = plot(NaN, NaN); 
title('Ausgangssignal'); 
xlabel('Zeit (s)'); 
ylabel('Amplitude [V]');

subplot(2,1,2);
h2 = plot(NaN, NaN); 
title('Eingangssignal'); 
xlabel('Zeit (s)'); 
ylabel('Amplitude [V]');

% === HAUPTSCHLEIFE: AUSGEBEN UND EINLESEN ===
disp('Starte Übertragung...');
for k = 1:numFrames
    % ► Signalblock ausgeben (Audio-Ausgabe erfolgt kontinuierlich frameweise)
    deviceWriter(signal_norm);  % digitaler Signalwert in [-1,1]
    output_log((k-1)*frameSize+1:k*frameSize) = signal_norm;

    % ► Signalblock einlesen (gleichzeitig erfolgt Sampling vom Eingang)
    audioIn = deviceReader();
    input_log((k-1)*frameSize+1:k*frameSize) = audioIn;

    % ► Live-Anzeige aktualisieren (z. B. alle 10 Frames)
    if mod(k,10) == 0
        time_plot = (0:length(signal_norm)-1)/fs;
        set(h1, 'XData', time_plot, 'YData', signal_norm * V_amp_max);  % physikalischer Wert
        set(h2, 'XData', time_plot, 'YData', audioIn * V_amp_max);      % physikalischer Wert
        drawnow;
    end
end
disp('Übertragung beendet.');

% === AUDIOGERÄTE FREIGEBEN (wichtig!) ===
release(deviceWriter);
release(deviceReader);

% === AMPLITUDEN BESTIMMEN (reale Spannung in V berechnen)
% Die Eingabe/Ausgabe ist normiert auf [-1,1], deshalb zurückskalieren:
max_out = max(abs(output_log)) * V_amp_max;  % physikalische Ausgangsamplitude
max_in  = max(abs(input_log))  * V_amp_max;  % physikalische Eingangsamplitude

fprintf('\n--- Ergebnisse ---\n');
fprintf('Gewünschte Ausgangsamplitude: %.2f V\n', v_amp);
fprintf('Tatsächlich ausgegeben:       %.3f V (Peak)\n', max_out);
fprintf('Tatsächlich eingelesen:       %.3f V (Peak)\n', max_in);

% === GESAMTEN SIGNALVERLAUF ZEICHNEN ===
t_total = (0:length(input_log)-1)' / fs;

figure;
subplot(2,1,1);
plot(t_total, output_log * V_amp_max);  % skalieren auf physikalische Volt
title('Ausgabeverlauf (physikalisch)');
xlabel('Zeit (s)');
ylabel('Amplitude [V]');

subplot(2,1,2);
plot(t_total, input_log * V_amp_max);   % ebenfalls skalieren
title('Eingabeverlauf (physikalisch)');
xlabel('Zeit (s)');
ylabel('Amplitude [V]');