function [pfOut1,  wt, pfOut1_mean, pfOut2_mean, rho1] = particle__filter_now(par, mu_rho, sig_rho,y, v, r, alp, nParticle)

phi1 = par(1); % AR in state of wind speed
gam  = par(2); % constants in log wind speed
mu_g = par(3); % location in wind direction for transition
mu_f = par(4); % location in wind direction for marginal
rho_f = par(5); % consentration in wind direction for marginal
V = par(6);
mu_rho = par(7); % constants in log wind speed
sig_rho = par(8);
N = length(y);

pfOut1 = zeros((N-1), nParticle,'gpuArray');
pfOut1_mean = zeros((N-1),1,'gpuArray');
pfOut2 = zeros((N), nParticle,'gpuArray');
pfOut2_mean = zeros((N),1,'gpuArray');
wt = zeros((N-1), nParticle,'gpuArray');
rho1 = zeros((N-1), nParticle,'gpuArray');

a0 = randn(nParticle,1);
t0 = rwrpcauchy(nParticle, mu_f, rho_f);
t0 = arrayfun(@(x) pi_shori(x), t0);


pfOut1(1, :) = a0*sqrt(1-phi1^2);
pfOut2(1, :) = t0;
rho1(1,:) = 0.95*(tanh(sig_rho*a0 + mu_rho )+1)/2;
wt(1,:) = 1 / nParticle;

pfOut1_mean(1) = pfOut1(1,:) * wt(1,:)';
pfOut2_mean(1) = pfOut2(1,:) * wt(1,:)';

N_eff = zeros(nParticle,1);
nEff = N/10;

for it = 2:(N-1)

pfOut1(it,:) = phi1 * pfOut1(it - 1, :) + randn(1, nParticle)*sqrt(1-phi1^2);
rho1(it,:) = 0.95 * ( tanh( sig_rho * pfOut1(it,:) + mu_rho)+1) / 2;
rho1(it,rho1(it,:) == 0) =  5.2736e-17;
rho1(it,rho1(it,:) == 0.95) =  0.9499;
%pfOut2(it+1,:) = arrayfun(@(x,y) r_conditional_WJ(1, x, mu_g, y, mu_f, rho_f, 1), pfOut2(it,:), rho1(it,:));
%pfOut2(it,:) = arrayfun(@(x) pi_shori(x), pfOut2(it,:));
%tmp1 = arrayfun(@(theta, rho_g) d_conditional_WJ(y(it-1), theta, mu_g, rho_g, mu_f, rho_f, 1), pfOut2(it-1,:), rho1(it-1,:));
%tmp1 = arrayfun(@(theta, rho_g) d_conditional_WJ(y(it+1), theta, mu_g, rho_g, mu_f, rho_f, 1), pfOut2(it,:), rho1(it,:));
%tmp1 = arrayfun(@(rho_g) d_conditional_WJ(y(it+1), y(it), mu_g, rho_g, mu_f, rho_f, 1),  rho1(it,:));
tmp1 = d_conditional_WJ(y(it+1), y(it), mu_g, rho1(it,:), mu_f, rho_f, 1);
%tmp2 = arrayfun(@(x) gampdf(v(it)/(gam*exp(x/2)) , V, 1/V)/(gam*exp(x/2)), pfOut1(it,:));
tmp2 = gampdf(v(it)./(gam.*exp(pfOut1(it,:)./2)) , V, 1/V)./(gam.*exp(pfOut1(it,:)./2));

wt(it,:) = (tmp1/sum(tmp1)) .* (tmp2/sum(tmp2)) .* wt(it-1,:);
%wt(it,:) = (tmp1) .* (tmp2) .* wt(it-1,:);
%wt(it,:) = (tmp1) .* (tmp2) .* wt(it-1,:);
wt(it,:) = wt(it,:) / sum(wt(it,:));

%[pfOut1(it,:), pfOut2(it,:)] = Resample2(pfOut1(it,:), pfOut2(it,:), wt(it,:), nParticle);
N_eff(it) = gather(1 / (wt(it,:) * wt(it,:)'));
    if  N_eff(it) < nEff
        
      [pfOut1(it,:)] = Resample3(pfOut1(it,:), wt(it,:), nParticle);
      [rho1(it,:)] = Resample3(rho1(it,:), wt(it,:), nParticle);
      wt(it,:) = 1 / nParticle;
    end

    pfOut1_mean(it) = pfOut1(it,:) * wt(it,:)';
                % pfOut2_mean(it) = pfOut2(it,:) * wt(it,:)';

end



end
