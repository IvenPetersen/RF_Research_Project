clear;
arduinoPort = "/dev/tty.usbmodem2021401";
baudRate   = 230400;
frameSize  = 64;                        % etwas größer, glattere Übergänge
fsTarget   = 42e6 / (2 * 420);          % z. B. 50 kHz DAC-Rate
sinFreq0   = 1e2;                      % Sinusfrequenz
sinFreq1   = 1e2;

s = serialport(arduinoPort, baudRate);
configureTerminator(s, 'LF');

% --- Phasenschritt pro Sample ---
phaseInc0 = 2*pi*sinFreq0/fsTarget;
phaseInc1 = 2*pi*sinFreq1/fsTarget;

% --- Initialisierung ---
phase0 = 0;
phase1 = 0;
idx = (0:frameSize-1)';

% --- Speicher vorbereiten ---
data0 = zeros(frameSize,1,'uint8');
data1 = zeros(frameSize,1,'uint8');
interleaved = zeros(2*frameSize,1,'uint8');

disp("Starte glatten Sinus-Stream...");

while true
    % Laufende Phase pro Frame berechnen
    phaseVec0 = phase0 + phaseInc0 * idx;
    phaseVec1 = phase1 + phaseInc1 * idx;

    % Update Phase (kontinuierlich)
    phase0 = mod(phaseVec0(end) + phaseInc0, 2*pi);
    phase1 = mod(phaseVec1(end) + phaseInc1, 2*pi);

    % 8-bit DAC-Werte berechnen
    data0 = uint8(127 + 127*sin(phaseVec0));
    data1 = uint8(127 + 127*sin(phaseVec1));

    % Interleaved packen (DAC0, DAC1, DAC0, DAC1, ...)
    interleaved(1:2:end) = data0;
    interleaved(2:2:end) = data1;

    % Schreiben + Handshake vom Arduino abwarten
    write(s, interleaved, "uint8");
    %read(s, 1, "uint8");  % wartet auf 'R'
end
