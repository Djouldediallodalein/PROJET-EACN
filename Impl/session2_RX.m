%% =====================================================================
%  Session 2 — RX side
%  Receives the frame produced by session2_TX.m, synchronises it,
%  estimates the channel from the pilot symbols, equalises the data
%  symbols, plots the live constellation and (optionally) measures the
%  average BER over a finite number of frames.
%
%  Two modes are available, selected through the variable RX_MODE below:
%      'live'  — infinite loop with live spectrum + constellation
%                  (no BER, used for visual validation)
%      'ber'   — finite number of frames, store everything, then
%                  demodulate and compute the average BER
% =====================================================================
clc;
clear;
close all;

%% Paths to the helper functions
addpath( fullfile( pwd , 'Livescript 1' ) ) ;     % biterr, demapping_QAM, symbol_estimation_QAM
addpath( fullfile( pwd , 'Livescript 3' ) ) ;     % convolution_RX, raised_cosine
addpath( fullfile( pwd , '..' , 'Mesures' ) ) ;   % syncfun

%% Mode: 'live' (continuous display) or 'ber' (finite frames + BER)
RX_MODE   = 'live' ;        % 'live' | 'ber'
nb_frame  = 50 ;            % only used in 'ber' mode

%% Receiver-only parameters
g_rx = 76 ;                 % USRP RX gain (dB) — start moderate

%% Load every parameter and reference produced by session2_TX.m
if ~isfile( 'tx_params.mat' )
    error( 'tx_params.mat not found. Run session2_TX.m first.' ) ;
end
load( 'tx_params.mat' ) ;
fprintf( 'tx_params.mat loaded — frame length = %d samples.\n' , length( signal_TX ) ) ;

%% Recreate the matched RRC filter (same parameters as TX)
g = raised_cosine( rolloff , span , sps , 'sqrt' ) ;

%% Configure the RX USRP — record twice the TX frame length so we are
%  guaranteed to capture at least one full frame whatever the start delay.
nb_pt_ac = 2 * length( signal_TX ) ;

rx = comm.SDRuReceiver( ...
        'Platform'              , 'B210'      , ...
        'SerialNum'             , '3241A58'   , ...   % adapt for the RX device
        'CenterFrequency'       , fc          , ...
        'ChannelMapping'        , 1           , ...
        'LocalOscillatorOffset' , 20e3        , ...
        'Gain'                  , g_rx        , ...
        'PPSSource'             , 'Internal'  , ...
        'ClockSource'           , 'External'  , ...
        'MasterClockRate'       , fs          , ...
        'TransportDataType'     , 'int16'     , ...
        'DecimationFactor'      , 1           , ...
        'SamplesPerFrame'       , nb_pt_ac    , ...
        'EnableBurstMode'       , 0             ...
        ) ;

%% Pre-allocate the live figures (updated in place every iteration)
fig_spec  = figure( 'Name' , 'RX spectrum'    ) ;
ax_spec   = axes( 'Parent' , fig_spec ) ; grid( ax_spec , 'on' ) ;
xlabel( ax_spec , 'Frequency [MHz]' ) ; ylabel( ax_spec , '|Y_L(f)| [dB]' ) ;
title( ax_spec , 'RX baseband spectrum' ) ;

fig_const = figure( 'Name' , 'RX constellation' ) ;
ax_const  = axes( 'Parent' , fig_const ) ; hold( ax_const , 'on' ) ; grid( ax_const , 'on' ) ;
xlabel( ax_const , 'I' ) ; ylabel( ax_const , 'Q' ) ;
title( ax_const , 'RX constellation' ) ;
axis( ax_const , 'equal' ) ;

% Time-domain view of the (raw, un-synchronised) received signal
fig_time = figure( 'Name' , 'RX time-domain' ) ;
ax_timeI = subplot( 2 , 1 , 1 , 'Parent' , fig_time ) ; grid( ax_timeI , 'on' ) ;
xlabel( ax_timeI , 'Time [µs]' ) ; ylabel( ax_timeI , 'I component' ) ;
title( ax_timeI , 'RX signal — I (real part)' ) ;
ax_timeQ = subplot( 2 , 1 , 2 , 'Parent' , fig_time ) ; grid( ax_timeQ , 'on' ) ;
xlabel( ax_timeQ , 'Time [µs]' ) ; ylabel( ax_timeQ , 'Q component' ) ;
title( ax_timeQ , 'RX signal — Q (imag part)' ) ;

%% Optional storage when running in 'ber' mode
ber_per_frame = zeros( 1 , nb_frame ) ;
loop_count    = 0 ;
keep_running  = true ;

%% =====================================================================
%  Main reception loop
% =====================================================================
disp( 'Receiving...  press Ctrl+C in live mode, or wait for ber mode.' ) ;
while keep_running

    %% --- 1. Capture one buffer (= 2 frames worth of samples) ---------
    signal_RX = double( step( rx ) ) ;

    %% --- 2. Coarse time synchronisation against the known TX signal --
    % syncfun crops signal_RX to the same length as signal_TX, aligned
    % on the cross-correlation peak.
    signal_RX_sync = syncfun( signal_RX , signal_TX , fs ) ;

    %% --- 3. RX matched filter + sampling at symbol rate ---------------
    symb_RX = convolution_RX( signal_RX_sync , g , sps ) ;
    % Remove the transient introduced by the TX and RX RRC filters
    symb_RX = symb_RX( span + 1 : end - span ) ;
   
    %% --- 4. Channel estimation from the pilots (LS, then averaging) --
    H_estim    = symb_RX( 1 : nb_pilot ) ./ symb_pilot ;
    h_estim_av = mean( H_estim ) ;

    %% --- 5. Equalisation of the data symbols ------------------------
    symb_RX_data    = symb_RX( nb_pilot + 1 : end ) ;
    symb_RX_data_EQ = symb_RX_data / h_estim_av ;

    %% --- 6. Live displays --------------------------------------------
    % Time-domain view of the raw RX buffer (before any processing)
    t_us = ( 0 : length( signal_RX ) - 1 ).' / fs * 1e6 ;
    plot( ax_timeI , t_us , real( signal_RX ) ) ;
    grid( ax_timeI , 'on' ) ;
    xlabel( ax_timeI , 'Time [µs]' ) ; ylabel( ax_timeI , 'I component' ) ;
    title( ax_timeI , 'RX signal — I (real part)' ) ;
    plot( ax_timeQ , t_us , imag( signal_RX ) ) ;
    grid( ax_timeQ , 'on' ) ;
    xlabel( ax_timeQ , 'Time [µs]' ) ; ylabel( ax_timeQ , 'Q component' ) ;
    title( ax_timeQ , 'RX signal — Q (imag part)' ) ;

    % Spectrum
    N_fft = 2^nextpow2( 16 * length( signal_RX_sync ) ) ;
    f     = linspace( -fs/2 , fs/2 , N_fft ) ;
    plot( ax_spec , f * 1e-6 , ...
          20 * log10( abs( fftshift( fft( signal_RX_sync , N_fft ) ) ) ) ) ;
    grid( ax_spec , 'on' ) ;

    % Constellation (overwrite the previous one)
    cla( ax_const ) ;
    %plot( ax_const , real( symb_RX_data    ) , imag( symb_RX_data    ) , 'o'  , 'Color' , [.6 .6 .9] ) ;
    plot( ax_const , real( symb_RX_data_EQ ) , imag( symb_RX_data_EQ ) , 'og' ) ;
    plot( ax_const , real( symb_TX( nb_pilot+1 : end ) ) , ...
                     imag( symb_TX( nb_pilot+1 : end ) ) , ...
                     '+r' , 'MarkerSize' , 12 , 'LineWidth' , 2 ) ;
    legend( ax_const ,  'RX equalized' , 'TX reference' , ...
            'Location' , 'best' ) ;
    drawnow ;

    %% --- 7. BER (only when running in 'ber' mode) --------------------
    if strcmpi( RX_MODE , 'ber' )
        symb_RX_data_estim = symbol_estimation_QAM( symb_RX_data_EQ , ...
                                                     nb_bit_per_symb , nb_data ) ;
        bit_RX_data        = demapping_QAM( symb_RX_data_estim , ...
                                             nb_bit_per_symb , nb_data ) ;
        [ ~ , ber_per_frame( loop_count + 1 ) ] = biterr( bit_TX_data , bit_RX_data ) ;
        fprintf( 'Frame %3d/%d — BER = %.3e\n' , ...
                 loop_count + 1 , nb_frame , ber_per_frame( loop_count + 1 ) ) ;
    end

    loop_count = loop_count + 1 ;
    if strcmpi( RX_MODE , 'ber' ) && loop_count >= nb_frame
        keep_running = false ;
    end
end

release( rx ) ;

%% =====================================================================
%  Post-processing for 'ber' mode
% =====================================================================
if strcmpi( RX_MODE , 'ber' )
    ber_avg = mean( ber_per_frame ) ;
    fprintf( '\nAverage BER over %d frames : %.3e\n' , nb_frame , ber_avg ) ;

    figure
    semilogy( 1 : nb_frame , max( ber_per_frame , 1e-6 ) , '-o' )
    grid on
    xlabel( 'Frame index' )
    ylabel( 'BER' )
    title( sprintf( 'BER per frame (avg = %.3e)' , ber_avg ) )
end
