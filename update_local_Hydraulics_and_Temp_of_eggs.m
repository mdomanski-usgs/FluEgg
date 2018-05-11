function [Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Egg_Direction]=update_local_Hydraulics_and_Temp_of_eggs(egg_index,Cell,Vz,Vy,H,W,DH,ustar,T,KS,Vzpart,Q,Egg_Direction)
% Updates egg local Hydraulic and thermal characteristigs
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
    %
    % Calculating the SG of esggs
    Rhoe(egg_index)=(0.5*(Rhoe_ref(t)+Rhoe_ref(t-1)))+0.20646*(Tref-Temp(Cell));%Calculated at half timestep
    SG(egg_index)=Rhoe(egg_index)/Rhow(Cell);%dimensionless
    if SG(egg_index)<1
        Vzpart(egg_index)=0;
    end
    % Dietrich
    Vzpart(egg_index)=-Dietrich(0.5*(D(t)+D(t-1)),SG(egg_index),T(egg_index))/100;
end%update_local_Hydraulics_and_Temp_of_eggs
