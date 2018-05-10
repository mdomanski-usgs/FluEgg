function Jump
    Kprime = zeros(size(DH),'single');Kz=Kprime;%Memory allocation
    Mortality = 0;
    waitstep = floor((Steps)/100);
    alpha = 2.51;%Average value among several rivers
    beta = 2.47;
    %%=================================================================================================    
    for t=2:Steps                    
        if ~mod(t, waitstep) || t==Steps
            fill=time(t)/Totaltime;
            % Check for Cancel button press
            if getappdata(h,'canceling')
                delete(h);
                Exit=1;
                return;
            end
            % Report current estimate in the waitbar's message field
            waitbar(fill,h,['Please wait....' sprintf('%12.0f',fill*100) '%']);
        end
        %%
        %a=Z(t-1,:)>0;
        if alivemodel==0 %If we are simulating eggs dying
            a = alive(t-1,:) == 1; %a = 1 for eggs that are alive in the previous time step
        else
            a = Z(t-1,:)' > -2*H;
        end
        %a = Z(t-1,:)' > -H;%Are they alive???
        %
        d = 0.5*(D(t)+D(t-1))/1000; %D -->diameter (mm)to m

        %% Vertical velocity profile
        viscosity = (1.79e-6)./(1+(0.03368*T(a))+(0.00021*(T(a).^2)));%m^2/s
        Zb = Z(t-1,a)'+H(a);
        Zb(Zb<0.00001) = 0.00001;
        % Determine the selected data set.
        str = get(handles.popup_roughness, 'String');
        val = get(handles.popup_roughness,'Value');

        % Set current data to the selected data set.
        switch str{val};
            case 'Log Law Smooth Bottom Boundary (Case flumes)'
                Vxz = ustar(a).*((1/0.41)*log((ustar(a).*Zb)./viscosity)+5.5);
                Vxz(Vxz<0)=0; %Non slip boundary condition;
            case 'Log Law Rough Bottom Boundary (Case rivers)'
                Vxz = ustar(a).*((1/0.41)*log(Zb./KS(a))+8.5);%Vxz of alive eggs
                Vxz(Vxz<0) = 0; %Non slip boundary condition;
        end
        Vxz=Egg_Direction(a).*Vxz;

        %% Streamwise velocity distribution in the transverse direction
        Vxz = abs(Vxz).*betapdf(Y(t-1,a)'./W(a),alpha,beta);
        %% X
        X(t,a) = X(t-1,a)'+Inv_mod*(Dt*Vxz)+(normrnd(0,1,sum(a),1).*sqrt(2*DH(a)*Dt));
        % Reflecting Boundary: Iff Eggs are located outside the
        % upstream boundary condition
        check = X(t,a);
        if Inv_mod==1
          check(check<d/2) = d-check(check<d/2);
        if length(check<d/2)>1 && Warning_flag==0
            hh=msgbox('Some eggs crossed the upstream boundary and where bounced back to the domain','FluEgg Warning','warn');
            pause(2)
            Warning_flag=Warning_flag+1;
            try
            delete(hh)
            catch
            end
        end 
        elseif sum(check<d/2)>=1
            ed=errordlg([{'Eggs are outside the domain'},{'Please review river input file or decrese the simulation time.'}],'Error');
            set(ed, 'WindowStyle', 'modal');
            uiwait(ed);
            minDt = 0; %terminate the simulation
            Exit=1;
            return
        end
        X(t,a) = check; %The new location of the eggs is check;
        check = []; %reset check
        X(t,~a) = X(t-1,~a);%If they were already dead,leave them in the same position.

        %% Y
        Y(t,a) = Y(t-1,a)'+(Dt*Vy(a))+(normrnd(0,1,sum(a),1).*sqrt(2*DH(a)*Dt));
        Y(t,~a) = Y(t-1,~a);%If they were already dead,leave them in the same position.

        %% Calculate Vertical dispersion
        [Kprime,Kz] = calculateKz;

        %% Movement in Z

        %% if larvae gas bladder stage
        if time(t)>T2_Hatching*3600  %after hatching
            Vzpart(a) = zeros(length(Vzpart(a)),1);
            Vswim(a) = zeros(length(Vzpart(a)),1);
        else %% if egg stage
            Vswim(a) = zeros(length(Vzpart(a)),1);
        end

        Z(t,a) = Z(t-1,a)'+Dt*(Vz(a)+Vswim(a)+Vzpart(a)+Kprime)+(normrnd(0,1,sum(a),1).*sqrt(2*Kz*Dt));%m

        %% Movement in Z
        % Z(t,a) = Z(t-1,a)'+Dt*(Vz(a)+Vzpart(a)+Kprime)+(normrnd(0,1,sum(a),1).*sqrt(2*Kz*Dt));%m
        Z(t,~a) = -H(~a)+d/2;%If they were already dead,leave them in the bottom.
        %% Check if eggs are in a new cell in this jump
        Check_if_egg_isin_newcell_or_New_Hydraulic_time_step
        if Exit==1  %If eggs are outside the domain
            delete(h)
            return
        end
        %% Reflective Boundary

        %% Reflective in Z
        %% If it overpasses the top
        beggs = false(size(Z,2),1);
        btop = Z(t,:)'>-d/2;%surface -->calculated based on the total No of eggs
        while sum(btop)>0
            Z(t,btop) = -d-Z(t,btop);
            b=Z(t,:)' < -H(:)+d/2;% Is any egg overpasses the bottom
            if sum(b) > 0 %if any egg touch the bottom get reflected...
                Z(t,b) = -Z(t,b)'-2*(H(b)-d/2);
                beggs = beggs|b; %this are the eggs that touched the bottom
            end
            btop = Z(t,:)'>-d/2;
        end
        %% If it overpasses the bottom
        b=Z(t,:)'<-H(:)+d/2;% Bottom _>need to check this outside the while too.  This is in case we overpassed just the bottom
        while sum(b)>0
            Z(t,b) = -Z(t,b)'-2*(H(b)-d/2);
            beggs = beggs|b;
            btop = Z(t,:)'>-d/2;%surface
            if sum(btop)>0
                Z(t,btop) = -d-Z(t,btop);
            end
            b=Z(t,:)'<-H(:)+d/2;% Bottom
        end

        %% Reflective in Y and double check after first jump
        check = Y(t,a);
        w = W(a)';
        while ~isempty(check(check<d/2))||~isempty(check(check>w-d/2))
            if ~isempty(check(check<d/2))
                check(check<d/2) = d-check(check<d/2);
                Y(t,a)=check;check=[];check=Y(t,a);
            end
            if ~isempty(check(check>w-d/2))
                w = W(a)';
                check(check>w-d/2) = 2*w(check>w-d/2)-d-check(check>w-d/2);
                Y(t,a) = check;
                check = [];
                check = Y(t,a);
            end
        end
        check = [];
        %%
        Y(t,~a) = Y(t-1,~a);%If they were already dead,leave them in the same position.

        %% Alive or dead ??
        if alivemodel==0
            [alive] = mortality_model(alive,d,a);
        end %mortality model

    end
    %% DELETE the waitbar;
    delete(h)
    %%
    M = msgbox('Please wait FluEgg is saving the results','FluEgg','help');
    %%
    if ~exist(['./results/Results_', get(handles.edit_River_name, 'String'),'_',get(handles.Totaltime, 'String'),'h_',get(handles.Dt, 'String'),'s'],'dir')
        mkdir('./results',['Results_', get(handles.edit_River_name, 'String'),'_',get(handles.Totaltime, 'String'),'h_',get(handles.Dt, 'String'),'s']);
    end
    Folderpath=['./results/Results_', get(handles.edit_River_name, 'String'),'_',get(handles.Totaltime, 'String'),'h_', ...
        get(handles.Dt, 'String'),'s/'];

    %% If Batch mode is activated
    Batchmode=get(handles.Batch,'Checked');
    if strcmp(Batchmode,'on')
        outputfile = [Folderpath,'Results_', get(handles.edit_River_name, 'String'),'_',get(handles.Totaltime, 'String'),'h_', ...
            get(handles.Dt, 'String'),'s','run ',num2str(handles.userdata.RunNumber) '.mat'];
    else
        outputfile = [Folderpath,'Results_', get(handles.edit_River_name, 'String'),'_',get(handles.Totaltime, 'String'),'h_', ...
            get(handles.Dt, 'String'),'s' '.mat'];
    end
    hFluEggGui = getappdata(0,'hFluEggGui');
    setappdata(hFluEggGui, 'outputfile', outputfile);
    %% DELETE_Or_comment_This is for debugging==========================================
%         hFluEggGui = getappdata(0,'hFluEggGui');
%         HECRAS_data=getappdata(hFluEggGui,'inputdata');
%         Depth_HEC_RAS=arrayfun(@(x) x.Riverinputfile(1,3), HECRAS_data.Profiles);
    %%=================================================================
    ResultsSim.X = X;
    ResultsSim.Y = Y;
    ResultsSim.Z = Z;
    ResultsSim.time = time;
    %ResultsSim.touch = touch; % For mortality model
    ResultsSim.D=D;
    ResultsSim.alive=alive;
    ResultsSim.CumlDistance=CumlDistance;
    ResultsSim.Depth=Depth;
    ResultsSim.Width=Width;
    ResultsSim.VX=VX;
    ResultsSim.Temp=Temp;
    ResultsSim.specie=specie;
    ResultsSim.Spawning=[Xi,Yi,Zi];
    ResultsSim.T2_Hatching=T2_Hatching;
    ResultsSim. T2_Gas_bladder= T2_Gas_bladder;
    savefast(outputfile,'ResultsSim');
    %folderName= uigetdir('./results','Folder name to save results');

    %% SAVE RESULTS AS TEXT FILE
    % This section was comented because it was taking a very long time
    % to save, maybe we will anable this in a future version
    % save([Folderpath,'X' '.txt'],'X', '-ASCII');
    % save([Folderpath,'Y' '.txt'],'Y', '-ASCII');
    % save([Folderpath,'Z' '.txt'],'Z', '-ASCII');
    % save([Folderpath,'time' '.txt'],'time', '-ASCII');
    % hFluEggGui=getappdata(0,'hFluEggGui');
    % setappdata(hFluEggGui, 'Folderpath', Folderpath);
    % hdr={'Specie=',specie;'Dt_s=',Dt;'Simulation time_h=',time(end)/3600};
    % dlmcell([Folderpath,'Simulation info' '.txt'],hdr,' ');
    delete(M)%delete message


    %%  3.1.  Calculate vertical diffusion                              %
    %                                                                 %
    function [Kprime,Kz]=calculateKz


        % Check if ustar=0 and display error if ustar=0
        if ustar(a)==0
            ed = errordlg('u* can not be equal to zero, try using a very small number different than zero','Error');
            set(ed, 'WindowStyle', 'modal');
            uiwait(ed);
            return
        end
        %+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        %% Calculate beta coefficient
        %
        % Reference:                                                  %
        % Van Rijn, L. . (1984). Sediment transport, Part II: Suspended
        % load transport. Journal of Hydraulic Engineering, ASCE,     %
        % 110(11), 1613?1641.                                         %

        % Garcia, T., Zamalloa, C. Z., Jackson, P. R., Murphy, E. A., &
        % Garcia, M. H. (2015). A Laboratory Investigation of the     %
        % Suspension, Transport, and Settling of Silver Carp Eggs     %
        % Using Synthetic Surrogates. PloS One, 10(12), e0145775.     %
        B = 1+(2*((abs(Vzpart(a))./ustar(a)).^2));
        outrange = abs(Vzpart(a))./ustar(a);
        outrange = outrange >1;%Out of the function range
        B(outrange) = 3;
        % Vertical location of the eggs with H as coordinate reference
        % In FluEgg Z=0 is the water surface and
        ZR = Z(t-1,a)'+H(a);%ZR(ZR<0.1)=0.1;ZR(ZR>H(1)-0.1)=H(1)-0.1;

        %+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
        %% Gets from GUI user defined option for vertical turbulent diffusivity model
        str = get(handles.popupDiffusivity, 'String');
        val=get(handles.popupDiffusivity,'Value');
        switch str{val};
            case 'Constant Turbulent Diffusivity'
                Kz=B.*(1/15).*H(a).*ustar(a);
                Kprime(a)=0;
                Kz(Kz<B.*viscosity)=B(Kz<B.*viscosity).*viscosity(Kz<B.*viscosity);  %If eddy diffusivity is less than the water viscosity, use the water viscosity
            case 'Parabolic Turbulent Diffusivity'
                Kprime=B.*0.41.*ustar(a).*(1-(2*ZR./H(a)));
                Zprime=ZR+(0.5*Kprime*Dt);
                Kz=B.*0.41.*ustar(a).*Zprime.*(1-(Zprime./H(a)));%Calculated at ofset location 0.5K'Dt
                Kz(Kz<B.*viscosity)=B(Kz<B.*viscosity).*viscosity(Kz<B.*viscosity);  %If eddy diffusivity is less than the water viscosity, use the water viscosity
            case 'Parabolic-Constant Turbulent Diffusivity'
                Kprime=B.*0.41.*ustar(a).*(1-(2*ZR./H(a)));%dimensionless
                Kprime(ZR./H(a)>=0.5)=0;  %constant portion
                Zprime=ZR+(0.5*Kprime*Dt);
                Kz=B.*0.41.*ustar(a).*Zprime.*(1-(Zprime./H(a)));%Calculated at ofset location 0.5K'Dt  %% Parabolic function
                Kz(ZR./H(a)>=0.5)=B(ZR./H(a)>=0.5).*0.25*0.41.*ustar(ZR./H(a)>=0.5).*H(ZR./H(a)>=0.5);  %% Constant part, corresponding to max diffisivity, refference Van Rijin
                Kz(Kz<B.*viscosity)=B(Kz<B.*viscosity).*viscosity(Kz<B.*viscosity);  %If eddy diffusivity is less than the water viscosity, use the water viscosity
        end %switch
    end %calculateKz
end %Function Jump
