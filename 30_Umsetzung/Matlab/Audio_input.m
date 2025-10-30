
fs = 44100; % Sampling frequency
duration = 0.3; % Duration of recording in seconds
recObj = audiorecorder(fs, 16, 1); % Create audiorecorder object
disp('Start speaking.')
recordblocking(recObj, duration); % Record audio
disp('End of recording.');

% Get the recorded audio data
audioData = getaudiodata(recObj);

% Compute the Fourier Transform of the audio data
n = length(audioData); % Length of the audio data
f = fs*(0:(n/2))/n; % Frequency range for the positive frequencies
Y = fft(audioData); % Compute the FFT
P2 = abs(Y/n); % Two-sided spectrum
P1 = P2(1:n/2+1); % Single-sided spectrum
P1(2:end-1) = 2*P1(2:end-1); % Adjust the amplitude

% Plot the normal spectrum
figure(1);
plot(f, P1);
title('Single-Sided Amplitude Spectrum of Recorded Audio');
xlabel('Frequency (f) [Hz]');
ylabel('|P1(f)|');
xlim([0 fs/2]); % Limit x-axis to half the sampling frequency
grid on;



hold on;
while true
    recordblocking(recObj, duration); % Record audio
    

    % Get the recorded audio data
    audioData = getaudiodata(recObj);
    

    Y = fft(audioData); % Compute the FFT
    P2 = abs(Y/n); % Two-sided spectrum
    P1 = P2(1:n/2+1); % Single-sided spectrum
    P1(2:end-1) = 2*P1(2:end-1); % Adjust the amplitud
    plot(f, P1);
   
end
