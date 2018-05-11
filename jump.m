function [minDt, Exit, ResultsSim] = ...
    jump(Steps, time, alivemodel, alive, X, Y, Z, D, T, H, roughness, ...
    ustar, KS, Egg_Direction, Inv_mod, DH, Dt, T2_Hatching, Vzpart, ...
    Vy, Vz)
%
% Parmeters
% ------
%   Steps:
%   time:
%   alivemodel:
%   alive:
%   X:
%   Y:
%   Z:
%   D:
%       Diameter
%   T:
%       Temperature
%   H:
%   roughness: 'smooth', 'rough'
%       Determines type of roughness in velocity calculation
%   ustar:
%       Shear velocity
%   KS:
%   Egg_Direction:
%   Inv_mod:
%   DH:
%   Dt:
%   T2_Hatching:
%   Vzpart:
%   Vy:
%   Vz:
%
% Returns
% -------
%   minDt:
%   Exit:
%   ResultsSim:
%
% Calls to other FluEgg functions - (For refactoring purposes only)
% -----
%   calculateKz
%   Check_if_egg_isin_newcell_or_New_Hydraulic_time_step
%   mortality_model
%

    alpha = 2.51; %Average value among several rivers
    beta = 2.47;

    for t=2:Steps

        if alivemodel == 0 %If we are simulating eggs dying
            a = alive(t-1, :) == 1; %a = 1 for eggs that are alive in the previous time step
        else
            a = Z(t-1, :)' > -2*H;
        end

        d = 0.5 * (D(t) + D(t - 1)) / 1000; %D -->diameter (mm)to m

        % Vertical velocity profile
        viscosity = (1.79e-6)./(1 + (0.03368*T(a)) + (0.00021*(T(a).^2)));  % m^2/s
        Zb = Z(t-1, a)' + H(a);
        Zb(Zb < 0.00001) = 0.00001;
        
        % Set current data to the selected data set.
        switch roughness;
            case 'smooth'
                Vxz = ustar(a).*((1/0.41)*log((ustar(a).*Zb)./viscosity) + 5.5);
                Vxz(Vxz < 0) = 0; %Non slip boundary condition;
            case 'rough'
                Vxz = ustar(a).*((1/0.41)*log(Zb./KS(a)) + 8.5);%Vxz of alive eggs
                Vxz(Vxz < 0) = 0; %Non slip boundary condition;
        end
        Vxz = Egg_Direction(a).*Vxz;

        % Streamwise velocity distribution in the transverse direction
        Vxz = abs(Vxz).*betapdf(Y(t - 1, a)'./W(a), alpha, beta);
        % X
        X(t, a) = X(t - 1, a)' + Inv_mod*(Dt*Vxz) + (normrnd(0, 1, sum(a), 1).*sqrt(2*DH(a)*Dt));
        % Reflecting Boundary: Iff Eggs are located outside the
        % upstream boundary condition
        check = X(t, a);
        if Inv_mod == 1
          check(check < d/2) = d - check(check < d/2);
        elseif sum(check < d/2) >= 1
            ed = errordlg([{'Eggs are outside the domain'}, {'Please review river input file or decrese the simulation time.'}], 'Error');
            set(ed, 'WindowStyle', 'modal');
            uiwait(ed);
            minDt = 0; %terminate the simulation
            Exit = 1;
            return
        end
        X(t, a) = check; %The new location of the eggs is check;
        check = []; %reset check
        X(t, ~a) = X(t - 1, ~a);%If they were already dead,leave them in the same position.

        % Y
        Y(t, a) = Y(t - 1, a)' + (Dt*Vy(a)) + (normrnd(0, 1, sum(a), 1).*sqrt(2*DH(a)*Dt));
        Y(t, ~a) = Y(t - 1, ~a);%If they were already dead,leave them in the same position.

        % Calculate Vertical dispersion
        [Kprime, Kz] = calculateKz();

        % Movement in Z

        % if larvae gas bladder stage
        if time(t) > T2_Hatching*3600  %after hatching
            Vzpart(a) = zeros(length(Vzpart(a)), 1);
            Vswim(a) = zeros(length(Vzpart(a)), 1);
        else %% if egg stage
            Vswim(a) = zeros(length(Vzpart(a)), 1);
        end

        Z(t, a) = Z(t - 1, a)' + Dt*(Vz(a) + Vswim(a) + Vzpart(a) + Kprime) + (normrnd(0, 1, sum(a), 1).*sqrt(2*Kz*Dt));%m

        % Movement in Z
        Z(t, ~a) = -H(~a) + d/2;%If they were already dead,leave them in the bottom.
        
        % Check if eggs are in a new cell in this jump
        Exit = Check_if_egg_isin_newcell_or_New_Hydraulic_time_step();
        if Exit == 1  %If eggs are outside the domain
            return
        end
        % Reflective Boundary

        % Reflective in Z
        % If it overpasses the top
        beggs = false(size(Z, 2), 1);
        btop = Z(t, :)' > -d/2;%surface -->calculated based on the total No of eggs
        while sum(btop) > 0
            Z(t, btop) = -d - Z(t, btop);
            b = Z(t, :)' < -H(:) + d/2;% Is any egg overpasses the bottom
            if sum(b) > 0 %if any egg touch the bottom get reflected...
                Z(t, b) = -Z(t, b)'-2*(H(b) - d/2);
                beggs = beggs | b; %this are the eggs that touched the bottom
            end
            btop = Z(t, :)' > -d/2;
        end
        % If it overpasses the bottom
        b = Z(t, :)' < -H(:) + d/2;% Bottom _>need to check this outside the while too.  This is in case we overpassed just the bottom
        while sum(b) > 0
            Z(t, b) = -Z(t, b)' - 2*(H(b) - d/2);
            beggs = beggs | b;
            btop = Z(t, :)' > -d/2;%surface
            if sum(btop) > 0
                Z(t,btop) = -d - Z(t, btop);
            end
            b = Z(t, :)' < -H(:) + d/2;% Bottom
        end

        % Reflective in Y and double check after first jump
        check = Y(t, a);
        w = W(a)';
        while ~isempty(check(check < d/2)) || ~isempty(check(check > w - d/2))
            if ~isempty(check(check < d/2))
                check(check < d/2) = d - check(check < d/2);
                Y(t, a) = check;
                check = [];
                check = Y(t, a);
            end
            if ~isempty(check(check > w - d/2))
                w = W(a)';
                check(check > w - d/2) = 2*w(check > w - d/2) -d - check(check > w - d/2);
                Y(t, a) = check;
                check = [];
                check = Y(t, a);
            end
        end
        check = [];
        %
        Y(t, ~a) = Y(t - 1, ~a);%If they were already dead,leave them in the same position.

        % Alive or dead ??
        if alivemodel == 0
            [alive] = mortality_model(alive, d, a);
        end %mortality model

    end
    % DELETE the waitbar;
    delete(h)
    %
    
    ResultsSim.X = X;
    ResultsSim.Y = Y;
    ResultsSim.Z = Z;
    ResultsSim.time = time;
    ResultsSim.D = D;
    ResultsSim.alive = alive;
    ResultsSim.CumlDistance = CumlDistance;
    ResultsSim.Depth = Depth;
    ResultsSim.Width = Width;
    ResultsSim.VX = VX; % [REFACTOR] where is this initialized?
    ResultsSim.Temp = Temp;
    ResultsSim.specie = specie;
    ResultsSim.Spawning = [Xi, Yi, Zi];
    ResultsSim.T2_Hatching = T2_Hatching;
    ResultsSim.T2_Gas_bladder = T2_Gas_bladder;

end %Function Jump
