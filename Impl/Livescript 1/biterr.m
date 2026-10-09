function [ nb_err , ber ] = biterr( bit_TX , bit_RX )
% BITERR  Compute the number of bit errors and the bit error rate (BER)
%
%   [ nb_err , ber ] = biterr( bit_TX , bit_RX )
%
%   Inputs:
%       bit_TX : transmitted bit vector (nb_bit x 1)
%       bit_RX : received bit vector    (nb_bit x 1)
%
%   Outputs:
%       nb_err : number of bit errors
%       ber    : bit error rate = nb_err / nb_bit

nb_bit = length( bit_TX ) ;
nb_err = sum( bit_TX ~= bit_RX ) ;
ber    = nb_err / nb_bit ;

end
