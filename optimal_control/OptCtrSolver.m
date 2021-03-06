function [Time,States]=OptCtrSolver(sys,para)
%OptCtrSolver  Solve optimal control problem numerically
%   Mainly use ode45 for fast computation, Interpolate points to construct
%   continuous function, only support positive time horizon (TimeVec(i)>=0)
%   [Time,States] = OptCtrSolver(sys,para) with predefine linear system and parameter
%   The dynamic system is in form of x_dot=Ax+Bu;   y=Cx+Du
%   sys:  contain A,B,C,D,Q,R,P,r
%   para: contain h,StartTime,EndTime,TimeVec,NumOfStates,CtlType,InitState
%
%   Option
%   LQT: Continuous Linear Quadratic Tracker, Final Time Horizon
%   LQR: Continuous Linear Quadratic Regulator, Fixed Time
%
%   Example    
%         [t,States]=ode45(sys,para);   
%         plot(t,States);
%     detail example can be found in TestSolver.m
%   
%   author: Rand Xie
%   date:   2015 Mar 17



%% System Structure
A=sys.A;    B=sys.B;    C=sys.C;    D=sys.D;
Q=sys.Q;    R=sys.R;    P=sys.P;    r=sys.r;

%% Parameters
CtlType=para.CtlType;
StartTime=para.StartTime;
h=para.h;
EndTime=para.EndTime;
TimeVec=para.TimeVec;
TimeVecBack=-flipud(TimeVec);

switch CtlType
    case 'LQT'
        %% Solve Subroutine backward
        Ns=size(C'*P*C,1);
        Sb0=reshape(C'*P*C,Ns^2,1);
        SubRoutine=@(t,S) reshape(-(A'*reshape(S,Ns,Ns)+reshape(S,Ns,Ns)*A-reshape(S,Ns,Ns)*B*inv(R)*B'*reshape(S,Ns,Ns)+C'*Q*C),Ns^2,1);
        SubRoutineBack=@(t,S) -SubRoutine(t,S);
        [Time,Sb]=ode45(SubRoutineBack,TimeVecBack,Sb0);
        Sout=flipud(Sb)';
        Sout=reshape(Sout,Ns,Ns,length(TimeVec));

        %% Solve V backward
        Vb0=C'*P*r(EndTime);
        K=@(t) inv(R)*B'*(Sout(:,:,1+floor(t/h))+(Sout(:,:,1+ceil(t/h))-Sout(:,:,1+floor(t/h)))*(t/h-floor(t/h)));
        vRoutine=@(t,v) -((A-B*K(abs(t)))'*v+C'*Q*r(abs(t)));
        vRoutineBack=@(t,v) -vRoutine(t,v);
        [Time,V]=ode45(vRoutineBack,TimeVecBack,Vb0);
        Vout=flipud(V);
        
        %% Calculate State
        InitState=para.InitState;
        Vfun=@(t) (Vout(1+floor(t/h),:)+(Vout(1+ceil(t/h),:)-Vout(1+floor(t/h),:))*(t/h-floor(t/h)));
        u=@(t,x) -K(abs(t))*x+inv(R)*B'*Vfun(abs(t))';
        x_dot=@(t,x) A*x+B*u(t,x);
        [Time,States]=ode45(x_dot,TimeVec,InitState);   
    case 'LQR'
        %% Solve Subroutine backward
        ST=sys.ST; %given
        Ns=size(ST,1);
        Sb0=reshape(ST,Ns^2,1);
        SubRoutine=@(t,S) reshape(-(A'*reshape(S,Ns,Ns)+reshape(S,Ns,Ns)*A-reshape(S,Ns,Ns)*B*inv(R)*B'*reshape(S,Ns,Ns)+Q),Ns^2,1);
        SubRoutineBack=@(t,S) -SubRoutine(t,S);
        [Time,Sb]=ode45(SubRoutineBack,TimeVecBack,Sb0);
        Sout=flipud(Sb)';
        Sout=reshape(Sout,Ns,Ns,length(TimeVec));
        
        %% Calculate K
        K=@(t) inv(R)*B'*(Sout(:,:,1+floor(t/h))+(Sout(:,:,1+ceil(t/h))-Sout(:,:,1+floor(t/h)))*(t/h-floor(t/h)));
        
        %% Solve V backward
        Vb0=C';
        vRoutine=@(t,v) -((A-B*K(abs(t)))'*v);
        vRoutineBack=@(t,v) -vRoutine(t,v);
        [Time,V]=ode45(vRoutineBack,TimeVecBack,Vb0);
        Vout=flipud(V);
        
        %% Solve P backward
        Pb0=0;
        Vfun=@(t) (Vout(1+floor(t/h),:)+(Vout(1+ceil(t/h),:)-Vout(1+floor(t/h),:))*(t/h-floor(t/h)));
        PRoutine=@(t) Vfun(abs(t))'*B*inv(R)*B'*Vfun(abs(t));
        PRoutineBack=@(t) -PRoutine(abs(t));
        [Time,Pb]=ode45(PRoutineBack,TimeVecBack,Pb0);
        Pout=flipud(Pb)';
        
        %% Calculate State and u
        Pfun=@(t) (Pout(1+floor(t/h),:)+(Pout(1+ceil(t/h),:)-Pout(1+floor(t/h),:))*(t/h-floor(t/h)));
        u=@(t,x) -(K(abs(t))-inv(R)*B'*Vfun(abs(t))*inv(Pfun(abs(t)))*Vfun(abs(t))')*x+inv(R)*B'*Vfun(abs(t))*inv(Pfun(abs(t)))*r(abs(t));
        InitState=para.InitState;
        x_dot=@(t,x) A*x+B*u(t,x);
        [Time,States]=ode45(x_dot,TimeVec,InitState);   
end
end
