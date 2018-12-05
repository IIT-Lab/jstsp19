
clear;
clc;

addpath('basic_system_functions');
addpath(genpath('benchmark_algorithms'));

%% Parameter initialization
Nt = 8;
Nr = 32;
total_num_of_clusters = 2;
total_num_of_rays = 3;
Np = total_num_of_clusters*total_num_of_rays;
L = 2;
snr_range = 10;
subSamplingRatio = 0.6;
Imax = 300;
maxRealizations = 1;
T_range = [20:20:100];

%% Variables initialization
error_proposed = zeros(maxRealizations,1);
error_omp = zeros(maxRealizations,1);
error_vamp = zeros(maxRealizations,1);
% error_twostage = zeros(maxRealizations,1);
mean_error_proposed = zeros(length(T_range), length(snr_range));
mean_error_omp =  zeros(length(T_range), length(snr_range));
mean_error_vamp =  zeros(length(T_range), length(snr_range));
% mean_error_twostage =  zeros(length(T_range), length(snr_range));

for snr_indx = 1:length(snr_range)
  snr = 10^(-snr_range(snr_indx)/10);
  snr_db = snr_range(snr_indx);
  
  for t_indx=1:length(T_range)
   T = T_range(t_indx);

   for r=1:maxRealizations
   disp(['realization: ', num2str(r)]);

    [H,Ar,At] = wideband_mmwave_channel(L, Nr, Nt, total_num_of_clusters, total_num_of_rays);
    Gr = Nr;
    Gt = Nt;
    Dr = 1/sqrt(Nr)*exp(-1j*(0:Nr-1)'*2*pi*(0:Gr-1)/Gr);
    Dt = 1/sqrt(Nt)*exp(-1j*(0:Nt-1)'*2*pi*(0:Gt-1)/Gt);
    [Y, Abar, Zbar, W] = wideband_hybBF_comm_system_training(H, Dr, Dt, T, snr);
    Mr = size(W'*Dr, 2);
    Mt = size(Abar, 1);
    % Random sub-sampling
    Omega = zeros(Nr, T);
    for t = 1:T
        indices = randperm(Nr);
        sT = round(subSamplingRatio*Nr);
        indices_sub = indices(1:sT);
        Omega(indices_sub, t) = ones(sT, 1);
    end
    OY = Omega.*Y;
    sT2 = round(subSamplingRatio*T);
    Phi = kron(Abar(:, 1:sT2).', W'*Dr);
    y = vec(Y(:,1:sT2));
    
    % VAMP sparse recovery
    disp('Running VAMP...');
    s_vamp = vamp(y, Phi+1e-6*eye(size(Phi)), snr, 100*L);
    S_vamp = reshape(s_vamp, Mr, Mt);
    error_vamp(r) = norm(S_vamp-Zbar)^2/norm(Zbar)^2
    if(error_vamp(r)>1)
        error_vamp(r) = 1;
    end
       
    
    % Sparse channel estimation
    disp('Running OMP...');
    s_omp = OMP(Phi, y, 100*L, snr);
    S_omp = reshape(s_omp, Mr, Mt);
    error_omp(r) = norm(S_omp-Zbar)^2/norm(Zbar)^2
    if(error_omp(r)>1)
        error_omp(r)=1;
    end
    
%     % Two-stage scheme matrix completion and sparse recovery
%     disp('Running Two-stage-based Technique..');
%     Y_twostage = mc_svt(Y, OY, Omega, Imax, 0.1);
%     s_twostage = vamp(vec(Y_twostage), kron(Abar.', W'*Dr), snr, 200*L);
%     S_twostage = reshape(s_twostage, Mr, Mt);
%     error_twostage(r) = norm(S_twostage-Zbar)^2/norm(Zbar)^2
%     if(error_twostage(r)>1)
%         error_twostage(r) = 1;
%     end
    
    % Proposed
    disp('Running ADMM-based MCSI...');
    rho = 0.0001;
    tau_S = 0.0001; %1/norm(OY, 'fro')^2;
    [~, Y_mcsi] = proposed_algorithm(OY, Omega, W'*Dr, Abar, Imax, rho*norm(OY, 'fro'), tau_S, rho, Y, Zbar);
    S_mcsi = pinv(W'*Dr)*Y_mcsi*pinv(Abar);
    error_proposed(r) = norm(S_mcsi-Zbar)^2/norm(Zbar)^2;

   end

    mean_error_proposed(t_indx, snr_indx) = mean(error_proposed);
    mean_error_omp(t_indx, snr_indx) = mean(error_omp);
    mean_error_vamp(t_indx, snr_indx) = mean(error_vamp);
%     mean_error_twostage(t_indx, snr_indx) = mean(error_twostage);

  end

end


figure;
p11 = semilogy(T_range, (mean_error_omp(:, 1)));hold on;
set(p11,'LineWidth',2, 'LineStyle', '-', 'MarkerEdgeColor', 'Black', 'MarkerFaceColor', 'Black', 'Marker', '>', 'MarkerSize', 8, 'Color', 'Black');
p12 = semilogy(T_range, (mean_error_vamp(:, 1)));hold on;
set(p12,'LineWidth',2, 'LineStyle', '-', 'MarkerEdgeColor', 'Blue', 'MarkerFaceColor', 'Blue', 'Marker', 'o', 'MarkerSize', 8, 'Color', 'Blue');
% p13 = semilogy(T_range, (mean_error_twostage(:, 1)));hold on;
% set(p13,'LineWidth',2, 'LineStyle', '--', 'MarkerEdgeColor', 'Black', 'MarkerFaceColor', 'Black', 'Marker', 's', 'MarkerSize', 8, 'Color', 'Black');
p14 = semilogy(T_range, (mean_error_proposed(:, 1)));hold on;
set(p14,'LineWidth',2, 'LineStyle', '-', 'MarkerEdgeColor', 'Green', 'MarkerFaceColor', 'Green', 'Marker', 'h', 'MarkerSize', 8, 'Color', 'Green');
 
% legend({'TD-OMP [11]', 'VAMP [23]', 'TSSR [15]', 'Proposed'}, 'FontSize', 12, 'Location', 'Best');
legend({'TD-OMP [11]', 'VAMP [23]', 'Proposed'}, 'FontSize', 12, 'Location', 'Best');

xlabel('number of training blocks');
ylabel('NMSE (dB)')
grid on;set(gca,'FontSize',12);
 
savefig('results/errorVStraining.fig')
save('results/errorVStraining.mat')