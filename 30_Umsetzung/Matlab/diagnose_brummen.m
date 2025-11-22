function diagnose_brummen()
%% ======================================================
% Test: Prüfen auf Sample-Dropouts via 16-bit Counter
%% ======================================================

fsADC       = 48000;
blockSize   = 1024;
baudRate    = 115200;
comPort     = "COM9";
bytesPerSample = 2;

%% Serielle Verbindung öffnen
try
    arduinoPort = serialport(comPort, baudRate);
    flush(arduinoPort);
catch
    error("Kann den COM-Port nicht öffnen.");
end

disp("Empfang läuft...  (Beende mit CTRL+C)");

%% Persistent Variablen vorbereiten
persistent lastCounter;
lastCounter = [];

%% Hauptschleife
while true

    % Warten bis Block verfügbar ist
    if arduinoPort.NumBytesAvailable < blockSize * bytesPerSample
        pause(0.0005);
        continue;
    end

    % Block lesen
    rawData = read(arduinoPort, blockSize * bytesPerSample, "uint8");
    adcSamples = typecast(uint8(rawData), "uint16");

    % Dropout-Analyse
    if isempty(lastCounter)
        lastCounter = adcSamples(end);
        continue;
    end

    diffs = mod(adcSamples - lastCounter, 65536);
    jumps = diffs ~= 1;

    if any(jumps)
        fprintf("‼ DROP: %d Fehler im aktuellen Block\n", sum(jumps));
    end

    lastCounter = adcSamples(end);
end

end
