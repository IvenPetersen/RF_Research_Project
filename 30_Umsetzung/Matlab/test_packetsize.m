%% --- USB-Paket-Monitor für Arduino ---
port = "COM14";          % COM-Port anpassen
baud = 2000000;          % USB-Baudrate
BLOCK_SIZE = 1024;       % Arduino Blockgröße
NUM_PACKETS = 100;       % Anzahl Pakete zum Testen

% --- Serielle Verbindung ---
s = serialport(port, baud);
flush(s);

fprintf('Starte Paket-Monitor...\n');

% --- Speicher für Timing und Größe ---
packetSizes = zeros(NUM_PACKETS,1);
packetTimes = zeros(NUM_PACKETS,1);

lastTime = tic;

for k = 1:NUM_PACKETS
    % Warten, bis genug Bytes verfügbar sind
    while s.NumBytesAvailable < BLOCK_SIZE*2
        pause(0.001);
    end
    
    % Paket lesen
    block = read(s, BLOCK_SIZE, "uint16");
    packetSizes(k) = length(block);
    
    % Zeit seit letztem Paket
    packetTimes(k) = toc(lastTime);
    lastTime = tic;
    
    fprintf('Paket %3d | Größe: %4d Samples | Delta t: %.4f s\n', ...
        k, packetSizes(k), packetTimes(k));
end

disp('Paket-Monitor beendet.');
flush(s);
