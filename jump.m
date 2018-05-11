function [minDt, Exit, ResultsSim] = ...
    jump(Steps, time, alivemodel, alive, X, Y, Z, D, T, H, roughness, ...
    ustar, KS, Egg_Direction, Inv_mod, DH, Dt, T2_Hatching, Vzpart, ...
    Vy, Vz)
%
% Parmeters
% ------
% Steps:
% time:
% alivemodel:
% alive:
% X:
% Y:
% Z:
% D:
%   Diameter
% T:
%	Temperature
% H:
% roughness: 'smooth', 'rough'
%   Determines type of roughness in velocity calculation
% ustar:
%   Shear velocity
% KS:
% Egg_Direction:
% Inv_mod:
% DH:
% Dt:
% T2_Hatching:
% Vzpart:
% Vy:
% Vz:
%
% Returns
% -------
% minDt:
% Exit:
% ResultsSim:
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
    ResultsSim.VX = VX; % is this 
    ResultsSim.Temp = Temp;
    ResultsSim.specie = specie;
    ResultsSim.Spawning = [Xi, Yi, Zi];
    ResultsSim.T2_Hatching = T2_Hatching;
    ResultsSim.T2_Gas_bladder = T2_Gas_bladder;

end %Function Jump

%  3.1.  Calculate vertical diffusion                              %
%                                                                 %
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


function Exit = Check_if_egg_isin_newcell_or_New_Hydraulic_time_step()
    %% Check if it is a new hydraulic_time_step, if so retrive hydraulic input variables
    hFluEggGui = getappdata(0,'hFluEggGui');
    HECRAS_data=getappdata(hFluEggGui,'inputdata');
    
    %% if we are in a new HEC-RAS time step
    %%==>We will have new hydraulic conditions for next time step
    try % for unsteady input
         HECRAS_time_sec=HECRAS_data.HECRAS_time_sec;
        if time(t)+ HECRAS_FluEgg_Timediff>=HECRAS_time_sec(HECRAS_time_counter+1)
            HECRAS_time_index=HECRAS_time_index+Inv_mod; %Take into account inverse modeling when time index should go backward
            HECRAS_time_counter=HECRAS_time_counter+1;
            
            [~,Depth,Q,~,Vlat,Vvert,Ustar,Temp,Width,VX,ks]=Create_Update_Hydraulic_and_QW_Variables(HECRAS_time_index);
            for egg_index=1:length(H)
                Cell=cell(egg_index);%Cell is the cell were the current egg is located 
                [Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Egg_Direction]=update_local_Hydraulics_and_Temp_of_eggs(egg_index,Cell,Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Q,Egg_Direction);
            end
        end
    catch
        %continue if steady state
    end
    
    
    %% Check if eggs are in a new cell in this jump
    %Find egg index of eggs that are in a new cell
    
    %% If not doing forward modeling.
    if Inv_mod==1
    [c,~]=find(X(t,:)'>(CumlDistance(cell)*1000));%If egg is in a new cell
    else %% If we are doing inverse modeling
     %For eggs in cells>1
     %find eggs that crossed a new cell
     [c,~]=find(X(t,cell>1)'<(CumlDistance(cell(cell>1)-1)*1000));
     eggs_in_first_cell=cell==1;
     if sum(eggs_in_first_cell)>=1
      [out,~]=find(X(t,eggs_in_first_cell)'<0);
      if length(out)>1
          ed=errordlg([{'Eggs are outside the domain'},{'Please review river input file or decrese the simulation time.'}],'Error');
            set(ed, 'WindowStyle', 'modal');
            uiwait(ed);
            minDt = 0; %terminate the simulation
            Exit=1;
            return
      end
     end
    end %End if Inv mod
    
    for i=1:length(c)
        egg_index=c(i);
        C=find(X(t,egg_index)<CumlDistance*1000,1,'first'); %Find the new cell where eggs are located
        %%=====================================================================
        if isempty(C)  % If the egg is outside the domain
            ed=errordlg([{'The cells domain have being exceeded.'},{'Please extend the River the domain in the River input file.'},{'Advice:'},{'1.  If your waterbody ends in a lake and you expect the eggs to settle, you can add an additional cell with Vmag=u*=very small value=1e-5m/s.'},{'2.  If your waterbody ends in a stream where you do not expect settling, you need to extend your domain by adding an additional cell with the stream hydrodynamics.'},{'3.  If the hydrodynamics after the last cell are approximately constant, you can extrapolate your domain by extending the cumulative distance of the last cell of your domain, use with caution.'}],'Error');
            set(ed, 'WindowStyle', 'modal');
            uiwait(ed);
            msgbox(['Simulation time=', sprintf('%5.1f',time(t)/3600),'h, ','Mean X=',sprintf('%5.1f',mean(X(t-1,:))/1000),'km'],'FluEgg message','help');
            Exit=1;
            return
            %                 if cellsExtended==0
            %                     msgbox('The last cell was extended to allow the eggs to drift during the simulation time','FluEgg message','Warn');
            %                     cellsExtended=1;
            %                 end
            %% Continue in the drift ================================================
        else
            
        cell(egg_index)=C; %Update the array that storage the cell number of all the eggs    
        Cell=cell(egg_index);%Cell is the cell were the current egg is located           
        [Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Egg_Direction]=update_local_Hydraulics_and_Temp_of_eggs(egg_index,Cell,Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Q,Egg_Direction);
        end
    end
    %% Delete or comment, this is for debug
    %H_unsteady(t,:)=H';
    
    
    %% Update egg local Hydraulic and thermal characteristigs 
    function [Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Egg_Direction]=update_local_Hydraulics_and_Temp_of_eggs(egg_index,Cell,Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Q,Egg_Direction)
       %Vx(c(i))=VX(Cell); %m/s
        Vz(egg_index)=Vvert(Cell); %m/s
        Egg_Direction(egg_index)=Q(Cell)/abs(Q(Cell)); %
        Vy(egg_index)=Vlat(Cell); %m/s
        H(egg_index)=Depth(Cell); %m
        W(egg_index)=Width(Cell); %m
        DH(egg_index)=0.6*Depth(Cell)*Ustar(Cell);
        ustar(egg_index)=Ustar(Cell);
        T(egg_index)=Temp(Cell);
        KS(egg_index)=ks(Cell); %mm
        %%
        %% Calculating the SG of esggs
        Rhoe(egg_index)=(0.5*(Rhoe_ref(t)+Rhoe_ref(t-1)))+0.20646*(Tref-Temp(Cell));%Calculated at half timestep
        SG(egg_index)=Rhoe(egg_index)/Rhow(Cell);%dimensionless
        if SG(egg_index)<1
            Vzpart(egg_index)=0;
        end
        %% Dietrich
        Vzpart(egg_index)=-Dietrich(0.5*(D(t)+D(t-1)),SG(egg_index),T(egg_index))/100;
    end%update_local_Hydraulics&Temp_of_eggs
    
end %New cell
