\name{do.call.emjmcmc}
\alias{do.call.emjmcmc}
\title{A help function used by parall.gmj to run parallel chains of (R)(G)MJMCMC algorithms}
\usage{do.call.emjmcmc(vect)}
\arguments{
\item{vect}{a vector of parameters of runemjmcmc as well as several additional fields that must come after runemjmcmc parameters such as: vect$simlen - the number of parameters of runemjmcmc in vect, vect$cpu - the cpu id for to set the unique seed, vect$NM - the number of unique best models from runemjmcmc to base the output report upon}
}
\value{a list of
\item{post.populi}{the total mass (sum of the marginal likelihoods times the priors of the visited models) from the addressed run of runemjmcmc}
\item{p.post}{posterior probabilities of the covariates approximated by the addressed run of runemjmcmc}
\item{cterm}{the best value of marginal likelihood times the prior from the addressed run of runemjmcmc}
\item{fparam}{the final set of covariates returned by the addressed run of runemjmcmc}
}
\seealso{runemjmcmc, parall.gmj}
\keyword{methods}% use one of  RShowDoc("KEYWORDS")
\keyword{models}% __ONLY ONE__ keyword per line