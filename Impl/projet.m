clc;
clear;
close all;

% =====================================================================
% Communication parameters
% =====================================================================
nb_data         = 2500 ;            % Number of data symbols per frame
nb_pilot        = 10 ;              % Number of pilot symbols per frame
nb_bit_per_symb = 4 ;               % Bits per symbol (16-QAM)
rolloff         = 0.5 ;             % RRC roll-off factor (fixed for T3.3 — chosen in T2)
symb_rate       = 5e6 ;             % Symbol rate (Hz) — sweep over [1, 5, 10, 15, 20, 25, 28] MHz for T3.3
sps             = 2 ;               % Samples per symbol (oversampling) — keep at 2 to enforce fs <= 56 MHz
span            = 32 ;              % RRC filter span (in symbols, fixed for T3.3 — chosen in T1)

fc              = 200e6 ;           % Carrier frequency (Hz)
g_tx            = 30 ;              % USRP TX gain (dB) — 0 to 89.75

% Derived
nb_bit = nb_data * nb_bit_per_symb ;
fs     = symb_rate * sps ;          % Must lie in [5e6 ; 56e6] for the B210 MasterClockRate

% =====================================================================
% TX baseband signal generation
% =====================================================================
g = raised_cosine( rolloff , span , sps , 'sqrt' ) ;

% Pilot symbols (random sequence, known to RX)
bit_pilot   = randi( [0 1] , nb_pilot * nb_bit_per_symb , 1 ) ;
symb_pilot  = mapping_QAM( bit_pilot , nb_bit_per_symb , length( bit_pilot ) ) ;

% Data symbols
bit_TX_data  = randi( [0 1] , nb_bit , 1 ) ;
symb_TX_data = mapping_QAM( bit_TX_data , nb_bit_per_symb , nb_bit ) ;

% Frame: pilots first, then data
symb_TX = [ symb_pilot ; symb_TX_data ] ;

% Pulse shaping (RRC) — produces the baseband waveform actually sent over the air
signal_TX = convolution_TX( symb_TX , g , sps ) ;

% Normalize to [-1 ; +1] to avoid DAC clipping in the USRP
signal_TX = signal_TX / max( abs( [ real( signal_TX ) ; imag( signal_TX ) ] ) ) ;

% USRP upload constraint (see useful_functions.m): keep frame under 30500 samples
if length( signal_TX ) > 30500
    warning( 'signal_TX length (%d) exceeds 30500 samples — USRP upload will be slow.' , length( signal_TX ) ) ;
end

% =====================================================================
% Baseband spectrum plot
% =====================================================================
% Zero-pad the FFT to get a smoother, higher-resolution spectrum
% (the time-domain signal is unchanged; we just evaluate the DTFT at more frequency bins)
N_fft = 2^nextpow2( 16 * length( signal_TX ) ) ;
f     = linspace( -fs/2 , fs/2 , N_fft ) ;

fig_spectrum = figure ;
plot( f * 1e-6 , 20 * log10( abs( fftshift( fft( signal_TX , N_fft ) ) ) ) )
grid on
xlabel( 'Frequency [MHz]' )
ylabel( '|X_{L}(f)| [dB]' )
title( 'TX baseband spectrum' )

% Save the figure for the report (filename encodes the key parameters and
% a timestamp, so successive runs are kept side by side)
timestamp = char( datetime( 'now' , 'Format' , 'ddMMyyyy_HHmmss' ) ) ;
fig_name  = sprintf( 'spectrum_sr%gMHz_span%d_ro%g_sps_gain%g_%d_%s' , ...
                     symb_rate/1e6 , span , rolloff , sps, g_tx , timestamp ) ;
exportgraphics( fig_spectrum , [ fig_name '.png' ] , 'Resolution' , 300 ) ;

% =====================================================================
% Save parameters and TX bits for the RX code (Session 2)
% =====================================================================
save( 'tx_params.mat' , ...
      'fc' , 'fs' , 'sps' , 'symb_rate' , 'rolloff' , 'span' , ...
      'nb_pilot' , 'nb_data' , 'nb_bit_per_symb' , ...
      'symb_pilot' , 'bit_TX_data' , 'signal_TX' ) ;

% =====================================================================
% USRP TX configuration
% =====================================================================
tx = comm.SDRuTransmitter( ...
        'Platform'              , 'B210'      , ...
        'SerialNum'             , '3241A58'   , ...
        'CenterFrequency'       , fc          , ...
        'ChannelMapping'        , 1           , ...
        'LocalOscillatorOffset' , 20e3        , ...
        'Gain'                  , g_tx        , ...
        'PPSSource'             , 'Internal'  , ...
        'ClockSource'           , 'Internal'  , ...
        'MasterClockRate'       , fs          , ...
        'InterpolationFactor'   , 1           , ...
        'TransportDataType'     , 'int16'     , ...
        'EnableBurstMode'       , 0             ...
        ) ;

% =====================================================================
% Continuous transmission
% =====================================================================
disp( 'Transmitting... press Ctrl+C to stop. Run release(tx) afterwards to free the USRP.' ) ;
while true
    tx( signal_TX ) ;
end
