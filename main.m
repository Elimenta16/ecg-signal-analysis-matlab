%% ECG Signal Analysis
% Educational MATLAB project for ECG signal processing and visualization.
%
% Features:
% - Band-pass filtering
% - R-peak and PQRST delineation
% - Heart-rate and HRV metrics (SDNN and RMSSD)
%
% Data source: PhysioNet
% Disclaimer: Educational use only. Not intended for clinical diagnosis.

clear;
clc;
close all;

%% Configuration
recordName = 'x0010';
channel = 10;
duration = 60;       % Analysis duration in seconds
displayWindow = 10;  % PQRST plot window in seconds

%% Load ECG data
[signal, Fs, tm] = rdsamp(recordName);

fprintf('\n========================================\n');
fprintf('           ECG SIGNAL ANALYSIS\n');
fprintf('========================================\n\n');
fprintf('Sampling frequency : %.0f Hz\n', Fs);
fprintf('Number of samples  : %d\n', size(signal, 1));
fprintf('Number of channels : %d\n', size(signal, 2));
fprintf('Selected channel   : %d\n', channel);
fprintf('Analysis duration  : %.0f seconds\n', duration);

%% Process ECG signal
results = processECG(signal, Fs, tm, channel, duration);

ecg = results.ecg;
ecgFiltered = results.ecg_filtered;
time = results.time;
peaks = results.peaks;
locations = results.locations;
rrIntervals = results.rr_intervals;
heartRate = results.heart_rate;
meanHeartRate = results.mean_heart_rate;
sdnn = results.sdnn;
rmssd = results.rmssd;
meanSTShift = results.mean_st_shift;

%% Signal statistics
fprintf('\n===== SIGNAL STATISTICS =====\n');
fprintf('Mean amplitude    : %.4f mV\n', mean(ecg));
fprintf('Standard deviation: %.4f mV\n', std(ecg));
fprintf('Maximum amplitude : %.4f mV\n', max(ecg));
fprintf('Minimum amplitude : %.4f mV\n', min(ecg));

%% Heart rate and HRV summary
fprintf('\n===== HEART RATE AND HRV =====\n');
fprintf('Detected R-peaks  : %d\n', numel(peaks));
fprintf('Mean heart rate   : %.2f BPM\n', meanHeartRate);
fprintf('Minimum heart rate: %.2f BPM\n', min(heartRate));
fprintf('Maximum heart rate: %.2f BPM\n', max(heartRate));
fprintf('SDNN              : %.2f ms\n', sdnn);
fprintf('RMSSD             : %.2f ms\n', rmssd);
fprintf('Mean ST shift     : %.3f mV\n', meanSTShift);

if meanSTShift > 0.10
    fprintf('Educational ST indicator: possible elevation (> 0.1 mV)\n');
elseif meanSTShift < -0.10
    fprintf('Educational ST indicator: possible depression (< -0.1 mV)\n');
else
    fprintf('Educational ST indicator: no relevant deviation detected\n');
end

%% Figure 1: Original versus filtered ECG
samplesToPlot = min(round(5 * Fs), numel(time));

figure('Name', 'Filtering Comparison', 'Color', 'w');

plot(time(1:samplesToPlot), ecg(1:samplesToPlot), 'LineWidth', 1);
hold on;

plot(time(1:samplesToPlot), ecgFiltered(1:samplesToPlot), ...
    'LineWidth', 1.2);

grid on;
xlabel('Time (s)');
ylabel('Amplitude (mV)');
title('Original vs. Filtered ECG Signal');
legend('Original', 'Filtered', 'Location', 'best');
xlim([0 min(5, duration)]);
hold off;

%% Figure 2: PQRST delineation
figure('Name', 'PQRST Delineation', 'Color', 'w');

plot(time, ecgFiltered, 'Color', [0.2 0.2 0.2], 'LineWidth', 1);
hold on;

plot(time(locations), ecgFiltered(locations), ...
    'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 5);

plot(time(results.p_locs), ecgFiltered(results.p_locs), ...
    'bs', 'MarkerFaceColor', 'b', 'MarkerSize', 4);

plot(time(results.q_locs), ecgFiltered(results.q_locs), ...
    'mv', 'MarkerFaceColor', 'm', 'MarkerSize', 4);

plot(time(results.s_locs), ecgFiltered(results.s_locs), ...
    'k^', 'MarkerFaceColor', 'k', 'MarkerSize', 4);

plot(time(results.t_locs), ecgFiltered(results.t_locs), ...
    'gd', 'MarkerFaceColor', 'g', 'MarkerSize', 4);

grid on;
xlabel('Time (s)');
ylabel('Amplitude (mV)');
title('PQRST Wave Delineation');
legend('Filtered ECG', 'R-peaks', 'P-waves', 'Q-waves', ...
    'S-waves', 'T-waves', 'NumColumns', 3, 'Location', 'best');

xlim([0 min(displayWindow, duration)]);
hold off;

%% Figure 3: RR intervals and instantaneous heart rate
figure('Name', 'Heart Rate Profile', 'Color', 'w');

subplot(2, 1, 1);

plot(rrIntervals, 'o-', ...
    'Color', [0.15 0.45 0.75], ...
    'LineWidth', 1.2, ...
    'MarkerSize', 4);

grid on;
xlabel('Beat number');
ylabel('RR interval (s)');
title('RR Intervals per Beat');

subplot(2, 1, 2);

plot(heartRate, 'o-', ...
    'Color', [0.85 0.25 0.2], ...
    'LineWidth', 1.2, ...
    'MarkerSize', 4);

grid on;
yline(60, '--k', 'Bradycardia threshold (60 BPM)');
yline(100, '--r', 'Tachycardia threshold (100 BPM)');
xlabel('Beat number');
ylabel('Heart rate (BPM)');
title('Instantaneous Heart Rate per Beat');

%% Final message
fprintf('\n========================================\n');
fprintf('      ECG ANALYSIS COMPLETED\n');
fprintf('========================================\n');