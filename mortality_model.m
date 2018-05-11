function [alive]=mortality_model(alive,d,a)
    % Load parameters
    Mp=0;   %By predators
    Mb=0;   %By burial or egg damage
    Mc=0;   %Custom mortality e.g. case of a Dam
    Mortality = Mp + Mb + Mc;
    % ================================================================
    alive(t,:)=alive(t-1,:);%If it was dead...it continue dead
    Mortality_model=4;
    switch Mortality_model
        case 1
            % Case 1
            %How many eggs are in the danger zone???
            bed=(0.05*H)-H;% in model coordinates;
            EggsInDanger=Z(t,:)'<bed-d/2&a';%Eggs in the danger zone that are alive
            Mortality=Mortality+0.01*sum(EggsInDanger);
            if  fix(Mortality)>=1
                index=randperm(sum(EggsInDanger));%randomly organize eggs that can die
                [Id,~]=find(EggsInDanger==1);%Tells the Id of eggs in danger
                for k=1:Mortality
                    alive(t,Id(index(k)))=0; %randomly select one egg in danger Id(index(k))
                end
            end
            Mortality=Mortality-fix(Mortality);
        case 2
            % Case 2
            % Consequtive entries to the danger zone
            bed=(0.05*H)-H;% in model coordinates;
            EggsInDanger=Z(t,:)'<bed-d/2;%Eggs in the danger zone
            touch(t,EggsInDanger)=1;
        case 3
            % Case 3
            % A percentage of the eggs that touched the bottom are killed
            EggsInDanger=beggs;%Eggs in risk of dying that are still alive
            Mortality=Mortality+0.01*sum(EggsInDanger);
            if  fix(Mortality)>=1
                index=randperm(sum(EggsInDanger));%randomly organize eggs that can die
                [Id,~]=find(EggsInDanger==1);%Tells the Id of eggs in danger
                for k=1:Mortality
                    alive(t,Id(index(k)))=0; %randomly select one egg in danger Id(index(k))
                end
            end
            Mortality=Mortality-fix(Mortality);
        case 4
            %if it was near the bottom at hatching time, eggs will be dead.
            %at the end of the previous time step before hatching
            if time(t)>(T2_Hatching*3600-Dt)&&count_mortality_at_hatching==0
                alive(t,:)=alive(t-1,:);%If it was dead...it continue dead
                %How many eggs are in the danger zone???
                bed=(0.05*H)-H;% in model coordinates;
                EggsInDanger=Z(t,:)'<bed-d/2&a';%Eggs in the danger zone that are alive
                alive(t,EggsInDanger)=0;
                count_mortality_at_hatching=1;
            end
    end %switch
    % At which cell the egg dye??
    celldead(alive(t,:)==0)=cell(alive(t,:)==0);
end %mortality model
