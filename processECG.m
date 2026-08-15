function results = processECG(signal, Fs, tm, channel, duration)
%PROCESSECG Process a selected ECG channel and calculate signal metrics.
%
% Inputs:
%   signal   - Multichannel ECG signal
%   Fs       - Sampling frequency (Hz)
%   tm       - Time vector (s)
%   channel  - Selected ECG channel
%   duration - Analysis duration (s)
%
% Output:
%   results  - Structure containing filtered ECG, PQRST locations,
%              heart-rate metrics, HRV metrics, and ST-shift estimate.
%
% Educational use only. Not intended for clinical diagnosis.

    %% 1. Channel extraction and analysis window
    ecg_full = signal(:, channel);
    N = min(round(duration * Fs), numel(ecg_full));

    ecg = ecg_full(1:N);
    time = tm(1:N);

    %% 2. Zero-phase band-pass filter (0.5 Hz - 40 Hz)
    low_cutoff = 0.5;
    high_cutoff = 40;

    [bFilter, aFilter] = butter(3, ...
        [low_cutoff high_cutoff] / (Fs / 2), ...
        'bandpass');

    ecg_filtered = filtfilt(bFilter, aFilter, ecg);

    %% 3. Adaptive R-peak detection
    qrs_diff = [0; diff(ecg_filtered)];
    qrs_squared = qrs_diff .^ 2;

    window_len = round(0.12 * Fs);

    qrs_integrated = conv(qrs_squared, ...
        ones(window_len, 1) / window_len, ...
        'same');

    % Minimum peak distance: 200 ms (up to 300 BPM)
    min_dist = round(0.20 * Fs);

    window_seconds = 4;
    window_samples = round(window_seconds * Fs);
    num_windows = ceil(N / window_samples);

    % Preallocate one cell per analysis window
    locs_per_window = cell(num_windows, 1);

    for windowIndex = 1:num_windows
        idx_start = (windowIndex - 1) * window_samples + 1;
        idx_end = min(windowIndex * window_samples, N);

        segment = qrs_integrated(idx_start:idx_end);

        % Adaptive threshold: 18% of the local maximum
        local_thresh = 0.18 * max(segment);

        [~, locs_temp] = findpeaks(segment, ...
            'MinPeakHeight', local_thresh, ...
            'MinPeakDistance', min_dist);

        locs_per_window{windowIndex} = idx_start + locs_temp - 1;
    end

    % Combine detections from every analysis window
    locs_integrated = vertcat(locs_per_window{:});

    %% 4. Align R-peaks to local maxima in the filtered ECG
    num_beats = numel(locs_integrated);
    locations = zeros(num_beats, 1);
    search_window = round(0.06 * Fs);

    for beatIndex = 1:num_beats
        peakIndex = locs_integrated(beatIndex);

        start_idx = max(1, peakIndex - search_window);
        end_idx = min(N, peakIndex + search_window);

        [~, max_rel] = max(ecg_filtered(start_idx:end_idx));
        locations(beatIndex) = start_idx + max_rel - 1;
    end

    % Remove duplicate or excessively close R-peaks
    locations = unique(locations);

    if numel(locations) > 1
        valid_idx = [true; diff(locations) >= min_dist];
        locations = locations(valid_idx);
    end

    num_beats = numel(locations);
    peaks = ecg_filtered(locations);

    %% 5. PQRST delineation and ST-shift estimation
    q_locs = zeros(num_beats, 1);
    s_locs = zeros(num_beats, 1);
    p_locs = zeros(num_beats, 1);
    t_locs = zeros(num_beats, 1);
    st_shifts = zeros(num_beats, 1);

    st_offset = round(0.08 * Fs);

    for beatIndex = 1:num_beats
        r_i = locations(beatIndex);

        % Q and S waves
        q_start = max(1, r_i - round(0.05 * Fs));
        [~, rel_q] = min(ecg_filtered(q_start:r_i));
        q_locs(beatIndex) = q_start + rel_q - 1;

        s_end = min(N, r_i + round(0.05 * Fs));
        [~, rel_s] = min(ecg_filtered(r_i:s_end));
        s_locs(beatIndex) = r_i + rel_s - 1;

        % P wave: pre-QRS search window
        p_start = max(1, r_i - round(0.22 * Fs));
        p_end = max(1, r_i - round(0.06 * Fs));

        if p_start < p_end
            [~, rel_p] = max(ecg_filtered(p_start:p_end));
            p_locs(beatIndex) = p_start + rel_p - 1;
        else
            p_locs(beatIndex) = q_locs(beatIndex);
        end

        % T wave: post-S ST-T search window
        t_start = min(N, s_locs(beatIndex) + round(0.06 * Fs));
        t_end = min(N, s_locs(beatIndex) + round(0.35 * Fs));

        if beatIndex < num_beats
            % Avoid overlapping with the next beat's P wave
            t_end = min(t_end, ...
                max(t_start, locations(beatIndex + 1) - round(0.12 * Fs)));
        end

        if t_start < t_end && t_end <= N
            [~, rel_t] = max(ecg_filtered(t_start:t_end));
            t_locs(beatIndex) = t_start + rel_t - 1;
        else
            t_locs(beatIndex) = s_locs(beatIndex);
        end

        % ST deviation relative to the P-Q baseline
        baseline = mean(ecg_filtered( ...
            p_locs(beatIndex):q_locs(beatIndex)));

        st_point = min(N, s_locs(beatIndex) + st_offset);

        st_shifts(beatIndex) = ecg_filtered(st_point) - baseline;
    end

    %% 6. RR intervals, heart rate, and HRV metrics
    rr_intervals = diff(time(locations));
    rr_intervals_ms = rr_intervals * 1000;

    heart_rate = 60 ./ rr_intervals;
    mean_heart_rate = mean(heart_rate);

    sdnn = std(rr_intervals_ms);
    rmssd = sqrt(mean(diff(rr_intervals_ms) .^ 2));

    % Educational ST-shift indicator
    mean_st_shift = mean(st_shifts);

    %% 7. Package results
    results.ecg = ecg;
    results.ecg_filtered = ecg_filtered;
    results.time = time;

    results.peaks = peaks;
    results.locations = locations;

    results.q_locs = q_locs;
    results.s_locs = s_locs;
    results.p_locs = p_locs;
    results.t_locs = t_locs;

    results.rr_intervals = rr_intervals;
    results.heart_rate = heart_rate;
    results.mean_heart_rate = mean_heart_rate;

    results.sdnn = sdnn;
    results.rmssd = rmssd;
    results.mean_st_shift = mean_st_shift;
end 