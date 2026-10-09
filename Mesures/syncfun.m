function [ sgl_sync ] = syncfun ( sgl_unsync , sgl_original , fs )

%**************************************************************************
%   This funcion synchronizes a delayed signal with respect to a reference
%   signal. The delayed signal is synchronized and cropped such
%   that its length is identical to the reference signal
%
%   Arguments:
%   - sgl_unsync:   non-synchronized signal
%   - sgl_original: reference signal
%   - fs:           Sampling frequency (supposed identical for both signals
%**************************************************************************

    N_rf = length( sgl_original ) ; % nb of samples of the original signal

    %% Cross-correlation calculation
    [ acor ,lag ] = xcorr( sgl_unsync , sgl_original ) ;                            % Cross-correlation between recorded signal and orignal signal
    ind_start = floor( length( lag ) / 2 ) ;
    acor = acor( ind_start : end ) ;
    lag = lag( ind_start : end ) ;
    
    %% Synchronized the delayed signal
    [ ~ , I ] = max( abs( acor ) ) ;                                                % Get the element for which the cross-correlation is maximum
    lagDiff   = lag( I ) ;                                                          % Index of the delayed signal sample that corresponds to the first element of the reference signal
    t_unsync = 0 : 1/fs : ( length( sgl_unsync ) - 1 ) / fs ;
    
    if lagDiff + N_rf > length( t_unsync ) 
        [ ~ , Icorrec ] = max( abs( acor(1 : ( I - floor( N_rf/2 ) ) ) ) ) ;        % Get the element for which the cross-correlation is maximum
        lagDiff   = lag( Icorrec ) ;                                                % Index of the delayed signal sample that corresponds to the first element of the reference signal
    end
    if ( lagDiff < 0 )     
        [ ~ , Icorrec ] = max( abs( acor( floor( length( lag ) / 2 ) : end ) ) ) ;	% Get the element for which the cross-correlation is maximum
        lagDiff   = lag( Icorrec )                                                	% Index of the delayed signal sample that corresponds to the first element of the reference signal
    end     
    sgl_sync = sgl_unsync( lagDiff + 1 : lagDiff  + N_rf )  ;                       %  Crop the unsynchronized signal to the original signal length starting at the sample that corresponds to the first sample of the orginial signal

end

