data {

// this is the input data that is given from python to stan via a dictionary
    
    int<lower=0> N;           // number of response matrix points (data space bins = number of detectors) times number of pointings in data set
    int<lower=0> Np;          // number of pointings in observation data set
    int<lower=0> y[Np*N];     // y observations = counts in each data space bin (data)

    real bg_model[Np,N];      // BG model (response) for each pointing and detector (any tracer already applied; renormalisation fitted; time nodes fixed below)
  
    // background re-normalisation times
    int<lower=0> Ncuts;       // number of time nodes where/when the background is rescaled
    int bg_cuts[Np];          // translated cut positions (which pointings are the change points)
    int bg_idx_arr[Np];       // data space indices where the Ncuts cuts are applied
  
    //priors on the fitted parameters
    real mu_Abg;              // prior for background scaling (note that the background is ~normalised to the number of counts in each block, i.e. 1.0 or less is expected)
    real sigma_Abg;           // prior width (depends slightly on the data set and observatoin target, but shouldn't be arbitrarily large, 10% of mu_Abg is useful)
  
}


parameters {

// these are the two parameters that we fit: sky amplitude and background amplitude
// note that each component can have more than one parameter to be fitted

    real<lower=1e-8> Abg[Ncuts]; // background model amplitude(s) for each background block (should be fitted around 1.0 when normalised to data)
    
}


transformed parameters {

// definition of our model

    real model_values[Np*N];                                                     // our combined model as a sum of sky models plus background models
    
    for (np in 1:Np) {                                                           // loop over pointings / observation interval
        for (nn in 1:N) {                                                        // loop over data space bins (detectors for SPI, phi/psi/chi for COSI, something else for other things)
            model_values[N*(np-1)+nn] = Abg[bg_idx_arr[np]] * bg_model[np,nn];   // each background block gets its own scaling at the respetive position (index) set before (given as model input)
        }
    }
    
}



model {

// initialisation of model, i.e. parameters, their priors (if any) and likelihood
    
    // normal priors for bg scaling parameters
    Abg ~ normal(mu_Abg,sigma_Abg);        // initialisation of normal prior(s) for bg (defined by input data)

    // likelihood: since we are dealing with count data, this is just the poisson likelihood
    y ~ poisson(model_values);             // that's all, yes

}


generated quantities {

// to check the quality of our fit, we generate some quantities, such as posterior samples (what the model looks like, given the inferred posterior distributions)
// and also PPCs (in how far would future data, drawn from the inferred posterior, match our current data set)

  vector[Np*N] ppc;                                                              // initialise PPC array (same dimensions as data array)

  // for the model posterior, we sum over the data space dimensions to only have time (or pointing) left to show adequacy of fit
  // (this can be arbitrarily extended to have every dimension, but grows huge as f***)
  vector[Np] model_tot = rep_vector(0,Np);                                       // initialise total posterior model to 0 (nan if not)
  vector[Np] model_bg = rep_vector(0,Np);                                        // initialise posterior bg model to 0

  // create posterior samples for PPC
  // and
  // generate the posterior of the model
  for (np in 1:Np) {                                                             // loop over pointings
      for (nn in 1:N) {                                                          // loop over data space
         ppc[N*(np-1)+nn] = poisson_rng(model_values[N*(np-1)+nn]);              // draw poisson samples from fitted model
	 		    						         // fitted model, summed over data-space-dimensions (what it is; only hours/time/pointings left)
         model_bg[np] += Abg[bg_idx_arr[np]] * bg_model[np,nn];			 // no need to loop over bg as only one more but several blocks (taken care of by loop over pointings)
         model_tot[np] += Abg[bg_idx_arr[np]] * bg_model[np,nn];		 // add background to total model posterior
      }
  }

}