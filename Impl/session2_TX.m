%% =====================================================================
%  Session 2 — TX side
%  Generates a QPSK frame with leading pilot symbols, saves all the
%  parameters and the TX bits to tx_params.mat (so that the RX instance
%  can demodulate and compute the BER), then transmits the frame
%  continuously through the USRP B210.
% =====================================================================
clc;
clear;
close all;

%% Make the helper functions visible (raised_cosine, mapping_QAM, ...)
addpath( fullfile( pwd , 'Livescript 1' ) ) ;
addpath( fullfile( pwd , 'Livescript 3' ) ) ;

%% Communication parameters
nb_data         = 200 ;            % Number of data symbols per frame
nb_pilot        = 50 ;              % Number of pilot symbols per frame
nb_bit_per_symb = 4 ;               % Bits per symbol (16-QAM)
rolloff         = 0.5 ;             % RRC roll-off factor
symb_rate       = 100e3 ;             % Symbol rate (Hz) — keep symb_rate*sps in [5;56] MHz
sps             = 200 ;               % Samples per symbol (oversampling)
span            = 32 ;              % RRC filter span (in symbols)

fc              = 5.2e9 ;           % Carrier frequency (Hz) — ISM band for over-the-air tests
g_tx            = 30 ;              % USRP TX gain (dB)

% Derived
nb_bit = nb_data * nb_bit_per_symb ;
fs     = symb_rate * sps ;          % Sampling frequency (Hz)

%% Pulse-shaping filter
g = raised_cosine( rolloff , span , sps , 'sqrt' ) ;

%% Pilot symbols (random sequence, known to RX through tx_params.mat)
bit_pilot   = randi( [0 1] , nb_pilot * nb_bit_per_symb , 1 ) ;
symb_pilot  = mapping_QAM( bit_pilot , nb_bit_per_symb , length( bit_pilot ) ) ;

%% Data symbols
bit_TX_data  = randi( [0 1] , nb_bit , 1 ) ;
symb_TX_data = mapping_QAM( bit_TX_data , nb_bit_per_symb , nb_bit ) ;

%% Frame: pilots first, then data
symb_TX = [ symb_pilot ; symb_TX_data ] ;

%% Pulse shaping
signal_TX = convolution_TX( symb_TX , g , sps ) ;

%% Normalise to [-1 ; +1] to avoid DAC clipping in the USRP
signal_TX = signal_TX / max( abs( [ real( signal_TX ) ; imag( signal_TX ) ] ) ) ;

%% USRP upload constraint (see useful_functions.m)
if length( signal_TX ) > 30500
    warning( 'signal_TX length (%d) exceeds 30500 samples — USRP upload will be slow.' , ...
             length( signal_TX ) ) ;
end

%% Baseband spectrum plot (used to verify against the analyzer)
N_fft = 2^nextpow2( 16 * length( signal_TX ) ) ;
f     = linspace( -fs/2 , fs/2 , N_fft ) ;

figure
plot( f * 1e-6 , 20 * log10( abs( fftshift( fft( signal_TX , N_fft ) ) ) ) )
grid on
xlabel( 'Frequency [MHz]' )
ylabel( '|X_{L}(f)| [dB]' )
title( 'TX baseband spectrum (Session 2)' )

%% Save everything the RX needs (parameters + reference signal + TX bits)
%
% The RX instance loads this file to:
%   - reproduce the exact same RX filter (rolloff, span, sps),
%   - know the pilot symbols for channel estimation,
%   - know the original TX bits to compute the BER,
%   - compare against signal_TX through xcorr in syncfun.
save( 'tx_params.mat' , ...
      'fc' , 'fs' , 'sps' , 'symb_rate' , 'rolloff' , 'span' , ...
      'nb_pilot' , 'nb_data' , 'nb_bit_per_symb' , 'nb_bit' , ...
      'symb_pilot' , 'symb_TX' , 'bit_TX_data' , 'signal_TX' ) ;

fprintf( 'tx_params.mat written (%d samples per frame).\n' , length( signal_TX ) ) ;

%% USRP TX configuration
tx = comm.SDRuTransmitter( ...
        'Platform'              , 'B210'      , ...
        'SerialNum'             , '31FE776'   , ...
        'CenterFrequency'       , fc          , ...
        'ChannelMapping'        , 1           , ...
        'LocalOscillatorOffset' , 20e3        , ...
        'Gain'                  , g_tx        , ...
        'PPSSource'             , 'Internal'  , ...
        'ClockSource'           , 'External'  , ...
        'MasterClockRate'       , fs          , ...
        'InterpolationFactor'   , 1           , ...
        'TransportDataType'     , 'int16'     , ...
        'EnableBurstMode'       , 0             ...
        ) ;

%% Continuous transmission
disp( 'Transmitting... press Ctrl+C to stop, then run release(tx).' ) ;
while true
    tx( signal_TX ) ;
end
