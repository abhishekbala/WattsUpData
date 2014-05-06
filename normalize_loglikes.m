%%
% The goal of this function is to return normalized log likelihoods and
% probabilities from a set of log likelihoods.

function prob = normalize_loglikes(LogLike)
    min_log = max(LogLike);
    normLogLike = LogLike - min_log;
    prob = exp(normLogLike);
    sum_probs = sum(prob);
    prob = prob/sum_probs;
end