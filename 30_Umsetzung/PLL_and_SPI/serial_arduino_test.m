% ADF4350_Test.m
% MATLAB Script to test Arduino Due ADF4350 PLL control over Serial

clear; clc; close all;

% === Serial Port Config ===
port = "COM5";        % COM-Port anpassen falls nötig
baud = 115200;        % gleiche Baudrate wie Arduino Serial.begin()
timeout = 2;          % Timeout (seconds)

% === Verbindung öffnen ===
disp("Verbinde zum Arduino auf " + port + " ...");
s = serialport(port, baud, "Timeout", timeout);

% Kleine Pause zur Initialisierung
pause(2);

% === Funktion zum Senden & Empfangen ===
sendFreq = @(f) sendCommand(s, f);

% ===== TESTMESSUNGEN =====
frequencies = [2400, 2645, 300, 1800, 4400];
for f = frequencies
    sendFreq(f);
    pause(10); % PLL settle time
end

disp(" Test abgeschlossen!");

% === Verbindung schließen ===
clear s;


%% Hilfsfunktion zum Senden/Empfangen
function sendCommand(s, freqHz)
    cmd = "F= " + num2str(freqHz) + newline;
    write(s, cmd, "char");
    pause(0.2);

    % empfangene Daten lesen (falls Debug an Arduino)
    while s.NumBytesAvailable > 0
        resp = readline(s);
        disp("Arduino: " + resp);
    end

    fprintf("MATLAB: Frequenz gesetzt: %.3f GHz\n", freqHz/1e3);
end
