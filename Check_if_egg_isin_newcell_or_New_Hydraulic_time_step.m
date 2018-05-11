function [Exit, minDt] = Check_if_egg_isin_newcell_or_New_Hydraulic_time_step(HECRAS_data)
%
% Parameters
% ----------
% HECRAS_data
%
    % if we are in a new HEC-RAS time step
    %==>We will have new hydraulic conditions for next time step
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
    
    
    % Check if eggs are in a new cell in this jump
    %Find egg index of eggs that are in a new cell
    
    % If not doing forward modeling.
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
            % Continue in the drift ================================================
        else
            
        cell(egg_index)=C; %Update the array that storage the cell number of all the eggs    
        Cell=cell(egg_index);%Cell is the cell were the current egg is located           
        [Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Egg_Direction]=update_local_Hydraulics_and_Temp_of_eggs(egg_index,Cell,Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Q,Egg_Direction);
        end
    end    
end %New cell
