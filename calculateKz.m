function [Kprime,Kz] = calculateKz(ustar, a, Vzpart, H, diffusivity)
%
% Calculates vertical diffusion
%
% Parameters
% ---------- 
% ustar:
% a:
% Vzpart:
% H:
% diffusivity: string. 'constant', 'parabolic', 'parabolic-constant'
%   Constant turbulent diffusivity
%   Parabolic turbulent diffusivity
%   Parabolic-constant turbulent diffusivity
%
% Returns Kprime, Kz
% -------
% Kprime:
% Kz:
    % Check if ustar=0 and display error if ustar=0
    if ustar(a) == 0
        ed = errordlg('u* can not be equal to zero, try using a very small number different than zero','Error');
        set(ed, 'WindowStyle', 'modal');
        uiwait(ed);
        Kprime = NaN;
        Kz = NaN;
        return
    end
    %+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    % Calculate beta coefficient
    %
    % Reference:                                                  %
    % Van Rijn, L. . (1984). Sediment transport, Part II: Suspended
    % load transport. Journal of Hydraulic Engineering, ASCE,     %
    % 110(11), 1613?1641.                                         %
    % Garcia, T., Zamalloa, C. Z., Jackson, P. R., Murphy, E. A., &
    % Garcia, M. H. (2015). A Laboratory Investigation of the     %
    % Suspension, Transport, and Settling of Silver Carp Eggs     %
    % Using Synthetic Surrogates. PloS One, 10(12), e0145775.     %
    B = 1 + (2*((abs(Vzpart(a))./ustar(a)).^2));
    outrange = abs(Vzpart(a))./ustar(a);
    outrange = outrange > 1;%Out of the function range
    B(outrange) = 3;
    % Vertical location of the eggs with H as coordinate reference
    % In FluEgg Z=0 is the water surface and
    ZR = Z(t - 1,a)' + H(a);

    switch diffusivity;
        case 'constant'
            Kz = B.*(1/15).*H(a).*ustar(a);
            Kprime(a) = 0;
            Kz(Kz < B.*viscosity) = B(Kz < B.*viscosity).*viscosity(Kz < B.*viscosity);  %If eddy diffusivity is less than the water viscosity, use the water viscosity
        case 'parabolic'
            Kprime = B.*0.41.*ustar(a).*(1 - (2*ZR./H(a)));
            Zprime = ZR + (0.5*Kprime*Dt);
            Kz = B.*0.41.*ustar(a).*Zprime.*(1 - (Zprime./H(a)));%Calculated at ofset location 0.5K'Dt
            Kz(Kz < B.*viscosity) = B(Kz < B.*viscosity).*viscosity(Kz < B.*viscosity);  %If eddy diffusivity is less than the water viscosity, use the water viscosity
        case 'parabolic-constant'
            Kprime = B.*0.41.*ustar(a).*(1 - (2*ZR./H(a)));%dimensionless
            Kprime(ZR./H(a) >= 0.5) = 0;  %constant portion
            Zprime = ZR+(0.5*Kprime*Dt);
            Kz = B.*0.41.*ustar(a).*Zprime.*(1 - (Zprime./H(a))); %Calculated at ofset location 0.5K'Dt  % Parabolic function
            Kz(ZR./H(a) >= 0.5) = B(ZR./H(a) >= 0.5).*0.25*0.41.*ustar(ZR./H(a) >= 0.5).*H(ZR./H(a)>=0.5);  % Constant part, corresponding to max diffisivity, refference Van Rijin
            Kz(Kz < B.*viscosity) = B(Kz < B.*viscosity).*viscosity(Kz < B.*viscosity);  %If eddy diffusivity is less than the water viscosity, use the water viscosity
    end %switch
end %calculateKz
